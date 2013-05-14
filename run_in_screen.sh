#!/bin/bash

echo "Killing rallybot screen session"
screen -S rallybot -X stuff 

echo "Starting rallybot in a screen session"
screen -S rallybot -t rallybot -d -m ./rallybot.rb
