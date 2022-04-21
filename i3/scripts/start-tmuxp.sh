#!/bin/bash

#
# execute tmuxp loading a terminal with given name
# 
# It makes sure there is only one instance with given name
#
name=$1

if [[ ! $(tmux list-sessions -F \#S |grep $name) ]]; then
  urxvtc -name $name -e tmuxp load $name &
fi
 
