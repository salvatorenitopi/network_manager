import os
import re
import sys
import time
import subprocess


INTERFACE = "wlan0"
DEBUG = True


BLACKLISTED = ["blacklisted_ssid_here"]

WPA2_KNOWN_NETWORKS = { "known_essid": "secretsecret" }


PRECONFIGURED_WPA_SUPPLICANT = '''
network={
	ssid="backup_network"
	psk="secretsecret"
	priority=100
}
'''


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


if (os.getuid() != 0):
	print ("[!] This script must be run as root")
	sys.exit(1)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
import socket
import fcntl
import struct

def get_ip_address(ifname):
	try:
		s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
		return socket.inet_ntoa(fcntl.ioctl(
			s.fileno(),
			0x8915,  # SIOCGIFADDR
			struct.pack('256s', ifname[:15].encode('utf-8'))
		)[20:24])

	except:
		return None
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
import requests

def test_internet_connection():
	try:
		headers = {
			'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
			'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
			'Accept-Language': 'en-US',
			'DNT': '1',
			'Connection': 'keep-alive',
			'Upgrade-Insecure-Requests': '1',
			'Sec-Fetch-Dest': 'document',
			'Sec-Fetch-Mode': 'navigate',
			'Sec-Fetch-Site': 'none',
			'Sec-Fetch-User': '?1',
			'Pragma': 'no-cache',
			'Cache-Control': 'no-cache',
		}
		r = requests.get("https://example.com/", headers=headers)

		if ((r.status_code == 200) and ("This domain is for use in illustrative examples in documents. You may use this" in r.text)):
			return True

		else:
			return False


	except:
		return False
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 



cellNumberRe = re.compile(r"^Cell\s+(?P<cellnumber>.+)\s+-\s+Address:\s(?P<mac>.+)$")
regexps = [
	re.compile(r"^ESSID:\"(?P<essid>.*)\"$"),
	re.compile(r"^Protocol:(?P<protocol>.+)$"),
	re.compile(r"^Mode:(?P<mode>.+)$"),
	re.compile(r"^Frequency:(?P<frequency>[\d.]+) (?P<frequency_units>.+) \(Channel (?P<channel>\d+)\)$"),
	re.compile(r"^Encryption key:(?P<encryption>.+)$"),
	re.compile(r"^Quality=(?P<signal_quality>\d+)/(?P<signal_total>\d+)\s+Signal level=(?P<signal_level_dBm>.+) d.+$"),
	re.compile(r"^Signal level=(?P<signal_quality>\d+)/(?P<signal_total>\d+).*$"),
]

# Detect encryption type
wpaRe = re.compile(r"IE:\ WPA\ Version\ 1$")
wpa2Re = re.compile(r"IE:\ IEEE\ 802\.11i/WPA2\ Version\ 1$")

# Runs the comnmand to scan the list of networks.
# Must run as super user.
# Does not specify a particular device, so will scan all network devices.
def scan(interface='wlan0'):
	cmd = ["iwlist", interface, "scan"]
	proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	points = proc.stdout.read().decode('utf-8')
	return points

# Parses the response from the command "iwlist scan"
def parse(content):
	cells = []
	lines = content.split('\n')
	for line in lines:
		line = line.strip()
		cellNumber = cellNumberRe.search(line)
		if cellNumber is not None:
			cells.append(cellNumber.groupdict())
			continue
		wpa = wpaRe.search(line)
		if wpa is not None :
			cells[-1].update({'encryption':'wpa'})
		wpa2 = wpa2Re.search(line)
		if wpa2 is not None :
			cells[-1].update({'encryption':'wpa2'}) 
		for expression in regexps:
			result = expression.search(line)
			if result is not None:
				if 'encryption' in result.groupdict() :
					if result.groupdict()['encryption'] == 'on' :
						cells[-1].update({'encryption': 'wep'})
					else :
						cells[-1].update({'encryption': 'off'})
				else :
					cells[-1].update(result.groupdict())
				continue
	return cells



def connect_network (network_name, password):
	blob = '''ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=IT

network={
	ssid="''' + network_name + '''"
	key_mgmt=NONE
}

''' + PRECONFIGURED_WPA_SUPPLICANT

	
	if (password != None):
		blob = '''ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=IT

network={
	ssid="''' + network_name + '''"
	psk="''' + password + '''"
}

''' + PRECONFIGURED_WPA_SUPPLICANT


	f = open("/etc/wpa_supplicant/wpa_supplicant.conf", "w")
	f.write(blob)
	f.close()
	
	# cmd = ["systemctl", "restart", "wpa_supplicant"]
	# proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	# points = proc.stdout.read().decode('utf-8')
	
	# cmd = ["dhclient", "-r", "wlan0"]
	# proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	# points = proc.stdout.read().decode('utf-8')

	cmd = ["ifconfig", "wlan0", "down"]
	proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	points = proc.stdout.read().decode('utf-8')

	cmd = ["ifconfig", "wlan0", "up"]
	proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	points = proc.stdout.read().decode('utf-8')

	cmd = ["systemctl", "daemon-reload"]
	proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	points = proc.stdout.read().decode('utf-8')

	cmd = ["systemctl", "restart", "dhcpcd"]
	proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	points = proc.stdout.read().decode('utf-8')

	# cmd = ["systemctl", "restart", "networking"]
	# proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	# points = proc.stdout.read().decode('utf-8')

	if (DEBUG): print ("[i] Wrote " + str(ap['essid']) + " in wpa_supplicant.conf and reloaded")





test_counter = 6
while True:
	
	connected = False

	if (test_counter == 6):
		if ((get_ip_address(INTERFACE) == None) or (test_internet_connection() == False)):		
			connected = False
			if (DEBUG): print("[!] FULL CHECK: failed")
		else:																				
			connected = True
			if (DEBUG): print("[i] FULL CHECK: success")

		test_counter = 0

	else:
		if (get_ip_address(INTERFACE) == None):
			connected = False
			if (DEBUG): print("[!] SEMI CHECK: failed")
		else:
			connected = True
			if (DEBUG): print("[i] SEMI CHECK: success")


	if (connected == False):

		content = scan(interface=INTERFACE)
		cells = parse(content)

		candidate_cells = []

		for cell in parse(content):
			if (not cell.get('essid') in BLACKLISTED):
				if (cell.get('encryption') == 'off'):				candidate_cells.append(cell)
				elif (WPA2_KNOWN_NETWORKS.get(cell.get('essid'))):	candidate_cells.append(cell)


		sorted_candidate_cells = sorted(candidate_cells, reverse=True, key=lambda k: k['signal_quality'])

		if (DEBUG): print ("[i] Found: " + str(len(sorted_candidate_cells)) + " networks")


		for ap in sorted_candidate_cells:

			wpa2_password = WPA2_KNOWN_NETWORKS.get(ap['essid'])
			if (wpa2_password == None):
				if (DEBUG): print ("[i] Connecting to open network: " + str(ap['essid']))
				connect_network (str(ap['essid']), None)
			else:
				if (DEBUG): print ("[i] Connecting to known wpa2 network: " + str(ap['essid']))
				connect_network (str(ap['essid']), wpa2_password)


			timeout = 60
			for i in range(0, timeout):
				interface_ip = get_ip_address(INTERFACE)
				if (interface_ip == None):
					print ("[i] waiting ip (timeout in " + str(timeout - i) + " seconds)")
					time.sleep(1)
				else:
					print ("[i] Assigned ip: " + str(interface_ip))
					break

			interface_ip = get_ip_address(INTERFACE)
			if (interface_ip == None):
				if (DEBUG): print ("[!] Connection to '" + str(ap['essid']) + "' failed")
				continue


			if (interface_ip == False):
				if (DEBUG): print ("[!] Test interface connection on '" + str(ap['essid']) + "': failed")
				continue

			else:
				if (test_internet_connection() == False):
					if (DEBUG): print ("[!] Test internet connection on '" + str(ap['essid']) + "': failed")
					continue

				else:
					if (DEBUG): print ("[*] Test internet connection on '" + str(ap['essid']) + "': success")
					break



		if (len(sorted_candidate_cells) == 0):
			if (DEBUG): print ("[!] No networks found")



	time.sleep(10)
	test_counter += 1

