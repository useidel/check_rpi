#!/bin/sh
# RPi plugin for Nagios/Icinga
# Written by Udo Seidel
#
# Description:
#
# This plugin will check the temperatue of the RPi
#
MYCHECK=""
CUSTOMWARNCRIT=0 # no external defined warning and critical levels

# However, for the temperature we can use a different method
# which does not need elevated rights ...
# good enough for a start ....

# Nagios/Icinga return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

EXITSTATUS=$STATE_UNKNOWN #default


PROGNAME=`basename $0`

print_usage() {
	echo 
	echo " This plugin will check the temperature status of RPi."
	echo 
	echo 
        echo " Usage: $PROGNAME -<t|h> -w <warning level> -c <critical level>"
        echo
        echo "   -t: Temperature in Grad Celsius"
        echo "   -w: WARNING level for temperature"
        echo "   -c: CRITICAL level for temperature" 
	echo 
}

if [ "$#" -lt 1 ]; then
	print_usage
        EXITSTATUS=$STATE_UNKNOWN
        exit $EXITSTATUS
fi

check_temperature_warning_critical() {
if [ $CUSTOMWARNCRIT -ne 0 ]; then
	# check if the levels are integers
	echo $WARNLEVEL | awk '{ exit ! /^[0-9]+$/ }'
	if [ $? -ne 0 ]; then
		echo " warning level ($WARNLEVEL) is not an integer"
		exit $STATE_UNKNOWN
	fi
	echo $CRITLEVEL | awk '{ exit ! /^[0-9]+$/ }'
	if [ $? -ne 0 ]; then
		echo " critical level ($CRITLEVEL) is not an integer"
		exit $STATE_UNKNOWN
	fi
	if [ $WARNLEVEL -gt $CRITLEVEL ]; then
		echo
		echo " The value for critical level has to be equal or higher than the one for warning level"
		echo " Your values are: critcal ($CRITLEVEL) and warning ($WARNLEVEL)"
		echo
		exit $STATE_UNKNOWN
	fi
	if [ $RPITEMP -lt $WARNLEVEL ]; then
		EXITSTATUS=$STATE_OK
		echo "Temperature OK - $RPITEMP 'C | $RPITEMP"
	else
		EXITSTATUS=$STATE_WARNING
		if [ $RPITEMP -lt $CRITLEVEL ]; then
			echo "Temperature WARNING - $RPITEMP 'C | $RPITEMP"
		else
			EXITSTATUS=$STATE_CRITICAL
				echo "Temperature CRITICAL - $RPITEMP 'C | $RPITEMP"
		fi
	fi


else
	echo "Temperature OK - $RPITEMP 'C | $RPITEMP"
fi
}

check_temperature_linux() {
BC="/usr/bin/bc"

# run a basic bc to see if it works
echo "2+2" | $BC > /dev/null 2>&1

if [ $? -ne 0 ]
then
EXITSTATUS=$STATE_CRITICAL
else
EXITSTATUS=$STATE_OK
fi

if [ -e /sys/class/thermal/thermal_zone0/temp ]; then
        RPITEMP=`cat /sys/class/thermal/thermal_zone0/temp`
else
        if [ -e /sys/class/hwmon/hwmon0/temp1_input ]; then
                RPITEMP=`cat /sys/class/hwmon/hwmon0/temp1_input`
        else
                echo " Cannot measure the temperature"
		exit $STATE_UNKNOWN
        fi
fi

RPITEMP=`echo "$RPITEMP / 1000"| $BC`
}


check_temperature_openbsd() {

RPITEMP=`sysctl hw.sensors.bcmtmon0.temp0|cut -f2 -d"="|cut -f1 -d"."`

# check if we have received an integer, i.e. is the hardware supported by bcmtmon
echo $RPITEMP | awk '{ exit ! /^[0-9]+$/ }'
if [ $? -ne 0 ]; then
	echo " Cannot measure the temperature"
	exit $STATE_UNKNOWN
fi

}

check_temperature() {
case `uname -s` in
Linux)
	check_temperature_linux
	check_temperature_warning_critical
	;;
OpenBSD)
	check_temperature_openbsd
	check_temperature_warning_critical
	;;
*)
	print_usage
	exit $STATE_UNKNOWN
	;;
esac
}

while getopts "htw:c:" OPT
do		
	case "$OPT" in
	h)
		print_usage
		exit $STATE_UNKNOWN
		;;
	t)
		MYCHECK=temperature
		;;
        w)
                WARNLEVEL=$3
		CUSTOMWARNCRIT=1
                ;;
        c)
                CRITLEVEL=$5
		CUSTOMWARNCRIT=1
                ;;
	*)
		print_usage
		exit $STATE_UNKNOWN
	esac
done

check_$MYCHECK

exit $EXITSTATUS

