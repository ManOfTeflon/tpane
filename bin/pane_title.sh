#!/bin/bash

log="$1"
cmd="${@:2}"

root_dir="$( cd "$( dirname $( realpath "${BASH_SOURCE[0]}" ) )/.." && pwd )"

# Set up the scrolling region and write into the non-scrolling line
TMUX= tmux new-session "$root_dir/bin/logged_output.sh '$log' $cmd"

