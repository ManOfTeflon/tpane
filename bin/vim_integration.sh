#!/bin/bash
#
# This script sets up vim<->tmux integration.
#
# It allows one to use a single set of keybinds to navigate between
# vim windows and tmux panes.  This makes it feel like vim has a
# terminal emulator built in.

no_logging=true
source_root="$( cd "$( dirname $( realpath "${BASH_SOURCE[0]}" ) )/.." && pwd )"
source $source_root/bin/utils.sh

[ -z $1 ] && exit

passthrough=$1

log $(tmux display -p "#S #I:#P #{pane_pid}")

if is_vim; then
    log 'current app is `vim`'
 
    # pass any key through to vim
    exec tmux send-keys C-w $passthrough
else
    log 'current app is `tmux`'

    # this list is pulled from `tmux list-keys`.  once tmux supports multiple
    # key-tables, this should be a lot prettier.
    case $passthrough in
        'h') passthrough="select-pane -L";;
        'j') passthrough="select-pane -D";;
        'k') passthrough="select-pane -U";;
        'l') passthrough="select-pane -R";;
        *) exit 0
    esac
    tmux $passthrough
fi
