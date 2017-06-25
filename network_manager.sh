#!/bin/bash

#Depedencies: apt-get install airmon-ng hostapd isc-dhcp-server -y
#/sys/class/net/
#ifconfig | grep wlan1 -A1 | grep inet


###########################################################

function fx_rst_connection {
	echo "[*] Killing processes..."
	service network-manager stop
	killall dhclient
	killall wpa_supplicant
}


function fx_rst_hotspot {
	echo "[*] Killing processes..."
	killall dhcpd
	killall hostapd
}


function fx_kill {
	echo "[*] Killing processes..."
	killall wpa_action wpa_supplicant wpa_cli dhclient ifplugd dhcdbd dhcpcd NetworkManager knetworkmanager avahi-autoipd avahi-daemon wlassistant wifibox
}


function fx_rst_var {
	interface=""
	internet=""

	tipo=""
	network=""
	pass=""

	ssid=""
	channel=""
	wpa=""
	wpa_passphrase=""

	sleep_time=2
	bssid=00:AA:11:BB:22:CC
	hidessid=0
}


function fx_rst_firewall {
	iptables -P INPUT ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -F INPUT
	iptables -F OUTPUT
	iptables -F FORWARD

	echo "0"  > /proc/sys/net/ipv4/ip_forward
}



###########################################################

function fx_connect {
	sudo ifconfig $interface down
	sudo ifconfig $interface up
	#OPEN
	if [ $tipo -eq 1 ]; then
		sudo iwconfig $interface essid $network key open
		echo "[*] Executing dhclient $interface"
		sudo dhclient $interface
	#WEP
	elif [ $tipo -eq 2 ]; then
		sudo iwconfig $interface essid $network key $pass
		echo "[*] Executing dhclient $interface"
		sudo dhclient $interface
	#WPA-WPA2
	elif [ $tipo -eq 3 ]; then
		#wpa_passphrase "$network" "$pass" > ~/wifi_cfg
		#sudo wpa_supplicant -i $interface -c ~/wifi_cfg -B
		wpa_passphrase "$network" "$pass" > wifi.conf
		sudo wpa_supplicant -i $interface -c wifi.conf -B
		echo "[*] Executing dhclient $interface"
		sudo dhclient $interface
		rm wifi.conf
	else
		echo "[!] Unknown Error"
		exit
	fi

}

###########################################################

function fx_hotspot {

	ifconfig $interface down
	ifconfig $interface up

	killall dhcpd
	killall hostapd

	echo "[*] Configuring hostapd..."

	#####################################

	rm /etc/hostapd/hostapd.conf

	(echo "interface=$interface
driver=nl80211
ssid=$ssid
hw_mode=g
channel=$channel
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=$hidessid
wpa=$wpa
wpa_passphrase=$wpa_passphrase
wpa_pairwise=TKIP
rsn_pairwise=CCMP") >> /etc/hostapd/hostapd.conf

	hostapd /etc/hostapd/hostapd.conf -B #>/dev/null &

	echo;echo;echo

	status=$?
	if [ "$status" !=  "0" ]; then
		echo "[!] Error with Hostapd, tring again..."
		killall hostapd
		hostapd /etc/hostapd/hostapd.conf -B
	else
		echo "[*] Hostapd started correctly"
	fi

	

	echo "[*] Waiting DHCP server for $sleep_time sec..."
	sleep $sleep_time

	#####################################

	# Primo AVVIO
	# mkdir /var/lib/dhcp
	# touch /var/lib/dhcp/dhcpd.leases

	ifconfig $interface  up
	ifconfig $interface  192.168.17.1 netmask 255.255.255.0

	touch /var/run/dhcpd.pid
	chmod 777 /var/run/dhcpd.pid

	rm /etc/dhcpd.conf

	(echo "authoritative;
default-lease-time 600;
max-lease-time 7200;
subnet 192.168.17.0 netmask 255.255.255.0 {
		option subnet-mask 255.255.255.0;
		option broadcast-address 192.168.17.255;
		option routers 192.168.17.1;
		option domain-name-servers 8.8.8.8; #DNS SERVER
		range 192.168.17.2 192.168.17.254;
}") >> /etc/dhcpd.conf

	dhcpd -q -cf /etc/dhcpd.conf $interface  >/dev/null &

	echo;echo;echo
	echo "[*] HOTSPOT ONLINE, SSID: $ssid"
	echo "[*] HOTSPOT ONLINE, PASS: $wpa_passphrase"
}

###########################################################

function fx_share {
	echo "[*] Configuring Firewall..."

	echo "1"  > /proc/sys/net/ipv4/ip_forward

	iptables -t nat -A POSTROUTING -o $internet -j MASQUERADE
	iptables -A FORWARD -i $internet -o $interface -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -i $interface -o $internet -j ACCEPT

	echo;echo;echo;
}

###########################################################

function fx_interactive_connect {
	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# CONNECT - Interface              #"
	echo "####################################"
	ifaces=($(ifconfig | grep "mtu" | cut -d " " -f 1 | tr -d ':'))
	for (( i=0; i<${#ifaces[@]}; i++ )); do echo "$i)" ${ifaces[i]}; done
	echo "####################################"
	printf "Interface: "; read i
	interface=${ifaces[i]}


	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# CONNECT - Network                #"
	echo "####################################"
	network_list=($(iwlist $interface scanning | grep 'ESSID' | cut -d ":" -f 2 | tr -d '"'))
	for (( i=0; i<${#network_list[@]}; i++ )); do echo "$i)" ${network_list[i]}; done
	echo "99) Custom/Hidden SSID"
	echo "####################################"
	printf "SSID: "; read i
	if [ $i -eq 99 ]; then
		printf "SSID: "; read network
	else
		network=${network_list[i]}
	fi


	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# CONNECT - Encryption             #"
	echo "####################################"
	echo "1) Open"
	echo "2) WEP"
	echo "3) WPA-WPA2"
	echo "####################################"
	printf "Type: "; read tipo


	if [[ $tipo != "1" ]]; then

		echo;echo;echo;echo;echo;
		echo "####################################"
		echo "# CONNECT - Password               #"
		echo "####################################"
		printf "Password: "; read pass

	fi


	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# CONNECT - Summary                #"
	echo "####################################"
	echo "Interface:   $interface"
	echo "Network:     $network"
	echo "Password:    $pass"
	echo "Tipo:        $tipo"
	echo "####################################"
	printf "Press enter to connect..."; read

	echo;echo;echo;echo;echo;

	if [ $tipo -eq 0 ]; then
		echo "bash ../connect_wifi.sh fast $interface $network null $tipo" > _fast/connect_$network.sh
	else
		echo "bash ../connect_wifi.sh fast $interface $network $pass $tipo" > _fast/connect_$network.sh
	fi
	chmod +x _fast/connect_$network.sh

}

###########################################################

function fx_interactive_hotspot {

	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# HOTSPOT - Interface              #"
	echo "####################################"
	ifaces=($(ifconfig | grep "mtu" | cut -d " " -f 1 | tr -d ':'))
	for (( i=0; i<${#ifaces[@]}; i++ )); do echo "$i)" ${ifaces[i]}; done
	echo "####################################"
	printf "Interface: "; read i
	interface=${ifaces[i]}
	

	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# HOTSPOT - SSID                   #"
	echo "####################################"
	printf "SSID: "; read ssid


	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# HOTSPOT - Channel                #"
	echo "####################################"
	printf "Channel: "; read channel
	

	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# HOTSPOT - Password (min 8 char)  #"
	echo "####################################"
	printf "Password: "; read wpa_passphrase
	
	if [ -z "$wpa_passphrase" ]; then

		wpa=0
		wpa_passphrase="nullnull"

	elif [ ${#wpa_passphrase} -lt 8 ]; then
		echo;echo;echo;echo;echo;
		echo "[!] Error, 8 is the minimum "
		echo "    password lenght, quitting..."
		exit 2
	else
		wpa=3
	fi

	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# HOTSPOT - Summary                #"
	echo "####################################"
	echo "Interface:   $interface"
	echo "ESSID:       $ssid"
	echo "Channel:     $channel"
	echo "Type:        $wpa"
	echo "Password:    $wpa_passphrase"
	echo "####################################"
	printf "Press enter to start the hotspot..."; read

	echo;echo;echo;echo;echo;

}

###########################################################

function fx_interactive_share {
	ifaces=($(ifconfig | grep "mtu" | cut -d " " -f 1 | tr -d ':'))

	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# SHARE - Internet                 #"
	echo "####################################"
	for (( i=0; i<${#ifaces[@]}; i++ )); do echo "$i)" ${ifaces[i]}; done
	echo "####################################"
	printf "Internet: "; read i
	internet=${ifaces[i]}


	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# SHARE - Inferface                #"
	echo "####################################"
	for (( i=0; i<${#ifaces[@]}; i++ )); do echo "$i)" ${ifaces[i]}; done
	echo "####################################"
	printf "Interface: "; read i
	interface=${ifaces[i]}


	echo;echo;echo;echo;echo;
	echo "####################################"
	echo "# SHARE - Summary                  #"
	echo "####################################"
	echo "Internet:    $internet"
	echo "Interface:   $interface"
	echo "####################################"
	printf "Press enter to share..."; read

	echo;echo;echo;echo;echo;
}

###########################################################

interface=""
internet=""

tipo=""
network=""
pass=""

ssid=""
channel=""
wpa=""
wpa_passphrase=""

sleep_time=2
bssid=00:AA:11:BB:22:CC
hidessid=0


if [ "$1" ==  "interactive" ]; then

	echo "####################################"
	echo "# Menu                             #"
	echo "####################################"
	echo "1) Connect - Connect WiFi"
	echo "2) Hotspot - Start WiFi Hotspot"
	echo "3) Share   - Share a Connection"
	echo "4) Bridge  - Connect+Hotspot+Share"
	echo "8) Help"
	echo "9) Quit"
	echo "####################################"
	printf "Choose: "; read i

	if [ $i -eq 1 ]; then
		
		fx_interactive_connect
		fx_rst_connection
		fx_connect

	elif [ $i -eq 2 ]; then

		fx_interactive_hotspot
		#fx_rst_hotspot
		fx_kill
		fx_hotspot

	elif [ $i -eq 3 ]; then

		fx_interactive_share
		fx_rst_firewall
		fx_share

	elif [ $i -eq 4 ]; then

		fx_interactive_connect
		fx_rst_connection
		fx_connect

		internet=$interface

		fx_interactive_hotspot
		#fx_rst_hotspot
		fx_kill
		fx_hotspot

		fx_share

		echo "[*] Bridged $internet ===> $interface"

	elif [ $i -eq 8 ]; then

		echo "Help"

	elif [ $i -eq 9 ]; then

		echo;echo;echo
		echo "[*] Gracefully quitting..."
		exit 0

	else
		
		echo;echo;echo
		echo "[!] Wrong choice, quitting..."
		exit 1

	fi



elif [ "$1" == "connect" ]; then

	echo "Connect"

elif [ "$1" == "hotspot" ]; then

	echo "Hotspot"


elif [ "$1" == "share" ]; then

	echo "Share"

elif [ "$1" == "bridge" ]; then

	echo "Bridge"

else

	echo "[!] Error, no parameters, try to do:"
	echo "    $0 interactive"
	exit 1

fi


