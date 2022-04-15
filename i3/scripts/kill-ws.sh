#!/bin/bash

i3-msg "workspace number 1 term; focus parent, focus parent, kill"
i3-msg "workspace number 2 web; focus parent, focus parent, kill"
#trick first kill workspace 4 than 3 so 3 is displayed last
i3-msg "workspace number 4 vm; focus parent, focus parent, kill"
i3-msg "workspace number 3 dev; focus parent, focus parent, kill"

