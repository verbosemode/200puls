#!/bin/bash
#
# Script for controlling PulseAudio output devices
# ================================================
#
# - If you find a bug, please let me know
# - If you know how to toggle the mute status of an active PulseAudio sink out of the box from command line, please let me know too
#
# Usage examples from my i3 config
# ================================
#
# bindsym XF86AudioMute exec --no-startup-id /usr/local/bin/200puls mute && killall -SIGUSR1 i3status
# bindsym XF86AudioRaiseVolume exec --no-startup-id /usr/local/bin/200puls raise-volume && killall -SIGUSR1 i3status
# bindsym XF86AudioLowerVolume exec --no-startup-id /usr/local/bin/200puls lower-volume && killall -SIGUSR1 i3status
#
# License
# =======
#
# "THE BEER-WARE LICENSE" (Revision 42):
# <jochenbartl@mail.de> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Jochen Bartl
#
# TODO
# - Error log
#

declare -g -r PACTL=$(which pactl)
declare -g -r NOTIFYSEND=$(which notify-send)

declare -g NOTIFY_ENABLED=1

# Output helper function for Error message
# - Exits shell script!
# Function arguments: $1 - Console output message
print_error() {
	echo "[ERROR] $1"
	exit 1
}

# Output helper function for normal info messages
# Function arguments: $1 - Console output message
print_info() {
	# Not sure if INFO output to STDERR is the best idea, but it works atm(TM, ©)
	echo "[INFO] $1" >&2
}

notify_send() {
	local summary=$1; shift
	local body=$1

	if [ "$NOTIFY_ENABLED" = "1" ]; then
		$NOTIFYSEND "$summary" "$body"
	fi
}

# Return ID of active/RUNNING sink
# FIXME Need to find a way to figure out which device is the fallback
get_active_sink() {
	local -i sinkid=0

	sinkid="$($PACTL list short sinks | grep RUNNING | cut -f1)"

	echo $sinkid
}

# Verify if Sink ID does exist
# Function arguments: $1 - Sink ID
# Returns 1 if ID is valid, 0 if not
is_sink_id_valid() {
	local -i sinkid=$1; shift
	local sinkids=""

	sinkids=$($PACTL list sinks short | awk '{print $1}' | tr "\n" " " | sed 's/ $//')

	for e in $sinkids; do
		if [ "$e" = "$sinkid" ]; then
			echo 1
			return 0
		fi
	done

	echo 0
	return 1
}

is_sink_mute() {
	local -i sinkid=$1; shift
	local -i sinkidvalid
	local mutestat=""

	sinkidvalid=$(is_sink_id_valid $sinkid)

	if [ "$sinkidvalid" != "1" ]; then
		print_error "is_sink_mute: SinkID $sinkid doesn't exist"
	fi

	# Try to find the mute status within the first 15 lines after the match, if not FIXME
	mutestat=$(pactl list sinks | grep -A15 "$(printf "Sink #%i" $sinkid)" | egrep "Mute:" | tr -d "[:space:]" | cut -d":" -f2)

	if [ "$mutestat" = "yes" ]; then
		echo "1"

		return 0
	elif [ "$mutestat" = "no" ]; then
		echo "0"

		return 0
	else
		print_error "[error] is_sink_mute: $mutestat"
		exit 666
	fi
}

get_sink_volume() {
	local -i sinkid=$1
	local vol=""
	local -i volleft=0
	local -i volright=0

	vol=$(pactl list sinks | grep -A15 "$(printf "Sink #%i" $sinkid)" | grep -P "\s+Volume:\s\d:" | sed 's/.*Volume: 0: \+\([0-9]\{1,3\}\)% 1: \+\([0-9]\{1,3\}\)%$/\1_\2/')
	volleft=$(echo $vol | cut -d"_" -f1)
	volright=$(echo $vol | cut -d"_" -f2)

	if [ "$volleft" != "$volright" ]; then
		print_error "get_sink_volume: Volume level on left($volleft)/right($volright) channel is not equal -> Not supported!" 
	else
		echo $volleft
		return 0
	fi
}

toggle_sink_mute() {
	local -i sinkid=$1; shift
	local -i sinkmute

	sinkmute=$(is_sink_mute $sinkid)
	
	if [ "$sinkmute" = "1" ]; then
		print_info "Unmuting sink $sinkid"
		notify_send "200puls" "Mute: off"
		$PACTL set-sink-mute $sinkid 0
	else
		print_info "Muting sink $sinkid"
		notify_send "200puls" "Mute: on"
		$PACTL set-sink-mute $sinkid 1
	fi
}

mute_active_sink() {
	local -i sinkid=$(get_active_sink)
	toggle_sink_mute $sinkid
}

# TODO Make 10% default, but allow custom value via $1
raise_sink_volume() {
	local -i sinkid=$(get_active_sink)
	local -i vol=0


	$PACTL set-sink-volume $sinkid -- +10%

	vol=$(get_sink_volume $sinkid)

	notify_send "Volume" "$vol%"
}

# TODO Make 10% default, but allow custom value via $1
lower_sink_volume() {
	local -i sinkid=$(get_active_sink)
	
	$PACTL set-sink-volume $sinkid -- -10%
	
	vol=$(get_sink_volume $sinkid)

	notify_send "Volume" "$vol%"
}

# The usual help message
usage() {
	echo -e "Usage:\n\n$0 [OPTION]... (mute|raise-volume|lower-volume)\n" 1>&2
	echo -e "\t-q, --quiet\n\t\tDisable notifications\n" 1>&2
	echo -e "Examples:\n\n\t$0 mute\tToggles mute status of the current output device\n" 1>&2
	echo -e "\t$0 raise-volume\tRaise volume of current output device by 10%\n" 1>&2
	echo -e "\t$0 lower-volume\tLower volume of current output device by 10%\n" 1>&2

	exit 2
}

## main()

# Disable notifciations if notify-send is missing
if [ -z "$NOTIFYSEND" ]; then
	NOTIFY_ENABLED=0
fi

tmp_getopts=$(getopt -o hq --long help,quiet -- "$@")
eval set -- "$tmp_getopts"

opt_quiet=0

while true; do
	case "$1" in
		-h|--help) usage;;
		# Disable notifications
		-q|--quiet) opt_quiet=1; shift 1;;
		--) shift; break;;
		*) usage;;
	esac
done

# Disable notifications
if [ "$opt_quiet" = "1" ]; then
	NOTIFY_ENABLED=0
fi

case "$1" in
	'test')
		get_active_sink
		get_sink_volume 0
		is_sink_mute 0
		is_sink_mute 3
	;;
	'mute')
		mute_active_sink
	;;
	'raise-volume')
		raise_sink_volume
	;;
	'lower-volume')
		lower_sink_volume
	;;
	'help')
		usage
	;;
	*)
		echo "YOUR ARGUMENT IS INVALID!"
		usage
	;;
esac

exit 0
