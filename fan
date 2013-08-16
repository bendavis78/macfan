#!/bin/bash

function set_speed {
    cd /sys/devices/platform/applesmc.768/ || exit 1
    if [[ -f /tmp/fanspeed ]]; then
        IFS=' ' read -a fans < /tmp/fanspeed
        if [[ ${fans[0]} != "-" ]]; then
            echo 1 > fan1_manual
            echo ${fans[0]} > fan1_output
        fi
        if [[ ${fans[1]} != "-" ]]; then
            echo 1 > fan2_manual
            echo ${fans[1]} > fan2_output
        fi
        echo ${fans[0]} ${fans[1]}
    else
        # set back to auto
        echo 0 > fan1_manual
        echo 0 > fan2_manual
        echo "auto"
    fi
}

function get_speed {
    echo "scale=2;6200*($1/100)" | bc | sed -e 's/\..*$//'
}

function main {
    PIDFILE=/var/run/fan-setter.pid
    DAEMON="$(realpath $0)"
    ARGS="-d"
    start-stop-daemon -p $PIDFILE --status
    if [[ "$?" != "0" ]]; then
        echo "fan-setter daemon not running -- starting now."
        gksudo -D "fan-setter daemon" -- start-stop-daemon -Sbmp $PIDFILE -x $DAEMON -- $ARGS
    fi
    if [[ $1 == "auto" ]]; then
        rm -f /tmp/fanspeed
    else
        speed1=$(get_speed $1)
        if [[ -n "$2" ]]; then
            speed2=$(get_speed $2)
        else
            speed2=$speed1
        fi
        echo "$speed1 $speed2" > /tmp/fanspeed;
        echo "Set speed to $speed1/$speed2"
    fi
}

if [[ $1 == "-d" ]]; then
    while true; do
        set_speed
        sleep 1
    done
else
    main $@
fi
