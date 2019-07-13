#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "[!] This script must be run as root."
   exit 1
fi


# dupe_script=$(ps -ef | grep "eth0_prober.sh" | grep -v grep | wc -l)

# if [ ${dupe_script} -gt 3 ]; then
# 	echo -e "The eth0_prober.sh script was already running."
# 	exit 0
# fi


# ---- ARGS ---------------------------------------------------------------------

HELP=false
VERBOSE=false
TIME=30


while true; do
	case "$1" in
	-h | --help )    	HELP=true; shift ;;
	-v | --verbose )    VERBOSE=true; shift ;;
	-- ) shift; break ;;
	* ) break ;;
	esac
done


while getopts ":t:" x; do
	case "${x}" in
		t)
			TIME=${OPTARG}
			;;

		*)
			#base case
			;;
	esac
done
shift $((OPTIND-1))

# -------------------------------------------------------------------------------




prober () {
	old_plugged=0
	plugged=0
	while [[ true ]]; do

		old_plugged=$plugged
		plugged=$(cat /sys/class/net/eth0/carrier)
		if [[ plugged -eq 1 ]]; then
			
			if [[ "$VERBOSE" = true ]]; then echo "[*] Plugged"; fi

			ip_addr=$(ip addr list eth0 |grep "inet " |cut -d' ' -f6|cut -d/ -f1)
			if [[ $ip_addr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then		# Check for IPv4 ip
				
				if [[ "$VERBOSE" = true ]]; then echo "[*] Already connected (nothing to do)"; fi

			else


				if [[ "$VERBOSE" = true ]]; then echo "[i] Trying to connect (using dhclient eth0)"; fi
				dhclient eth0

				if [ $? -ne 0 ]; then
					if [[ "$VERBOSE" = true ]]; then echo "[!] Failed to connect"; fi
				else
					if [[ "$VERBOSE" = true ]]; then echo "[*] Connected successfully"; fi
				fi


			fi

		else


			if [[ "$VERBOSE" = true ]]; then echo "[!] Need to be plugged"; fi



			if [[ plugged -eq 0 && old_plugged -eq 1 ]]; then

				if [[ "$VERBOSE" = true ]]; then echo "[i] Cable disconnection detected"; fi

				if [[ "$VERBOSE" = true ]]; then echo "    - Removing ip from eth0"; fi
				ifconfig eth0 0.0.0.0

				if [[ "$VERBOSE" = true ]]; then echo "    - Putting eth0 down"; fi
				ifconfig eth0 down

				if [[ "$VERBOSE" = true ]]; then echo "    - Putting eth0 up"; fi
				ifconfig eth0 up

			fi


		fi

		sleep $TIME

	done
}





if [[ "$HELP" = true ]]; then

	echo
	echo "Usage: $0 [options]"
	echo
	echo "      help              -h       shows this message"
	echo "      verbose           -v       verbose output"
	echo
	exit 1

else

	ifconfig eth0 up
	prober

fi