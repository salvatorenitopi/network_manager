#!/bin/bash

connect () {
	echo "SOME"
}


while [[ -z "$running" ]]; do
	connect
	running=$(ps cax | grep hostapd)
	sleep 2
done