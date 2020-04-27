# OSSA Collector

This script runs from a local machine (Source System) against a remote host (Target System)

* Source System: Your Mac/Ubuntu/Windows 10 (WSL) desktop/laptop/VM
* Target System: A server/vm/container running Ubuntu 14.04 or later

## Script Duration

Collector should complete is less than 15 seconds

## Script Options

There is only one option/argument required for collector.sh

* Credentials for the remote host that you wish to scan
	* Should be supplied in the form of user@host or user@ip_address
	
	```
	./collector.sh -h
	```
	
	* Usage will be displayed
	
	``` 
	./Usage: ./collector.sh user@host
	```

## Data is automatically collected data locally

Change your working directory to ossa-generator/collector where this file
is located. Once in ossa-collector/collector you can:

* Run Script against Remote Machine using a hostname

	```
	./collector.sh myuser@ubuntu.example.org
	
	Running OSSA Collector against ubuntu.example.org. Please wait...
	```
* Run Script against Remote Machine using an IP address

	```
	./collector.sh myuser@172.27.20.25
	
	Running OSSA Collector against 172.27.20.25. Please wait...
	```

### Data will automatically be collected on your local machine
Once collector.sh has completed, the script will print a pointer to the local compressed archive

	```
	The OSSA Collector for ubuntu.example.org completed in 00:00:08.

	Data collected by the OSSA Collector is located at 
	/tmp/ossa-collector-data.ubuntu.example.org.tgz.
	```
## Data Colllected

|Files Collected|Purpose|
|:------------- |:------------- |
|/etc/apt/sources.list|To ensure proper package origin is used for assessment|
|/etc/hostname|To identify hostname of assessed system(s)|
|/etc/hosts|To identify hostname of assessed system(s)|
|/etc/lsb-release|To indentify the release of Ubuntu being assessed|
|/var/lib/apt/lists/*Release|To ensure proper package names/versions are used for assessment|
|/var/lib/apt/lists/*Packages|To ensure proper package names/versions are used for assessment|
|/var/lib/dpkg/status|To ensure proper package names/versions are used for assessment|
|```dpkg -l``` output|To ensure proper package names/versions are used for assessment|
|```apt-cache``` policy output|To ensure proper package origin is used for assessment|
|```snap list``` output|To show which snaps are being used on assessed system(s)|
|```ps -auxwww``` output|To help identify which packages are actually being used|
|```ps -eao pid,ppid,user,stat,etimes,cmd --sort=cmd``` output|To help identify which packages are actually being used|
|```netstat -an``` output|To help identify which packages are actually being used|
