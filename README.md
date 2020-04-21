<img width=100 src="https://raw.githubusercontent.com/ThinGuy/svg/master/Ubuntu_Badge-Circle_Of_Friends.svg?sanitize=true" title="Ubuntu LTS"><img width=100 src="https://raw.githubusercontent.com/ThinGuy/svg/master/Ubuntu_Badge-Focal_Fossa.svg?sanitize=true" title="Ubuntu 20.04 LTS Focal Fossa"><img width=100 src="https://raw.githubusercontent.com/ThinGuy/svg/master/Ubuntu_Badge-Bionic_Beaver.svg?sanitize=true" title="Ubuntu 18.04 LTS Bioic Beaver"><img width=100 src="https://raw.githubusercontent.com/ThinGuy/svg/master/Ubuntu_Badge-Xenial_Xerus.svg?sanitize=true" title="Ubuntu 16.04 LTS Xenial Xerus"><img width=100 src="https://raw.githubusercontent.com/ThinGuy/svg/master/Ubuntu_Badge-Trusty_Tahr.svg?sanitize=true" title="Ubuntu 14.04 LTS Trusty Tahr">

# Open Source Security Audit (ossa)
A set of scripts which gather information about [open source packages](https://ubuntu.com/about/packages) that are being used on [LTS versions](https://ubuntu.com/about/release-cycle) of [Ubuntu](https://ubuntu.com/about) for the purpose of a [security](https://usn.ubuntu.com/) and [support](https://ubuntu.com/support) assessment

[ossa-full](~./ossa-full) - Gathers information about packages and processes, can scan for CVEs,etc
[ossa-lite](~./ossa-lite) - Script intended to be ran on a remote system via ssh.  This version runs the fastest, but lacks package origin information.
[ossa-lite-madison](~./ossa-lite-madison) - Script intended to be ran on a remote system via ssh.  This version grabs [apt-cache madison](https://manpages.ubuntu.com/manpages/bionic/man8/apt-cache.8.html) information so package origin can be derived

See README.md in each directory for documentation for notes on how to run each script and a description about the information that is collected.

**Caveats:** 
 - This is a work in progress
 

