# mackbook-lighter

MacBook keyboard and screen backlight adjust on the ambient light.
Internally, macbook-lighter reads the following files:

* /sys/devices/platform/applesmc.768/light
* /sys/class/backlight/intel_backlight/brightness
* /sys/class/leds/smc::kbd_backlight/brightness
* /sys/class/backlight/intel_backlight/max_brightness
* /sys/class/leds/smc::kbd_backlight/max_brightness

So you're expected to install corresponding Nvidia/Intel drivers first.

## Usage

```bash
# Increase keyboard backlight by 50
macbook-lighter-kbd --inc 50
# Increase screen backlight by 50
macbook-lighter-screen --inc 50
# Set screen backlight to max
macbook-lighter-screen --max
# start auto adjust daemon
systemctl start macbook-lighter
# start auto adjust interactively, root previlege needed
macbook-lighter-ambient
```

## Tested MacBook Versions

* MacBook Pro Late 2013 (11,1)
* Macbook Air 2012
