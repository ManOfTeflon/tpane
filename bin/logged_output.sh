#!/bin/bash

no_logging=true
source_root="$( cd "$( dirname $( realpath "${BASH_SOURCE[0]}" ) )/.." && pwd )"
source $source_root/bin/utils.sh

pane_type="$1"

select_type $pane_type

title="Log output: $pane_type"

red=200
green=0
blue=255
steps=20

tmux set-window-option -q status-position top
tmux set-window-option -q status-right ""
tmux set-window-option -q status-left ""
tmux set-window-option -q status-utf8 on
tmux set-window-option -q automatic-rename off
tmux set-window-option -q status-bg "#000000"
tmux set-window-option -q window-status-current-format "#[fg=#$(printf "%02x%02x%02x" $red $green $blue),bg=#000000]$title"

# declare -a gradient
# for i in $(seq 0 $[$steps-1]); do
#     color="$(printf "%02x%02x%02x" $[$red*$i/$steps] $[$green*$i/$steps] $[$blue*$i/$steps])"
#     gradient=( "${gradient[@]}" "$color" )
# done
# foreground="$color"
# color_prefix="#"

# gradient=( {232..255} ) # Greyscale
# gradient=( {88..93} ) # Red -> purple
# gradient=( {16..21} {57..52} ) # Blue -> red
# gradient=( {232..240..2} {59..63} {69..64} ) # Black -> grey -> blue -> green
# gradient=( {16..21} {27..22} ) # Black -> blue -> green
gradient=( {232..240..2} {59..63} 105 135 {129..124} ) # Black -> grey -> blue -> red
foreground=165
color_prefix="colour"

columns=$(tmux display -p "#{pane_width}")
buf=2
margin=$[($columns-${#title})/2]
per=1 # $[($margin-$buf)/${#gradient[@]}]
tokens=$(printf "═%.0s" $(seq 1 $per))
title="$(
    printf "#[bg=#000000]"
    for i in "${gradient[@]}" ; do printf "#[fg=$color_prefix${i}]$tokens"; done
    printf "#[fg=%s%s]%*s%s%*s" "$color_prefix" "$foreground" "$buf" "" "$title" $buf ""
    for (( idx=${#gradient[@]}-1 ; idx>=0 ; idx-- )); do printf "#[fg=$color_prefix${gradient[idx]}]$tokens"; done
)"

tmux set-window-option -q window-status-current-format "$title"

contents="$(tail -2000 $type_log)"
echo "$contents" > $type_log

cat $type_log

set -o pipefail
set +e

while :; do
    (
        while :; do
            echo -n >$type_pid_file

            read -u 4 -r file dir interactive line

            if [ "$?" != "0" ]; then
                break
            fi

            if [ -e "$file" -a -d "$dir" ]; then
                (
                    flock 100

                    echo "-1" >"$file"

                    if ((interactive)); then
                        set -m
                        (
                            set +m

                            echo -n $BASHPID >$type_pid_file

                            cd $dir

                            log $line
                            $line
                        )

                        r=$?
                        set +m

                        clear
                        stty sane
                    else
                        (
                            cd $dir

                            bash -c "$line" 2>&1 | tee -a $type_log
                        )

                        r=$?
                    fi

                    echo $r >"$file"
                ) 100>$type_lock
            fi
        done
    ) 4<$type_fifo
done


