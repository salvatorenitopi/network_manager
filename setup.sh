#!/bin/bash

########################################################################################################################

echo; echo "[*] Updating system"
apt update; #apt upgrade -y

########################################################################################################################

echo; echo "[*] Installing software"
apt install hostapd isc-dhcp-server psmisc net-tools -y

########################################################################################################################