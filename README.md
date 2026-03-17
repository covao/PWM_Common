# pwm_common

A minimal unified PWM interface for Raspberry Pi that switches between Software PWM ([pigpio](http://abyz.me.uk/rpi/pigpio/)) and Hardware PWM ([rpi-hardware-pwm](https://github.com/Pioreactor/rpi_hardware_pwm)) with a single constructor argument.

## Overview

- **Single API** — one method `PWM(pin, freq, duty)` works for both Software and Hardware PWM
- **Runtime switching** — choose SW/HW at instantiation via `use_hardware_pwm` flag
- **Software PWM** — uses pigpio; works on any GPIO pin (BCM numbering)
- **Hardware PWM** — uses rpi-hardware-pwm; jitter-free output on dedicated PWM pins (GPIO 12/18 for channel 0, GPIO 13/19 for channel 1)
- **Unified duty cycle** — duty is always specified as a percentage (0.0–100.0 %) regardless of the backend

| Mode | Library | Available pins | Jitter |
|---|---|---|---|
| Software PWM | pigpio | Any GPIO | Low (DMA-based) |
| Hardware PWM | rpi-hardware-pwm | GPIO 12, 13, 18, 19 only | None |

## Requirements
- Raspberry Pi OS Bookworm or later
- Raspberry Pi 1–5 (hardware PWM only on Pi 5)

## Installation

### 1. Run the setup script (recommended)

`setup_pwm.sh` automatically detects the Raspberry Pi model and configures the appropriate PWM backend.

```bash
bash setup_pwm.sh
sudo reboot
```

## Uninstall

```bash
pip uninstall rpi-hardware-pwm
sudo apt remove python3-pigpio
sudo systemctl disable pigpiod
```

Remove the `dtoverlay=pwm-2chan` (Pi 1–4) or `dtoverlay=pwm-pi5` (Pi 5) line from `/boot/firmware/config.txt` and reboot.

## Example

### Software PWM (pigpio) — any GPIO pin

```python
from pwm_common import PWM_Common

pwm = PWM_Common(use_hardware_pwm=False)

# Servo center position: 1500 us pulse at 50 Hz = 7.5% duty
pwm.PWM(pin=14, freq=50, duty=7.5)

# Motor forward at 60% speed on GPIO 13
pwm.PWM(pin=13, freq=490, duty=60.0)

pwm.stop()
```

### Hardware PWM (rpi-hardware-pwm) — GPIO 12/18 (ch0) or 13/19 (ch1)

```python
from pwm_common import PWM_Common

pwm = PWM_Common(use_hardware_pwm=True)

# Servo center position on GPIO 18 (Hardware PWM channel 0)
pwm.PWM(pin=18, freq=50, duty=7.5)

# Motor forward at 60% speed on GPIO 19 (Hardware PWM channel 1)
pwm.PWM(pin=19, freq=490, duty=60.0)

pwm.stop()
```

### Switching between SW/HW at runtime

```python
from pwm_common import PWM_Common

USE_HARDWARE_PWM = True  # Change to False for Software PWM

pwm = PWM_Common(use_hardware_pwm=USE_HARDWARE_PWM)
pwm.PWM(pin=18, freq=50, duty=7.5)
pwm.stop()
```

### API Reference

```
PWM_Common(use_hardware_pwm=False)
```
| Parameter | Type | Default | Description |
|---|---|---|---|
| `use_hardware_pwm` | bool | `False` | `True`: Hardware PWM (rpi-hardware-pwm), `False`: Software PWM (pigpio) |

```
PWM_Common.PWM(pin, freq, duty)
```
| Parameter | Type | Description |
|---|---|---|
| `pin` | int | GPIO pin number (BCM numbering) |
| `freq` | float | PWM frequency in Hz |
| `duty` | float | Duty cycle 0.0–100.0 (%) |

```
PWM_Common.stop()
```
Stops all PWM outputs and releases resources. Call this on shutdown.
