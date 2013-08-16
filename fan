#!/bin/bash

PIDFILE=/var/run/fan-setter.pid
SYSDIR=/sys/devices/platform/applesmc.768
CONF=/etc/fan

# safe defaults
MIN=3000
read f1_max < $SYSDIR/fan1_max
read f2_max < $SYSDIR/fan2_max
read f1_min < $SYSDIR/fan1_min
read f2_min < $SYSDIR/fan2_min
(( MAX = f1_max < f2_max ? f1_max : f2_max ))
(( MIN = f1_min > f2_min ? f1_min : f2_min ))

# overrides from conf
. $CONF 2> /dev/null

function safe {
    speed=$1
    (( speed = speed > MAX ? MAX : speed )) 
    (( speed = speed < MIN ? MIN : speed ))
    echo $speed
}

function set_speed {
    cd $SYSDIR || exit 1
    if [[ -f /tmp/fanspeed ]]; then
        IFS=' ' read -a fans < /tmp/fanspeed
        fans[0]=$(safe fans[0])
        fans[1]=$(safe fans[1])
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
    echo "scale=2;$MAX*($1/100)" | bc | sed -e 's/\..*$//'
}

function main {
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
        speed1=$(safe $speed1)
        speed2=$(safe $speed2)
        echo "$speed1 $speed2" > /tmp/fanspeed;
        echo "Set speed to $speed1/$speed2"
    fi
}

if [[ $1 == "-d" ]]; then
    if [[ ! -f /etc/fan ]]; then
        touch /etc/fan
    fi
    while true; do
        set_speed
        sleep 1
    done
elif [[ $1 == "-k" ]]; then
    gksudo -D "fan-setter daemon" -- start-stop-daemon --stop --pidfile=$PIDFILE
    [[ $? == 0 ]] && echo "stopped"
else
    main $@
fi
