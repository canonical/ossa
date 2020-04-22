## cvescan-file.sh
This script accepts a package manifest as an argument and then performs an OpenSCAP CVE Scan against it

### Noteworthy Features

* An array of Ubuntu Release:Codename is created on the fly
	* Uses data from releases.ubuntu.com old-releases.ubuntu.com
* Ubuntu release will be detected from the manifest
	* Specifically the version of update-manager-core
	* One less option for users to enter
* regex used should work through Ubuntu 29.10
* Trusty's version of update-manager-core doesn't match the release
	* It is consistently "196"
* Release specific OVAL data is verified to exist before downloading
	* Aborts for missing (404) and network/timeout issues
* Manifest and OVAL data Must be same directory
	* A symlink is created on the fly and deleted after each run
* A variety of [sample manifests](#sample-manifests) are available
	* Located in the sample-manifests directory

### Usage

* There is only one option/argument required for ossa-lite.sh
	* The path of the manifest file 
	
```
	./cvescan-file.sh <manifest file>
```
	
	* e.g.
	
``` 
	./cvescan-file.sh ./sample-manifests/b-min.manifest
```

### Script Output

```
$ ./cvescan2 ./sample-manifests/b-min.manifest 
Detected Ubuntu release bionic from ./sample-manifests/b-min.manifest
Checking if OVAL data if available for Ubuntu Bionic
Downloading OVAL data for bionic
  - Common Vulnerabilities Addressed: 9904
  - Current Vulnerability Exposure: 0
OpenSCAP CVE scan report is located @ /home/ubuntu/bionic.report.htm
```

#### Sample Manifests

* b=bionic, e=eoan, f=focal, t=trusty, x=xenial
* single digit prefixes are daily builds
* [a-z]-ga prefixes are release build
* [a-z]-min prefixes are minimal builds
	* ./sample-manifests/b.manifest
	* ./sample-manifests/b-ga.manifest
	* ./sample-manifests/b-min.manifest
	* ./sample-manifests/e.manifest
	* ./sample-manifests/e-min.manifest
	* ./sample-manifests/f.manifest
	* ./sample-manifests/t.manifest
	* ./sample-manifests/t-ga.manifest
	* ./sample-manifests/x.manifest
