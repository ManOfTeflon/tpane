#!/bin/bash
#

[ -z $1 ] && exit

log(){
    # echo $@
    # echo $@ >> ~/tmp/log
    return
}

case $1 in
    'h') cmd="select-pane -L";;
    'j') cmd="select-pane -D";;
    'k') cmd="select-pane -U";;
    'l') cmd="select-pane -R";;
    *) exit 0
esac

pane1=$(tmux list-panes -F '#{?pane_active,active,} #{pane_id}' | grep active | awk '{ print $2 }')
tmux $cmd
pane2=$(tmux list-panes -F '#{?pane_active,active,} #{pane_id}' | grep active | awk '{ print $2 }')

tmux swap-pane -s "$pane2" -t "$pane1"

