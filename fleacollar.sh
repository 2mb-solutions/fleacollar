#!/bin/bash

# This script has the lofty goal of becoming a full configuration utility for mutt.
# Written by Storm Dragon: https://social.stormdragon.tk/storm
# Written by Michael Taboada: https://2mb.social/mwtab
# Contributions by Kyle: https://kyle.tk
# This is a 2MB Solutions project: https://2mb.solutions
# Released under the terms of  the WTFPL: http://wtfpl.net

# Setup for gettext localization
export TEXTDOMAIN=fleacollar.sh
export TEXTDOMAINDIR=/usr/share/locale
. gettext.sh

# Settings to improve accessibility of dialog.
export DIALOGOPTS='--insecure --no-lines --visit-items'

# Variables
muttHome=~/.mutt

# Functions
check_dependancies()
{
    local dep
    for dep in gpg mutt ; do
       if ! command -v $dep &> /dev/null ; then
            echo "$(eval_gettext "\$dep is not installed. Please install $dep and run this script again.")"
            exit 1
         fi
    done
    if ! [ -d ~/.gnupg ]; then
        read -p "$(eval_gettext "No configuration for GPG was found. To have \${0##*/} configure this for you press enter. If you would like to configure GPG manually, press control+c.") " continue
        configure_gpg
    fi
}

menulist() {
    # Args: minimum group 2, multiples of 2, "tag" "choice"
    # returns: selected tag
    local menuList
    ifs="$IFS"
    IFS=$'\n'
    dialog --backtitle "$(gettext "Use the up and down arrow keys to find the option you want, then press enter to select it.")" \
        --no-tags \
        --menu "$(gettext "Please select one")" 0 0 0 $@ --stdout
    IFS="$ifs"
}

msgbox() {
# Returns: None
# Shows the provided message on the screen with an ok button.
dialog --msgbox "$*" 0 0
} 

passwordbox() {
    # Returns: text entered by the user
    # Args 1, Instructions for box.
    # args: 2 initial text (optional)
    dialog --backtitle "$(gettext "Enter text and press enter.")" \
        --passwordbox "$1" 0 0 "$2" --stdout
}
 
yesno() {
    # Returns: Yes or No
    # Args: Question to user.
    # Called  in if $(yesno) == "Yes"
    # Or variable=$(yesno)
    dialog --backtitle "$(gettext "Press 'Enter' for \"yes\" or 'Escape' for
\"no\".")" --yesno "$*" 0 0 --stdout
    if [[ $? -eq 0 ]]; then
        echo "Yes"
    else
        echo "No"
    fi
}
 
initialize_directory()
{
    if ! [ -d "$muttHome" ]; then
        mkdir -p "${muttHome}/cache/bodies"
    fi
    if ! [ -f "$muttHome/aliases" ]; then
        touch "$muttHome/aliases"
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
        seamonkey\
        w3m
        do
            unset browserPath
            browserPath="$(command -v $i)"
            if [ -n "$browserPath" ]; then
                browsers[$x]="$browserPath"
                ((x++))
            fi
        done
        echo "$(gettext "Select browser for viewing html email:")"
        browserPath="$(menulist $(for i in "${browsers[@]##*/}" ; do echo "$i";echo "$i";done))"
        if [ -z "$browserPath" ]; then
            exit 0
        fi
        case "${browserPath##*/}" in
            "elinks")
                echo "text/html; $browserPath -dump -force-html -dump-charset utf-8 -no-numbering %s; nametemplate=%s.html; copiousoutput" > "$muttHome/mailcap"
            ;;
            "lynx|w3m")
                echo "text/html; $browserPath -dump %s; nametemplate=%s.html; copiousoutput" > "$muttHome/mailcap"
            ;;
            *)
                echo "text/html; $browserPath %s; nametemplate=%s.html; copiousoutput" > "$muttHome/mailcap"
        esac
        if command -v antiword &> /dev/null ; then
            echo "application/msword; $(command -v antiword) %s; copiousoutput" >> "$muttHome/mailcap"
        fi
    fi
    if ! [ -f "$muttHome/gpg.rc" ]; then
        cp "/usr/share/doc/mutt/samples/gpg.rc" "$muttHome/"
        echo "set pgp_autosign=yes" >> "$muttHome/gpg.rc"
        echo "set crypt_autosign=yes" >> "$muttHome/gpg.rc"
        echo "set pgp_replyencrypt=yes" >> "$muttHome/gpg.rc"
        echo "set pgp_timeout=1800" >> "$muttHome/gpg.rc"
        if [[ $(gpg --list-secret-keys | wc -l) -eq 0 ]]; then
            read -p "$(gettext "No gpg key was found. Type your name and press entr to quickly generate a PGP key.control+c if you would like to create it manually.") " continue
            gpg --quick-gen-key "${continue:-${USER}}"
        fi
        PS3="$(gettext "Select the key you want to use for encryption/signing:")"
        select key in $(gpg --list-secret-keys | grep '.*@.*' | cut -d '<' -f2 | cut -d '>' -f1) ; do
            if [[ -n "$key" ]]; then
                break
            fi
        done
        keyName="$(gpg --list-secret-keys --keyid-format short | grep -B1 ^uid | head -n1 | rev | cut -c -8 | rev)"
        echo "set pgp_sign_as=$keyName" >> "$muttHome/gpg.rc"
    fi
    # Create macro file
    if ! [ -f "$muttHome/macros" ]; then
        echo "macro index 'c' '<change-folder>?<change-dir><home>^K=<enter>'" > "$muttHome/macros"
        echo "bind index \"^\" imap-fetch-mail\"" >> "$muttHome/macros"
    fi
    # Create basic muttrc
    if ! [ -f "$muttHome/muttrc" ]; then
        # Find desired editor
        x=0
        for i in\
        emacs\
        gedit\
        leafpad\
        mousepad\
        nano\
        pluma\
        vi\
        vim
        do
            unset editorPath
            editorPath="$(command -v $i)"
            if [ -n "$editorPath" ]; then
                editors[$x]="$editorPath"
                ((x++))
            fi
        done
        echo "$gettext "Select editor for email composition:")"
        i="$(menulist $(for i in "${editors[@]##*/}" ; do echo "$i";echo "$i";done))"
        if [ -z "$i" ]; then
            exit 0
        fi
        echo "set editor=$i" > "$muttHome/muttrc"
        echo "set text_flowed=yes" >> "$muttHome/muttrc"
        # I need to figure out a way to detect and set the language for the next setting.
        echo "set send_charset=us-ascii:utf-8" >> "$muttHome/muttrc"
        echo "set pager = 'builtin'" >> "$muttHome/muttrc"
        echo "set pager_stop = 'yes'" >> "$muttHome/muttrc"
        echo "set sort=threads" >> "$muttHome/muttrc"
        echo "set beep_new=yes" >> "$muttHome/muttrc"
        echo "set print=yes" >> "$muttHome/muttrc"
        echo "set imap_check_subscribed" >> "$muttHome/muttrc"
        echo "set sort_alias=alias" >> "$muttHome/muttrc"
        echo "set reverse_alias=yes" >> "$muttHome/muttrc"
        echo "set alias_file=${muttHome/#$HOME/\~}/aliases" >> "$muttHome/muttrc"
        echo "set history_file=${muttHome/#$HOME/\~}/history" >> "$muttHome/muttrc"
        echo "set history=1024" >> "$muttHome/muttrc"
        echo "set mailcap_path=${muttHome/#$HOME/\~}/mailcap" >> "$muttHome/muttrc"
        echo "set header_cache=${muttHome/#$HOME/\~}/cache/headers" >> "$muttHome/muttrc"
        echo "set message_cachedir=${muttHome/#$HOME/\~}/cache/bodies" >> "$muttHome/muttrc"
        echo "set certificate_file=${muttHome/#$HOME/\~}/certificates" >> "$muttHome/muttrc"
        echo "set markers=no" >> "$muttHome/muttrc"
        echo "auto_view text/html" >> "$muttHome/muttrc"
        echo "alternative_order text/plain text/html" >> "$muttHome/muttrc"
        echo "message-hook '!(~g|~G) ~b\"^ 5 dash charactersBEGIN\\ PGP\\ (SIGNED\\ )?MESSAGE\"' \"exec check-traditional-pgp\"" >> "$muttHome/muttrc"
        echo "source ${muttHome/#$HOME/\~}/gpg.rc" >> "$muttHome/muttrc"
        echo "source ${muttHome/#$HOME/\~}/macros" >> "$muttHome/muttrc"
    fi
}

configure_gpg()
{
    # GPG stuff in .bashrc:
    if ! grep 'GPG_TTY=$(tty)'  ~/.bashrc ; then
        echo -e 'GPG_TTY=$(tty)\nexport GPG_TTY' >> ~/.bashrc
    fi
    # Make sure the configuration directory exists
if ! [ -d ~/.gnupg/ ]; then
        gpg --list-secret-keys &> /dev/null
    fi
    if [ -f ~/.gnupg/gpg.conf ]; then
        read -p "$(gettext "This will overwrite your existing ~/.gnupg/gpg.conf file. Press enter to continue or control+c to abort. ")" continue
    fi
    cat << EOF > ~/.gnupg/gpg.conf
charset utf-8
require-cross-certification
no-escape-from-lines
no-mangle-dos-filenames
personal-digest-preferences SHA512
cert-digest-algo SHA512
use-agent
default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed
keyserver wwwkeys.pgp.net
keyserver hkp://pool.sks-keyservers.net
keyserver pgp.zdv.uni-mainz.de
keyserver-options auto-key-retrieve
EOF
    if [ -f ~/.gnupg/gpg-agent.conf ]; then
        read -p "$(gettext "This will overwrite your existing ~/.gnupg/gpg-agent.conf file. Press enter to continue or control+c to abort. ")" continue
    fi
    cat << EOF > ~/.gnupg/gpg-agent.conf
default-cache-ttl 300
max-cache-ttl 999999
allow-loopback-pinentry
EOF
}

add_email_address()
{
    read -p "$(gettext "Please enter your email address: ")" emailAddress
    if ! [[ "$emailAddress" =~ .*@.*\..* ]]; then
        read -p "$(gettext "this appears to be an invalid email address. Continue anyway? (y/n) ")" continue
        if [ "${continue^}" != "Y" ]; then
            exit 0
        fi
    fi
    if [ -f "$muttHome/$emailAddress" ]; then
        read -p "$(gettext "This email address already exists. Overwrite the existing settings? (y/n) ")" continue
        if [ "${continue^}" != "Y" ]; then
            exit 0
        else
            sed -i "/$emailAddress/d" "$muttHome/muttrc"
        fi
    fi
    read -p "$(gettext "Enter your name as you want it to appear in emails. From: ")" realName
    echo "set realname=\"$realName\"" > "$muttHome/$emailAddress"
    echo "set from=\"$emailAddress\"" >> "$muttHome/$emailAddress"
    echo "set use_from = \"yes\"" >> "$muttHome/$emailAddress"
    echo "set hostname=${emailAddress##*@}" >> "$muttHome/$emailAddress"
    case "$emailAddress" in
        *gmail.com)
            configure_gmail "$emailAddress"
        ;;
        *hotmail.com)
            configure_hotmail "$emailAddress"
        ;;
        *)
            continue="$(yesno "$(gettext "Is this a gmail account?")")"
            if [[ "$continue" == "Yes" ]]; then
                configure_gmail "$emailAddress"
            else
                configure_generic "$emailAddress"
            fi
    esac
    # Password encryption with gpg
    passOne=a
    passTwo=b
    until [ "$passOne" = "$passTwo" ]; do
        passOne="$(passwordbox "$(gettext "Please enter the password for $emailAddress:")")"
        passTwo="$(passwordbox "$(gettext "Please enter the password again: ")")"
        if [ "$passOne" != "$passTwo" ]; then
            echo "$(gettext "The passwords do not match.")"
        fi
    done
    keyName="$(gpg --list-secret-keys --keyid-format short | grep -B1 ^uid | head -n1 | rev | cut -c -8 | rev)"
    # I wish it were possible to just echo the password through gpg and not have an unencrypted file at all.
    # but either it's not, or I just can't figure out how to do it. So we'll use mktemp and shred.
    passwordFile="$(mktemp)"
    echo -e "set imap_pass=\"$passOne\"\nset smtp_pass=\"$passOne\"" > "$passwordFile"
    gpg -r $keyName -e "$passwordFile"
    mv "$passwordFile.gpg" "$muttHome/$emailAddress.gpg"
    shred -fuzn 10 "$passwordFile" 
    echo "source \"gpg -d ${muttHome/#$HOME/\~}/${emailAddress}.gpg|\"" >> "$muttHome/$emailAddress"
    add_keybinding
echo "folder-hook *$emailAddress/ 'source ${muttHome/#$HOME/\~}/$emailAddress'" >> "$muttHome/$emailAddress"
    msgbox "$(gettext "Email address added, press enter to continue.")"
}

configure_gmail()
{
    # This is just to create the base file with settings common to all gmail accounts
    # I decided to do these in functions so as to not have a truly giagantic case statement in the add email function
    echo "unset imap_passive" >> "$muttHome/$1"
echo "unset record" >> "$muttHome/$1"
echo "set imap_user=$1" >> "$muttHome/$1"
echo "set smtp_url=\"smtp://${1%@*}@smtp.gmail.com:587/" >> "$muttHome/$1"
echo "set folder=imaps://${1%@*}@imap.gmail.com/" >> "$muttHome/$1"
echo "set spoolfile = +INBOX" >> "$muttHome/$1"
echo "mailboxes = +INBOX" >> "$muttHome/$1"
echo "set postponed = +[Gmail]/Drafts" >> "$muttHome/$1"
echo "set record=+[Gmail]/Sent" >> "$muttHome/$1"
echo "set imap_keepalive=300" >> "$muttHome/$1"
echo "set mail_check=300" >> "$muttHome/$1"
echo "bind editor <Tab> complete-query" >> "$muttHome/$1"
    unset continue
    if command -v goobook &> /dev/null ; then
        read -p "$(eval_gettext "Goobook is installed, would you like to use it as your addressbook for the account \$1? ")" continue
    fi
    if [ "${continue^}" = "Y" ]; then
        echo "set query_command=\"goobook query %s\"" >> "$muttHome/$1"
        # Normally macros go in muttHome/macros, but this may be a gmail specific setting
        echo "macro index,pager a \"<pipe-message>goobook add<return>\" \"add sender to google contacts\"" >> "$muttHome/$1"
    else
        echo "source ~/${muttHome#/home/*/}/aliases" >> "$muttHome/$1"
    fi
}

configure_hotmail()
{
    # This is just to create the base file with settings common to all hotmail accounts
    # I decided to do these in functions so as to not have a truly giagantic case statement in the add email function
    echo "unset imap_passive" >> "$muttHome/$1"
echo "unset record" >> "$muttHome/$1"
echo "set imap_user=$1" >> "$muttHome/$1"
echo "set smtp_url=\"smtp://$1@smtp-mail.outlook.com:587/" >> "$muttHome/$1"
echo "set folder=imaps://$1@imap-mail.outlook.com/" >> "$muttHome/$1"
echo "set ssl_force_tls=yes" >> "$muttHome/$1"
echo "set spoolfile=+Inbox" >> "$muttHome/$1"
echo "mailboxes = +Inbox" >> "$muttHome/$1"
echo "set postponed=+Drafts" >> "$muttHome/$1"
echo "set record=+Sent" >> "$muttHome/$1"
echo "set imap_keepalive=300" >> "$muttHome/$1"
echo "set mail_check=300" >> "$muttHome/$1"
echo "bind editor <Tab> complete-query" >> "$muttHome/$1"
    echo "source ~/${muttHome#/home/*/}/aliases" >> "$muttHome/$1"
}

configure_generic()
{
    # Break the email address into its components:
    local userName="${1%%@*}"
    local hostName="${1##*@}"
    local imapHost
    local imapUser
    local imapPort
    local smtpHost
    local smtpUser
    local smtpPort
    local extraSettings
    read -p "$(gettext "Enter imap host: ")" -e -i imap.$hostName imapHost
    read -p "$(gettext "Enter imap user: ")" -e -i $1 imapUser
    read -p "$(gettext "Enter imap port: ")" -e -i 993 imapPort
    read -p "$(gettext "Enter smtp host: ")" -e -i smtp.$hostName smtpHost
    read -p "$(gettext "Enter smtp user: ")" -e -i $userName smtpUser
    read -p "$(gettext "Enter smtp port: ")" -e -i 587 smtpPort
    read -p "$(gettext "Enter extra settings, one line at a time, just press enter when done: ")" extraSettings
    while [ "$extraSettings" != "" ]; do
        echo "$extraSettings" >> "$muttHome/$1"
        read $extreSettings
    done
    echo "unset imap_passive" >> "$muttHome/$1"
echo "unset record" >> "$muttHome/$1"
echo "set smtp_url=\"smtp://$smtpUser@$smtpHost:$smtpPort/" >> "$muttHome/$1"
echo "set folder=imaps://$imapUser@$imapHost:$imapPort/" >> "$muttHome/$1"
echo "mailboxes = +INBOX" >> "$muttHome/$1"
echo "set spoolfile = +INBOX" >> "$muttHome/$1"
echo "set postponed = +Drafts" >> "$muttHome/$1"
echo "set imap_keepalive=300" >> "$muttHome/$1"
echo "set mail_check=300" >> "$muttHome/$1"
echo "bind editor <Tab> complete-query" >> "$muttHome/$1"
    echo "source ~/${muttHome#/home/*/}/aliases" >> "$muttHome/$1"
}

add_keybinding()
{
# Here we search for previous keybinding
local fNumber=1
while : ; do
grep "^[[:space:]m]acro.*index.*<F$fNumber>.*" $muttHome/muttrc &> /dev/null || break # fNumber is now the currently open keybinding.
((fNumber++)) # fNumber was taken, so increment it.
done
# Bind key FfNumber to the mail account.
echo "macro generic,index <F$fNumber> '<sync-mailbox><enter-command>source ${muttHome/#$HOME/\~}/$emailAddress<enter><change-folder>!<enter>'" >> "$muttHome/muttrc"
echo "mail account  $emailAddress bound to F$fNumber."
if ! grep "^source.*@.*\..*" "$muttHome/muttrc" &> /dev/null ; then
read -p "$(eval_gettext "Make \$emailAddress the default account? (Y/N) ")" continue
if [ "${continue^^}" = "Y" ]; then
echo "source ${muttHome/#$HOME/\~}/$emailAddress" >> "$muttHome/muttrc"
fi
fi
}

new_contact()
{
    read -p "$(gettext "Enter the contact name as it should appear in the to line of the email. To: ")" contactName
    if [ -z "$contactName" ]; then
        exit 0
    fi
    read -p "$(gettext "Enter the email address for $contactName: ")" contactEmail
    if [ -z "$contactEmail" ]; then
        exit 0
    fi
    if grep "$contactEmail" "$muttHome/aliases" &> /dev/null ; then
        read -p "$(gettext "This email address already exists in your contacts. Press control+c to keep the current settings or enter to continue and replace the existing contact")" continue
    fi
    contactAlias="${contactName,,%% *}"
}

# This is the main loop of the program
# Call functions to be ran every time the script is ran.
check_dependancies
initialize_directory
# Let's make a mainmenu variable to hold all the options for the select loop.
mainmenu=("$(gettext "Add Email Address")" "$(gettext "Configure GPG")" "$(gettext "New Contact")" "$(gettext "Exit")")
while : ; do
i="$(IFS=$'\n';menulist $(for i in "${mainmenu[@]}" ; do echo "$i";echo "$i";done))"
    [[ -z "$i" ]] && exit 0
    functionName="${i,,}"
    functionName="${functionName// /_}"
    functionName="${functionName/exit/exit 0}"
    $functionName
done

exit 0
