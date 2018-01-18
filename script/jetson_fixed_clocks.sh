#!/bin/bash
##########################################################
#  Script to set TX2 CPU clocks at fixed frequency       #
#  Usage:                                                #
#      jetson_fixed_clocks.sh FREQUENCY                  #
#                                                        #
#  FREQUENCY must be one of,                             #
#      345600                                            #
#      499200                                            #
#      652800                                            #
#      806400                                            #
#      960000                                            #
#      1113600                                           #
#      1267200                                           #
#      1420800                                           #
#      1574400                                           #
#      1728000                                           #
#      1881600                                           #
#      2035200                                           #
##########################################################

usage() {
    echo 'Usage:'
    echo '  jetson_fixed_clocks.sh FREQUENCY'
}

if [ -z $1 ]; then
    usage; exit 1
elif ! [[ $1 =~ ^-?[0-9]+$ ]]; then
    echo "[ERROR] Argument must be numeric number"; exit 1
elif [ 345600 -eq $1 ]; then
    FREQ=$1
elif [ 499200 -eq $1 ]; then
    FREQ=$1
elif [ 652800 -eq $1 ]; then
    FREQ=$1
elif [ 806400 -eq $1 ]; then
    FREQ=$1
elif [ 960000 -eq $1 ]; then
    FREQ=$1
elif [ 1113600 -eq $1 ]; then
    FREQ=$1
elif [ 1267200 -eq $1 ]; then
    FREQ=$1
elif [ 1420800 -eq $1 ]; then
    FREQ=$1
elif [ 1574400 -eq $1 ]; then
    FREQ=$1
elif [ 1728000 -eq $1 ]; then
    FREQ=$1
elif [ 1881600 -eq $1 ]; then
    FREQ=$1
elif [ 2035200 -eq $1 ]; then
    FREQ=$1
fi

if [ -z $FREQ ]; then
    echo "[Error] Not supported argument $1"
    echo "        Frequency must be one of 345600, 499200, 652800, 806400, 960000, 1113600"
    echo "        1267200, 1420800, 1574400, 1728000, 1881600, 2035200"
    exit 1
fi

echo "Set all CPU cores frequence at $FREQ"

echo "userspace" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo "345600" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo "$FREQ" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_setspeed

echo "userspace" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
echo "345600" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_min_freq
echo "$FREQ" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_setspeed

echo "userspace" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
echo "345600" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_min_freq
echo "$FREQ" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_setspeed

echo "userspace" > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
echo "345600" > /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq
echo "$FREQ" > /sys/devices/system/cpu/cpu3/cpufreq/scaling_setspeed

echo "userspace" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
echo "345600" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
echo "$FREQ" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_setspeed

echo "userspace" > /sys/devices/system/cpu/cpu5/cpufreq/scaling_governor
echo "345600" > /sys/devices/system/cpu/cpu5/cpufreq/scaling_min_freq
echo "$FREQ" > /sys/devices/system/cpu/cpu5/cpufreq/scaling_setspeed

echo "TX2 CPU status: [$(cat /sys/devices/system/cpu/online)]"
echo "         CPU-0: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)"
echo "         CPU-1: $(cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_cur_freq)"
echo "         CPU-2: $(cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_cur_freq)"
echo "         CPU-3: $(cat /sys/devices/system/cpu/cpu3/cpufreq/scaling_cur_freq)"
echo "         CPU-4: $(cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_cur_freq)"
echo "         CPU-5: $(cat /sys/devices/system/cpu/cpu5/cpufreq/scaling_cur_freq)"

