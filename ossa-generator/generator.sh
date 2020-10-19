#!/bin/bash

export OSSA_VER=1.0
export VERBOSE=true
[[ -z ${1} || ${1} =~ -h || ! -f ${1} ]] && { echo -en "Usage: ./${PROG} <path to ossa archive>\nNote: sudo access is required\n" 1>&2;exit 2; }
[[ -f ${1} ]] && export OSSA_ARCHIVE=${1}

#Root/sudo check
[[ ${EUID} -eq 0 ]] && { export SCMD="";[[ ${DEBUG} = True ]] && { printf "\e[38;2;255;200;0mDEBUG: User is root\n\n"; };exit; } || { [[ ${EUID} -ne 0 && -n $(id|grep -io sudo) ]] && export SCMD=sudo || { export SCMD="";printf "\e[38;2;255;0;0mERROR: User (${USER}) does not have sudo permissions. Quitting.\n\n";exit 5; }; }

[[ ${DEBUG} = true ]] && { set -x;export VERBOSE=true; }
export SCRIPT="$(readlink -f $( cd "$( dirname "${BASH_SOURCE[0]}" )/" && pwd )/${BASH_SOURCE[0]##*/})"
export SCRIPT_DIR=${SCRIPT%/*}
export PROG=${0##*/}
declare -c TITLE="${PROG//.sh}"
export TITLE_FULL="OSSA ${TITLE}"
export NO_CVE_SCAN=false

printf "\n\e[1mOSSA Generator Version ${OSSA_VER}\e[0m\n\n"
printf "\e[2G - Using OSSA data from ${OSSA_ARCHIVE}\n"

trap 'tput cnorm;[[ ${DEBUG} = true ]] && set +x;export VERBOSE=false;trap - INT TERM EXIT KILL QUIT;exit 0' INT TERM EXIT KILL QUIT;

# Set timer 
TZ=UTC export NOW=$(date +%s)sec

# Turn off cursor
tput civis

# source OSSA functions
[[ -f ${SCRIPT_DIR}/../lib/ossa_functions && ${VERBOSE} = true ]] && { printf "\e[2G - Sourcing OSSA functions: ${SCRIPT_DIR}/../lib/ossa_functions\n"; }
[[ -f ${SCRIPT_DIR}/../lib/ossa_functions ]] && source ${SCRIPT_DIR}/../lib/ossa_functions

# set OSSA_HOST based on OSSA_ARCHIVE filename
[[ -n ${OSSA_ARCHIVE} ]] && export OSSA_HOST=$(grep -oP '(?<=data\.).*(?=\.tgz$)' <<< "${OSSA_ARCHIVE}") || export OSSA_HOST=unknown
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Parsed OSSA_HOST to ${OSSA_HOST}\n"; }

# main ossa directory
export OSSA_DIR=/opt/ossa

# working directory for this assessment
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Working directory for ${OSSA_HOST} will be set to ${OSSA_WORKDIR}\n"; }
export OSSA_WORKDIR="${OSSA_DIR}/${OSSA_HOST}"

# set ossa user
[[ -z ${OSSA_USER} ]] && export OSSA_USER=${OSSA_USER:-$(id -un 1000)}
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Parameter \$OSSA_USER has been set to ${OSSA_USER}\n"; }

# set ossa group 
[[ -z ${OSSA_GROUP} ]] && export OSSA_GROUP=${OSSA_GROUP:-$(id -gn 1000)}
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Parameter \$OSSA_GROUP has been set to ${OSSA_GROUP}\n"; }

# set rc file
export OSSA_RC=${OSSA_WORKDIR}/ossarc
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Setting parameter \$OSSA_RC (runtime configuration) to ${OSSA_RC}\n"; }

# Make working directroy and extract the archive
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Extracting OSSA data from ${OSSA_ARCHIVE}\n"; }
${SCMD} mkdir -p ${OSSA_WORKDIR}
[[ -f ${OSSA_ARCHIVE} ]] && ${SCMD} tar -C ${OSSA_WORKDIR} -xzf ${OSSA_ARCHIVE}
[[ -n $(find ${OSSA_WORKDIR} -maxdepth 1 -type f -iname "apt-files.*\.tar") && ${VERBOSE} = true ]] && { printf "\e[2G - Extracting $(find ${OSSA_WORKDIR} -maxdepth 1 -type f -iname "apt-files.*\.tar")\n"; }
[[ -n $(find ${OSSA_WORKDIR} -maxdepth 1 -type f -iname "apt-files.*\.tar") ]] && { ${SCMD} mkdir -p ${OSSA_WORKDIR}/apt && ${SCMD} tar -C ${OSSA_WORKDIR}/apt -xf $(find ${OSSA_WORKDIR} -maxdepth 1 -type f -iname "apt-files.*\.tar"); }

# set workdir permisssions
if [[ -n ${OSSA_WORKDIR} && -d ${OSSA_WORKDIR} ]];then
	[[ ${VERBOSE} = true ]] && { printf "\e[2G - Setting permissions on directory ${OSSA_WORKDIR}\n"; }
	${SCMD} find ${OSSA_WORKDIR} \( -type d -exec chmod u+rwx,g+rwx,o+rx {} \; -o -type f -exec chmod u+rw,g+rw,o+r {} \; \)
	[[ ${VERBOSE} = true ]] && { printf "\e[2G - Setting ownership on directory ${OSSA_WORKDIR} to ${OSSA_USER}:${OSSA_GROUP}\n"; }
	${SCMD} find ${OSSA_WORKDIR} \( -type d -exec chown ${OSSA_USER}:${OSSA_GROUP} {} \; -o -type f -exec chown ${OSSA_USER}:${OSSA_GROUP} {} \; \)
fi

# populate rc file with current OSSA* env settings
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Adding current OSSA env variables to ${OSSA_RC}\n"; }
set|grep ^OSSA|sed 's|^|export |g'|tee 1>/dev/null ${OSSA_RC}

# add file locations to rc
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Adding OSSA file variables to ${OSSA_RC}\n"; }
(cd ${OSSA_WORKDIR} && ls -1|xargs -rn1 -P0 bash -c 'V=${0%%.*};V=${V^^};V=${V//-/_};echo $V="$( cd "$( dirname "${0}" )/" && pwd )/${0##*/}"'|tee 1>/dev/null -a ${OSSA_RC})

# re-source updated rc file
source-file ${OSSA_RC} -q

# Add lsb_release information to rc file
[[ -f ${LSB_RELEASE} ]] && sed 's/DISTRIB/OSSA/g' ${LSB_RELEASE} |tee 1>/dev/null -a ${OSSARC}

# re-source updated rc file
source-file ${OSSA_RC} -q

# Create manifest
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Creating package manifest from dpkg -l output\n"; }
[[ -s ${DPKG_L} ]] && { awk '/^ii/{gsub(/:.*$/,"",$2);print $2,$3}' ${DPKG_L} |tee 1>/dev/null ${OSSA_WORKDIR}/manifest.${OSSA_HOST}; }
echo "export OSSA_MANIFEST=${OSSA_WORKDIR}/manifest.${OSSA_HOST}"|tee 1>/dev/null -a ${OSSARC}

# re-source updated rc file
source-file ${OSSA_RC} -q

# Create package origin list ( ~ apt-cache madison using files only)
if [[ -f ${OSSA_WORKDIR}/manifest.${OSSA_HOST} ]];then
	TZ=UTC export ORIGIN_NOW=$(date +%s)sec;
	SPID=$((cat ${OSSA_WORKDIR}/manifest.${OSSA_HOST})|xargs -rn2 -P0 bash -c 'printf "${0}|${1}|$(grep "^Package: ${0//+/\+}$" '${OSSA_WORKDIR}'/apt/var/lib/apt/lists/*_Packages|head -n1|sed -r "s/^.*dists_|_binary.*$//g;s/_/\//g")\n"'|tee 1>/dev/null ${OSSA_WORKDIR}/apt-madison.out) &
	SPID=$!
	declare -ag CHARS=($(printf "\u22EE\u2003\b") $(printf "\u22F0\u2003\b") $(printf "\u22EF\u2003\b") $(printf "\u22F1\u2003\b"))
	if [[ ${DEBUG} = true ]];then
		[[ ${VERBOSE} = true ]] && { printf "\e[2G - Parsing package origin information. Please wait\n"; }
	else
		while kill -0 $SPID 2>/dev/null;do
			for c in ${CHARS[@]};do printf 1>&2 "\r\e[2G - ${TITLE_FULL}: Parsing package origin information. Please wait %s  (Elapsed Time: $(TZ=UTC date --date now-${ORIGIN_NOW} "+%M:%S"))\e[K\e[0m" $c;sleep .03;done
		done
	fi
	wait $SPID
	[[ ${VERBOSE} = true ]] && { echo -en "\r\e[K\r\e[2G - Parsing package origin information took $(TZ=UTC date --date now-${ORIGIN_NOW} "+%H:%M:%S").\n"; }

	# add package origin file info to rc file
	[[ ${VERBOSE} = true ]] && { printf "\e[2G - Adding OSSA_MADISON env variable to ${OSSA_RC}\n"; }
	echo "export OSSA_MADISON=\"${OSSA_WORKDIR}/apt-madison.out\""|tee 1>/dev/null -a ${OSSARC}

	# Copy lines without origin info from OSSA_MADISON to ${OSSA_WORKDIR}/unknown-origin.list
	[[ ${VERBOSE} = true ]] && { printf "\e[2G - Parsing packages with unknown origins\n"; }
	grep -- "\|$" ${OSSA_WORKDIR}/apt-madison.out|tee 1>/dev/null ${OSSA_WORKDIR}/unknown-origin.list
	echo "export OSSA_UNKNOWN_PKGS=\"${OSSA_WORKDIR}/unknown-origin.list\""|tee 1>/dev/null -a ${OSSARC}

	# Remove lines without origin info from OSSA_MADISON
	[[ ${VERBOSE} = true ]] && { printf "\e[2G - Stripping unknown origins from ${OSSA_WORKDIR}/apt-madison.out\n"; }
	sed -i '/|$/d' ${OSSA_WORKDIR}/apt-madison.out
# re-source updated rc file
	source-file ${OSSA_RC} -q
fi


# Run get-release-info function
if [[ ! -f ${OSSA_WORKDIR}/ubuntu-releases.csv ]];then
	[[ ${VERBOSE} = true ]] && { printf "\e[2G - Running function \"get-release-info\"\n"; }
	get-release-info
	# Add ubuntu-releases.csv info to rc file
	([[ -f ${OSSA_WORKDIR}/ubuntu-releases.csv ]] && echo "export OSSA_RELEASE_CSV=${OSSA_WORKDIR}/ubuntu-releases.csv"|tee 1>/dev/null -a ${OSSA_RC})
	# re-source updated rc file
	source-file ${OSSA_RC} -q
fi

# Run show-release-info function
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Running function \"show-release-info\"\n"; }
show-release-info
# add release info tables to rc file
[[ -f ${OSSA_WORKDIR}/release-info-ansi && ${VERBOSE} = true ]] && { printf "\e[2G - Updating \${OSSA_RC} with location of release-info (ansi version)\n"; }
([[ -f ${OSSA_WORKDIR}/release-info-ansi ]] && echo "export OSSA_RELEASE_TABLE_ANSI=${OSSA_WORKDIR}/release-info-ansi"|tee 1>/dev/null -a ${OSSA_RC})
[[ -f ${OSSA_WORKDIR}/release-info && ${VERBOSE} = true ]] && { printf "\e[2G - Updating \${OSSA_RC} with location of release-info (txt version)\n"; }
([[ -f ${OSSA_WORKDIR}/release-info ]] && echo "export OSSA_RELEASE_TABLE=${OSSA_WORKDIR}/release-info"|tee 1>/dev/null -a ${OSSA_RC})

# re-source updated rc file
source-file ${OSSA_RC} -q


# Create package origin table
if [[ -f ${OSSA_WORKDIR}/apt-madison.out ]];then
	[[ ${VERBOSE} = true ]] && { printf "\e[2G - Making package origin tables...\n"; }
	declare -ag COMPONENTS=(main universe multiverse restricted)
	declare -ag POCKETS=(${OSSA_CODENAME} ${OSSA_CODENAME}-updates ${OSSA_CODENAME}-security ${OSSA_CODENAME}-backports ${OSSA_CODENAME}-proposed)
	for x in ${COMPONENTS[@]};do
		declare -ag ${x^^}=\(\);eval ${x^^}+=\( $(grep "/${x}" ${OSSA_MADISON}|wc -l) \)
		for y in ${POCKETS[@]};do
			eval ${x^^}+=\( ${y}:$(grep "${y}/${x}" ${OSSA_MADISON}|wc -l) \)
		done
	done
	export COMPONENT_TOTAL=$((${MAIN[0]##*:}+${UNIVERSE[0]##*:}+${MULTIVERSE[0]##*:}+${RESTRICTED[0]##*:}))
	export RELEASE_TOTAL=$((${MAIN[1]##*:}+${UNIVERSE[1]##*:}+${MULTIVERSE[1]##*:}+${RESTRICTED[1]##*:}))
	export UPDATES_TOTAL=$((${MAIN[2]##*:}+${UNIVERSE[2]##*:}+${MULTIVERSE[2]##*:}+${RESTRICTED[2]##*:}))
	export SECURITY_TOTAL=$((${MAIN[3]##*:}+${UNIVERSE[3]##*:}+${MULTIVERSE[3]##*:}+${RESTRICTED[3]##*:}))
	export BACKPORTS_TOTAL=$((${MAIN[4]##*:}+${UNIVERSE[4]##*:}+${MULTIVERSE[4]##*:}+${RESTRICTED[4]##*:}))
	export PROPOSED_TOTAL=$((${MAIN[5]##*:}+${UNIVERSE[5]##*:}+${MULTIVERSE[5]##*:}+${RESTRICTED[5]##*:}))	
	((for ((i=0; i<${#POCKETS[@]}; i++)); do printf '%s\n' ${POCKETS[i]};done|paste -sd"|"|sed 's/^/Ubuntu '${OSSA_CODENAME^}'|'${OSSA_HOST}'|/g'
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[0]} ${MAIN[0]##*:} ${MAIN[1]##*:} ${MAIN[2]##*:} ${MAIN[3]##*:} ${MAIN[4]##*:} ${MAIN[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[1]} ${UNIVERSE[0]##*:} ${UNIVERSE[1]##*:} ${UNIVERSE[2]##*:} ${UNIVERSE[3]##*:} ${UNIVERSE[4]##*:} ${UNIVERSE[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[2]} ${MULTIVERSE[0]##*:} ${MULTIVERSE[1]##*:} ${MULTIVERSE[2]##*:} ${MULTIVERSE[3]##*:} ${MULTIVERSE[4]##*:} ${MULTIVERSE[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[3]} ${RESTRICTED[0]##*:} ${RESTRICTED[1]##*:} ${RESTRICTED[2]##*:} ${RESTRICTED[3]##*:} ${RESTRICTED[4]##*:} ${RESTRICTED[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' Totals ${COMPONENT_TOTAL} ${RELEASE_TOTAL} ${UPDATES_TOTAL} ${SECURITY_TOTAL} ${BACKPORTS_TOTAL} ${PROPOSED_TOTAL}
	)|column -nexts"|"|tee ${OSSA_WORKDIR}/package_table.txt| \
	sed -re '1s/Ubuntu '${OSSA_CODENAME^}'/'$(printf "\e[1;48;2;233;84;32m\e[1;38;2;255;255;255m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_CODENAME}'/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_HOST}'/'$(printf "\e[1;48;2;255;255;255m\e[1;38;2;233;84;32m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_CODENAME}'-updates/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_CODENAME}'-security/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_CODENAME}'-backports/'$(printf "\e[38;2;255;200;0m")'&'$(printf "\e[0m")'/g' \
		-re '1s/'${OSSA_CODENAME}'-proposed/'$(printf "\e[38;2;255;0;0m")'&'$(printf "\e[0m")'/g' \
		-re 's/main|universe/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/g' \
		-re 's/multiverse.*$|restricted.*$/'$(printf "\e[38;2;255;0;0m")'&'$(printf "\e[0m")'/g')|tee ${OSSA_WORKDIR}/package-table-ansi|sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'|tee 1>/dev/null ${OSSA_WORKDIR}/package-table
fi

# add package table info tables to rc file
[[ -f ${OSSA_WORKDIR}/package-table-ansi && ${VERBOSE} = true ]] && { printf "\e[2G - Updating \${OSSA_RC} with location of package-table (ansi version)\n"; }
([[ -f ${OSSA_WORKDIR}/package-table-ansi ]] && echo "export OSSA_PACKAGE_TABLE_ANSI=${OSSA_WORKDIR}/package-table-ansi"|tee 1>/dev/null -a ${OSSA_RC})
[[ -f ${OSSA_WORKDIR}/package-table && ${VERBOSE} = true ]] && { printf "\e[2G - Updating \${OSSA_RC} with location of package-table (text version)\n"; }
([[ -f ${OSSA_WORKDIR}/package-table ]] && echo "export OSSA_PACKAGE_TABLE=${OSSA_WORKDIR}/package-table"|tee 1>/dev/null -a ${OSSA_RC})

# re-source updated rc file
source-file ${OSSA_RC} -q


# get package names for popularity contest
if [[ -f ${OSSA_WORKDIR}/popularity-contest.${OSSA_HOST} ]];then
	[[ ${VERBOSE} = true ]] && { printf "\e[2G - Parsing \"popularity-contest\" data\n"; }
	TZ=UTC export POPC_NOW=$(date +%s)sec;
	SPID=$((awk 'BEGIN { cmd="dpkg -S" $4"|sed 's/:.*$//g'"};{if ($0 ~ /"POPULAR"/) next};{OFS=",";if ( $1 ~ /^[0-9]+$/ && $1 != 0) {cmd="dpkg -S "$4"|sed 's/:.*$//g'";cmd|getline P;print strftime("%Y-%m-%d-%H:%M:%S", $1),strftime("%Y-%m-%d-%H:%M:%S", $2),$3,$4,P;next} else print $1,$2,$3,$4;next}' ${OSSA_WORKDIR}/popularity-contest.${OSSA_HOST})|tee 1>/dev/null ${OSSA_WORKDIR}/popularity-contest.processed) &
	SPID=$!
	declare -ag CHARS=($(printf "\u22EE\u2003\b") $(printf "\u22F0\u2003\b") $(printf "\u22EF\u2003\b") $(printf "\u22F1\u2003\b"))
	if [[ ${DEBUG} = true ]];then
		[[ ${VERBOSE} = true ]] && { printf "\e[2G - Parsing popularity-contest data. Please wait\n"; }
	else
		while kill -0 $SPID 2>/dev/null;do
			for c in ${CHARS[@]};do printf 1>&2 "\r\e[2G - ${TITLE_FULL}: Parsing popularity-contest data. Please wait %s  (Elapsed Time: $(TZ=UTC date --date now-${POPC_NOW} "+%M:%S"))\e[K\e[0m" $c;sleep .03;done
		done
	fi
	wait $SPID
	[[ ${VERBOSE} = true ]] && { echo -en "\r\e[K\r\e[2G - Parsing popularity-contest data took $(TZ=UTC date --date now-${POPC_NOW} "+%H:%M:%S").\n"; }
	([[ -f ${OSSA_WORKDIR}/popularity-contest.processed ]] && echo "export OSSA_POPCONTEST=\"${OSSA_WORKDIR}/popularity-contest.processed\""|tee 1>/dev/null -a ${OSSA_RC})
	# re-source updated rc file
	[[ -f ${OSSA_WORKDIR}/popularity-contest.processed ]] && source-file ${OSSA_RC} -q
fi


# Install OpenSCAP if not installed
[[ $(is-installed openscap-daemon) = true ]] || { printf "Installing OpenSCAP.  You may be prompted for your password\n";${SCMD} apt install -yq openscap-daemon &>/tmp/install.openscap-daemon.log; }
[[ $(is-installed openscap-daemon) = true ]] || { printf "Failure installing OpenSCAP.  Check log @ /tmp/install.openscap-daemon.log\n"; export NO_CVE_SCAN=true; }


# Test for presence of  OVAL data for Ubuntu release that is being assessed 
[[ ${VERBOSE} = true ]] && { printf "\e[2G - Checking the availability of OVAL Data for Ubuntu ${OSSA_CODENAME}\n"; }
export OVAL_URI="https://people.canonical.com/~ubuntu-security/oval/oci.com.ubuntu.${OSSA_CODENAME}.cve.oval.xml.bz2"
[[ ${VERBOSE} = true ]] && { printf "\e[2G - OVAL URL: ${OVAL_URI}\n"; }
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
	[[ ${VERBOSE} = true ]] && { printf "\e[2G - Initiating download of OVAL data for Ubuntu ${OSSA_CODENAME^}\n"; }
	curl -slSL --connect-timeout 10 --max-time 30 --retry 2 --retry-delay 2 ${OVAL_URI} -o- |bunzip2 -d|tee 1>/dev/null ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2})
	TEST_OVAL_RC="$?"
	[[ $? -eq 0 && -f ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2}) ]] || { OVAL_MSG="Error(s) occurred (${TEST_OVAL_RC}) while downloading OVAL data for Ubuntu ${OSSA_CODENAME}\n";export NO_CVE_SCAN=true; }
fi

[[ -f ${OSSA_WORKDIR}/release-info && ${VERBOSE} = true ]] && { printf "\e[2G - Displaying \"release-info\"\n\n"; }
[[ -f ${OSSA_WORKDIR}/release-info ]] && { cat ${OSSA_WORKDIR}/release-info|sed 's/^.*$/      &/g'; }
echo;echo

[[ -f ${OSSA_WORKDIR}/package-table && ${VERBOSE} = true ]] && { printf "\e[2G - Displaying \"package-table\"\n\n"; }
[[ -f ${OSSA_WORKDIR}/package-table ]] && { cat ${OSSA_WORKDIR}/package-table|sed 's/^.*$/      &/g'; }
echo;echo

if [[ ${NO_CVE_SCAN} = false && ${TEST_OVAL:(-3)} -eq 200 && -f ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2}) ]];then
	[[ ${VERBOSE} = true ]] && { printf "\e[2G - Initiating CVE scan for Ubuntu ${OSSA_CODENAME^}\n\n"; }
	oscap oval eval --report ${OSSA_WORKDIR}/oscap-cve-scan-report.${OSSA_HOST,,}.htm ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2})|awk -vF=0 -vT=0 '{if ($NF=="false") F++} {if ($NF=="true") T++} END {print "CVE Scan Results (Summary)\n  Common Vulnerabilities Addressed: "F"\n  Current Vulnerability Exposure: "T}'|tee ${OSSA_WORKDIR}/cve-stats.${OSSA_HOST,,}|sed 's/^.*$/      &/g'
else
	printf "\e[2G - ERROR: Cannot perform CVE Scan\nREASON: ${OVAL_MSG}\n\n"	
fi

echo -en "\n${TITLE_FULL} for ${OSSA_HOST} completed in $(TZ=UTC date --date now-${ORIGIN_NOW} "+%H:%M:%S")"|tee -a ${OSSA_WORKDIR}/ossa-generator.log
echo;echo

[[ ${DEBUG} = true ]] && { set +x;export VERBOSE=false DEBUG=false; }
