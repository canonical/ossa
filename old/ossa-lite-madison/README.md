# ossa-lite-madison
This script runs from a local system against a remote host
* Local System:  Your Mac/Ubuntu/Windows 10 (WSL) laptop
* Remote Host: A server/vm/container running Ubuntu 14.04 or later

## Script Duration
ossa-lite-madison should complete is less than 2 minutes

## Script Options
There is only one option/argument required for ossa-lite-madison.sh
* Credentials for the remote host that you wish to scan
	* Should be supplied in the form of user@host or user@ip_address
	
	```
	./ossa-lite-madison.sh -h
	```
	
	* Usage will be displayed
	
	``` 
	./Usage: ossa-lite-madison.sh user@host
	```

## Data is automatically collected data locally
Your current working directory must be in ossa/ossa-lite-madison, where this file
is located. Once in ossa/ossa-lite-madison you can:

* Run Script against Remote Machine using a hostname

	```
	./ossa-lite-madison.sh myuser@my-ubuntu-instance.example.org
	```
	
* Run Script against Remote Machine using an IP address

	```
	./ossa-lite-madison.sh myuser@172.27.20.25
	```

### Data will automatically be collected on your local machine
Once ossa-lite-madison.sh has completed, the script will show the location of the local compressed archive

	```
	Open Source Security Assessment Lite has completed.

	Please send /tmp/ossa-lite-madison.ob20.tgz to your Canonical representative.
	```
