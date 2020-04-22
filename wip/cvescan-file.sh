#!/bin/bash

REPORT=report.htm
MANIFEST_FILE="${1}"

error() {
	echo "Error: $*" >&2
	exit 4
}

# Install openscap if needed
[[ $(dpkg 2>/dev/null -l openscap-daemon|awk 2>/dev/null '/openscap-daemon/{print $1}') = ii ]] && { printf "OpenSCAP already installed \U1F60E\n"; } || { echo "Need to install OpenSCAP.  Please enter password when prompted";sudo apt install openscap-daemon -yq; }

# Create array of DISTRIB_RELEASE:DISTRIB_CODENAME from 14.04 until 29.10
declare -ag UBU_VERSIONS=($(printf '%s\n' http://releases.ubuntu.com http://old-releases.ubuntu.com/releases|(xargs -rn1 -P0 -I{} curl -sSlL {}|awk 2>/dev/null -vRS=">|<" '/^Ubuntu.[0-9]+/{gsub(/\(|\).*$|LTS |Beta /,"");gsub(/\.[0-9]$/,"",$2);split($2,a,/\./); print $2":"tolower($3)}')|sort -uV|grep 2>/dev/null -E "(2[0-9]|1[4-9])\.(1[0-0]|0[4-4])"))

# Ensure the release:codename array covers what currently supported (last 4 releases)
[[ ${#UBU_VERSIONS[@]} -ge 4 ]] || { error "Could not fetch full list of Ubuntu releases.  Array size is ${#UBU_VERSIONS[@]}."; }

# Make sure the MANIFEST_FILE exists and has update-manager-core listed as it's included in all versions including minimal
[[ -s ${MANIFEST_FILE} && -n $(grep 2>/dev/null -oE 'update-manager-core' ${MANIFEST_FILE}) ]] || { error "Manifest ${MANIFEST_FILE} seems incomplete.  Missing \"update-manager-core\"."; }

# Determine release from update-manager-core package version.  Current regex will work from 14.04 until 29.10
MANIFEST_RELEASE=$(awk 2>/dev/null '/update-manager-core/{print $2}' ${MANIFEST_FILE}|grep 2>/dev/null -oE "(2[0-9]|1[4-9])\.(1[0-0]|0[4-4])|196")

# Trusty's version of update-manager core is consistently 196 
[[ ${MANIFEST_RELEASE} = 196 ]] && { export MANIFEST_RELEASE=14.04; }

# Test that we got the update-manager-core package version from MANIFEST_FILE
[[ -n ${MANIFEST_RELEASE} ]] || { error "Could not determine Ubuntu Release from manifest: ${MANIFEST_FILE}"; }

# Get matching DISTRIB_CODENAME from UBU_VERSIONS that matches MANIFEST_RELEASE
MANIFEST_CODENAME=$(printf '%s\n' ${UBU_VERSIONS[@]}|grep 2>/dev/null -oP "(?<=${MANIFEST_RELEASE}:)[^$]+")

# Test that we got the DISTRIB_CODENAME from UBU_VERSIONS
[[ -n ${MANIFEST_CODENAME} ]] && { echo "Detected Ubuntu release ${MANIFEST_CODENAME} from ${MANIFEST_FILE}"; } || { error "Could not determine Ubuntu codename for ${MANIFEST_RELEASE}"; }

# Check if there is OVAL file that matches MANIFEST_CODENAME
OVAL_URI="https://people.canonical.com/~ubuntu-security/oval/oci.com.ubuntu.${MANIFEST_CODENAME}.cve.oval.xml.bz2"

# Set curl args
CARGS='-slSL --connect-timeout 5 --max-time 20 --retry 5 --retry-delay 1'

# Test if OVAL_URL is reachable/exists - Take up to 20 seconds
echo "Checking if OVAL data if available for Ubuntu ${MANIFEST_CODENAME^}"
TEST_OVAL=$(curl ${CARGS} -w %{http_code} -o /dev/null ${OVAL_URI} 2>&1)

OVAL_DIR=$HOME

# If matching OVAL file, download it.  Exit on timeout or 404
[[ ${TEST_OVAL:(-3)} -eq 404 ]] && { error "OVAL data does not exist for ${MANIFEST_CODENAME}"; }
[[ ${TEST_OVAL:(-3)} -eq 000 ]] && { error "Could not connect to \"$(awk -F/ '{print $3}' <<<${OVAL_URI})\"."; }
[[ ${TEST_OVAL:(-3)} -eq 200 ]] && { echo "Downloading OVAL data for ${MANIFEST_CODENAME}";curl ${CARGS} ${OVAL_URI} -o- |bunzip2 -d|tee 1>/dev/null ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2}); }

# Put manifest in same directory as OVAL data
ln -sf ${MANIFEST_FILE} ${OVAL_DIR}/

# Make sure that worked
[[ -e ${OVAL_DIR}/${MANIFEST_FILE##*/} ]] || { error "Could not colocate OVAL data and manifest file"; }

# If all is well, scan the manifest
[[ -f ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2}) && -h ${OVAL_DIR}/${MANIFEST_FILE##*/} ]] && { oscap oval eval --report ${OVAL_DIR}/${MANIFEST_CODENAME}.${REPORT} ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2})|awk -vF=0 -vT=0 '{if ($NF=="false") F++} {if ($NF=="true") T++} END {print "  - Common Vulnerabilities Addressed: "F"\n  - Current Vulnerability Exposure: "T}'; }
[[ -s ${OVAL_DIR}/${MANIFEST_CODENAME}.${REPORT} ]] && { echo "OpenSCAP CVE scan report is located @ ${OVAL_DIR}/${MANIFEST_CODENAME}.${REPORT}"; } || { error "Could not find the OpenSCAP CVE scan report: ${OVAL_DIR}/${MANIFEST_CODENAME}.${REPORT}"; }

# Remove symlinked manifest
[[ -h ${OVAL_DIR}/${MANIFEST_FILE##*/} ]] && { rm -f ${OVAL_DIR}/${MANIFEST_FILE##*/}; }