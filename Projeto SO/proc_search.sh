#!/bin/bash

valid_number_regex='^[0-9]+$'
PIDS=()

for dir in /proc/*/; do
    dir=${dir%*/}
    dir2=$(echo ${dir##*/})
    if [[ $dir2 =~ $valid_number_regex ]] ; then
        PIDS+=($dir2)
    fi
done

for i in ${PIDS[@]}; do
    echo "$i"
done