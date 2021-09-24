set -e

# load config
[ -f /etc/macbook-lighter.conf ] && source /etc/macbook-lighter.conf

device=${DEVICE:-intel_backlight}
brightness=/sys/class/backlight/$device/brightness
curr_brightness=`cat $brightness`
max_brightness=`cat /sys/class/backlight/$device/max_brightness`

screen_help () {
    echo 'Usage: macbook-lighter-screen <OPTION> [NUM]'
    echo 'Increase or decrease screen backlight for MacBook'
    echo ''
    echo 'Exactly one of the following options should be specified.'
    echo '  -i [NUM], --inc [NUM]   increase backlight by NUM'
    echo '  -d [NUM], --dec [NUM]   decrease backlight by NUM'
    echo '  -m, --min               close backlight'
    echo '  -M, --max_brightness    set backlight to max_brightness'
    echo '  -h, --help              print this message'
    echo ''
    echo 'Examples:'
    echo '  # Increase screen backlight by 50'
    echo '  macbook-lighter-screen --inc 50'
    echo ''
    echo '  # Set screen backlight to max_brightness'
    echo '  macbook-lighter-screen --max_brightness'
}

screen_set() {
    echo $1 > $brightness
    echo set to $1
}

case $1 in
    -i|--inc)
        screen_set $((curr_brightness + $2 > max_brightness ? max_brightness : curr_brightness + $2))
    ;;
    -d|--dec)
        screen_set $((curr_brightness < $2 ? 0 : curr_brightness - $2))
    ;;
    -m|--min)
        screen_set 0
    ;;
    -M|--max_brightness)
        screen_set $max_brightness
    ;;
    -h|--help)
        screen_help
        exit 0
    ;;
    *)
        echo invalid options
        screen_help
        exit 1
    ;;
esac
