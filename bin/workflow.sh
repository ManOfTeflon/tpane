#!/bin/bash

exec 2>&1 >/dev/null
# exec 2>&1 >/dev/pts/26

foreground_pane="$(tmux list-panes -F "#{pane_active} #{pane_id}" | grep '^1' | awk '{print $2}')"

root_dir="$( cd "$( dirname $( realpath "${BASH_SOURCE[0]}" ) )/.." && pwd )"

if ! (pstree $(tmux display -p "#{pane_pid}") | grep "vim" -q); then
    pgrep vim
    tmux display -p "#{pane_pid}"
    pstree $(tmux display -p "#{pane_pid}")
    echo "vim is not the foreground!"
    exit 1
fi

echo "waiting: $@"

build_success="$($root_dir/bin/wait_pane.sh build $@)"

echo "foreground: $foreground_pane"
tmux select-pane -t "${foreground_pane}"

echo "returned: $build_success"
if [ "$build_success" = "0" ]; then
    tmux send-keys -t "${foreground_pane}" Escape Escape :BuildSuccess Enter
    echo "sent success"
else
    tmux send-keys -t "${foreground_pane}" Escape Escape :BuildFailure Enter
    echo "sent failure"
fi

