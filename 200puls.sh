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


declare -g -r PACTL=$(which pactl)

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

# Return ID of active/RUNNING sink
get_active_sink() {
	local -i sinkid

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

toggle_sink_mute() {
	local -i sinkid=$1; shift
	local -i sinkmute

	sinkmute=$(is_sink_mute $sinkid)
	
	if [ "$sinkmute" = "1" ]; then
		print_info "Unmuting sink $sinkid"
		$PACTL set-sink-mute $sinkid 0
	else
		print_info "Muting sink $sinkid"
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

	$PACTL set-sink-volume $sinkid -- +10%
}

# TODO Make 10% default, but allow custom value via $1
lower_sink_volume() {
	local -i sinkid=$(get_active_sink)
	
	$PACTL set-sink-volume $sinkid -- -10%
}

# The usual help message
usage() {
	echo -e "Usage:\n\n$0 (mute|raise-volume|lower-volume)\n" 1>&2
	echo -e "Example:\n\n\t$0 mute\tToggles mute status of the current output device\n" 1>&2
	echo -e "\t$0 raise-volume\tRaise volume of current output device by 10%\n" 1>&2
	echo -e "\t$0 lower-volume\tLower volume of current output device by 10%\n" 1>&2

	exit 2
}

case "$1" in
	'test')
		get_active_sink
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
