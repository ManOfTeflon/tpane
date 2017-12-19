#!/bin/bash

source_root="$( cd "$( dirname $( realpath "${BASH_SOURCE[0]}" ) )/.." && pwd )"
source $source_root/bin/utils.sh

return_tmpfile=
interactive=
while :; do
    case "$1" in
        -t)
            return_tmpfile=yes
            ;;
        -i)
            interactive=yes
            ;;
        *)
            break
            ;;
    esac
    shift
done

pane_type="$1"
cmd="${@:2}"

# tmux_args="-v -p 30 -d"
tmux_args="-h -l 80 -d"

log "tmux args: $tmux_args"

select_type current
lock_pane
gc_pane

foreground_pane="${TMUX_PANE}"
log $(get_current)
log ${foreground_pane}
if ! has_current; then
    set_foreground "${foreground_pane}"
fi
log "foreground pane is $foreground_pane"

select_type "$pane_type"

if [ -n "$return_tmpfile" ]; then
    outfile="$(mktemp)"
else
    outfile="/dev/null"
fi

gc_pane

if [ "$pane_type" = "exit" ]; then
    hide_current

    exit 0
fi

# If the pane file is there, attempt to join the specified pane.  If joining fails, remove the file and proceed.  Otherwise, leave the pane file alone.
#
if has_pane; then
    if has_pid && [ -n "$cmd" ]; then
        kill -9 "-$(get_pid)"
    fi

    if ! (pane_is_current "$(get_pane)"); then
        join_pane
    fi
fi

if ! has_pane; then
    create_pane
    join_pane
fi

log "pane should be set up"

if [ -n "$cmd" ]; then
    log "running commands"
    workdir="$(pwd)"

    if [ -n "${interactive}" ]; then
        cmds=( "$outfile $workdir 1 $cmd" )
    else
        cmds=( "echo -e"
               "echo -e '\\e[0;33m╒═══════════'"
               "echo -e '│'"
               "echo -e '│   Running: \\e[m${cmd}\\e[0;33m'"
               "echo -e '│'"
               "echo -e '╘═══════════\\e[m'"
               "echo -e"
        )
        cmds=( "${cmds[@]/#/0 }" )
        cmds=( "${cmds[@]/#/$workdir }" )
        cmds=( "${cmds[@]/#//dev/null }" )

        success="\\n\\e[0;32mSuccess!\\e[m"
        failure="\\n\\e[0;31mFailure!\\e[m"
        cmd="${cmd} && echo -e '${success}' || echo -e '${failure}'"

        cmds=( "${cmds[@]}" "$outfile $workdir 0 $cmd" )
    fi

    run_pane_cmds "${cmds[@]}"

    if [ -n "$return_tmpfile" ]; then
        echo -n $outfile

        log "result will be piped to $outfile"
    fi
fi

if [ -n "${interactive}" -o "${has_pid}" ]; then
    foreground_pane="$(get_pane)"
fi

tmux select-pane -t "$foreground_pane"

log "done"

