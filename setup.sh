#!/bin/bash

# This gem has native C extensions
echo "Installing nokogiri"
gem install nokogiri --no-ri --no-rdoc

echo "Unpacking ruby gems"
mkdir -p vendor/gems/

gems=( cinch rally_api html2md httpclient nokogiri )
for g in ${gems[@]}; do
    gem unpack $g --target=./vendor/gems/
done
