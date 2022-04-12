#!/bin/bash

#
# execute urxvt terminal with given name
# 
# It makes sure there is only one instance with given name
#
# inspiration: https://dangerous.tech/running-a-script-at-login-with-i3/
#
name=$1

if [[ ! $(pgrep -u $UID -f "urxvt -name ${name}") ]]; then
  urxvt -name $name &
fi
 
