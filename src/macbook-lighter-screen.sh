set -e

device='/sys/class/backlight/intel_backlight/brightness'
current=`cat $device`
max=`cat /sys/class/backlight/intel_backlight/max_brightness`

screen_help () {
    echo 'Usage: macbook-lighter-screen <OPTION> [NUM]'
    echo 'Increase or decrease screen backlight for MacBook'
    echo ''
    echo 'Exactly one of the following options should be specified.'
    echo '  -i [NUM], --inc [NUM]   increase backlight by NUM'
    echo '  -d [NUM], --dec [NUM]   decrease backlight by NUM'
    echo '  -m, --min               close backlight'
    echo '  -M, --max               set backlight to max'
    echo '  -h, --help              print this message'
    echo ''
    echo 'Examples:'
    echo '  # Increase screen backlight by 50'
    echo '  macbook-lighter-screen --inc 50'
    echo ''
    echo '  # Set screen backlight to max'
    echo '  macbook-lighter-screen --max'
}

screen_set() {
    echo $1 > $device
    echo set to $1
}

case $1 in
    -i|--inc)
        screen_set $((current+$2 > max ? max : current + $2))
    ;;
    -d|--dec)
        screen_set $((current < $2 ? 0 : current - $2))
    ;;
    -m|--min)
        screen_set 0
    ;;
    -M|--max)
        screen_set $max
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
