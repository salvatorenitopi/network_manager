#!/bin/bash

ifconfig eth0 up

prober () {
while [[ true ]]; do

	plugged=$(cat /sys/class/net/eth0/carrier)
	if [[ plugged -eq 1 ]]; then
		
		echo "[*] Plugged"

		connected=$(ifconfig eth0 | grep "inet " | awk '{print $2}' | cut -d '.' -f2)
		if [[ connected ]]; then
			
			echo "[*] Connected"

		else

			echo "[!] Need to connect"

		fi

	else

		echo "[!] Need to be plugged"

	fi

	sleep 5

done
}

prober

#cat /sys/class/net/eth0/carrier
#ifconfig eth0 | grep "inet " | awk '{print $2}' | cut -d '.' -f2