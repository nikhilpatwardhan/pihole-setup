#!/usr/bin/env bash

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run with sudo" >&2
  exit 1
fi

FILE="/etc/apt/apt.conf.d/50unattended-upgrades"
DESIRED_REBOOT="Unattended-Upgrade::Automatic-Reboot "true";"
DESIRED_REBOOT_TIME="Unattended-Upgrade::Automatic-Reboot-Time "03:00";"

echo "Setting date-time"
timedatectl set-timezone Asia/Kolkata

echo "Updating the system..."
apt-get update
apt-get upgrade -y

echo "Install pre-requisities..."
apt install -y curl
apt install -y sqlite3
apt install -y unattended-upgrades apt-listchanges

echo "Installing PiHole..."
curl -sSL https://install.pi-hole.net | bash

insert_into_adlist() {
  local url="$1"
  sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('$url', 1, '')"
}

echo "Configuring PiHole..."
insert_into_adlist 'https://phishing.army/download/phishing_army_blocklist_extended.txt'
insert_into_adlist 'https://v.firebog.net/hosts/Prigent-Crypto.txt'
insert_into_adlist 'https://lists.cyberhost.uk/malware.txt'
insert_into_adlist 'https://v.firebog.net/hosts/Easyprivacy.txt'
insert_into_adlist 'https://v.firebog.net/hosts/Easylist.txt', 1, ''
insert_into_adlist 'https://v.firebog.net/hosts/AdguardDNS.txt', 1, ''
insert_into_adlist 'https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt'
insert_into_adlist 'https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts'
insert_into_adlist 'https://urlhaus.abuse.ch/downloads/hostfile/'
insert_into_adlist 'https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt'
insert_into_adlist 'https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt'

pihole -g

echo "Configuring automatic updates..."
update_existing_line() {
  local key_regex="$1"
  local desired_line="$2"

  if grep -Fxq "$desired_line" "$FILE"; then
    echo "OK: Desired line already present: $desired_line"
    return 0
  fi

  if grep -Eiq "^\s*(//\s*)?$key_regex" "$FILE"; then
    echo "Updating to $desired_line"
    sed -ri "s|^\s*(//\s*)?($key_regex).*|$desired_line|" "$FILE"
    return 0
  fi

  echo "Key $key_regex not found"
  return 0
}

update_existing_line 'Unattended-Upgrade::Automatic-Reboot false' "$DESIRED_REBOOT"
update_existing_line 'Unattended-Upgrade::Automatic-Reboot-Time' "$DESIRED_REBOOT_TIME"

systemctl enable apt-daily.timer apt-daily-upgrade.timer
systemctl restart apt-daily.timer apt-daily-upgrade.timer

echo "Done"
