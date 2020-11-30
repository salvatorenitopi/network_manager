#!/bin/bash

#Depedencies: apt-get install hostapd isc-dhcp-server psmisc net-tools screen -y



if [ "$(id -u)" != "0" ]; then
	echo "[!] This script must be run as root."
	exit 1
fi




function fx_check_dependencies {

	missing=""
	dep=('isc-dhcp-server' 'psmisc' 'net-tools' 'screen')

	#t=$(/usr/bin/dpkg -s aircrack-ng &> /dev/null; echo $?)


	for (( j=0; j<${#dep[@]}; j++ )); do
		t=$(/usr/bin/dpkg -s ${dep[j]} &> /dev/null; echo $?)
		if [ "$t" -ne 0 ]; then
			echo -e "[!] ${dep[j]} Not installed"
			missing="$missing ${dep[j]}"
		else
			echo -e "[*] ${dep[j]} Installed"

		fi

	done


	if [ ! -z "$missing" ]; then
		echo "[!] Missing dependencies, please do:"; echo
		echo "    apt-get update; apt-get install $missing"
		exit 1
	fi
	

}



function fx_share_wlan0_eth0 {

	interface="eth0"
	internet="wlan0"


	killall dhcpd


	echo "[i] Configuring Interface and DHCP..."


	# Primo AVVIO
	mkdir -p /var/lib/dhcp
	touch /var/lib/dhcp/dhcpd.leases

	ifconfig $interface up
	ifconfig $interface 192.168.17.1 netmask 255.255.255.0

	touch /var/run/dhcpd.pid
	chmod 777 /var/run/dhcpd.pid

	(echo "authoritative;
default-lease-time 600;
max-lease-time 7200;
subnet 192.168.17.0 netmask 255.255.255.0 {
		option subnet-mask 255.255.255.0;
		option broadcast-address 192.168.17.255;
		option routers 192.168.17.1;
		option domain-name-servers 8.8.8.8; #DNS SERVER
		range 192.168.17.2 192.168.17.254;

#		host test_dhcp_client {
#			hardware ethernet FF:FF:FF:00:00:00;
#			fixed-address 192.168.17.100;
#		}
}") > /tmp/dhcpd.conf

#(echo "subnet  192.168.17.0 netmask 255.255.255.0 {
#
#        option routers                  192.168.17.1;
#        option subnet-mask              255.255.255.0;
#        option broadcast-address        192.168.17.255;
#        option domain-name-servers      8.8.8.8;
#        option ntp-servers              192.168.17.1;
#        option netbios-name-servers     192.168.17.1;
#        option netbios-node-type 2;
#
#        default-lease-time 86400;
#        max-lease-time 86400;
#
#}")

	dhcpd -q -cf /tmp/dhcpd.conf $interface  >/dev/null &

	echo "[i] Configuring Firewall..."

	echo "1"  > /proc/sys/net/ipv4/ip_forward

	iptables -t nat -A POSTROUTING -o $internet -j MASQUERADE
	iptables -A FORWARD -i $internet -o $interface -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -i $interface -o $internet -j ACCEPT

	# sudo ip route del default via 192.168.17.1 dev eth0

	echo "[i] Launching deth0rr (default_eth0_route_remover) screen..."

	if ! sudo screen -list | grep -q "deth0rr"; then
		sudo screen -dm -S "deth0rr" bash -c "while true; do ip route del default via 192.168.17.1 dev eth0; sleep 5; done"
	fi

	echo;echo;

	echo "[*] Now you can unplug/plug the eth0 cable"

	echo;echo;
}



fx_share_wlan0_eth0


