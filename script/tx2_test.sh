#!/bin/bash

## Usage: Collect TX2 CPU/GPU performance along with temperature
#    ./tx2_test.sh 

TEGRASTATS_TMPOUT=/tmp/tegrastats.out
TEGRASTATS_PIDFILE=/tmp/tegrastats.pid

if [ -f $TEGRASTATS_PIDFILE ]; then
    pid=$(cat $TEGRASTATS_PIDFILE)
    sudo kill $pid
fi
    
sudo $HOME/tegrastats > $TEGRASTATS_TMPOUT &
TEGRASTATS_PID=$(echo $!)
echo $TEGRASTATS_PID > $TEGRASTATS_PIDFILE

function term_handler() {
    echo "** Trapped CTRL-C. Terminate tegrastats process now."
    echo "Kill process $TEGRASTATS_PID"
    sudo killall tegrastats
    sudo rm $TEGRASTATS_PIDFILE
    exit 0
}

trap 'term_handler' SIGINT

while true
do
    sensor_temps=$(sensors -A)
    echo $sensor_temps
    echo $(tail -n 1 $TEGRASTATS_TMPOUT)
    echo "------------------------------"
    sleep 1
done
