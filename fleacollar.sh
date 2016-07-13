#!/bin/bash

# This script has the lofty goal of becoming a full configuration utility for mutt.
# Written by Storm Dragon: https://social.stormdragon.tk/storm
# Written by Michael Taboada: https://2mb.social/mwtab
# This is a 2MB Solutions project: https://2mb.solutions
# Released under the terms of  the WTFPL: http://wtfpl.net

# Variables
muttHome=~/.muttest

# Functions
create_mailcap()
{
    if ! [ -d "$muttHome" ]; then
        mkdir -p "$muttHome"
    fi
    if ! [ -f "$muttHome/mailcap" ]; then
        # Find desired browser
        local x=0
        for i in\
        chromium\
        elinks\
        epiphany\
        firefox\
        google-chrome\
        links\
        lynx\
        midori\
        seamonkey
        do
            unset browserPath
            browserPath="$(command -v $i)"
            if [ -n "$browserPath" ]; then
                browsers[$x]="$browserPath"
                ((x++))
            fi
        done
        echo "Select browser for viewing html email:"
        select i in "${browsers[@]##*/}" ; do
            browserPath="$i"
            if [ -n "$browserPath" ]; then
                break
            fi
        done
        case "${browserPath##*/}" in
            "elinks")
                echo "text/html; $browserPath -dump -force-html -dump-charset utf-8 -no-numbering %s; nametemplate=%s.html; copiousoutput" > "$muttHome/mailcap"
            ;;
            "lynx")
                echo "text/html; $browserPath -dump %s; nametemplate=%s.html; copiousoutput" > "$muttHome/mailcap"
            ;;
            *)
                echo "text/html; $browserPath %s; nametemplate=%s.html; copiousoutput" > "$muttHome/mailcap"
        esac
        if command -v antiword &> /dev/null ; then
            echo "application/msword; $(command -v antiword) %s; copiousoutput" >> "$muttHome/mailcap"
        fi
    fi
}

add_email_address()
{
    read -p "Please enter your email address: " emailAddress
    if ! [[ "$emailAddress" =~ .*@.*\..* ]]; then
        read -p "this appears to be an invalid email address. Continue anyway? " continue
        if [ "${continue^}" != "Y" ]; then
            exit 0
        fi
    fi
    if [ -f "$muttHome/$emailAddress" ]; then
        read -p "This email address already exists. Overwrite the existing settings? " continue
        if [ "${continue^}" != "Y" ]; then
            exit 0
        fi
    fi
    case "$emailAddress" in
        *gmail.com)
            configure_gmail "$emailAddress"
        ;;
    esac
}

configure_gmail()
{
    # This is just to create the base file with settings common to all gmail accounts
    # I decided to do these in functions so as to not have a truly giagantic case statement in the add email function
    echo "unset imap_passive" > "$muttHome/$1"
echo "unset record" >> "$muttHome/$1"
echo "set imap_user=$1" >> "$muttHome/$1"
echo "set smtp_url=\"smtp://${1%@*}@smtp.gmail.com:587/" >> "$muttHome/$1"
echo "set folder=imaps://${1%@*}@imap.gmail.com/" >> "$muttHome/$1"
echo "mailboxes=+INBOX" >> "$muttHome/$1"
echo "set postponed=+[Gmail]/Drafts" >> "$muttHome/$1"
echo "set imap_keepalive=300" >> "$muttHome/$1"
echo "set mail_check=300" >> "$muttHome/$1"
echo "bind editor <Tab> complete-query" >> "$muttHome/$1"
    unset continue
    if command -v goobook &> /dev/null ; then
        read -p "Goobook is installed, would you like to use it as your addressbook for the account $1? " continue
    fi
    if [ "${continue^}" = "Y" ]; then
        echo "set query_command=\"goobook query %s\"" >> "$muttHome/$1"
        # Normally macros go in muttHome/macros, but this may be a gmail specific setting
        echo "macro index,pager a \"<pipe-message>goobook add<return>\" \"add sender to google contacts\"" >> "$muttHome/$1"
    else
        echo "source ~/${muttHome#/home/*/}/aliases" >> "$muttHome/$1"
    fi
}

# This is the main loop of the program
# Call functions to be ran every time the script is ran: checks for things like mailcap
create_mailcap
# Let's make a mainmenu variable to hold all the options for the select loop.
mainmenu=('Add Email Address' 'Exit')
select i in "${mainmenu[@]}" ; do
    functionName="${i,,}"
    functionName="${functionName// /_}"
    functionName="${functionName/exit/exit 0}"
    $functionName
done

exit 0
