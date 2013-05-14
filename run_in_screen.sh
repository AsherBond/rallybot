#!/bin/bash

echo "Starting rallybot in a screen session"
screen -S rallybot -t rallybot -d -m ./rallybot.rb
