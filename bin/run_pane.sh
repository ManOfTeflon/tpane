#!/bin/bash

cmd="${@:2}"
pane_type="$1"

current_pane_file="$HOME/.tpane/foreground.pane"
root_dir="$( cd "$( dirname $( realpath "${BASH_SOURCE[0]}" ) )/.." && pwd )"

# debug_log_file="/dev/pts/5"
mkdir -p $HOME/.tpane
exec 300>$HOME/.tpane/lock
flock 300

function debug_log
{
    [ -z "$debug_log_file" ] || echo "${@}" > "$debug_log_file"
}

debug_log ""
debug_log "starting $0 ${@}"

if [ -n "$debug_log_file" ]; then
    exec 2> "$debug_log_file"
fi

function pane_exists
{
    tmux list-panes -a -F "#{pane_id}" | grep -q "$1"
    r=$?
    if (exit $r); then
        debug_log "$1 exists"
    else
        debug_log "$1 does not exist"
    fi
    exit $r
}

function pane_is_current
{
    if [ -f "$current_pane_file" ] && ( pane_exists "$1" ) && [ "$(cat "$current_pane_file")" = "$1" ]; then
        debug_log "$1 is current"
        exit 0
    fi
    debug_log "$1 is not current"
    exit 1
}

foreground_pane="$(tmux list-panes -F "#{pane_active} #{pane_id}" | grep '^1' | awk '{print $2}')"
if (pane_is_current "$foreground_pane"); then
    tmux select-pane -U
    foreground_pane="$(tmux list-panes -F "#{pane_active} #{pane_id}" | grep '^1' | awk '{print $2}')"
fi

debug_log "foreground pane is $foreground_pane"

function hide_current
{
    debug_log "hiding current pane if any"
    if [ -f "$current_pane_file" ]; then
        debug_log "hiding pane $(cat "$current_pane_file")"
        TMUX= tmux new-session -d -s hidden 2>/dev/null
        tmux move-pane -s "$(cat "$current_pane_file")" -t hidden 2>/dev/null
        debug_log "hid pane $(cat "$current_pane_file")"
        rm "$current_pane_file"
    fi
}

function kill_pane
{
    if (pane_is_current "$(cat "$type_pane_file")"); then
        rm "$current_pane_file"
    fi
    debug_log "killing pane $(cat "$type_pane_file")"
    tmux kill-pane -t "$(cat "$type_pane_file")"
    debug_log "killed pane $(cat "$type_pane_file")"
    rm "$type_pane_file"
}

function join_pane
{
    if [ -f "$current_pane_file" ] && ! (pane_is_current "$(cat "$type_pane_file")"); then
        action="swap-pane -d"
        target="$(cat "$current_pane_file")"
    else
        action="join-pane $tmux_args"
        target="$foreground_pane"
    fi
    command=( tmux $action -s "$(cat "$type_pane_file")" -t "$target" )
    "${command[@]}"
    if (exit $?); then
        debug_log "joined pane $(cat "$type_pane_file")"
        cat "$type_pane_file" > $current_pane_file
    else
        debug_log "failed to join pane $(cat "$type_pane_file") with command ${command[@]}"
        rm "$type_pane_file"
    fi
}

function create_pane
{
    debug_log "creating new pane"
    if (interactive "$pane_type"); then
        tmux new-window -d -P -F '#{pane_id}' -t hidden "$root_dir/bin/pane_title.sh '' $cmd" > $type_pane_file
    else
        tmux new-window -d -P -F '#{pane_id}' -t hidden "$root_dir/bin/pane_title.sh '$pane_type' $root_dir/bin/bash_loop.sh $type_fifo $type_lock" > $type_pane_file
        touch $type_log
        # echo "tail -n1000 $type_log" > $type_fifo
    fi
    debug_log "created_pane $(cat "$type_pane_file")"
}

declare -a interactive_logs=( "interactive" "test" "replay" )

function interactive
{
    for log in "${interactive_logs[@]}"; do
        if [ "$log" == "${1}" ]; then
            debug_log "$1 is interactive"
            exit 0
        fi
    done
    debug_log "$1 is not interactive"
    exit 1
}

# If the claimed current pane doesn't exist, empty the file
#
if [ -f "$current_pane_file" ] && ! (pane_exists "$(cat "$current_pane_file")"); then
    debug_log "removing current pane file"
    rm "$current_pane_file"
fi

type_pane_file="$HOME/.tpane/$1.pane"
type_fifo="$HOME/.tpane/$1.fifo"
type_log="$HOME/.tpane/$1.log"
type_lock="$HOME/.tpane/$1.lock"
mkfifo $type_fifo 2>/dev/null

outfile="$(mktemp)"

debug_log "type_pane_file: $type_pane_file"
debug_log "type_fifo: $type_fifo"
debug_log "type_log: $type_log"
debug_log "type_lock: $type_lock"

tmux_args="-v -p 30 -d"

debug_log "tmux args: $tmux_args"

# If the claimed type pane doesn't exist, delete the file
#
if [ -f "$type_pane_file" ] && ! (pane_exists "$(cat "$type_pane_file")"); then
    debug_log "removing type pane file"
    rm "$type_pane_file"
fi

# If the pane type is interactive but no command was given, only act if a background pane exists for that pane type
#
if (interactive "$pane_type") && [ ! -f "$type_pane_file" ] && [ -z "$cmd" ]; then
    exit 0
fi

if [ "$pane_type" = "exit" ]; then
    hide_current

    tmux select-pane -t "$foreground_pane"
    exit 0
fi

# If the pane file is there, attempt to join the specified pane.  If joining fails, remove the file and proceed.  Otherwise, leave the pane file alone.
#
if [ -f "$type_pane_file" ]; then
    if (interactive "$pane_type") && [ -n "$cmd" ]; then
        kill_pane
    elif ! (pane_is_current "$(cat "$type_pane_file")"); then
        join_pane
    fi
fi

if [ ! -f "$type_pane_file" ]; then
    create_pane
    join_pane
fi

if (interactive "$pane_type"); then
    foreground_pane="$(cat "$type_pane_file")"
fi

tmux select-pane -t "$foreground_pane"

if ! (interactive "$pane_type"); then
    while [ "$foreground_pane" != "$(tmux list-panes -F "#{pane_active} #{pane_id}" | grep '^1' | awk '{print $2}')" ]; do
        sleep 0.1
    done
fi

debug_log "pane should be set up"

if ! (interactive "$pane_type") && [ -n "$cmd" ]; then
    debug_log "running commands"
    nohup echo -e "/dev/null echo\n/dev/null echo 'Running: $cmd'\n$outfile $cmd" 2>/dev/null >$type_fifo & disown
    echo -n $outfile
fi

debug_log "done"

