#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "sudo access required"
  exit
fi

apt-get update && apt-get upgrade

# SET UP FIREWALL
read -p "Install and set up firewall? [y/n] " confirm; if [[ "$confirm" == [yY] ]]; then
    apt-get install ufw
    systemctl enable --now ufw
    ufw enable
fi

# REMOVE BAD PACKAGES
echo "-------------------"
echo "Remove bad packages"
echo "-------------------"
completed=0
while [ "$completed" -eq 0 ]; do
    bad_packages=(ssh vsftpd nmap zenmap apache2 nginx lighttpd wireshark tcpdump netcat-traditional nikto ophcrack zangband amule)
    declare -a to_delete
    declare -a skipped

    for package in "${bad_packages[@]}"; do
        read -p "Delete $package? [y/n] " confirm
        if [[ "$confirm" == [yY] ]]
        then
            echo "Removing $package."
            to_delete+=("$package")
        else
            echo "Skipping $package."
            skipped+=("$package")
        fi
    done
    unset bad_packages
    echo "The following packages WILL be removed:"
    echo "${to_delete[@]}"
    echo ""
    echo "The following packages will NOT be removed:"
    echo "${skipped[@]}"
    echo ""
    read -p "Do you want to continue? [Y/n] " confirm
    if [[ "$confirm" == [yY] ]]; then
        unset skipped
        apt-get purge -y "${to_delete[@]}"
        apt-get autoremove
        completed=1
    else
        echo "Try again:"
    fi
    unset to_delete
done

# MANAGE USERS
echo "------------"
echo "Manage users"
echo "------------"
read -p "Enter secure password to be used: " default_pw
for name in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    read -p "Manage $name? [y/n] " confirm; if [[ "$confirm" == [yY] ]]; then
        read -p "Is $name an authorized user? [y/n] " confirm; if [[ "$confirm" == [yY] ]]; then
            read -p "Is $name an administrator? [y/n] " confirm
            if [[ "$confirm" == [yY] ]]; then
                usermod -aG sudo "$name"
                passwd "$name"
            else
                gpasswd -d "$name" sudo
                read -p "Use default password? [y/n] " confirm; if [[ "$confirm" == [yY] ]]; then
                    echo "$name:$default_pw" | chpasswd
                else
                    passwd "$name"
                fi
            fi
        else
            deluser --remove-home "$name"
        fi
    fi
    echo ""
done
echo "Add any users that were not included already. Then, disable the guest account in settings."
echo "To expire a user's password: sudo chage -d 0 username"
read -p "Press ENTER to continue..."

# MISC
echo "-------------"
echo "Miscellaneous"
echo "-------------"
echo "Scanning for prohibited files..."

prohibited=$(find /home -type f \
    \( -iname "*.mp3" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" \
       -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.mov" \) )

if [ -n "$prohibited" ]; then
    echo "Prohibited files found:"
    echo "$prohibited"
    echo "Remove the files you deem to be unallowed."
    read -p "Press ENTER to continue..."
else
    echo "No prohibited files detected."
fi

echo "A few editor windows will open. Add or modify the following values:"
echo "/etc/login.defs: PASS_MAX_DAYS 90, PASS_MIN_DAYS 0, PASS_WARN_AGE 7"
echo "/etc/pam.d/common-password, line containing pam_unix.so: remember=5 minlen=8"
gedit /etc/login.defs
gedit /etc/pam.d/common-password
read -p "Press ENTER to continue...."
echo ""
echo "An editor window will open. Add or modify the following line:"
echo "net.ipv4.tcp_syncookies = 1"
gedit /etc/sysctl.conf
read -p "Press ENTER to continue...."
sudo sysctl -p

echo "TO-DO:"
echo "Complete tasks inside README, Secure SSH (/etc/ssh/sshd_config) and FTP (/etc/vsftpd/vsftpd.conf), enable automatic updates, enable security update list, secure web server/other services (if posible), find more prohibited apps"