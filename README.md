<img width=100 src="https://raw.githubusercontent.com/ThinGuy/svg/master/Ubuntu_Badge-Circle_Of_Friends.svg?sanitize=true" title="Ubuntu LTS"><img width=100 src="https://raw.githubusercontent.com/ThinGuy/svg/master/Ubuntu_Badge-Focal_Fossa.svg?sanitize=true" title="Ubuntu 20.04 LTS Focal Fossa"><img width=100 src="https://raw.githubusercontent.com/ThinGuy/svg/master/Ubuntu_Badge-Bionic_Beaver.svg?sanitize=true" title="Ubuntu 18.04 LTS Bioic Beaver"><img width=100 src="https://raw.githubusercontent.com/ThinGuy/svg/master/Ubuntu_Badge-Xenial_Xerus.svg?sanitize=true" title="Ubuntu 16.04 LTS Xenial Xerus"><img width=100 src="https://raw.githubusercontent.com/ThinGuy/svg/master/Ubuntu_Badge-Trusty_Tahr.svg?sanitize=true" title="Ubuntu 14.04 LTS Trusty Tahr">

# Open Source Security Audit (ossa)
A set of non-invasive, lightweight scripts to gather information about [open source packages](https://ubuntu.com/about/packages) that are being used on [LTS versions](https://ubuntu.com/about/release-cycle) of [Ubuntu](https://ubuntu.com/about) for the purpose of a [security](https://usn.ubuntu.com/) and [support](https://ubuntu.com/support) assessment

## Downloading the Scripts

```
git clone https://github.com/ThinGuy/ossa.git
```

## Available Scripts

* [ossa-full](https://github.com/ThinGuy/ossa/tree/master/ossa-full) - Gathers information about packages and processes, scan for CVEs,etc
* [ossa-lite](https://github.com/ThinGuy/ossa/tree/master/ossa-lite) - Script intended to be ran on a remote system via ssh.  This version runs the fastest, but lacks package origin information.
* [ossa-lite-madison](https://github.com/ThinGuy/ossa/tree/master/ossa-lite-madison) - Script intended to be ran on a remote system via ssh.  This version grabs [apt-cache madison](https://manpages.ubuntu.com/manpages/bionic/man8/apt-cache.8.html) information so package origin can be derived


### Prerequisites

* A machine (physical, virtual, container) running Ubuntu 14.04 or later
* A standard user (non-privileged) account on the machine
	* An account with [sudo access](https://help.ubuntu.com/community/Sudoers) is ONLY required if:
		* You wish to perform CVE Scanning while running the [ossa-full](https://github.com/ThinGuy/ossa/tree/master/ossa-full) script AND if OpenSCAP is not already installed
			* If OpenSCAP is already installed, sudo access  is not required to perform the scan
			* If the CVE Scan option is selected AND sudo access is detected, some of the gather tools will collect more information than if ran as a non-privileged account.
* ssh access to the above machine for the "lite" scripts
	* MacOS, Linux, and Windows Subsystem for Linux (WSL) all work
	* Windows users can make use of powershell, but that is an exercise left to the user


## Running the scripts

* See README.md in each directory for documentation for notes on how to run each script and a description about the information that is collected.


## Running the scripts

* See README.md in each directory for documentation for notes on how to run each script and a description about the information that is collected.
