#!/bin/bash

# Modify these if you like
slp="1"
time_scale="59"

# Don't change these
tmp=""
min="0"
offset="0"
#new_per="0"
#new_desk="0"
update_now="0"

old_bar_text=""
bar_text=""

options="$1"
minute_scaled="$[ $time_scale / $slp ]"
#declare -a cmd_arr=()

finish() {
	unset per
	unset tmp
	unset time_scale
#	unset new_per
	unset min
	unset options
#	unset new_desk
	unset update_now
	unset cur
	unset offset
	unset wind
	unset desk
	unset slp
	unset minute_scaled
	unset task_hexs
	unset task_wins
	unset active_win
	unset old_active_win
	unset pc_name
	unset max_task_len
	unset win_list
	unset old_win_num
	unset win_num
	unset win_desk
	unset active_col
	unset not_col
	unset tasks
	unset spacer
	unset hex_i
	unset win_i
	unset win_len
	unset format_len
	unset cut_len
	unset spacer_len
	unset name_len
}
trap finish EXIT

get_battery() {
	# This command will change in the future
    per="$(acpi --battery | cut -d, -f2)"
}

get_date() {
	cur="$(date '+%a %b %d, %H:%M')"
}

get_desktop() {
	tmp="$(wmctrl -d)"
	tmp="${tmp%*  \* *}"
	desk="${tmp: -1}"
	update_now="1"
}

declare -a task_hexs=()
declare -a task_wins=()
pc_name="$(uname -n)"
max_task_len="100"
active_win=""
old_active_win=""
win_num=""
old_win_num=""
win_list=""
active_col="%{B#545454}"
not_col="%{B-}"
format_len="4"

get_tasks() {
	win_num="$(ps -u --no-headers | wc -l)"
	get_active_win
	if [ "$active_win" != "$old_active_win" ] || [ "$old_win_num" != "$win_num" ]; then
		IFS='
		'
		win_list="$(wmctrl -l)"
		win_list="${win_list//$pc_name/}"
		old_win_num="$win_num"
		old_active_win="$active_win"
		task_hexs=()
		task_wins=()
		for line in $win_list; do
			task_hexs+=( "${line:0:10}" )
			line="${line:12}"
			win_desk="${line%% *}"
			win_name="${line#$win_desk*}"
#			win_name="${win_name:2}"
			task_wins+=( "$win_desk""${win_name:2}" )
		done
		format_tasks
	fi
}

get_active_win() {
	active_win="$(xprop -root _NET_ACTIVE_WINDOW)"
	active_win="${active_win#* # }"
	tmp="${#active_win}"
	if [ "$tmp" -gt "3" ]; then
		for i in `seq 0 $[ 9 - $tmp ]`; do
			active_win="${active_win:0:2}""0""${active_win:2}"
		done
	else
		get_desktop
	fi
}

format_tasks() {
	tasks=""
	# still needs work but it'll do for now
	win_len="$[ $max_task_len / ${#task_hexs[@]} ]"
	for i in `seq 0 $[ ${#task_hexs[@]} - 1 ]`; do
		hex_i="${task_hexs[$i]}"
		win_i="${task_wins[$i]}"
		spacer=""
		name_len="$[ ${#win_i} + $format_len ]"
		if [ "$name_len" -lt "$win_len" ]; then
			spacer_len="$[ $win_len - $name_len ]"
			for i in `seq 0 $spacer_len`; do
				spacer+=" "
			done
		fi
		cut_len="$[ $win_len - $format_len - ${#spacer} ]"
		if [ "$active_win" = "$hex_i" ]; then
			desk="${win_i:0:1}"
			tasks+=" $desk) $active_col"
			tasks+="${win_i:1:$cut_len}$spacer$not_col"
		else
			tasks+=" ${win_i:0:1}) "
			# command on left click
			tasks+="%{A:wmctrl -a $hex_i -i; xdotool windowactivate $hex_i:}"
			tasks+="${win_i:1:$cut_len}$spacer%{A}"
		fi
	done
	update_now="1"
}

get_seconds_offset() {
	offset="$(date '+%S')"
	if [ "${offset:0:1}" = "0" ]; then
		offset="${offset:1}"
	fi
	offset="$[ $time_scale - $offset ]"
	offset="$[ $offset / $slp ]"
}

sync_time_update() {
	tmp="$(date '+%S')"
	if [ "${tmp:0:1}" = "0" ]; then
		tmp="${tmp:1}"
	fi
	if [ "$tmp" -gt "5" ]; then
		minute_scaled="$[ $time_scale - $tmp + 2 ]"
		minute_scaled="$[ $minute_scaled / $slp ]"
	elif [ "$tmp" -gt "2" ]; then
		minute_scaled="$[ $minute_scaled - 1 ]"
	else
		minute_scaled="$[ $time_scale / $slp ]"
	fi
}

update_bar() {
	if [ "$update_now" -eq "1" ]; then
		bar_text="%{l} $desk$tasks""%{c}$cur""%{r}$per "
		echo "$bar_text"
		update_now="0"
#		echo "update bar"
#		echo
	fi
#	printf "%s%s%s\\n" "$bar_text"
}

init_values() {
	get_seconds_offset
	get_date
	get_battery
	get_tasks
}

main() {
	init_values

	for i in `seq 0 $offset`; do
		get_tasks
		update_bar
		sleep "$slp"
	done
	unset offset

	sync_time_update

	while true; do
		get_date
		if [ "$min" -eq "5" ]; then
			get_battery
			sync_time_update
			min="0"
		fi
		update_now="1"
		for i in `seq 0 $minute_scaled`; do
			get_tasks
			update_bar
			sleep "$slp"
		done
		min="$[ $min + 1 ]"
	done
}

main
