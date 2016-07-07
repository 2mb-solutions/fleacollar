#!/bin/bash

# This script has the lofty goal of becoming a full configuration utility for mutt.
# Written by Storm Dragon: https://social.stormdragon.tk/storm
# Written by Michael Taboada: https://2mb.social/mwtab
# This is a 2MB Solutions project: https://2mb.solutions
# Released under the terms of  the WTFPL: http://wtfpl.net

# Variables
muttHome="$HOME/.mutt"

# Functions
add_email_address()
{
read -p "Please enter your email address: " emailAddress
if [ -f "$emailAddress" ]; then
read -p "This email address alread exists, would you like to remove it? " continue

}

# This is the main loop of the program
# Let's make a mainmenu variable to hold all the options for the select loop.
mainmenu=('Add Email Address' 'Exit')
select i in "${mainmenu[@]}" ; do
    functionName="${i,,}"
    functionName="${functionName// /_}"
    functionName="${functionName/exit/exit 0}"
    $functionName
done

exit 0
