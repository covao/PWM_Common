"""
pwm_common.py
Unified PWM interface supporting:
  - Software PWM via pigpio
  - Hardware PWM via rpi-hardware-pwm
Required libraries:
- pigpio(Software PWM) for raspberrypi-4,zero-2w
- rpi-hardware-pwm(Hardware PWM) for raspberrypi5
"""

class PWM_Common:
    """Unified PWM interface supporting Software PWM (pigpio) and Hardware PWM (rpi-hardware-pwm)."""

    # GPIO pin to Hardware PWM channel mapping (BCM numbering)
    # GPIO 18 / 12 -> channel 0,  GPIO 19 / 13 -> channel 1
    _PIN_TO_CHANNEL = {18: 2, 12: 0, 19: 3, 13: 1}

    def __init__(self, use_hardware_pwm: bool = False):
        """
        Initialize PWM driver.
        :param use_hardware_pwm: True  -> Hardware PWM via rpi-hardware-pwm (GPIO 12/18 or 13/19 only)
                                 False -> Software PWM via pigpio (any GPIO pin)
        """
        self.use_hardware_pwm = use_hardware_pwm
        self._hw_pwm_instances = {}  # {pin: HardwarePWM}

        if use_hardware_pwm:
            from rpi_hardware_pwm import HardwarePWM
            self._HardwarePWM = HardwarePWM
        else:
            import pigpio
            self._pi = pigpio.pi()

    def PWM(self, pin: int, freq: float, duty: float) -> None:
        """
        Set PWM output.
        :param pin:  GPIO pin number (BCM)
        :param freq: Frequency in Hz
        :param duty: Duty cycle 0.0 - 100.0 (%)
        """
        if self.use_hardware_pwm:
            self._pwm_hardware(pin, freq, duty)
        else:
            self._pwm_software(pin, freq, duty)

    def _pwm_hardware(self, pin: int, freq: float, duty: float) -> None:
        """Drive Hardware PWM via rpi-hardware-pwm (channel 0 or 1)."""
        channel = self._PIN_TO_CHANNEL.get(pin)
        if channel is None:
            raise ValueError(
                f"Pin {pin} does not support Hardware PWM. "
                "Use GPIO 12/18 (ch0) or 13/19 (ch1)."
            )
        if pin not in self._hw_pwm_instances:
            # First call: create instance and start
            self._hw_pwm_instances[pin] = self._HardwarePWM(channel, hz=freq)
            self._hw_pwm_instances[pin].start(duty)
        else:
            # Subsequent calls: update frequency and duty cycle
            pwm = self._hw_pwm_instances[pin]
            pwm.change_frequency(freq)
            pwm.change_duty_cycle(duty)

    def _pwm_software(self, pin: int, freq: float, duty: float) -> None:
        """Drive Software PWM via pigpio."""
        if freq == 50:
            # Servo mode: convert duty cycle to pulse width in microseconds
            pulsewidth = duty * 200.0 # Period = 1/50Hz = 20000 µs
            self._pi.set_servo_pulsewidth(pin, int(pulsewidth))
        else:
            self._pi.set_PWM_frequency(pin, int(freq))
            self._pi.set_PWM_range(pin, 10000)               # 10000-step resolution
            self._pi.set_PWM_dutycycle(pin, int(duty * 100)) # duty% * 100 -> 0..10000

    def stop(self, pin: int) -> None:
        """Stop PWM output on the specified pin."""
        if self.use_hardware_pwm:
            pwm = self._hw_pwm_instances.pop(pin, None)
            if pwm is not None:
                pwm.stop()
        else:
            self._pi.set_servo_pulsewidth(pin, 0)
            self._pi.set_PWM_dutycycle(pin, 0)
