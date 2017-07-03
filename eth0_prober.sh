#!/bin/bash

ifconfig eth0 up

prober () {
while [[ true ]]; do

	plugged=$(cat /sys/class/net/eth0/carrier)
	if [[ plugged == 1 ]]; then
		
		echo "[*] Plugged"

		connected=$(ifconfig eth0 | grep "inet " | awk '{print $2}' | cut -d '.' -f2)
		if [[ connected ]]; then
			
			echo "[*] Connected"

		fi

	fi

	sleep 2
done

}

prober

#cat /sys/class/net/eth0/carrier
#ifconfig eth0 | grep "inet " | awk '{print $2}' | cut -d '.' -f2