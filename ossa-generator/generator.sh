#!/bin/bash

[[ -z ${1} || ${1} =~ -h || ! -f ${1} ]] && { echo -en "Usage: ./${PROG} <path to ossa-lite archive>\nNote: sudo access is required\n" 1>&2;exit 2; }
[[ -f ${1} ]] && export OSSA_ARCHIVE=${1}
printf "Using OSSA data from ${OSSA_ARCHIVE}\n"

#Root/sudo check
[[ ${EUID} -eq 0 ]] && { export SCMD="";[[ ${DEBUG} = True ]] && { printf "\e[38;2;255;200;0mDEBUG: User is root\n\n"; };exit; } || { [[ ${EUID} -ne 0 && -n $(id|grep -io sudo) ]] && export SCMD=sudo || { export SCMD="";printf "\e[38;2;255;0;0mERROR: User (${USER}) does not have sudo permissions. Quitting.\n\n";exit 5; }; }

[[ ${DEBUG} = true ]] && { set -x;export VERBOSE=true; }
export SCRIPT="$(readlink -f $( cd "$( dirname "${BASH_SOURCE[0]}" )/" && pwd )/${BASH_SOURCE[0]##*/})"
export SCRIPT_DIR=${SCRIPT%/*}
export PROG=${0##*/}
declare -c TITLE="${PROG//.sh}"
export TITLE_FULL="OSSA ${TITLE}"
export NO_CVE_SCAN=false

trap 'tput cnorm;[[ ${DEBUG} = true ]] && set +x;export VERBOSE=false;trap - INT TERM EXIT KILL QUIT;exit 0' INT TERM EXIT KILL QUIT;

# Set timer 
TZ=UTC export NOW=$(date +%s)sec

# Turn off cursor
tput civis

# source OSSA functions
[[ -f ${SCRIPT_DIR}/../lib/ossa_functions ]] && source ${SCRIPT_DIR}/../lib/ossa_functions

PKG_PREQS=(libopenscap8 xsltproc curl)

# main ossa directory
export OSSA_DIR=/opt/ossa

# working directory for this assessment
export OSSA_WORKDIR="${OSSA_DIR}/$(basename ${OSSA_ARCHIVE%.*})"

# set OSSA_HOST based on OSSA_ARCHIVE filename
[[ -n ${OSSA_ARCHIVE} ]] && export OSSA_HOST=$(echo ${OSSA_ARCHIVE}|grep -oP '(?<=data\.)[^.]+') || export OSSA_HOST=unknown

# set ossa user
[[ -z ${OSSA_USER} ]] && export OSSA_USER=${OSSA_USER:-$(id -un 1000)}
[[ ${VERBOSE} = true ]] && { printf "Setting \${OSSA_USER} to ${OSSA_USER}\n"; }

# set ossa group 
[[ -z ${OSSA_GROUP} ]] && export OSSA_GROUP=${OSSA_GROUP:-$(id -gn 1000)}
[[ ${VERBOSE} = true ]] && { printf "Setting \${OSSA_GROUP} to ${OSSA_GROUP}\n"; }

# set rc file
export OSSA_RC=${OSSA_WORKDIR}/ossarc
[[ ${VERBOSE} = true ]] && { printf "Setting \${OSSA_RC} to ${OSSA_RC}\n"; }

# Make working directroy and extract the archive
[[ ${VERBOSE} = true ]] && { printf "Extracting OSSA data from ${OSSA_ARCHIVE}\n"; }
${SCMD} mkdir -p ${OSSA_WORKDIR}
[[ -f ${OSSA_ARCHIVE} ]] && ${SCMD} tar -C ${OSSA_WORKDIR} -xzf ${OSSA_ARCHIVE}
[[ -n $(find ${OSSA_WORKDIR} -maxdepth 1 -type f -iname "apt-files.*\.tar") ]] && { mkdir -p ${OSSA_WORKDIR}/apt && tar -C ${OSSA_WORKDIR}/apt -xf $(find ${OSSA_WORKDIR} -maxdepth 1 -type f -iname "apt-files.*\.tar"); }

# set workdir permisssions
if [[ -n ${OSSA_WORKDIR} && -d ${OSSA_WORKDIR} ]];then
	[[ ${VERBOSE} = true ]] && { printf "Setting permissions on directory ${OSSA_WORKDIR}\n"; }
	${SCMD} find ${OSSA_WORKDIR} \( -type d -exec chmod u+rwx,g+rwx,o+rx {} \; -o -type f -exec chmod u+rw,g+rw,o+r {} \; \)
	[[ ${VERBOSE} = true ]] && { printf "Setting ownership on directory ${OSSA_WORKDIR} to ${OSSA_USER}:${OSSA_GROUP}\n"; }
	${SCMD} find ${OSSA_WORKDIR} \( -type d -exec chown ${OSSA_USER}:${OSSA_GROUP} {} \; -o -type f -exec chown ${OSSA_USER}:${OSSA_GROUP} {} \; \)
fi

# populate rc file with current OSSA* env settings
[[ ${VERBOSE} = true ]] && { printf "Adding current OSSA env variables to ${OSSA_RC}\n"; }
set|grep ^OSSA|sed 's|^|export |g'|tee 1>/dev/null ${OSSA_RC}

# add file locations to rc
[[ ${VERBOSE} = true ]] && { printf "Adding OSSA file variables to ${OSSA_RC}\n"; }
(cd ${OSSA_WORKDIR} && ls -1|xargs -rn1 -P0 bash -c 'V=${0%%.*};V=${V^^};V=${V//-/_};echo $V="$( cd "$( dirname "${0}" )/" && pwd )/${0##*/}"'|tee 1>/dev/null -a ${OSSA_RC})

# re-source updated rc file
source-file ${OSSA_RC} -q

# Add lsb_release information to rc file
[[ -f ${LSB_RELEASE} ]] && sed 's/DISTRIB/OSSA/g' ${LSB_RELEASE} |tee 1>/dev/null -a ${OSSARC}

# re-source updated rc file
source-file ${OSSA_RC} -q

# Create manifest
[[ ${VERBOSE} = true ]] && { printf "Creating package manifest from dpkg -l output\n"; }
[[ -s ${DPKG_L} ]] && { awk '/^ii/{gsub(/:.*$/,"",$2);print $2,$3}' ${DPKG_L} |tee 1>/dev/null ${OSSA_WORKDIR}/manifest.${OSSA_HOST}; }
echo "export OSSA_MANIFEST=${OSSA_WORKDIR}/manifest.${OSSA_HOST}"|tee 1>/dev/null -a ${OSSARC}

# re-source updated rc file
source-file ${OSSA_RC} -q

# Create package origin list ( ~ apt-cache madison using files only)
if [[ -f ${OSSA_WORKDIR}/manifest.${OSSA_HOST} ]];then
	TZ=UTC export ORIGIN_NOW=$(date +%s)sec;
	SPID=$((cat ${OSSA_WORKDIR}/manifest.${OSSA_HOST})|xargs -rn2 -P0 bash -c 'printf "${0}|${1}|$(grep "^Package: ${0//+/\+}$" /var/lib/apt/lists/*_Packages|head -n1|sed -r "s/^.*dists_|_binary.*$//g;s/_/\//g")\n"'|tee 1>/dev/null ${OSSA_WORKDIR}/apt-madison.out) &
	SPID=$!
	declare -ag CHARS=($(printf "\u22EE\u2003\b") $(printf "\u22F0\u2003\b") $(printf "\u22EF\u2003\b") $(printf "\u22F1\u2003\b"))
	if [[ ${DEBUG} = true ]];then
		[[ ${VERBOSE} = true ]] && { printf "Parsing package origin information. Please wait\n"; }
	else
		while kill -0 $SPID 2>/dev/null;do
			for c in ${CHARS[@]};do printf 1>&2 "\r - ${TITLE_FULL}: Parsing package origin information. Please wait %s  (Elapsed Time: $(TZ=UTC date --date now-${NOW} "+%M:%S"))\e[K\e[0m" $c;sleep .03;done
		done
	fi
	wait $SPID
	[[ ${VERBOSE} = true ]] && { echo -en "\r\e[K\rParsing package origin information took $(TZ=UTC date --date now-${ORIGIN_NOW} "+%H:%M:%S").\n"; }

	# add package origin file info to rc file
	[[ ${VERBOSE} = true ]] && { printf "Adding OSSA_MADISON env variable to ${OSSA_RC}\n"; }
	echo "export OSSA_MADISON=\"${OSSA_WORKDIR}/apt-madison.out\""|tee 1>/dev/null -a ${OSSARC}

	# Copy lines without origin info from OSSA_MADISON to ${OSSA_WORKDIR}/unknown-origin.list
	grep '|$' ${OSSA_MADISON}|tee 1>/dev/null ${OSSA_WORKDIR}/unknown-origin.list
	echo "export OSSA_UNKNOWN_PKGS=\"${OSSA_WORKDIR}/unknown-origin.list\""|tee 1>/dev/null -a ${OSSARC}

	# Remove lines without origin info from OSSA_MADISON
	sed -i '/|$/d' ${OSSA_MADISON}
	# re-source updated rc file
	source-file ${OSSA_RC} -q
fi


# Run get-release-info function
if [[ ! -f ${OSSA_WORKDIR}/ubuntu-releases.csv ]];then
	get-release-info
	# Add ubuntu-releases.csv info to rc file
	([[ -f ${OSSA_WORKDIR}/ubuntu-releases.csv ]] && echo "export OSSA_RELEASE_CSV=${OSSA_WORKDIR}/ubuntu-releases.csv"|tee 1>/dev/null -a ${OSSA_RC})
	# re-source updated rc file
	source-file ${OSSA_RC} -q
fi

# Run show-release-info function
show-release-info
# add release info tables to rc file
([[ -f ${OSSA_WORKDIR}/release-info-ansi ]] && echo "export OSSA_RELEASE_TABLE_ANSI=${OSSA_WORKDIR}/release-info-ansi"|tee 1>/dev/null -a ${OSSA_RC})
([[ -f ${OSSA_WORKDIR}/release-info ]] && echo "export OSSA_RELEASE_TABLE=${OSSA_WORKDIR}/release-info"|tee 1>/dev/null -a ${OSSA_RC})
# re-source updated rc file
source-file ${OSSA_RC} -q


# show package origin info
make-origin-table
# add package table info tables to rc file
([[ -f ${OSSA_WORKDIR}/package-table-ansi ]] && echo "export OSSA_PACKAGE_TABLE_ANSI=${OSSA_WORKDIR}/package-table-ansi"|tee 1>/dev/null -a ${OSSA_RC})
([[ -f ${OSSA_WORKDIR}/package-table ]] && echo "export OSSA_PACKAGE_TABLE=${OSSA_WORKDIR}/package-table"|tee 1>/dev/null -a ${OSSA_RC})
# re-source updated rc file
source-file ${OSSA_RC} -q


# get package names for popularity contest
[[ -f ${OSSA_WORKDIR}/popularity-contest.${OSSA_HOST} ]] && { awk 'BEGIN { cmd="dpkg -S" $4"|sed 's/:.*$//g'"};{if ($0 ~ /"POPULAR"/) next};{OFS=",";if ( $1 ~ /^[0-9]+$/ && $1 != 0) {cmd="dpkg -S "$4"|sed 's/:.*$//g'";cmd|getline P;print strftime("%Y-%m-%d-%H:%M:%S", $1),strftime("%Y-%m-%d-%H:%M:%S", $2),$3,$4,P;next} else print $1,$2,$3,$4;next}' ${OSSA_WORKDIR}/popularity-contest.${OSSA_HOST}; }

# Install OpenSCAP if not installed
[[ $(is-installed openscap-daemon) = true ]] || { printf "Installing OpenSCAP.  You may be prompted for your password\n";${SCMD} apt install -yq openscap-daemon &>/tmp/install.openscap-daemon.log; }
[[ $(is-installed openscap-daemon) = true ]] || { printf "Failure installing OpenSCAP.  Check log @ /tmp/install.openscap-daemon.log\n"; export NO_CVE_SCAN=true; }


# Test for presence of  OVAL data for Ubuntu release that is being assessed 
[[ ${VERBOSE} = true ]] && { printf "Checking the availability of OVAL Data for Ubuntu ${OSSA_CODENAME}\n"; }
export OVAL_URI="https://people.canonical.com/~ubuntu-security/oval/oci.com.ubuntu.${OSSA_CODENAME}.cve.oval.xml.bz2"
[[ ${VERBOSE} = true ]] && { printf "OVAL URL: ${OVAL_URI}\n"; }
export TEST_OVAL=$(curl -slSL --connect-timeout 10 --max-time 30 --retry 2 --retry-delay 2 -w %{http_code} -o /dev/null ${OVAL_URI} 2>&1)
[[ ${OSSA_DEBUG} = true ]] && { echo "URL Test Results: ${TEST_OVAL}"; }
if [[ ${TEST_OVAL:(-3)} -eq 404 ]];then
	OVAL_MSG="OVAL data file for Ubuntu ${OSSA_CODENAME^} is not available. Skipping download.\n"
	export NO_CVE_SCAN=true
elif [[ ${TEST_OVAL:(-3)} -eq 000 ]];then
	OVAL_MSG="Network issues prevented download of OVAL data for Ubuntu ${OSSA_CODENAME}\n"
	export NO_CVE_SCAN=true
fi

# If OVAL data reachable, download it
if [[ ${TEST_OVAL:(-3)} -eq 200 ]];then
	[[ ${VERBOSE} = true ]] && { printf "Initiating download of OVAL data for Ubuntu ${OSSA_CODENAME^}\n"; }
	curl -slSL --connect-timeout 10 --max-time 30 --retry 2 --retry-delay 2 ${OVAL_URI} -o- |bunzip2 -d|tee 1>/dev/null ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2})
	TEST_OVAL_RC="$?"
	[[ $? -eq 0 && -f ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2}) ]] || { OVAL_MSG="Error(s) occurred (${TEST_OVAL_RC}) while downloading OVAL data for Ubuntu ${OSSA_CODENAME}\n";export NO_CVE_SCAN=true; }
fi

[[ -f ${OSSA_WORKDIR}/release-info ]] && cat ${OSSA_WORKDIR}/release-info
echo
[[ -f ${OSSA_WORKDIR}/package-table ]] && cat ${OSSA_WORKDIR}/package-table
echo
if [[ ${NO_CVE_SCAN} = false && ${TEST_OVAL:(-3)} -eq 200 && -f ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2}) ]];then
	[[ ${VERBOSE} = true ]] && { printf "Initiating CVE scan for Ubuntu ${OSSA_CODENAME^}\n"; }
	oscap oval eval --report ${OSSA_WORKDIR}/oscap-cve-scan-report.${OSSA_HOST,,}.htm ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2})|awk -vF=0 -vT=0 '{if ($NF=="false") F++} {if ($NF=="true") T++} END {print "CVE Scan Results (Summary)\n  Common Vulnerabilities Addressed: "F"\n  Current Vulnerability Exposure: "T}'|tee ${OSSA_WORKDIR}/cve-stats.${OSSA_HOST,,}
else
	printf "ERROR: Cannot perform CVE Scan\nREASON: ${OVAL_MSG}\n\n"	
fi

echo -en "\n${TITLE_FULL} for ${OSSA_HOST} completed in $(TZ=UTC date --date now-${ORIGIN_NOW} "+%H:%M:%S")"|tee -a ${OSSA_WORKDIR}/ossa-generator.log
echo;echo

[[ ${DEBUG} = true ]] && { set +x;export VERBOSE=false DEBUG=false; }