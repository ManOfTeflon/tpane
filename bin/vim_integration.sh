#!/bin/bash
#
# This script sets up vim<->tmux integration.
#
# It allows one to use a single set of keybinds to navigate between
# vim windows and tmux panes.  This makes it feel like vim has a
# terminal emulator built in.

log(){
    # echo $@
    # echo $@ >> ~/tmp/log
    return
}

log ""
log "Start: $@"

[ -z $1 ] && exit

passthrough=$1

log $(tmux display -p "#S #I:#P #{pane_pid}")

if (pstree $(tmux display -p "#{pane_pid}") | grep "vim" -q); then
    log 'Current app is `vim`'
 
    # pass any key through to vim
    exec tmux send-keys C-w $passthrough
else
    log 'Current app is `tmux`'

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
