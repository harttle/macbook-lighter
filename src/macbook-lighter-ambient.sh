#!/usr/bin/env bash

lid_dev="/proc/acpi/button/lid/LID0/state";
light_dev="/sys/devices/platform/applesmc.768/light";
power_dev="/sys/class/power_supply/ADP1/online";
screen_dev="/sys/class/backlight/intel_backlight/brightness";
kbd_dev="/sys/class/leds/smc::kbd_backlight/brightness";
screen_max=$(cat /sys/class/backlight/intel_backlight/max_brightness);
kbd_max=$(cat /sys/class/leds/smc::kbd_backlight/max_brightness);

#####################################################
# Settings
# transition duration
ML_DURATION=${ML_DURATION:-1.5}
# frame for each step
ML_FRAME=0.017
# check interval
ML_INTERVAL=5
# bright enough
ML_BRIGHT=40
# trigger threshold
ML_SCREEN_THRESHOLD=10
# min screen brightness
ML_MIN_BRIGHT=15
# keyboard brightness on dark
ML_KBD_BRIGHT=128
# battery dim
ML_BATTERY_DIM=${ML_BATTERY_DIM:-0.2}
# DEBUG
ML_DEBUG=${ML_DEBUG:-false}
$ML_DEBUG && set -e

#####################################################
# Private States
screen_ajusted_at=0
kbd_adjusted_at=0

function get_light {
    val=$(cat $light_dev)   # eg. (41,0)
    echo $((${val:1:-3} + 1))    # eg. 41
}

function transition {
    from=$1
    to=$2
    dev=$3
    $ML_DEBUG && echo "transition $dev from $from to $to"
    length=$(echo "$from - $to" | bc)
    steps=$(echo "$ML_DURATION / $ML_FRAME" | bc)
    for ((step=1; step<=$steps; step++)); do
        result=$(echo "($to - $from) * $step / $steps + $from" | bc)
        echo "$result" > $dev
    done
}

function screen_range {
    screen_to=$1
    if (( screen_to < ML_MIN_BRIGHT )); then
        echo $ML_MIN_BRIGHT
    elif (( screen_to > screen_max )); then
        echo $screen_max
    else
        echo $screen_to
    fi
}

function update_screen {
    light=$1
    screen_from=$(cat $screen_dev)
    screen_to=$(echo "$screen_from * $light / $screen_ajusted_at" | bc)
    screen_to=$(screen_range $screen_to)
    if (( screen_to - screen_from > -ML_SCREEN_THRESHOLD && screen_to - screen_from < ML_SCREEN_THRESHOLD )); then
        $ML_DEBUG && echo "threshold not reached($screen_from->$screen_to), skip update"
        return
    fi
    screen_ajusted_at=$light
    transition $screen_from $screen_to $screen_dev
}

function update_kbd {
    light=$1
    kbd_from=$(cat $kbd_dev)

    $ML_DEBUG && echo light:$light, kbd_adjusted_at:$kbd_adjusted_at, ML_BRIGHT: $ML_BRIGHT
    if (( light >= ML_BRIGHT && kbd_adjusted_at < ML_BRIGHT )); then
        ML_KBD_BRIGHT=$kbd_from
        kbd_to=0
    elif (( light < ML_BRIGHT && kbd_adjusted_at >= ML_BRIGHT )); then
        kbd_to=$ML_KBD_BRIGHT
    fi

    if (( kbd_to == kbd_from )); then
        $ML_DEBUG && echo "kbd threshold not reached($kbd_from->$kbd_to), skip update"
        return
    fi
    kbd_adjusted_at=$light
    transition $kbd_from $kbd_to $kbd_dev
}

function update {
    $ML_DEBUG && echo updating
    lid=$(awk -F: '{print $2}' $lid_dev)
    if [ "$lid" == "closed" ]; then
        $ML_DEBUG && echo lid closed, skip update
        return
    fi

    light=$(get_light)
    update_screen $light
    update_kbd $light
}

function watch {
    while true; do
        update
        sleep $ML_INTERVAL
    done
}

function init {
    light=$(get_light)
    power=$(cat $power_dev)
    screen_ajusted_at=$light
    kbd_adjusted_at=$light
    if (( light >= ML_BRIGHT )); then
        screen_to=$screen_max
        kbd_to=0
    else
        screen_to=$(echo "(1.2 - $ML_BATTERY_DIM) * $screen_max * $light / $ML_BRIGHT" | bc)
        screen_to=$(screen_range $screen_to)
        kbd_to=$ML_KBD_BRIGHT
    fi

    screen_from=$(cat $screen_dev)
    kbd_from=$(cat $kbd_dev)

    transition $screen_from $screen_to $screen_dev
    transition $kbd_from $kbd_to $kbd_dev
}

init
watch
