#!/bin/bash

export SCRIPT="$(readlink -f $( cd "$( dirname "${BASH_SOURCE[0]}" )/" && pwd )/${BASH_SOURCE[0]##*/})"
export SCRIPT_DIR=${SCRIPT%/*}
export PROG=${0##*/}
declare -c TITLE="${PROG//.sh}"
export TITLE_FULL="OSSA ${TITLE}"
[[ -f ${SCRIPT_DIR}/../lib/ossa_functions ]] && source ${SCRIPT_DIR}/../lib/ossa_functions

[[ -f 
[[ -z ${1} || ${1} =~ -h || ! -f ${1} ]] && { echo -en "Usage: ./${0##*/} <path to ossa-lite archive>\nNote: sudo access is required\n" 1>&2;exit 2; }

[[ -f ${PROG_DIR}/../lib/ossa_functions ]] && source ${PROG_DIR}/../lib/ossa_functions 

#Root/sudo check
[[ ${EUID} -eq 0 ]] && { export SCMD="";[[ ${DEBUG} = True ]] && { printf "\e[38;2;255;200;0mDEBUG: User is root\n\n"; };exit; } || { [[ ${EUID} -ne 0 && -n $(id|grep -io sudo) ]] && export SCMD=sudo || { export SCMD="";printf "\e[38;2;255;0;0mERROR: User (${USER}) does not have sudo permissions. Quitting.\n\n";exit 5; }; }
TZ=UTC export NOW=$(date +%s)sec;

[[ -f ${1} ]] && export OSSA_ARCHIVE=${1}
[[ ${VERBOSE} = true ]] && { printf "Using OSSA data from ${OSSA_ARCHIVE}\n"; }


# set ossa user
[[ ${VERBOSE} = true ]] && { printf "Setting \${OSSA_USER} to "; }
[[ -z ${OSSA_USER} ]] && export OSSA_USER=${OSSA_USER:-$(id -un 1000)};[[ ${VERBOSE} = true ]] && { echo $OSSA_USER; }

# set ossa group 
[[ ${VERBOSE} = true ]] && { printf "Setting \${OSSA_GROUP} to "; }
[[ -z ${OSSA_GROUP} ]] && export ${OSSA_GROUP:-$(id -gn 1000)};echo ${OSSA_GROUP}

# main ossa directory
export OSSA_DIR=/opt/ossa;[[ ${VERBOSE} = true ]] && { printf "Setting \${OSSA_DIR} to ${OSSA_DIR}\n"; }

# working directory for this assesment 
export OSSA_WORKDIR="${OSSA_DIR}/$(basename ${OSSA_ARCHIVE%.*})";[[ ${VERBOSE} = true ]] && { printf "Setting \${OSSA_WORKDIR} to ${OSSA_WORKDIR}\n"

# set rc file
export OSSA_RC=${OSSA_WORKDIR}/ossarc;[[ ${VERBOSE} = true ]] && { printf "Setting \${OSSA_RC} to ${OSSA_RC}\n"; }

# Make working directroy and extract the archive
[[ ${VERBOSE} = true ]] && { printf "Exractive OSSA data from ${OSSA_ARCHIVE}\n"; }
${SCMD} mkdir -p ${OSSA_WORKDIR} && ${SCMD} tar -C ${OSSA_WORKDIR} -xzf ${OSSA_ARCHIVE}

# set workdir permisssions
if [[ -n ${OSSA_WORKDIR} && -d ${OSSA_WORKDIR} ]];then
	[[ ${VERBOSE} = true ]] && { printf "Setting permissions on directory ${OSSA_WORKDIR}\n"; }
	${SCMD} find ${OSSA_WORKDIR} \( -type d -exec chmod u+rwx,g+rwx,o+rx {} \; -o -type f -exec chmod u+rw,g+rw,o+r {} \; \)
	[[ ${VERBOSE} = true ]] && { printf "Setting ownership on directory ${OSSA_WORKDIR} to ${OSSA_USER}.${OSSA_GROUP}\n"; }
	${SCMD} find ${OSSA_WORKDIR} \( -type d -exec chown ${OSSA_USER}.${OSSA_GROUP} {} \; -o -type f -exec chown ${OSSA_USER}:${OSSA_GROUP} {} \; \)
fi

# populate rc file with current OSSA* env settings
[[ ${VERBOSE} = true ]] && { printf "Adding current OSSA env variables to ${OSSA_RC}\n"; }
set|grep ^OSSA|sed 's|^|export |g'|tee 1>/dev/null ${OSSA_RC}

# add file locations to rc
[[ ${VERBOSE} = true ]] && { printf "Adding OSSA file variables to ${OSSA_RC}\n"; }
(cd ${OSSA_WORKDIR} && ls -1|xargs -rn1 -P0 bash -c 'V=${0%%.*};V=${V^^};V=${V//-/_};echo $V="$( cd "$( dirname "${0}" )/" && pwd )/${0##*/}"'|tee 1>/dev/null -a ${OSSA_RC})
[[ -s ${OSSA_RC} ]] && { [[ ${VERBOSE} = true ]] && printf "Sourcing RC file (${OSSA_RC})\n";source ${OSSA_RC}; }
[[ -f ${LSB_RELEASE} ]] && sed 's/DISTRIB/OSSA/g' ${LSB_RELEASE} |tee 1>/dev/null -a ${OSSARC}


# Create manifest
[[ -s ${DPKG_L} ]] && { awk '/^ii/{print $2"\t"$3}' ${DPKG_L}|tee 1>/dev/null ${OSSA_WORKDIR}/manifest.${OSSA_HOST}; }
echo "export OSSA_MANIFEST=${OSSA_WORKDIR}/manifest.${OSSA_HOST}"|tee 1>/dev/null -a ${OSSARC}

# source updated rc file
[[ -s ${OSSA_RC} ]] && source ${OSSA_RC}

# Create package origin list ( ~ apt-cache madison using files only)
TZ=UTC export NOW=$(date +%s)sec;
SPID=$((dpkg -l |awk '/^ii/{gsub(/:.*$/,"",$2);print $2,$3}')|xargs -rn2 -P0 bash -c 'printf "${0}|${1}|$(grep "^Package: ${0//+/\+}$" /var/lib/apt/lists/*_Packages|head -n1|sed -r "s/^.*dists_|_binary.*$//g;s/_/\//g")\n"'|tee 1>/dev/null ~/apt-madison.txt) &
SPID=$!
declare -ag CHARS=($(printf "\u22EE\u2003\b") $(printf "\u22F0\u2003\b") $(printf "\u22EF\u2003\b") $(printf "\u22F1\u2003\b"))
while kill -0 $SPID 2>/dev/null;do
for c in ${CHARS[@]};do printf "\r\e[2G - ${TITLE_FULL}: Parsing package origin information. Please wait %s  (Elapsed Time: $(TZ=UTC date --date now-${NOW} "+%M:%S"))\e[K\e[0m" $c;sleep .03;done
done
wait $SPID
echo -en "\r\e[K\rParsing package origin information took $(TZ=UTC date --date now-${NOW} "+%H:%M:%S").\n";


show-release-info|tee ${OSSA_WORKDIR}/release-table.ansi|sed 2>/dev/null 's/\x1b\[[0-9;]*[a-zA-Z]//g'|tee 1>/dev/null ${OSSA_WORKDIR}/release.table.txt
([[ -f ${OSSA_WORKDIR}/release-table.ansi ]] && echo "export OSSA_RELEASE_TABLE_ANSI=${OSSA_WORKDIR}/release-table.ansi"|tee 1>/dev/null -a ${OSSA_RC})
([[ -f ${OSSA_WORKDIR}/release-table.txt ]] && echo "export OSSA_RELEASE_TABLE=${OSSA_WORKDIR}/release-table.txt"|tee 1>/dev/null -a ${OSSA_RC})



#cp ${OSSA_MANIFEST} ${PROG_DIR}
#printf "Running cvescan -f ${PROG_DIR}/${OSSA_MANIFEST##*/} -p all\n"
#cvescan -f ${PROG_DIR}/${OSSA_MANIFEST##*/}

######################
# DOWNLOAD OVAL DATA #
######################
printf "\e[2GChecking the availbility of OVAL Data for Ubuntu ${OSSA_CODENAME}\n"
printf "\e[4GOVAL URL: https://people.canonical.com/~ubuntu-security/oval/oci.com.ubuntu.${OSSA_CODENAME}.cve.oval.xml.bz2\n"
export OVAL_URI="https://people.canonical.com/~ubuntu-security/oval/oci.com.ubuntu.${OSSA_CODENAME}.cve.oval.xml.bz2"
export TEST_OVAL=$(curl -slSL --connect-timeout ${C} --max-time ${M} --retry 2 --retry-delay 2 -w %{http_code} -o /dev/null ${OVAL_URI} 2>&1)
[[ ${OSSA_DEBUG} = true ]] && { echo "${TEST_OVAL}"; }
if [[ ${TEST_OVAL:(-3)} -eq 404 ]];then
	printf "\e[2GOVAL data file for Ubuntu ${OSSA_CODENAME^} is not available. Skipping download.\n"
elif [[ ${TEST_OVAL:(-3)} -eq 000 ]];then
	printf "\e[2GNetwork issues prevented download of OVAL data for Ubuntu ${OSSA_CODENAME}\n"
fi

####################
# PERFORM CVE SCAN #
####################

if [[ ${TEST_OVAL:(-3)} -eq 200 ]];then
	printf "\e[4GInitiating CVE Scan:\n\e[6GOVAL Data OS: Ubuntu ${OSSA_CODENAME^}\n"
	curl -slSL --connect-timeout ${C} --max-time ${M} --retry 2 --retry-delay 2 ${OVAL_URI} -o- |bunzip2 -d|tee 1>/dev/null ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2})
printf "\e[6GOVAL Scan Type:  Package manifest\n\e[6GOrigin Hostname: ${OSSA_HOST}\n\e[6GOrigin Codename: ${OSSA_CODENAME^}\n\n"
	oscap oval eval --report ${OSSA_WORKDIR}/oscap-cve-scan-report.${OSSA_HOST,,}.html ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2})|awk -vF=0 -vT=0 '{if ($NF=="false") F++} {if ($NF=="true") T++} END {print "CVE Scan Results (Summary)\n  Common Vulnerabilities Addressed: "F"\n  Current Vulnerability Exposure: "T}'|tee ${OSSA_WORKDIR}/cve-stats.${OSSA_HOST,,}|sed 's/^.*$/ &/g'
fi

echo;echo
