# Full Script (ossa-full)
This script should be ran from the system that is being assessed

## Script Options
* Get script options by running the following:
```
./ossa-full.sh -h
	```
	* Help options will be displayed
	``` 
	 Script: ossa.sh

	 Usage: ossa.sh [ Options ] 

	 Options:

		 -d, --dir               Directory to store Open Source Security Assessment Data (Default: /tmp/ossa_files)

		 -s, --suffix            Append given suffix to collected files (Default: ".orangebox20.orangebox.me.focal"

		 -o, --override          Copy apt list file regardless if they contain embedded credentials (Default: false)

		 -p, --purge             Purge existing OSSA Directory (Default: False)

		 -k, --keep              Keep OSSA Directory after script completes (Default: False)

		 -e, --encrypt           Encrypt OSSA Datafiles with given passphrase (Default: False)

		 -m, --no-madison        Do not run apt-cache madison against package manifest (Default: False)

		 -S, --scan              Install OpenSCAP & scan manifest for CVEs. Sudo access is required only
														 if OpenSCAP is not installed. (Default: False)

		 -h, --help              This message

	 Examples:

		 Change location of collected data:
			 ./ossa-full.sh -d $HOME/ossa_files

		 Set custom file suffix:
			 ./ossa-full.sh -s $(hostname -f).$(lsb_release 2>/dev/null -sr)

		 Purge existing/leftover directory, perform CVE Scan, encrypt compressed archive of collected data, and
			 keep data directory after run

			 ./ossa-full.sh -pSke 'MyP@ssW0rd!' 
	```


### Transfer Script to Remote Machine
Your current working directory must be in ossa/ossa-full, where this file
is located. Once in ossa/ossa-full you can:

* Transfer the script a remote system using scp:

```
$ scp ossa-full.sh user@host:.
```

### Run Script on  Remote Machine
* ssh to remote machine:
	```
	$ ssh user@host
	```
* Get list of script options:
	```
	./ossa-full.sh -h
	```
* Run script using desired options:
	```
	./ossa-full.sh -Spke 'MyP@55w0rD123!'
	```

### Transfer Results to your machine
Once ossa-full.sh has completed, you may want to fetch the compressed archive of data files to to the team performing the assessment.
* The name and path of the archive will be presented to the user once he script has completed:
```
 Open Source Security Assessment completed in 00:01:43

 Encrypted data collected during the Open Source Security Assessment is located at
 /tmp/ossa-datafile.encrypted.orangebox20.focal.tgz
```

* Download the script output using scp:

```
$ scp user@host:/tmp/ossa-datafile.encrypted.orangebox20.focal.tgz .
```