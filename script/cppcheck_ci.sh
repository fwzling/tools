#!/bin/bash
##########################################################
#  Script to run cppcheck for uos project                #
#  Usage:  cppcheck_ci.sh [options]                      #
#  Options:                                              #
#      -u=<dir-path>  | --uos-home=<dir-path>            #
#      -s=<file-path> | --suppression-list=<file-path>   #
#      -o=<dir-path>  | --output=<file-path>             #
#      -k             | --keep-xml                       #
#      -h             | --help                           #
##########################################################

usage() {
    echo 'Script to run cppcheck for uos project'
    echo 'Usage:'
    echo '  cppcheck_ci.sh [-u|--uos-home]=</path/to/uos/home/dir>'
    echo '                 [-s|--suppression-list]=</path/to/suppression/list/file>'
    echo '                 [-o|--output]=/path/to/cppcheck/results/dir'
}

check_status() {    # (status, command)
    if [ $1 -eq 0 ]; then
        echo ">>> $2 completed"
    else
        echo ">>> $2 failed"
        exit 1
    fi
}

if ! cppcheck_loc="$(type -p cppcheck)" || [ -z "$cppcheck_loc" ]; then
    echo 'cppcheck is not installed. run the command below to install it first.'
    echo '      sudo apt-get install cppcheck'
    exit 1
fi

for arg in "$@"
do
    case $arg in
        -u=*|--uos-home=*) UOS_HOME="${arg#*=}"
        shift
        ;;
        -s=*|--suppression-list=*) SUPP_LIST="${arg#*=}"
        shift
        ;;
        -o=*|--output=*) OUTPUT="${arg#*=}"
        shift
        ;;
        -k|--keep-xml) KEEP_XML='Yes'
        shift
        ;;
        -h|--help) usage; exit 0
        ;;
        *) usage; exit 1
        ;;
    esac
done

if [ -z "$UOS_HOME" ]; then
    echo 'Argument missing: --uos-home='
    usage; exit 1
else
    if [ ! -d "$UOS_HOME" ]; then
        echo 'UOS Home directory does not exist.'
        exit 1
    else
        if [ ! -d "$UOS_HOME/src" ]; then
            echo 'No src directory found in UOS Home directory.'
            exit 1
        fi
    fi

fi

if [ -z "$SUPP_LIST" ]; then
    echo 'Argument missing: --suppression-list='
    usage; exit 1
else
    if [ ! -f "$SUPP_LIST" ]; then
        echo 'Suppression list file does not exsit.'
        exit 1
    fi
fi

if [ -z "$OUTPUT" ]; then
    echo 'Argument missing: --output='
    usage; exit 1
else
    OUTPUT=`realpath $OUTPUT`
fi

echo ">>> Enter UOS Home directory $UOS_HOME"
cd $UOS_HOME

TS=$(date +%Y%m%d%H%M%S)
TMP_XML_OUTPUT="/tmp/cppcheck_results-$TS.xml"

CHECK_COMMAND="cppcheck --enable=performance,portability,missingInclude \
                        -U__AVR -i./src/uos_3rdparty -i./src/uos_depend \
                        -i./src/vtracker/3rdparty \
                        -I ./src/uos_core/include \
                        -I ./src/uos_cv_framework/include \
                        -I ./src/uos_rcslib/uos_rcs/include \
                        -I ./src/uos_base/include \
                        -I ./src/uos_cv_vogm/include \
                        -I ./src/uos_camera/include \
                        -I ./src/ucs_rcslib/rcslib/include \
                        -I ./src/uos_chassis/include \
                        -I ./src/uos_cv_lanedet/uos_lanedet_t/include \
                        -I ./src/uos_gps/include \
                        -I ./src/uos_io/include \
                        -I ./src/uos_lateralctrl/include \
                        -I ./src/uos_lidar/include \
                        -I ./src/uos_local_planner/include \
                        -I ./src/uos_lslam/carto/include \
                        -I ./src/uos_map_planner/include \
                        -I ./src/uos_mot/uos_mot_lidar/include \
                        -I ./src/uos_navigation/include \
                        -I ./src/uos_park_planner/include \
                        -I ./src/uos_planner_base/include \
                        -I ./src/uos_sl_lidar/include \
                        -I ./src/uos_track_planner/include \
                        -I ./src/uos_vlane_planner/include \
                        -I ./src/uos_vrep/include \
                        --suppressions-list=$SUPP_LIST \
                        --suppress=missingIncludeSystem \
                        --xml -j 4 src"
echo $CHECK_COMMAND
$CHECK_COMMAND 2>$TMP_XML_OUTPUT
check_status $? 'CPPCHECK'

REPORT_COMMAND="cppcheck-htmlreport --file=$TMP_XML_OUTPUT \
                                    --source-dir=. --title uos \
                                    --report-dir=$OUTPUT"
echo $REPORT_COMMAND
$REPORT_COMMAND
check_status $? 'HTML-REPORT'

echo ">>> Reports are generated in $OUTPUT"

if [ -z $KEEP_XML ]; then
    rm $TMP_XML_OUTPUT
    check_status $? 'HTML-REPORT'
    echo ">>> Temporary XML report was removed."
fi

if [ -f "$OUTPUT/style.css" ]; then
    echo "<style>" >> "$OUTPUT/index.html"
    cat "$OUTPUT/style.css" >> "$OUTPUT/index.html"
    echo "</style>" >> "$OUTPUT/index.html"
    echo ">>> Style sheet embeded."
fi

echo ">>> Finished!"
