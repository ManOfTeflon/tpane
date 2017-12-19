#!/bin/bash

source_root="$( cd "$( dirname $( realpath "${BASH_SOURCE[0]}" ) )/.." && pwd )"
source $source_root/bin/utils.sh

pane_type="$1"

# Set up the scrolling region and write into the non-scrolling line
TMUX= tmux new-session -A -D -s "tpane_$pane_type" "$source_root/bin/logged_output.sh '$pane_type'"

