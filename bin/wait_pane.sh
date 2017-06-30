#!/bin/bash

lockfile="$HOME/.tpane/$1.lock"
outfile=$2

while [ -z "$(cat $outfile)" ]; do sleep 1; done

(
    flock 100

    cat $outfile
) 100>$lockfile

