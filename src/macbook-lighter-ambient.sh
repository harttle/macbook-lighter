#!/usr/bin/env bash

light_dev="/sys/devices/platform/applesmc.768/light";
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
ML_INTERVAL=7
# bright enough
ML_BRIGHT=40
# trigger threshold
ML_THRESHOLD=2
# min screen brightness
ML_MIN_BRIGHT=15
# DEBUG
ML_DEBUG=${ML_DEBUG:-false}
$ML_DEBUG && set -e

#####################################################
# Private States
last_light=0

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

function check {
    $ML_DEBUG && echo checking
    lid=$(awk -F: '{print $2}' /proc/acpi/button/lid/LID0/state)
    if [ "$lid" == "closed" ]; then
        $ML_DEBUG && echo lid closed, skip update
        return
    fi

    light=$(get_light)
    diff=$(echo $((light-last_light)) | tr -d -)
    if (( diff < ML_THRESHOLD )); then
        $ML_DEBUG && echo "threshold not reached($last_light->$light), skip update"
        return
    fi

    screen_from=$(cat $screen_dev)
    screen_to=$(echo "$screen_from * $light / $last_light" | bc)
    screen_to=$(screen_range $screen_to)
    transition $screen_from $screen_to $screen_dev

    kbd_from=$(cat $kbd_dev)
    kbd_to=$(echo "$kbd_from * $last_light / $light" | bc)
    transition $kbd_from $kbd_to $kbd_dev

    last_light=$light
}

function watch {
    while true; do
        check
        sleep $ML_INTERVAL
    done
}

function init {
    light=$(get_light)
    last_light=$light
    if (( light >= ML_BRIGHT )); then
        screen_to=$screen_max
        kbd_to=$kbd_max
    else
        screen_to=$(echo "$screen_max * $light / $ML_BRIGHT" | bc)
        screen_to=$(screen_range $screen_to)
        kbd_to=$(echo "$kbd_max * $light / $ML_BRIGHT" | bc)
    fi
    screen_from=$(cat $screen_dev)
    kbd_from=$(cat $kbd_dev)
    transition $screen_from $screen_to $screen_dev
    transition $kbd_from $kbd_to $kbd_dev
}

init
watch
