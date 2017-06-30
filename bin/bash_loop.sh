#!/bin/bash

while :; do
    (
        while :; do
            read file line

            if [ "$?" != "0" ]; then
                break
            fi

            (
                flock 100

                echo "-1" >"$file"

                bash -c "unbuffer $line"
                r=$?

                echo $r >"$file"
            ) 100>$2
        done
    ) <$1
done

