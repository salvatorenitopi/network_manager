# README #

## Description

This is a simple CLI network manager for Linux.

Features:  
-- Connect to a wifi network  
-- Share internet connection between interfaces   
-- Create a bridge*  

*A bridge is a process that involves:
1) Connection to a network (with a secondary interface)
2) Creating an Hotspot (withe the AP interface)
3) Sharing internet from the secondary interface to the AP interface

## How to use

    Usage: ./network_manager.sh -m [mode] [options]

      MODE: -m connect [options]

            interface           -i       wlan interface used to connect
            network             -n       network name to connect to
            encryption_type     -e       encryption type: 1=OPEN 2=WEP 3=WPA/WPA2
            passphrase          -p       passphrase needed to connect (not required only if -e 1)


      MODE: -m hotspot [options]

            interface           -i       wlan interface used as hotspot
            ssid                -s       ssid of the hotpot
            channel             -c       channel of the hotspot
            passphrase          -p       passphrase needed to connect (not compulsory)


      MODE: -m share [options]

            internet_interface  -i       interface that is connected to internet/network
            forward_interface   -f       interface you wish to use as traffic forwarder
