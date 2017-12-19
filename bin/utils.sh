#!/bin/bash

set -e

argv=( "$0" "${@}" )
source_root="$( cd "$( dirname $( realpath "${BASH_SOURCE[0]}" ) )/.." && pwd )"
data_root="$HOME/.tpane"
debug_log_file="$data_root/tpane.log"

mkdir -p $data_root
touch $debug_log_file

if [ -z "$no_logging" ]; then
    if [ -z "$debug_log_file" -o ! -e "$debug_log_file" ]; then
        debug_log_file=/dev/null
    fi

    exec 3>>"$debug_log_file" 2>&3

    function log
    {
        echo "$(date +%T.%N) $(basename ${argv[0]}): ${@}" >&3
    }

else
    function log
    {
        return 0
    }
fi

log ""
log "logging to ${debug_log_file}"
log "starting $0 ${@}"

function pane_exists
{
    if [ -z "$1" ]; then
        return 1
    fi

    tmux list-panes -a -F "#{pane_id}" | grep -q "$1"
    r=$?
    if (exit $r); then
        log "$1 exists"
    else
        log "$1 does not exist"
    fi
    return $r
}

function has_current
{
    [ -s "$current_pane_file" ]
}

function get_current
{
    cat "$current_pane_file"
}

function has_pane
{
    [ -s "$type_pane_file" ]
}

function get_pane
{
    cat "$type_pane_file"
}

function has_pid
{
    [ -s "$type_pid_file" ]
}

function get_pid
{
    cat "$type_pid_file"
}

function has_log
{
    [ -s "$type_log" ]
}

function pane_is_current
{
    if has_current && pane_exists "$1" && [ "$(get_current)" = "$1" ]; then
        log "$1 is current"
        return 0
    fi
    log "$1 is not current"
    return 1
}

function select_type
{
    type_name="$1"
    type_pane_file="$data_root/$type_name/pane"
    type_pid_file="$data_root/$type_name/pid"
    type_fifo="$data_root/$type_name/fifo"
    type_log="$data_root/$type_name/log"
    type_lock="$data_root/$type_name/lock"

    if [ "$type_name" != "exit" ]; then
        mkdir -p "$data_root/$type_name"
    fi

    if [ "$type_name" != "current" ]; then
        log "selection type $type_name"
        log "   type_pane_file: $type_pane_file"
        log "   type_pid_file: $type_pid_file"
        log "   type_fifo: $type_fifo"
        log "   type_log: $type_log"
        log "   type_lock: $type_lock"
    fi
}

function set_foreground
{
    declare type_saved="$type_name"
    select_type foreground

    log "foreground saved: $1"
    echo $1 >$type_pane_file

    select_type "$type_saved"
}

function get_foreground
{
    declare type_saved="$type_name"
    select_type foreground

    cat $type_pane_file
    log "foreground read: $(cat $type_pane_file)"

    select_type "$type_saved"
}

function is_vim
{
    if [ -n "$1" ]; then
        pstree $(tmux display -t $1 -p "#{pane_pid}") | grep "\\bvim\\?\\b" -q
        r=$?
    else
        pstree $(tmux display -p "#{pane_pid}") | grep "\\bvim\\?\\b" -q
        r=$?
    fi

    return $r
}

function get_tty
{
    tmux display -p "#{pane_tty}"
}

function lock_pane
{
    exec 100>$type_lock
    flock 100
}

function gc_pane
{
    if has_pane && ! (pane_exists "$(get_pane)"); then
        log "removing type pane file"
        rm "$type_pane_file"
    fi
}

function hide_current
{
    log "hiding current pane if any"
    if has_current; then
        log "hiding pane $(get_current)"
        tmux move-pane -s "$(get_current)" -t tpane_hidden 2>/dev/null
        log "hid pane $(get_current)"
        rm "$current_pane_file"
    fi
}

function kill_pane
{
    if (pane_is_current "$(get_pane)"); then
        rm "$current_pane_file"
    fi
    log "killing pane $(get_pane)"
    tmux kill-pane -t "$(get_pane)"
    log "killed pane $(get_pane)"
    rm "$type_pane_file"
}

function join_pane
{
    if has_current && ! (pane_is_current "$(get_pane)"); then
        action="swap-pane -d"
        target="$(get_current)"
    else
        action="join-pane $tmux_args"
        target="$(get_foreground)"
    fi
    command=( tmux $action -s "$(get_pane)" -t "$target" )
    "${command[@]}"
    if (exit $?); then
        log "joined pane $(get_pane)"
        get_pane > $current_pane_file
    else
        log "failed to join pane $(get_pane) with command ${command[@]}"
        rm "$type_pane_file"
    fi
}

function create_pane
{
    log "creating new pane"
    mkfifo $type_fifo 2>/dev/null || true
    tmux new-window -d -P -F '#{pane_id}' -t tpane_hidden "$source_root/bin/pane_title.sh '$type_name'" > $type_pane_file
    touch $type_log
    log "created pane $(get_pane)"
}

function run_pane_cmds
{
    cmds=( "${@}" )
    cmds=( "${cmds[@]/%/
}" )

    nohup echo -n "${cmds[@]}" 2>/dev/null >$type_fifo & disown
}

function run_interactive
{
    cmd="/dev/null $(pwd) 1 $@"
    run_pane_cmds $cmd
}

select_type current

current_pane_file="$type_pane_file"

if (TMUX= tmux new-session -d -s tpane_hidden 2>/dev/null); then
    log "created tpane_hidden session"
fi

