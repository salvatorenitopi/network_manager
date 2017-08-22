#!/bin/bash

connect () {
	echo "SOME"
}

counter=0
while [[ -z "$running" && $counter -lt "5" ]]; do
	connect
	running=$(ps cax | grep hostapd)
	sleep 2
	counter=$((counter+1))
	echo $counter
done