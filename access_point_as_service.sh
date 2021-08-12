#!/bin/bash
# SOURCE: https://www.raspberrypi.org/documentation/computers/configuration.html#setting-up-a-routed-wireless-access-point



sudo apt update; sudo apt install hostapd dnsmasq -y



cat <<EOF > /etc/dhcpcd.conf
#hostname

#clientid

#persistent

#option rapid_commit

#option domain_name_servers, domain_name, domain_search, host_name
#option classless_static_routes
#option interface_mtu

#require dhcp_server_identifier

#slaac private


interface wlan0
	static ip_address=192.168.4.1/24
	nohook wpa_supplicant
EOF



cat <<EOF > /etc/sysctl.d/routed-ap.conf
# Enable IPv4 routing
net.ipv4.ip_forward=1
EOF



mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig

cat <<EOF > /etc/dnsmasq.conf
interface=wlan0 # Listening interface
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
                # Pool of IP addresses served via DHCP
domain=wlan     # Local wireless DNS domain
address=/gw.wlan/192.168.4.1
                # Alias for this router
EOF



cat <<EOF > /etc/hostapd/hostapd.conf
country_code=IT
interface=wlan0
ssid=NETWORK
hw_mode=g
channel=7
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF



systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq

