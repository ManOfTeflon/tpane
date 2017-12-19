#!/bin/bash

source_root="$( cd "$( dirname $( realpath "${BASH_SOURCE[0]}" ) )/.." && pwd )"
source $source_root/bin/utils.sh

pane_type="$1"
outfile="$2"

if [ -z "${outfile}" ]; then
    exit 1
fi

select_type $pane_type

while [ -z "$(cat $outfile)" ]; do sleep 1; done

lock_pane

cat $outfile

