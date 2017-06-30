#!/bin/bash

tmux list-sessions -F '#{session_id} #{session_name} #{session_attached}' | awk '/[0-9]+ 0$/ { print $1; }' | xargs -n1 tmux kill-session -t

