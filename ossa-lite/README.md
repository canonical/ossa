## Script Options
There is only one option/argument required for ossa-lite.sh
* Credentials for the remote host that you wish to scan
	* Should be supplied in the form of user@host or user@ip_address
	
	```
	./ossa-lite.sh -h
	```
	
	* Usage will be displayed
	
	``` 
	./Usage: ossa-lite.sh user@host
	```

## Script duration
ossa-lite should complete is less than 30 seconds

## Data is automatically collected data locally
Your current working directory must be in ossa/ossa-lite, where this file
is located. Once in ossa/ossa-lite you can:

* Run Script against Remote Machine using a hostname
	```
	./ossa-lite.sh myuser@my-ubuntu-instance.example.org
	```
* Run Script against Remote Machine using an IP address
	```
	./ossa-lite.sh myuser@172.27.20.25
	```

### Data will automatically be collected on your local machine
Once ossa-lite.sh has completed, the script will print a pointer to the local compressed archive
	```
	Open Source Security Assessment Lite has completed.

	Please send /tmp/ossa-lite.ob20.tgz to your Canonical representative.
	```
