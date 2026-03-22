#!/bin/bash
set -e

# ── Helper ────────────────────────────────────────────────────────────────────
is_pi5() {
    grep -aq "Raspberry Pi 5" /proc/device-tree/model 2>/dev/null
}

usage() {
    echo "Usage: bash $(basename "$0") [-uninstall]"
    echo ""
    echo "  (no option)   Install and configure PWM for the detected Raspberry Pi model"
    echo "  -uninstall    Remove PWM packages, overlays, and config entries"
    exit 0
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
do_uninstall() {
    echo "=== Uninstalling PWM setup ==="

    CFG="/boot/firmware/config.txt"

    # 1. Remove rpi-hardware-pwm
    if pip show rpi-hardware-pwm > /dev/null 2>&1; then
        pip uninstall -y rpi-hardware-pwm --break-system-packages
        echo "Removed: rpi-hardware-pwm"
    else
        echo "rpi-hardware-pwm is not installed. Skipping."
    fi

    # 2. Remove pigpio (Pi 1-4 only)
    if ! is_pi5; then
        if dpkg -s python3-pigpio > /dev/null 2>&1; then
            sudo systemctl stop pigpiod.service 2>/dev/null || true
            sudo systemctl disable pigpiod.service 2>/dev/null || true
            sudo apt remove -y pigpio python3-pigpio
            echo "Removed: pigpio, python3-pigpio"
        else
            echo "pigpio is not installed. Skipping."
        fi
    fi

    # 3. Remove dtoverlay entries from config.txt
    if [ -f "$CFG" ]; then
        if grep -qE '^[[:space:]]*dtoverlay=pwm[-a-z0-9]*([, ].*)?$' "$CFG"; then
            sudo cp "$CFG" "$CFG.bak.$(date +%Y%m%d-%H%M%S)"
            sudo sed -i -E '/^[[:space:]]*dtoverlay=pwm[-a-z0-9]*([, ].*)?$/d' "$CFG"
            echo "Removed dtoverlay=pwm* entries from $CFG"
        else
            echo "No pwm dtoverlay entries found in $CFG. Skipping."
        fi
    fi

    # 4. Remove custom Pi 5 overlay file
    if [ -f /boot/firmware/overlays/pwm-pi5.dtbo ]; then
        sudo rm /boot/firmware/overlays/pwm-pi5.dtbo
        echo "Removed: /boot/firmware/overlays/pwm-pi5.dtbo"
    fi

    echo ""
    echo "Uninstall complete. Reboot required to apply dtoverlay changes."
    echo "Run: sudo reboot"
    exit 0
}

# ── Parse arguments ───────────────────────────────────────────────────────────
case "${1:-}" in
    -uninstall) do_uninstall ;;
    -h|-help|--help) usage ;;
    "") ;;  # No argument: proceed with install
    *)
        echo "Unknown option: $1"
        usage
        ;;
esac

# ── 1. Install pigpio (Software PWM / Pi 1-4 only) ───────────────────────────
if is_pi5; then
    echo "Raspberry Pi 5 detected: skipping pigpio install."
else
    yes | sudo apt install -y pigpio python3-pigpio
    sudo systemctl enable pigpiod.service
    sudo systemctl start pigpiod.service
fi

# ── 2. Install rpi-hardware-pwm (Hardware PWM / all models) ──────────────────
pip install rpi-hardware-pwm --break-system-packages


# ── 3. Apply dtoverlay for Hardware PWM ──────────────────────────────────────
CFG="/boot/firmware/config.txt"

if is_pi5; then
    # Pi 5: build and install a custom overlay (uses rp1_pwm0 / rp1_gpio)
    cat << 'DTSEOF' > /tmp/pwm-pi5-overlay.dts
/dts-v1/;
/plugin/;

/{
    compatible = "brcm,bcm2712";

    fragment@0 {
        target = <&rp1_gpio>;
        __overlay__ {
            pwm_pins: pwm_pins {
                pins = "gpio12", "gpio18", "gpio13", "gpio19";
                function = "pwm0", "pwm0", "pwm1", "pwm1";
            };
        };
    };

    fragment@1 {
        target = <&rp1_pwm0>;
        frag1: __overlay__ {
            pinctrl-names = "default";
            pinctrl-0 = <&pwm_pins>;
            status = "okay";
        };
    };
};
DTSEOF

    sudo apt-get install -y device-tree-compiler
    dtc -I dts -O dtb -o /tmp/pwm-pi5.dtbo /tmp/pwm-pi5-overlay.dts
    sudo cp /tmp/pwm-pi5.dtbo /boot/firmware/overlays/
    echo "Copied: /boot/firmware/overlays/pwm-pi5.dtbo"

    # Update config.txt: remove any existing pwm overlay then append pwm-pi5
    sudo cp "$CFG" "$CFG.bak.$(date +%Y%m%d-%H%M%S)"
    sudo sed -i -E '/^[[:space:]]*dtoverlay=pwm[-a-z0-9]*([, ].*)?$/d' "$CFG"
    echo 'dtoverlay=pwm-pi5' | sudo tee -a "$CFG" > /dev/null
    echo "Added to $CFG:"
    grep -n '^dtoverlay=pwm-pi5$' "$CFG"

else
    # Pi 1-4: use the standard pwm-2chan overlay
    sudo cp "$CFG" "$CFG.bak.$(date +%Y%m%d-%H%M%S)"
    sudo sed -i -E '/^[[:space:]]*dtoverlay=pwm[-a-z0-9]*([, ].*)?$/d' "$CFG"
    echo 'dtoverlay=pwm-2chan' | sudo tee -a "$CFG" > /dev/null
    echo "Added to $CFG:"
    grep -n '^dtoverlay=pwm-2chan$' "$CFG"
fi

# ── 4. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "Setup complete. Reboot required to apply dtoverlay changes."
echo "Run: sudo reboot"
