#!/bin/bash

[[ -z ${1} || ${1} =~ -h || ! -f ${1} ]] && { echo -en "Usage: ./${0##*/} <path to ossa-lite archive>\nNote: sudo access is required\n" 1>&2;exit 2; }
[[ -f ${1} ]] && export OSSA_ARCHIVE=${1}

export PROG_DIR="$( cd "$( dirname "${0}" )/" && pwd )"

#Root/sudo check
[[ ${EUID} -eq 0 ]] && { export SCMD="";[[ ${DEBUG} = True ]] && { printf "\e[38;2;255;200;0mDEBUG: User is root\n\n"; };exit; } || { [[ ${EUID} -ne 0 && -n $(id|grep -io sudo) ]] && export SCMD=sudo || { export SCMD="";printf "\e[38;2;255;0;0mERROR: User (${USER}) does not have sudo permissions. Quitting.\n\n";exit 5; }; }

printf "Using OSSA data from ${OSSA_ARCHIVE}\n"
# set ossa user
printf "Setting \${OSSA_USER} to "
[[ -z ${OSSA_USER} ]] && export OSSA_USER=${OSSA_USER:-$(id -un 1000)};echo $OSSA_USER
# set ossa group
printf "Setting \${OSSA_GROUP} to "
[[ -z ${OSSA_GROUP} ]] && export ${OSSA_GROUP:-$(id -gn 1000)};echo ${OSSA_GROUP}
# main ossa directory
export OSSA_DIR=/opt/ossa;printf "Setting \${OSSA_DIR} to ${OSSA_DIR}\n"
# working directory for this assesment 
export OSSA_WORKDIR="${OSSA_DIR}/$(basename ${OSSA_ARCHIVE%.*})";printf "Setting \${OSSA_WORKDIR} to ${OSSA_WORKDIR}\n"
# set rc file
export OSSA_RC=${OSSA_WORKDIR}/ossarc;printf "Setting \${OSSA_RC} to ${OSSA_RC}\n"
# Make working directroy and extract the archive
printf "Exractive OSSA data from ${OSSA_ARCHIVE}\n"
${SCMD} mkdir -p ${OSSA_WORKDIR} && ${SCMD} tar -C ${OSSA_WORKDIR} -xzf ${OSSA_ARCHIVE}
# set workdir permisssions
if [[ -n ${OSSA_WORKDIR} && -d ${OSSA_WORKDIR} ]];then
	printf "Setting permissions on directory ${OSSA_WORKDIR}\n"
	${SCMD} find ${OSSA_WORKDIR} \( -type d -exec chmod u+rwx,g+rwx,o+rx {} \; -o -type f -exec chmod u+rw,g+rw,o+r {} \; \)
	printf "Setting ownership on directory ${OSSA_WORKDIR} to ${OSSA_USER}.${OSSA_GROUP}\n"
	${SCMD} find ${OSSA_WORKDIR} \( -type d -exec chown ${OSSA_USER}.${OSSA_GROUP} {} \; -o -type f -exec chown ${OSSA_USER}:${OSSA_GROUP} {} \; \)
fi
# populate rc file with current OSSA* env settings
printf "Adding current OSSA env variables to ${OSSA_RC}\n"
set|grep ^OSSA|sed 's|^|export |g'|tee 1>/dev/null ${OSSA_RC}
# add file locations to rc
printf "Adding OSSA file variables to ${OSSA_RC}\n"
(cd ${OSSA_WORKDIR} && ls -1|xargs -rn1 -P0 bash -c 'V=${0%%.*};V=${V^^};V=${V//-/_};echo $V="$( cd "$( dirname "${0}" )/" && pwd )/${0##*/}"'|tee 1>/dev/null -a ${OSSA_RC})
[[ -s ${OSSA_RC} ]] && { printf "Sourcing RC file (${OSSA_RC})\n";source ${OSSA_RC}; }
[[ -f ${LSB_RELEASE} ]] && sed 's/DISTRIB/OSSA/g' ${LSB_RELEASE} |tee 1>/dev/null -a ${OSSARC}
echo export OSSA_HOST=$(grep -oP '(?<=madison\.)[^$]+' <<< "${OSSA_ARCHIVE//.tgz}")|tee 1>/dev/null -a ${OSSARC}
[[ -s ${OSSA_RC} ]] && source ${OSSA_RC}
# Create manifest
[[ -s ${DPKG_L} ]] && { awk '/^ii/{print $2"\t"$3}' ${DPKG_L}|tee 1>/dev/null ${OSSA_WORKDIR}/manifest.${OSSA_HOST}; }
echo "export OSSA_MANIFEST=${OSSA_WORKDIR}/manifest.${OSSA_HOST}"|tee 1>/dev/null -a ${OSSARC}
[[ -s ${OSSA_RC} ]] && source ${OSSA_RC}
clear
# Show package breakdown by component and suite
if [[ -f ${APT_MADISON} ]];then
	declare -ag COMPONENTS=(main universe multiverse restricted)
	declare -ag POCKETS=(${OSSA_CODENAME} ${OSSA_CODENAME}-updates ${OSSA_CODENAME}-security ${OSSA_CODENAME}-backports ${OSSA_CODENAME}-proposed)
	for x in ${COMPONENTS[@]};do
		declare -ag ${x^^}=\(\);eval ${x^^}+=\( $(grep "/${x}" ${APT_MADISON}|wc -l) \)
		for y in ${POCKETS[@]};do
			eval ${x^^}+=\( ${y}:$(grep "${y}/${x}" ${APT_MADISON}|wc -l) \)
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
		-re 's/multiverse.*$|restricted.*$/'$(printf "\e[38;2;255;0;0m")'&'$(printf "\e[0m")'/g')|sed 's/^.*$/ &/g'|tee ${OSSA_WORKDIR}/package_table.ansi
		printf '\n\n'
fi
#cp ${OSSA_MANIFEST} ${PROG_DIR}
#printf "Running cvescan -f ${PROG_DIR}/${OSSA_MANIFEST##*/} -p all\n"
#cvescan -f ${PROG_DIR}/${OSSA_MANIFEST##*/}

######################
# DOWNLOAD OVAL DATA #
######################

export OVAL_URI="https://people.canonical.com/~ubuntu-security/oval/oci.com.ubuntu.${OSSA_CODENAME}.cve.oval.xml.bz2"
export TEST_OVAL=$(curl -slSL --connect-timeout 5 --max-time 20 --retry 5 --retry-delay 1 -w %{http_code} -o /dev/null ${OVAL_URI} 2>&1)
[[ ${OSSA_DEBUG} = true ]] && { echo "${TEST_OVAL}"; }
if [[ ${TEST_OVAL:(-3)} -eq 404 ]];then
	printf "\e[2GOVAL data file for Ubuntu ${OSSA_CODENAME^} is not available. Skipping download.\n"
elif [[ ${TEST_OVAL:(-3)} -eq 200 ]];then
	printf "\e[2GDownloading OVAL data for Ubuntu ${OSSA_CODENAME^}\n"
	curl -slSL --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 ${OVAL_URI} -o- |bunzip2 -d|tee 1>/dev/null ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2})
elif [[ ${TEST_OVAL:(-3)} -eq 000 ]];then
	printf "\e[2GNetwork issues prevented download of OVAL data for Ubuntu ${OSSA_CODENAME}\n"
fi

####################
# PERFORM CVE SCAN #
####################

if [[ ${TEST_OVAL:(-3)} -eq 200 ]];then
	printf "\e[2GInitiating CVE Scan against package manifest collected from host ${OSSA_HOST} running Ubuntu ${OSSA_CODENAME^}...\n\n"
	oscap oval eval --report ${OSSA_WORKDIR}/oscap-cve-scan-report.${OSSA_HOST,,}.html ${OSSA_WORKDIR}/$(basename ${OVAL_URI//.bz2})|awk -vF=0 -vT=0 '{if ($NF=="false") F++} {if ($NF=="true") T++} END {print "CVE Scan Results (Summary)\nCommon Vulnerabilities Addressed: "F"\nCurrent Vulnerability Exposure: "T}'|tee ${OSSA_WORKDIR}/cve-stats.${OSSA_HOST,,}|sed 's/^.*$/ &/g'
fi
