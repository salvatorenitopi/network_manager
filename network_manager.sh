#!/bin/bash

#Depedencies: apt-get install hostapd isc-dhcp-server psmisc net-tools -y
#/sys/class/net/
#ifconfig | grep wlan1 -A1 | grep inet

IFS=$'\n'		# Don't consider spaces ad newline

###########################################################
function fx_check_dependencies {

	missing=""
	dep=('hostapd' 'isc-dhcp-server' 'psmisc' 'net-tools')

	t=$(/usr/bin/dpkg -s aircrack-ng &> /dev/null; echo $?)


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

	killall dhcpd
	killall hostapd

	ifconfig $interface down
	ifconfig $interface up

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
	mkdir /var/lib/dhcp
	touch /var/lib/dhcp/dhcpd.leases

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
	echo "Tipo:        $tipo"
	echo "Password:    $pass"
	echo "####################################"
	printf "Press enter to connect..."; read

	echo;echo;echo;echo;echo;


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


############################################################################################

#!/bin/bash

# m     mode

# CONNECT
# i     interface
# n     network
# e     encryption_type
# p     passphrase


# HOSTPOT
# i     interface
# s     ssid
# c     channel
# p     passphrase


# SHARE
# i     internet_interface
# f     forward_interface



fx_help() { 
	echo
    echo "Usage: $0 -m [mode] [options]"
    echo
    echo "MODE: -m connect [options]"
    echo 
    echo "      interface           -i       wlan interface used to connect"
    echo "      network             -n       network name to connect to"
    echo "      encryption_type     -e       encryption type: 1=OPEN 2=WEP 3=WPA/WPA2"
    echo "      passphrase          -p       passphrase needed to connect (not required only if -e 1)"
    echo
    echo
    echo "MODE: -m hotspot [options]"
    echo
    echo "      interface           -i       wlan interface used as hotspot"
    echo "      ssid                -s       ssid of the hotpot"
    echo "      channel             -c       channel of the hotspot"
    echo "      passphrase          -p       passphrase needed to connect (not compulsory)"
    echo
    echo
    echo "MODE: -m share [options]"
    echo
    echo "      internet_interface  -i       interface that is connected to internet/network"
    echo "      forward_interface   -f       interface you wish to use as traffic forwarder"
    echo
    echo
    exit 1
}

HELP=false

while true; do
	case "$1" in
	-h | --help )    HELP=true; shift ;;
	-- ) shift; break ;;
    * ) break ;;
	esac
done

echo HELP=$HELP

while getopts ":m:i:n:e:p:s:c:f:" x; do
    case "${x}" in
        m)
            m=${OPTARG}
            ;;

        i)
            i=${OPTARG}
            ;;

        n)
            n=${OPTARG}
            ;;

        e)
            e=${OPTARG}
            ;;

        p)
            p=${OPTARG}
            ;;

        s)
            s=${OPTARG}
            ;;

        c)
            c=${OPTARG}
            ;;

        f)
            f=${OPTARG}
            ;;

        *)
            #usage
            ;;
    esac
done
shift $((OPTIND-1))

####################################################################


if [[ "$HELP" = true ]]; then

	fx_help

elif [[ -z $m ]]; then

	fx_check_dependencies

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

		fx_help

	elif [ $i -eq 9 ]; then

		echo;echo;echo
		echo "[*] Gracefully quitting..."
		exit 0

	else
		
		echo;echo;echo
		echo "[!] Wrong choice, quitting..."
		exit 1

	fi
    
else

####################################################################
    
    if [[ $m == "connect" ]]; then

        if [ -z $i ] || [ -z $n ] || [ -z $e ]; then
        	echo
            echo "[!] Missing parameters:"
            echo "    interface        -i $i"
            echo "    network          -n $n"
            echo "    encryption_type  -e $e"
            echo
            echo
            exit 1

        else

            if [ $e -eq 1 ] && [ $e -eq 2 ] && [ $e -eq 3 ]; then
            	echo
                echo "[!] Parameter:"
                echo "    encryption_type -e supports only: <1|2|3>"
                echo
                echo
                exit 1

            elif [ $e -eq 1 ]; then

            	fx_check_dependencies

                interface=$i
				network=$n
				tipo=$e

				fx_rst_connection
				fx_connect

            elif [ $e -eq 2 ] || [ $e -eq 3 ]; then
                if [[ -z $p ]]; then
                	echo
                    echo "[!] Missing parameters:"
                    echo "    passphrase -p $p"
                    echo
                    echo
                    exit 1

                else

                	fx_check_dependencies

                    interface=$i
					network=$n
					tipo=$e
					pass=$p

					fx_rst_connection
					fx_connect

                fi
            fi
        fi
        
####################################################################
        
    elif [[ $m == "hotspot" ]]; then
        if [ -z $i ] || [ -z $s ] || [ -z $c ]; then
        	echo
            echo "[!] Missing parameters:"
            echo "    interface -i $i"
            echo "    ssid      -s $s"
            echo "    channel   -c $c"
            echo
            echo
            exit 1

        else
            if [[ -z $p ]]; then

            	fx_check_dependencies

                echo "HOTSPOT OPEN"
                
                interface=$i
                ssid=$s
                channel=$c
                wpa_passphrase="nullnull"
                wpa=0

                #fx_rst_hotspot
				fx_kill
				fx_hotspot

            else

            	fx_check_dependencies

                echo "HOTSPOT WPA2"

                interface=$i
                ssid=$s
                channel=$c
                wpa_passphrase=$p
                wpa=3

                #fx_rst_hotspot
				fx_kill
				fx_hotspot

            fi
        fi

####################################################################

    elif [[ $m == "share" ]]; then
        if [ -z $i ] && [ -z $f ]; then
        	echo
            echo "[!] Missing parameters:"
            echo "    internet_interface -i $i"
            echo "    forward_interface  -f $f"
            echo
            echo
        else

        	fx_check_dependencies

            echo "share"
            
            interface=$f
            internet=$i

            fx_rst_firewall
			fx_share

        fi
        

####################################################################

    else
        echo "[!] Parameter:"
        echo "    mode -m supports only: <connect|hotspot|share>"
        exit 1
    fi

fi

############################################################################################

unset IFS 		# unset Don't consider spaces ad newline