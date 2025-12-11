#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "sudo access required"
  exit
fi

apt update && apt upgrade

# SET UP FIREWALL
read -p "Install and set up firewall? [y/n] " confirm; if [[ "$confirm" == [yY] ]]; then
    apt install ufw
    systemctl enable --now ufw
    ufw enable
fi

# REMOVE BAD PACKAGES
echo "-------------------"
echo "Remove bad packages"
echo "-------------------"
completed=0
while [ "$completed" -eq 0 ]; do
    bad_packages=(nmap zenmap apache2 nginx lighttpd wireshark tcpdump netcat-traditional nikto ophcrack)
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
        apt purge -y "${to_delete[@]}"
        apt autoremove
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
echo "Remember to add any users that were not included already."