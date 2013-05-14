#!/bin/bash

echo "Unpacking ruby gems"
mkdir -p vendor/gems/
gems=( cinch rally_api html2md )
for g in ${gems[@]}; do
    gem unpack $g --target=./vendor/gems/
done
