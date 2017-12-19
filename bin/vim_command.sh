#!/bin/bash

source_root="$( cd "$( dirname $( realpath "${BASH_SOURCE[0]}" ) )/.." && pwd )"
source $source_root/bin/utils.sh

foreground_pane="$(get_foreground)"
log "foreground: $foreground_pane"

if is_vim "${foreground_pane}"; then
    tmux select-pane -t "${foreground_pane}"
    tmux send-keys -t "${foreground_pane}" Escape Escape ":$(echo "$@")" Enter
fi

