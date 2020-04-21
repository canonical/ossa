# Full Script (ossa-full)
This script should be ran from the system that is being assessed

## Script Options

```
~$ ./ossa.sh -h

 Script: ossa.sh
 
 Usage: ossa.sh [ Options ] 
 
 Options:

   -d, --dir               Directory to store Open Source Security Assessment Data (Default: /tmp/ossa_files)

   -s, --suffix            Append given suffix to collected files (Default: ".orangebox20.orangebox.me.focal"

   -o, --override          Copy apt list file regardless if they contain embedded credentials (Default: false)

   -p, --purge             Purge existing OSSA Directory (Default: False)

   -k, --keep              Keep OSSA Directory after script completes (Default: False)

   -e, --encrypt           Encrypt OSSA Datafiles with given passphrase (Default: False)

   -m,--no-madison         Do not run apt-cache madison against package manifest (Default: False)

   -S, --scan              Install OpenSCAP & scan manifest for CVEs. Require sudo access
                           if OpenSCAP is not installed. (Default: False)

   -h, --help              This message

 Examples:

   Change location of collected data:
     ossa.sh -d $HOME/ossa_files

   Set custom file suffix:
     ossa.sh -s $(hostname -f).$(lsb_release 2>/dev/null -sr)

   Purge existing/leftover directory, perform CVE Scan, encrypt compressed archive of collected data, and
     keep data directory after run

     ossa.sh -pSke 'MyP@ssW0rd!' 
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
