#!/bin/bash
##############################################################################
# ossa.sh - Open Source Security Assessment 
#
#
#  Author(s): Craig Bender <craig.bender@canonical.com>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, version 3 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#  Copyright (C) 2020 Canonical Ltd.
#
##############################################################################

# Start Timer
TZ=UTC export NOW=$(date +%s)sec

################
# SET DEFAULTS #
################

export PROG=${0##*/}
export OSSA_DIR='/tmp/ossa_files'
export OSSA_HOST=$(hostname -s)
export OSSA_RELEASE="$(lsb_release 2>/dev/null -sc)"
export OSSA_SUFFX="${OSSA_HOST}.${OSSA_RELEASE}"
export OSSA_PURGE=true
export OSSA_KEEP=false
export OSSA_CREDS_DETECTED=false
export OSSA_IGNORE_CREDS=false
export OSSA_ENCRYPT=false
export OSSA_PW=
export OSSA_SCAN=false
export OSSA_SUDO=false
export OSSA_MADISON=true
export OSSA_DEBUG=false
declare -ag OSSA_ORIGINS=(Canonical Ubuntu LP-PPA-maas)
declare -ag OSSA_COPY_ERRORS=()


#########
# USAGE #
#########

ossa-full_Usage() {
    printf "\n\e[2GScript: ${FUNCNAME%%-*}.sh\n\n"
    printf "\e[2GUsage: ${FUNCNAME%%-*}.sh [ Options ] \n\n"
    printf "\e[2GOptions:\n\n"
    printf "\e[3G -d, --dir\e[28GDirectory to store Open Source Security Assessment Data (Default: /tmp/ossa_files)\n\n"
    printf "\e[3G -s, --suffix\e[28GAppend given suffix to collected files (Default: \".$(hostname -f).$(lsb_release 2>/dev/null -cs)\"\n\n"
    printf "\e[3G -o, --override\e[28GDo perform password scrubbing of embedded credentials (Default: false)\n\n"
    printf "\e[3G -n, --no-purge\e[28GDo NOT purge existing OSSA Directory (Default: False)\n\n"
    printf "\e[3G -k, --keep\e[28GKeep OSSA Directory after script completes (Default: False)\n\n"
    printf "\e[3G -e, --encrypt\e[28GEncrypt OSSA Datafiles with given passphrase (Default: False)\n\n"
    printf "\e[3G -m, --no-madison\e[28GDo not run apt-cache madison against package manifest (Default: False)\n\n"
    printf "\e[3G -O, --origins\e[28GIf you are running a mirror of an official ubuntu repository,\n\e[28Gadd the URL(s) to they can be marked as official\n\n\e[28GNote: Format should be a single URL or a space/comma\n\e[34Gseparated list, surrounded by quotes\n\n"
    printf "\e[3G -S, --scan\e[28GInstall OpenSCAP & scan manifest for CVEs. Sudo access is required only\n\e[28Gif OpenSCAP is not installed. (Default: False)\n\n"
    printf "\e[3G -D, --debug\e[28GEnable set -x\n\n"
    printf "\e[3G -t, --test\e[28GTests access to OVAL Data URL, increasing timeouts until http return code = 200\n\n"
    printf "\e[3G -h, --help\e[28GThis message\n\n"
    printf "\e[2GExamples:\n\n"
    printf "\e[4GChange location of collected data:\n"
    printf "\e[6G./${FUNCNAME%%_*}.sh -d \$HOME/ossa_files\n"
    printf "\n\e[4GSet custom file suffix:\n"
    printf "\e[6G./${FUNCNAME%%_*}.sh -s dc1.psql001.xenial\n"
    printf "\n\e[4GPerform CVE Scan, encrypt compressed archive of collected data, and\n\e[6Gkeep data directory after run\n\n"
    printf '\e[6G./'${FUNCNAME%%_*}'.sh -Ske '"'"'MyP@ssW0rd!'"'"' \n\n'
};export -f ossa-full_Usage


############
# URL-TEST #
############
test-oval-url() {
	export URI="https://people.canonical.com/~ubuntu-security/oval/oci.com.ubuntu.bionic.cve.oval.xml.bz2"
	export C=1 M=10 T=000
	echo "Testing connectivity to https://people.canonical.com/~ubuntu-security/oval/oci.com.ubuntu.bionic.cve.oval.xml.bz2"
	until [[ ${T:(-3)} -eq 200 ]];do 
		T="$(curl -slSL --connect-timeout ${C} --max-time ${M} -w %{http_code} --retry 0 -o /dev/null ${URI} 2>&1)"
		C=$((C+1)) M=$((M+1))
		[[ ${TL:(-3)} -eq 200 ]] && { echo "\rHTTP Code: $T Time Values: connect-timeout=$C max-time=$M\e[K\n\n"; } || { echo -en "\rHTTP Code: $T Time Values: connect-timeout=$C max-time=$M\e[K"; }
		sleep 1
	done
	echo
	return ${T:(-3)}
};export -f test-oval-url

################
# ARGS/OPTIONS #
################

ARGS=$(getopt -o s::d:e:O:SnomkDh --long suffix::,dir:,encrypt:,origins:,scan,no-purge,override,keep,no-madison,help,debug -n ${PROG} -- "$@")
eval set -- "$ARGS"
while true ; do
    case "$1" in
        -d|--dir) export OSSA_DIR=${2};shift 2;;
        -e|--encrypt) export OSSA_ENCRYPT=true;export OSSA_PW="${2}";shift 2;;
        -s|--suffix) case "$2" in '') export OSSA_SUFFX="";; *) export OSSA_SUFFX="${2}";;esac;shift 2;continue;;
        -n|--no-purge) export OSSA_PURGE=false;shift 1;;
        -o|--override) export OSSA_IGNORE_CREDS=true;shift 1;;
        -k|--keep) export OSSA_KEEP=true;shift 1;;
        -S|--scan) export OSSA_SCAN=true;shift 1;;
        -m|--no-madison) export OSSA_MADISON=false;shift 1;;
        -O|--origins) declare -ag EXTRA_ORIGINS=($(printf "${2//[,| ]/\\n}\n"));shift 2;;
        -D|--debug) export OSSA_DEBUG=true;shift 1;;
        -t|--test) test-oval-url;exit 0;;
        -h|--help) ossa-full_Usage;exit 2;;
        --) shift;break;;
    esac
done


###################
# START OF SCRIPT #
###################

[[ ${OSSA_DEBUG} = true ]] && { set -x; }

# Trap interupts and exits so we can restore the screen 
[[ ${OSSA_DEBUG} = true ]] || { trap 'tput sgr0; tput cnorm; tput rmcup; trap - INT TERM KILL;exit 0' INT TERM KILL; }

# Save screen contents, clear the screen and turn off the cursor
[[ ${OSSA_DEBUG} = true ]] || { tput smcup;tput civis;tput clear; }

############################
# DISPLAY SELECTED OPTIONS #
############################

# Print config/option data
printf "\n\e[1G\e[1mOpen Source Security Assessment Configuration\e[0m\n"
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: OSSA Data will be stored in \e[38;2;0;160;200m${OSSA_DIR}\e[0m\n"
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Purge Existing Directory option is \e[38;2;0;160;200m${OSSA_PURGE^^}\e[0m\n"
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Keep OSSA Data option is \e[38;2;0;160;200m${OSSA_KEEP^^}\e[0m\n"
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Override Password Protection option is \e[38;2;0;160;200m${OSSA_IGNORE_CREDS^^}\e[0m\n"
[[ ${OSSA_IGNORE_CREDS} = true ]] && { printf "\e[11G\e[38;2;255;200;0mWARNING\e[0m: Data may contain embedded credentials\n"; }
[[ ${OSSA_IGNORE_CREDS} = false ]] && { printf "\e[11G\e[1mNOTE\e[0m:Embedded credentials detected in files will be scrubbed\n"; }
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Archive Encryption option is \e[38;2;0;160;200m${OSSA_ENCRYPT^^}\e[0m\n"
[[ ${OSSA_ENCRYPT} = true ]] && { printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Encryption Passphrase is \"\e[38;2;0;160;200m${OSSA_PW}\e[0m\"\n"; }
[[ ${OSSA_ENCRYPT} = true ]] && { printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Performing cracklib-check against supplied passphrase. Result: $(cracklib-check <<< ${OSSA_PW}|awk -F': ' '{print $2}')\n"|sed 's/\ OK.*$/'$(printf "\e[38;2;0;255;0m&\e[0m")'/g;s/\ it.*$/'$(printf "\e[38;2;255;0;0m&\e[0m")'/g;s/\ it/\ It/g'; }
# If Suffix is set, make sure it doesn't start with a period
if [[ -n ${OSSA_SUFFX} ]];then
    [[ ${OSSA_SUFFX:0:1} = '.' ]] && export OSSA_SUFFX="${OSSA_SUFFX:1}"
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: A Suffix of \"\e[38;2;0;160;200m${OSSA_SUFFX}\e[0m\" will be appended to each file collected\n"
else
    export OSSA_SUFFX=
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: File suffix is \e[38;2;0;160;200mNULL\e[0m\n"
fi
# Report customer provided origin list
if [[ -n ${EXTRA_ORIGINS[@]} && ${#EXTRA_ORIGINS[@]} -ge 1 ]];then
	printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: The following mirror URLs were provided as official Ubuntu or Canonical Mirrors:\n"
	printf '\e[12G - \e[38;2;0;160;200m%s\e[0m\n' ${EXTRA_ORIGINS[@]}
fi
# Added ability to scan for CVEs
# This requires either that OpenSCAP is already installed or root level access to install the package
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Scan option is \e[38;2;0;160;200m${OSSA_SCAN^^}\e[0m\n"
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Run apt-cache madison is option is \e[38;2;0;160;200m${OSSA_MADISON^^}\e[0m\n"
if [[ ${OSSA_SCAN} = true ]];then
    if [[ $(dpkg 2>/dev/null -l openscap-daemon|awk '/openscap-daemon/{print $1}') = ii ]];then
        printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: OpenSCAP is \e[1malready installed\e[0m.  \e[38;2;0;255;0mRoot-level access is not required\e[0m.\n"
    else
        printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: OpenSCAP is \e[1mNOT\e[0m installed.  \e[38;2;255;200;0mRoot-level access will be required\e[0m.  Checking credentials...\n"
        #Root/sudo check
        [[ ${EUID} -eq 0 ]] && { export SCMD="";[[ ${DEBUG} = True ]] && { printf "\e[38;2;255;200;0mDEBUG:\e[0m User is root\n\n";export OSSA_SUDO=true; }; } || { [[ ${EUID} -ne 0 && -n $(id|grep -io sudo) ]] && { export SCMD=sudo;export OSSA_SUDO=true; } || { export SCMD="";printf "\e[38;2;255;0;0mERROR:\e[0m User (${USER}) does not have sudo permissions.\e[0m Quitting.\e[0m\n\n";export OSSA_SUDO=false; }; }
        [[ ${OSSA_SUDO} = false ]] && { export OSSA_SCAN=false;printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Insufficent sudo privilages.  CVE Scanning will not occur\n"; }
        [[ ${OSSA_SUDO} = true ]] && { export OSSA_SCAN=true;printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: User has sufficent sudo privilages to install packages.  CVE Scanning occur as desired\n"; }
        [[ ${OSSA_SUDO} = true && ${OSSA_SCAN} = true ]] && { printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Installing OpenSCAP to scan for high and critical CVEs\n";${SCMD} apt 2>/dev/null install openscap-daemon -yqq >/dev/null 2>&1; }
        [[ ${OSSA_SUDO} = true && ${OSSA_SCAN} = true ]] && { [[ $(dpkg -l openscap-daemon|awk '/openscap-daemon/{print $1}') = ii ]];printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: OpenSCAP installed successfully\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: OpenSCAP did not appear to install correctly.  Cancelling CVE Scan\n";export OSSA_SCAN=false; }
    fi
fi

###############################
# CREATE DIRECTORIES FOR DATA #
###############################

# Create OSSA Directory to store files
printf "\n\e[2G\e[1mCreate OSSA Data Directory\e[0m\n"

# Remove existing directory if user chose that option
if [[ ${OSSA_PURGE} = true ]];then
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Removing existing directory: ${OSSA_DIR}\n"
    [[ -d ${OSSA_DIR} ]] && { rm -rf ${OSSA_DIR}; } || { printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Existing directory does not exist.\n"; } 
    [[ -d ${OSSA_DIR} ]] && { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not remove existing directory ${OSSA_DIR}\n"; } || { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Removed existing directory ${OSSA_DIR}\n"; }
fi

# Create OSSA Directory using a given name
mkdir -p ${OSSA_DIR}/{apt/package-files,apt/release-files,apt/source-files/part-files,util-output,manifests,oval_data,reports}
[[ -d ${OSSA_DIR} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created directory ${OSSA_DIR}\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not create directory ${OSSA_DIR}\n";exit; }

export PKG_DIR=${OSSA_DIR}/apt/package-files
export REL_DIR=${OSSA_DIR}/apt/release-files
export SRC_DIR=${OSSA_DIR}/apt/source-files
export PARTS_DIR=${SRC_DIR}/part-files
export UTIL_DIR=${OSSA_DIR}/util-output
export MFST_DIR=${OSSA_DIR}/manifests
export OVAL_DIR=${OSSA_DIR}/oval_data
export RPRT_DIR=${OSSA_DIR}/reports

#####################################
# LINUX STANDARD BASE (lsb_release) #
#####################################

# Fetch lsb-release file if it exists, otherwise generate a similar file
printf "\n\e[2G\e[1mGather Linux Standard Base Information (lsb_release)\e[0m\n"
if [[ -f /etc/lsb-release ]];then
  printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Copying /etc/lsb-release to ${UTIL_DIR}/\n"
    cp /etc/lsb-release ${UTIL_DIR}/lsb-release.${OSSA_SUFFX}
		[[ -s ${UTIL_DIR}/lsb-release.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Copied lsb-release information\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not copy lsb-release information\n"; }
else
    if [[ -n $(command -v lsb_release) ]];then
        printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Creating lsb-release file using $(which lsb_release)\n"
        for i in ID RELEASE CODENAME DESCRIPTION;do echo DISTRIB_${i}=$(lsb_release -s$(echo ${i,,}|cut -c1)); done|tee 1>/dev/null ${UTIL_DIR}/lsb-release.${OSSA_SUFFX}
				[[ -s ${UTIL_DIR}/lsb-release.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Copied lsb-release information\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not copy lsb-release information\n"; }
    else
        printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: lsb_release is not installed.  Skipping.\n"
    fi
fi

#########################
# CREATE MANIFEST FILES #
#########################

# Create a variety of manifest files
printf "\n\e[2G\e[1mCreate Package Manifest Files\e[0m\n"

# Create manifest file
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Creating manifest file\n"
(dpkg -l|awk '/^ii/&&!/^$/{print $2"\t"$3}'|sort -uV)|tee 1>/dev/null ${MFST_DIR}/manifest.${OSSA_SUFFX}
[[ -s ${MFST_DIR}/manifest.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created manifest file\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not create manifest file\n"; }

if [[ ${OSSA_MADISON} = true ]];then
	TZ=UTC export MADISON_NOW=$(date +%s)sec
	[[ -f ${MFST_DIR}/madison.out.${OSSA_SUFFX} ]] && rm -f ${MFST_DIR}/madison.out.${OSSA_SUFFX}
	touch ${MFST_DIR}/madison.out.${OSSA_SUFFX}
	# Get madison information for manifest and show a spinner while it runs
	((awk '{print $1}' ${MFST_DIR}/manifest.${OSSA_SUFFX} |xargs -rn1 -P0 bash -c 'apt-cache madison ${0}|head -n1|awk '"'"'{print $1"|"$3"|"$6}'"'"'|xargs|tee 1>/dev/null -a '${MFST_DIR}'/madison.out.${OSSA_SUFFX}') &)
	SPID=$(pgrep -of 'apt-cache madison')
	declare -ag CHARS=($(printf "\u22EE\u2003\b") $(printf "\u22F0\u2003\b") $(printf "\u22EF\u2003\b") $(printf "\u22F1\u2003\b"))
	if [[ ${OSSA_DEBUG} = true ]];then
		printf "Running apt-cache madison against manifest. Please wait\n"
	else
		while kill -0 $SPID 2>/dev/null;do
				for c in ${CHARS[@]};do printf "\r\e[2G - \e[38;2;0;160;200mINFO\e[0m: Running apt-cache madison against manifest. Please wait %s\e[K\e[0m" $c;sleep .03;done
		done
	fi
	sleep .5
	[[ -f ${MFST_DIR}/madison.out.${OSSA_SUFFX} ]] && { printf "\r\e[K\r\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created ${MFST_DIR}/madison.out.${OSSA_SUFFX}\n"; } || { printf "\r\e[K\r\e[2G - \e[38;2;255;0;0mERROR\e[0m: Creating ${MFST_DIR}/madison.out.${OSSA_SUFFX}\n"; }
	MADISON_TIME=$(TZ=UTC date --date now-${MADISON_NOW} "+%H:%M:%S")
	printf "\r\e[K\r\e[5G -  apt-cache madison completed in ${MADISON_TIME}\e[0m\n\n"
	declare -ag COMPONENTS=(main universe multiverse restricted)
	declare -ag POCKETS=(${OSSA_RELEASE} ${OSSA_RELEASE}-updates ${OSSA_RELEASE}-security ${OSSA_RELEASE}-backports ${OSSA_RELEASE}-proposed)
	for x in ${COMPONENTS[@]};do declare -ag ${x^^}=\(\);eval ${x^^}+=\( $(grep "/${x}" ${MFST_DIR}/madison.out.${OSSA_SUFFX}|wc -l) \);for y in ${POCKETS[@]};do eval ${x^^}+=\( ${y}:$(grep "${y}/${x}" ${MFST_DIR}/madison.out.${OSSA_SUFFX}|wc -l) \);done;done
	export COMPONENT_TOTAL=$((${MAIN[0]##*:}+${UNIVERSE[0]##*:}+${MULTIVERSE[0]##*:}+${RESTRICTED[0]##*:}))
	export RELEASE_TOTAL=$((${MAIN[1]##*:}+${UNIVERSE[1]##*:}+${MULTIVERSE[1]##*:}+${RESTRICTED[1]##*:}))
	export UPDATES_TOTAL=$((${MAIN[2]##*:}+${UNIVERSE[2]##*:}+${MULTIVERSE[2]##*:}+${RESTRICTED[2]##*:}))
	export SECURITY_TOTAL=$((${MAIN[3]##*:}+${UNIVERSE[3]##*:}+${MULTIVERSE[3]##*:}+${RESTRICTED[3]##*:}))
	export BACKPORTS_TOTAL=$((${MAIN[4]##*:}+${UNIVERSE[4]##*:}+${MULTIVERSE[4]##*:}+${RESTRICTED[4]##*:}))
	export PROPOSED_TOTAL=$((${MAIN[5]##*:}+${UNIVERSE[5]##*:}+${MULTIVERSE[5]##*:}+${RESTRICTED[5]##*:}))	
	((for ((i=0; i<${#POCKETS[@]}; i++)); do printf '%s\n' ${POCKETS[i]};done|paste -sd"|"|sed 's/^/Ubuntu '${OSSA_RELEASE^}'|'${OSSA_HOST}'|/g'
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[0]} ${MAIN[0]##*:} ${MAIN[1]##*:} ${MAIN[2]##*:} ${MAIN[3]##*:} ${MAIN[4]##*:} ${MAIN[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[1]} ${UNIVERSE[0]##*:} ${UNIVERSE[1]##*:} ${UNIVERSE[2]##*:} ${UNIVERSE[3]##*:} ${UNIVERSE[4]##*:} ${UNIVERSE[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[2]} ${MULTIVERSE[0]##*:} ${MULTIVERSE[1]##*:} ${MULTIVERSE[2]##*:} ${MULTIVERSE[3]##*:} ${MULTIVERSE[4]##*:} ${MULTIVERSE[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[3]} ${RESTRICTED[0]##*:} ${RESTRICTED[1]##*:} ${RESTRICTED[2]##*:} ${RESTRICTED[3]##*:} ${RESTRICTED[4]##*:} ${RESTRICTED[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' Totals ${COMPONENT_TOTAL} ${RELEASE_TOTAL} ${UPDATES_TOTAL} ${SECURITY_TOTAL} ${BACKPORTS_TOTAL} ${PROPOSED_TOTAL}
	)|column -nexts"|"|tee ${OSSA_DIR}/package_table.txt| \
	sed -re '1s/Ubuntu '${OSSA_RELEASE^}'/'$(printf "\e[1;48;2;233;84;32m\e[1;38;2;255;255;255m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_RELEASE}'/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_HOST}'/'$(printf "\e[1;48;2;255;255;255m\e[1;38;2;233;84;32m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_RELEASE}'-updates/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_RELEASE}'-security/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_RELEASE}'-backports/'$(printf "\e[38;2;255;200;0m")'&'$(printf "\e[0m")'/g' \
		-re '1s/'${OSSA_RELEASE}'-proposed/'$(printf "\e[38;2;255;0;0m")'&'$(printf "\e[0m")'/g' \
		-re 's/main|universe/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/g' \
		-re 's/multiverse.*$|restricted.*$/'$(printf "\e[38;2;255;0;0m")'&'$(printf "\e[0m")'/g')|sed 's/^.*$/     &/g'|tee ${OSSA_DIR}/package_table.ansi
		printf '\n\n'
fi


# Create a manifest file based on packages that were expressly manually installed
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Creating manifest of manually installed packages\n"
(apt 2>/dev/null list --manual-installed|awk -F"/| " '!/^$|^Listing/{print $1"\t"$3}')|tee 1>/dev/null ${MFST_DIR}/manifest.manual.${OSSA_SUFFX}
[[ -s ${MFST_DIR}/manifest.manual.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created manually-installed manifest file\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not create manually-installed packages manifest file\n"; }

# Create a manifest file based on packages that were automatically installed (dependency, pre-req)
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Creating manifest of automatically installed packages\n"
(apt 2>/dev/null list --installed|awk -F"/| " '!/^$|^Listing/&&/,automatic\]/{print $1"\t"$3}')|tee 1>/dev/null ${MFST_DIR}/manifest.automatic.${OSSA_SUFFX}
[[ -s ${MFST_DIR}/manifest.automatic.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created automatically-installed packages manifest file\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not create automatically-installed packages manifest file\n"; }

######################
# COPY PACKAGE FILES #
######################

printf "\n\e[2G\e[1mCollect Repository Package files\e[0m\n"
if [[ -n $(find 2>/dev/null /var/lib/apt/lists -maxdepth 1 -regextype "posix-extended" -iregex '.*(Packages$)') ]];then
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Searching Repository Package files\n"
    find 2>/dev/null /var/lib/apt/lists -maxdepth 1 -regextype "posix-extended" -iregex '.*(Packages$)' -exec cp {} ${PKG_DIR}/ \;
    [[ -n $(find 2>/dev/null ${PKG_DIR} -maxdepth 1 -regextype "posix-extended" -iregex '.*(Packages$)') ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Copied Package files to ${PKG_DIR}\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not copy Package files to ${PKG_DIR}\n"; }
else
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Could not find Repository Package files. Skipping.\n"
fi
####################
# COPY DPKG STATUS #
####################

printf "\n\e[2G\e[1mCollect dpkg status file\e[0m\n"
if [[ -f /var/lib/dpkg/status ]];then
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Searching for dpkg status file\n"
    cp /var/lib/dpkg/status ${PKG_DIR}/dpkg.status.${OSSA_SUFFX}
    [[ -f ${PKG_DIR}/dpkg.status.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Copied dpkg status file\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not copy dpkg status file\n"; }
else
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Could not /var/lib/dpkg/status. Skipping.\n"
fi

######################
# COPY RELEASE FILES #
######################

printf "\n\e[2G\e[1mCollect Repository Release files\e[0m\n"
if [[ -n $(find 2>/dev/null /var/lib/apt/lists -maxdepth 1 -regextype "posix-extended" -iregex '.*(Release$)') ]];then
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Gathering Repository Release files\n"
    find 2>/dev/null /var/lib/apt/lists -maxdepth 1 -regextype "posix-extended" -iregex '.*(Release$)' -exec cp {} ${REL_DIR}/ \;
    [[ -n $(find 2>/dev/null ${REL_DIR} -maxdepth 1 -regextype "posix-extended" -iregex '.*(Release$)') ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Copied Release files to ${REL_DIR}\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not copy Release files to ${REL_DIR}\n"; }
else
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Could not find Repository Release files. Skipping.\n"
fi

####################
# APT SOURCE FILES #
####################

# Count repositories in use
export OSSA_REPO_COUNT=$(apt-cache policy|awk 2>/dev/null '/500/'|wc -l)

# Discover and evaluate sources.list(.d) for embedded credentials
printf "\n\e[2G\e[1mCollect Apt Source List and Part Files\e[0m\n"

# Get defined sources.list file from apt-config
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Deriving location of sources.list from \"apt-config dump\"\n"
export SOURCES_LIST=$(apt-config dump|awk '/^Dir[ ]|^Dir::Etc[ ]|^Dir::Etc::sourcel/{gsub(/"|;$/,"");print "/"$2}'|sed -r ':a;N;$! ba;s/\/\/|\n//g')

# Check for stored password in defined sources.list file
if [[ -s ${SOURCES_LIST} ]];then
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Checking ${SOURCES_LIST} for embedded credentials\n"
    if [[ -n $(grep -lRE 'http?(s)://[Aa-Zz-]+:[Aa-Zz0-9-]+@' ${SOURCES_LIST}) ]];then
    	export OSSA_CREDS_DETECTED=true
    	printf "\e[2G - \e[38;2;255;200;0mNOTE\e[0m: ${SOURCES_LIST} may have embedded credentials stored in the URIs\n"
    else
    	export OSSA_CREDS_DETECTED=false
    fi
fi

# if script detects that SOURCES_LIST possibly contains credentials, scrub detected strings
# Use -o,--override option force the copy

if [[ ${OSSA_CREDS_DETECTED} = true && ${OSSA_IGNORE_CREDS} = true ]];then
	printf "\e[2G - \e[38;2;255;200;0mNOTE\e[0m: Copying ${SOURCES_LIST} that may contain embedded credentials but password scrubbing has been overridden! \n"
	[[ -f ${SOURCES_LIST} ]] && { cp ${SOURCES_LIST} ${SRC_DIR}/sources.list.${OSSA_SUFFX}; }
	[[ -f ${SRC_DIR}/sources.list.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Copied ${SOURCES_LIST} to ${SRC_DIR}/sources.list.${OSSA_SUFFX}\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not copy ${SOURCES_LIST} to ${SRC_DIR}/sources.list.${OSSA_SUFFX}\n";OSSA_COPY_ERRORS+=( "${SOURCES_LIST}" ); }
else
	[[ -f ${SOURCES_LIST} ]] && { cp ${SOURCES_LIST} ${SRC_DIR}/sources.list.${OSSA_SUFFX}; }
	if [[ -f ${SRC_DIR}/sources.list.${OSSA_SUFFX} ]];then
		printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Copied ${SOURCES_LIST} to ${SRC_DIR}/sources.list.${OSSA_SUFFX}\n";
		printf "\e[2G - \e[38;2;255;200;0mNOTE\e[0m: Scrubbing any possible embedded credentials from ${SRC_DIR}/sources.list.${OSSA_SUFFX}\n\e[12GUse -o,--override option to prevent data scrubbing.\n\n"
		[[ -f ${SRC_DIR}/sources.list.${OSSA_SUFFX} ]] && { sed -i 's/\/\/[^@+]*@/\/\//' ${SRC_DIR}/sources.list.${OSSA_SUFFX}; }
		if [[ -n $(grep -lRE 'http?(s)://[Aa-Zz-]+:[Aa-Zz0-9-]+@' ${SRC_DIR}/sources.list.${OSSA_SUFFX}) ]];then
			printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Scrubbing of ${SRC_DIR}/sources.list.${OSSA_SUFFX} appears to have failed.  Removing ${SRC_DIR}/sources.list.${OSSA_SUFFX}\n"
			rm -rf ${SRC_DIR}/sources.list.${OSSA_SUFFX}
			OSSA_COPY_ERRORS+=( "${SOURCES_LIST}" )	
		fi
	else
		printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not copy ${SOURCES_LIST} to ${SRC_DIR}/sources.list.${OSSA_SUFFX}\n"
		OSSA_COPY_ERRORS+=( "${SOURCES_LIST}" )
	fi
fi
export OSSA_CREDS_DETECTED=false

# Get defined sources part list files from apt-config
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Deriving location of source part files from \"apt-config dump\"\n"
export SOURCES_LIST_D=$(apt-config dump|awk '/^Dir[ ]|^Dir::Etc[ ]|^Dir::Etc::sourcep/{gsub(/"|;$/,"");print "/"$2}'|sed -r ':a;N;$! ba;s/\/\/|\n//g')

# Check for potential embedded credentials in defined sources part list files
if [[ -n $(find 2>/dev/null ${SOURCES_LIST_D} -type f) ]];then
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Checking for embedded credentials in source parts files (${SOURCES_LIST_D}/*) \n"
    [[ -n $(grep -lRE 'http?(s)://[Aa-Zz-]+:[Aa-Zz0-9-]+@' ${SOURCES_LIST_D}/) ]] && { export OSSA_CREDS_DETECTED=true;printf "\e[2G - \e[38;2;255;200;0mNOTE\e[0m: Files in (${SOURCES_LIST_D} may have embedded credentials stored in the URIs\n"; } || { export OSSA_CREDS_DETECTED=false; }

	# if script detects that SOURCES_LIST_D possibly contains credentials, scrub detected strings
	# Use -o,--override option force the copy
	if [[ ${OSSA_CREDS_DETECTED} = true && ${OSSA_IGNORE_CREDS} = true ]];then
		printf "\e[2G - \e[38;2;255;200;0mNOTE\e[0m: Copying data from ${SOURCES_LIST_D}/ that may contain embedded credentials but password scrubbing has been overridden! \n"
		[[ -n $(find 2>/dev/null ${SOURCES_LIST_D} -type f -iname "*.list" -o -type l -iname "*.list") ]] && { find 2>/dev/null ${SOURCES_LIST_D} -type f -iname "*.list" -o -type l -iname "*.list"|xargs -rn1 -P0 bash -c 'cp ${0} ${PARTS_DIR}/${0##*/}.${OSSA_SUFFX}'; }
		[[ -n $(find 2>/dev/null ${PARTS_DIR}/ -type f -iname "*.list.*" -o -type l -iname "*.list.*") ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Copied ${SOURCES_LIST_D}/* to ${PARTS_DIR}/\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: There was an error copying files from ${SOURCES_LIST_D}/* to ${PARTS_DIR}/\n";OSSA_COPY_ERRORS+=( "${SOURCES_LIST_D}/*" ); }
	else
		printf "\e[2G - \e[38;2;255;200;0mNOTE\e[0m: Scrubbing any embedded credentials from ${PARTS_DIR}/*\n\e[12GUse -o,--override option to prevent data scrubbing.\n\n"
		[[ -n $(find 2>/dev/null ${SOURCES_LIST_D} -type f -iname "*.list" -o -type l -iname "*.list") ]] && { find 2>/dev/null ${SOURCES_LIST_D} -type f -iname "*.list" -o -type l -iname "*.list"|xargs -rn1 -P0 bash -c 'cp ${0} ${PARTS_DIR}/${0##*/}.${OSSA_SUFFX}'; }
		[[ -n $(find 2>/dev/null ${PARTS_DIR}/ -type f -iname "*.list.*" -o -type l -iname "*.list.*") ]] && find 2>/dev/null ${PARTS_DIR}/ -type f -iname "*.list.*" -o -type l -iname "*.list.*" -exec sed -i 's/\/\/[^@+]*@/\/\//' {} \;
		if [[ -n $(find 2>/dev/null ${PARTS_DIR}/ -type f -iname "*.list.*" -o -type l -iname "*.list.*") ]];then
			printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Copied ${SOURCES_LIST_D}/* to ${PARTS_DIR}/\n"
		else
			printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: There was an error copying files from ${SOURCES_LIST_D}/* to ${PARTS_DIR}/\n"
			OSSA_COPY_ERRORS+=( "${SOURCES_LIST_D}/*" )
		fi
	fi
else
	printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: No part files exist in sources.list.d. Skipping\n"
fi
export OSSA_CREDS_DETECTED=false


#########################
# UBUNTU SUPPORT STATUS #
#########################

# Create a ubuntu-support-status file
printf "\n\e[2G\e[1mRun ubuntu-support-status\e[0m\n"
if [[ -n $(command -v ubuntu-support-status) ]];then
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Running ubuntu-support-status\n"
    ubuntu-support-status --list|tee 1>/dev/null ${UTIL_DIR}/ubuntu-support-status.${OSSA_SUFFX}
    [[ -s ${UTIL_DIR}/ubuntu-support-status.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created ubuntu-support-status output file\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not create ubuntu-support-status output file\n" ; }
else
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: ubuntu-support-status not installed. Skipping\n"
fi

##########################
# UBUNTU SECURITY STATUS #
##########################

export USS_B64='IyEvdXNyL2Jpbi9weXRob24zCgppbXBvcnQgYXB0CmltcG9ydCBhcmdwYXJzZQppbXBvcnQgZGlzdHJvX2luZm8KaW1wb3J0IG9zCmltcG9ydCBzeXMKaW1wb3J0IGdldHRleHQKaW1wb3J0IHN1YnByb2Nlc3MKCmZyb20gVXBkYXRlTWFuYWdlci5Db3JlLnV0aWxzIGltcG9ydCBnZXRfZGlzdAoKZnJvbSBkYXRldGltZSBpbXBvcnQgZGF0ZXRpbWUKZnJvbSB0ZXh0d3JhcCBpbXBvcnQgd3JhcApmcm9tIHVybGxpYi5lcnJvciBpbXBvcnQgVVJMRXJyb3IsIEhUVFBFcnJvcgpmcm9tIHVybGxpYi5yZXF1ZXN0IGltcG9ydCB1cmxvcGVuCgojIFRPRE8gbWFrZSBERUJVRyBhbiBlbnZpcm9ubWVudGFsIHZhcmlhYmxlCkRFQlVHID0gRmFsc2UKCgpjbGFzcyBQYXRjaFN0YXRzOgogICAgIiIiVHJhY2tzIG92ZXJhbGwgcGF0Y2ggc3RhdHVzCgogICAgVGhlIHJlbGF0aW9uc2hpcCBiZXR3ZWVuIGFyY2hpdmVzIGVuYWJsZWQgYW5kIHdoZXRoZXIgYSBwYXRjaCBpcyBlbGlnaWJsZQogICAgZm9yIHJlY2VpdmluZyB1cGRhdGVzIGlzIG5vbi10cml2aWFsLiBXZSB0cmFjayBoZXJlIGFsbCB0aGUgaW1wb3J0YW50CiAgICBidWNrZXRzIGEgcGFja2FnZSBjYW4gYmUgaW46CgogICAgICAgIC0gV2hldGhlciBpdCBpcyBzZXQgdG8gZXhwaXJlIHdpdGggbm8gRVNNIGNvdmVyYWdlCiAgICAgICAgLSBXaGV0aGVyIGl0IGlzIGluIGFuIGFyY2hpdmUgY292ZXJlZCBieSBFU00KICAgICAgICAtIFdoZXRoZXIgaXQgcmVjZWl2ZWQgTFRTIHBhdGNoZXMKICAgICAgICAtIHdoZXRoZXIgaXQgcmVjZWl2ZWQgRVNNIHBhdGNoZXMKCiAgICBXZSBhbHNvIHRyYWNrIHRoZSB0b3RhbCBwYWNrYWdlcyBjb3ZlcmVkIGFuZCB1bmNvdmVyZWQsIGFuZCBmb3IgdGhlCiAgICB1bmNvdmVyZWQgcGFja2FnZXMsIHdlIHRyYWNrIHdoZXJlIHRoZXkgb3JpZ2luYXRlIGZyb20uCgogICAgVGhlIFVidW50dSBtYWluIGFyY2hpdmUgcmVjZWl2ZXMgcGF0Y2hlcyBmb3IgNSB5ZWFycy4KICAgIENhbm9uaWNhbC1vd25lZCBhcmNoaXZlcyAoZXhjbHVkaW5nIHBhcnRuZXIpIHJlY2VpdmUgcGF0Y2hlcyBmb3IgMTAgeWVhcnMuCiAgICAgICAgcGF0Y2hlcyBmb3IgMTAgeWVhcnMuCiAgICAiIiIKICAgIGRlZiBfX2luaXRfXyhzZWxmKToKICAgICAgICAjIFRPRE8gbm8tdXBkYXRlIEZJUFMgaXMgbmV2ZXIgcGF0Y2hlZAogICAgICAgIHNlbGYucGtnc191bmNvdmVyZWRfZmlwcyA9IHNldCgpCgogICAgICAgICMgbGlzdCBvZiBwYWNrYWdlIG5hbWVzIGF2YWlsYWJsZSBpbiBFU00KICAgICAgICBzZWxmLnBrZ3NfdXBkYXRlZF9pbl9lc21pID0gc2V0KCkKICAgICAgICBzZWxmLnBrZ3NfdXBkYXRlZF9pbl9lc21hID0gc2V0KCkKCiAgICAgICAgc2VsZi5wa2dzX21yID0gc2V0KCkKICAgICAgICBzZWxmLnBrZ3NfdW0gPSBzZXQoKQogICAgICAgIHNlbGYucGtnc191bmF2YWlsYWJsZSA9IHNldCgpCiAgICAgICAgc2VsZi5wa2dzX3RoaXJkcGFydHkgPSBzZXQoKQogICAgICAgICMgdGhlIGJpbiBvZiB1bmtub3ducwogICAgICAgIHNlbGYucGtnc191bmNhdGVnb3JpemVkID0gc2V0KCkKCgpkZWYgcHJpbnRfZGVidWcocyk6CiAgICBpZiBERUJVRzoKICAgICAgICBwcmludChzKQoKCmRlZiB3aGF0c19pbl9lc20odXJsKToKICAgIHBrZ3MgPSBzZXQoKQogICAgIyByZXR1cm4gYSBzZXQgb2YgcGFja2FnZSBuYW1lcyBpbiBhbiBlc20gYXJjaGl2ZQogICAgdHJ5OgogICAgICAgIHJlc3BvbnNlID0gdXJsb3Blbih1cmwpCiAgICBleGNlcHQgKFVSTEVycm9yLCBIVFRQRXJyb3IpOgogICAgICAgIHByaW50X2RlYnVnKCdmYWlsZWQgdG8gbG9hZDogJXMnICUgdXJsKQogICAgICAgIHJldHVybiBwa2dzCiAgICB0cnk6CiAgICAgICAgY29udGVudCA9IHJlc3BvbnNlLnJlYWQoKS5kZWNvZGUoJ3V0Zi04JykKICAgIGV4Y2VwdCBJT0Vycm9yOgogICAgICAgIHByaW50KCdmYWlsZWQgdG8gcmVhZCBkYXRhIGF0OiAlcycgJSB1cmwpCiAgICAgICAgc3lzLmV4aXQoMSkKICAgIGZvciBsaW5lIGluIGNvbnRlbnQuc3BsaXQoJ1xuJyk6CiAgICAgICAgaWYgbm90IGxpbmUuc3RhcnRzd2l0aCgnUGFja2FnZTonKToKICAgICAgICAgICAgY29udGludWUKICAgICAgICBlbHNlOgogICAgICAgICAgICBwa2cgPSBsaW5lLnNwbGl0KCc6ICcpWzFdCiAgICAgICAgICAgIHBrZ3MuYWRkKHBrZykKICAgIHJldHVybiBwa2dzCgoKZGVmIGxpdmVwYXRjaF9pc19lbmFibGVkKCk6CiAgICAiIiIgQ2hlY2sgdG8gc2VlIGlmIGxpdmVwYXRjaCBpcyBlbmFibGVkIG9uIHRoZSBzeXN0ZW0iIiIKICAgIHRyeToKICAgICAgICBjX2xpdmVwYXRjaCA9IHN1YnByb2Nlc3MucnVuKFsiL3NuYXAvYmluL2Nhbm9uaWNhbC1saXZlcGF0Y2giLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICJzdGF0dXMiXSwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIHN0ZG91dD1zdWJwcm9jZXNzLlBJUEUsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBzdGRlcnI9c3VicHJvY2Vzcy5QSVBFKQogICAgIyBpdCBjYW4ndCBiZSBlbmFibGVkIGlmIGl0IGlzbid0IGluc3RhbGxlZAogICAgZXhjZXB0IEZpbGVOb3RGb3VuZEVycm9yOgogICAgICAgIHJldHVybiBGYWxzZQogICAgaWYgY19saXZlcGF0Y2gucmV0dXJuY29kZSA9PSAwOgogICAgICAgIHJldHVybiBUcnVlCiAgICBlbGlmIGNfbGl2ZXBhdGNoLnJldHVybmNvZGUgPT0gMToKICAgICAgICByZXR1cm4gRmFsc2UKCgpkZWYgZXNtX2lzX2VuYWJsZWQoKToKICAgICIiIiBDaGVjayB0byBzZWUgaWYgZXNtIGlzIGFuIGF2YWlsYWJsZSBzb3VyY2UiIiIKICAgIGFjcCA9IHN1YnByb2Nlc3MuUG9wZW4oWyJhcHQtY2FjaGUiLCAicG9saWN5Il0sCiAgICAgICAgICAgICAgICAgICAgICAgICAgIHN0ZG91dD1zdWJwcm9jZXNzLlBJUEUsIHN0ZGVycj1zdWJwcm9jZXNzLlBJUEUpCiAgICBncmVwID0gc3VicHJvY2Vzcy5ydW4oWyJncmVwIiwgIi1GIiwgIi1xIiwgImh0dHBzOi8vJXMiICUgZXNtX3NpdGVdLAogICAgICAgICAgICAgICAgICAgICAgICAgIHN0ZGluPWFjcC5zdGRvdXQsIHN0ZG91dD1zdWJwcm9jZXNzLlBJUEUpCiAgICBpZiBncmVwLnJldHVybmNvZGUgPT0gMDoKICAgICAgICByZXR1cm4gVHJ1ZQogICAgZWxpZiBncmVwLnJldHVybmNvZGUgPT0gLTE6CiAgICAgICAgcmV0dXJuIEZhbHNlCgoKZGVmIHRyaW1fYXJjaGl2ZShhcmNoaXZlKToKICAgIHJldHVybiBhcmNoaXZlLnNwbGl0KCItIilbLTFdCgoKZGVmIHRyaW1fc2l0ZShob3N0KToKICAgICMgKi5lYzIuYXJjaGl2ZS51YnVudHUuY29tIC0+IGFyY2hpdmUudWJ1bnR1LmNvbQogICAgaWYgaG9zdC5lbmRzd2l0aCgiYXJjaGl2ZS51YnVudHUuY29tIik6CiAgICAgICAgcmV0dXJuICJhcmNoaXZlLnVidW50dS5jb20iCiAgICByZXR1cm4gaG9zdAoKCmRlZiBtaXJyb3JfbGlzdCgpOgogICAgbV9maWxlID0gJy91c3Ivc2hhcmUvdWJ1bnR1LXJlbGVhc2UtdXBncmFkZXIvbWlycm9ycy5jZmcnCiAgICBpZiBub3Qgb3MucGF0aC5leGlzdHMobV9maWxlKToKICAgICAgICBwcmludCgiT2ZmaWNpYWwgbWlycm9yIGxpc3Qgbm90IGZvdW5kLiIpCiAgICB3aXRoIG9wZW4obV9maWxlKSBhcyBmOgogICAgICAgIGl0ZW1zID0gW3guc3RyaXAoKSBmb3IgeCBpbiBmXQogICAgbWlycm9ycyA9IFtzLnNwbGl0KCcvLycpWzFdLnNwbGl0KCcvJylbMF0gZm9yIHMgaW4gaXRlbXMKICAgICAgICAgICAgICAgaWYgbm90IHMuc3RhcnRzd2l0aCgiIyIpIGFuZCBub3QgcyA9PSAiIl0KICAgICMgZGRlYnMudWJ1bnR1LmNvbSBpc24ndCBpbiBtaXJyb3JzLmNmZyBmb3IgZXZlcnkgcmVsZWFzZQogICAgbWlycm9ycy5hcHBlbmQoJ2RkZWJzLnVidW50dS5jb20nKQogICAgcmV0dXJuIG1pcnJvcnMKCgpkZWYgb3JpZ2luc19mb3IodmVyOiBhcHQucGFja2FnZS5WZXJzaW9uKSAtPiBzdHI6CiAgICBzID0gW10KICAgIGZvciBvcmlnaW4gaW4gdmVyLm9yaWdpbnM6CiAgICAgICAgaWYgbm90IG9yaWdpbi5zaXRlOgogICAgICAgICAgICAjIFdoZW4gdGhlIHBhY2thZ2UgaXMgaW5zdGFsbGVkLCBzaXRlIGlzIGVtcHR5LCBhcmNoaXZlL2NvbXBvbmVudAogICAgICAgICAgICAjIGFyZSAibm93L25vdyIKICAgICAgICAgICAgY29udGludWUKICAgICAgICBzaXRlID0gdHJpbV9zaXRlKG9yaWdpbi5zaXRlKQogICAgICAgIHMuYXBwZW5kKCIlcyAlcy8lcyIgJSAoc2l0ZSwgb3JpZ2luLmFyY2hpdmUsIG9yaWdpbi5jb21wb25lbnQpKQogICAgcmV0dXJuICIsIi5qb2luKHMpCgoKZGVmIHByaW50X3dyYXBwZWQoc3RyKToKICAgIHByaW50KCJcbiIuam9pbih3cmFwKHN0ciwgYnJlYWtfb25faHlwaGVucz1GYWxzZSkpKQoKCmRlZiBwcmludF90aGlyZHBhcnR5X2NvdW50KCk6CiAgICBwcmludChnZXR0ZXh0LmRuZ2V0dGV4dCgidXBkYXRlLW1hbmFnZXIiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgIiVzIHBhY2thZ2UgaXMgZnJvbSBhIHRoaXJkIHBhcnR5IiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICIlcyBwYWNrYWdlcyBhcmUgZnJvbSB0aGlyZCBwYXJ0aWVzIiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGxlbihwa2dzdGF0cy5wa2dzX3RoaXJkcGFydHkpKSAlCiAgICAgICAgICAiezo+e3dpZHRofX0iLmZvcm1hdChsZW4ocGtnc3RhdHMucGtnc190aGlyZHBhcnR5KSwgd2lkdGg9d2lkdGgpKQoKCmRlZiBwcmludF91bmF2YWlsYWJsZV9jb3VudCgpOgogICAgcHJpbnQoZ2V0dGV4dC5kbmdldHRleHQoInVwZGF0ZS1tYW5hZ2VyIiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICIlcyBwYWNrYWdlIGlzIG5vIGxvbmdlciBhdmFpbGFibGUgZm9yICIKICAgICAgICAgICAgICAgICAgICAgICAgICAgICJkb3dubG9hZCIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAiJXMgcGFja2FnZXMgYXJlIG5vIGxvbmdlciBhdmFpbGFibGUgZm9yICIKICAgICAgICAgICAgICAgICAgICAgICAgICAgICJkb3dubG9hZCIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBsZW4ocGtnc3RhdHMucGtnc191bmF2YWlsYWJsZSkpICUKICAgICAgICAgICJ7Oj57d2lkdGh9fSIuZm9ybWF0KGxlbihwa2dzdGF0cy5wa2dzX3VuYXZhaWxhYmxlKSwgd2lkdGg9d2lkdGgpKQoKCmRlZiBwYXJzZV9vcHRpb25zKCk6CiAgICAnJydQYXJzZSBjb21tYW5kIGxpbmUgYXJndW1lbnRzLgoKICAgIFJldHVybiBwYXJzZXIKICAgICcnJwogICAgcGFyc2VyID0gYXJncGFyc2UuQXJndW1lbnRQYXJzZXIoCiAgICAgICAgZGVzY3JpcHRpb249J1JldHVybiBpbmZvcm1hdGlvbiBhYm91dCBzZWN1cml0eSBzdXBwb3J0IGZvciBwYWNrYWdlcycpCiAgICBwYXJzZXIuYWRkX2FyZ3VtZW50KCctLXRoaXJkcGFydHknLCBhY3Rpb249J3N0b3JlX3RydWUnKQogICAgcGFyc2VyLmFkZF9hcmd1bWVudCgnLS11bmF2YWlsYWJsZScsIGFjdGlvbj0nc3RvcmVfdHJ1ZScpCiAgICByZXR1cm4gcGFyc2VyCgoKaWYgX19uYW1lX18gPT0gIl9fbWFpbl9fIjoKICAgICMgZ2V0dGV4dAogICAgQVBQID0gInVwZGF0ZS1tYW5hZ2VyIgogICAgRElSID0gIi91c3Ivc2hhcmUvbG9jYWxlIgogICAgZ2V0dGV4dC5iaW5kdGV4dGRvbWFpbihBUFAsIERJUikKICAgIGdldHRleHQudGV4dGRvbWFpbihBUFApCgogICAgcGFyc2VyID0gcGFyc2Vfb3B0aW9ucygpCiAgICBhcmdzID0gcGFyc2VyLnBhcnNlX2FyZ3MoKQoKICAgIGVzbV9zaXRlID0gImVzbS51YnVudHUuY29tIgoKICAgIHRyeToKICAgICAgICBkcGtnID0gc3VicHJvY2Vzcy5jaGVja19vdXRwdXQoWydkcGtnJywgJy0tcHJpbnQtYXJjaGl0ZWN0dXJlJ10pCiAgICAgICAgYXJjaCA9IGRwa2cuZGVjb2RlKCkuc3RyaXAoKQogICAgZXhjZXB0IHN1YnByb2Nlc3MuQ2FsbGVkUHJvY2Vzc0Vycm9yOgogICAgICAgIHByaW50KCJmYWlsZWQgZ2V0dGluZyBkcGtnIGFyY2hpdGVjdHVyZSIpCiAgICAgICAgc3lzLmV4aXQoMSkKCiAgICBjYWNoZSA9IGFwdC5DYWNoZSgpCiAgICBwa2dzdGF0cyA9IFBhdGNoU3RhdHMoKQogICAgY29kZW5hbWUgPSBnZXRfZGlzdCgpCiAgICBkaSA9IGRpc3Ryb19pbmZvLlVidW50dURpc3Ryb0luZm8oKQogICAgbHRzID0gZGkuaXNfbHRzKGNvZGVuYW1lKQogICAgcmVsZWFzZV9leHBpcmVkID0gVHJ1ZQogICAgaWYgY29kZW5hbWUgaW4gZGkuc3VwcG9ydGVkKCk6CiAgICAgICAgcmVsZWFzZV9leHBpcmVkID0gRmFsc2UKICAgICMgZGlzdHJvLWluZm8tZGF0YSBpbiBVYnVudHUgMTYuMDQgTFRTIGRvZXMgbm90IGhhdmUgZW9sLWVzbSBkYXRhCiAgICBpZiBjb2RlbmFtZSAhPSAneGVuaWFsJzoKICAgICAgICBlb2xfZGF0YSA9IFsoci5lb2wsIHIuZW9sX2VzbSkKICAgICAgICAgICAgICAgICAgICBmb3IgciBpbiBkaS5fcmVsZWFzZXMgaWYgci5zZXJpZXMgPT0gY29kZW5hbWVdWzBdCiAgICBlbGlmIGNvZGVuYW1lID09ICd4ZW5pYWwnOgogICAgICAgIGVvbF9kYXRhID0gKGRhdGV0aW1lLnN0cnB0aW1lKCcyMDIxLTA0LTIxJywgJyVZLSVtLSVkJyksCiAgICAgICAgICAgICAgICAgICAgZGF0ZXRpbWUuc3RycHRpbWUoJzIwMjQtMDQtMjEnLCAnJVktJW0tJWQnKSkKICAgIGVvbCA9IGVvbF9kYXRhWzBdCiAgICBlb2xfZXNtID0gZW9sX2RhdGFbMV0KCiAgICBhbGxfb3JpZ2lucyA9IHNldCgpCiAgICBvcmlnaW5zX2J5X3BhY2thZ2UgPSB7fQogICAgb2ZmaWNpYWxfbWlycm9ycyA9IG1pcnJvcl9saXN0KCkKCiAgICAjIE4uQi4gb25seSB0aGUgc2VjdXJpdHkgcG9ja2V0IGlzIGNoZWNrZWQgYmVjYXVzZSB0aGlzIHRvb2wgZGlzcGxheXMKICAgICMgaW5mb3JtYXRpb24gYWJvdXQgc2VjdXJpdHkgdXBkYXRlcwogICAgZXNtX3VybCA9IFwKICAgICAgICAnaHR0cHM6Ly8lcy8lcy91YnVudHUvZGlzdHMvJXMtJXMtJXMvbWFpbi9iaW5hcnktJXMvUGFja2FnZXMnCiAgICBwa2dzX2luX2VzbWEgPSB3aGF0c19pbl9lc20oZXNtX3VybCAlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgKGVzbV9zaXRlLCAnYXBwcycsIGNvZGVuYW1lLCAnYXBwcycsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICdzZWN1cml0eScsIGFyY2gpKQogICAgcGtnc19pbl9lc21pID0gd2hhdHNfaW5fZXNtKGVzbV91cmwgJQogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIChlc21fc2l0ZSwgJ2luZnJhJywgY29kZW5hbWUsICdpbmZyYScsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICdzZWN1cml0eScsIGFyY2gpKQoKICAgIGZvciBwa2cgaW4gY2FjaGU6CiAgICAgICAgcGtnbmFtZSA9IHBrZy5uYW1lCgogICAgICAgIGRvd25sb2FkYWJsZSA9IFRydWUKICAgICAgICBpZiBub3QgcGtnLmlzX2luc3RhbGxlZDoKICAgICAgICAgICAgY29udGludWUKICAgICAgICBpZiBub3QgcGtnLmNhbmRpZGF0ZSBvciBub3QgcGtnLmNhbmRpZGF0ZS5kb3dubG9hZGFibGU6CiAgICAgICAgICAgIGRvd25sb2FkYWJsZSA9IEZhbHNlCiAgICAgICAgcGtnX3NpdGVzID0gW10KICAgICAgICBvcmlnaW5zX2J5X3BhY2thZ2VbcGtnbmFtZV0gPSBzZXQoKQoKICAgICAgICBmb3IgdmVyIGluIHBrZy52ZXJzaW9uczoKICAgICAgICAgICAgIyBMb29wIHRocm91Z2ggb3JpZ2lucyBhbmQgc3RvcmUgYWxsIG9mIHRoZW0uIFRoZSBpZGVhIGhlcmUgaXMgdGhhdAogICAgICAgICAgICAjIHdlIGRvbid0IGNhcmUgd2hlcmUgdGhlIGluc3RhbGxlZCBwYWNrYWdlIGNvbWVzIGZyb20sIHByb3ZpZGVkCiAgICAgICAgICAgICMgdGhlcmUgaXMgYXQgbGVhc3Qgb25lIHJlcG9zaXRvcnkgd2UgaWRlbnRpZnkgYXMgYmVpbmcKICAgICAgICAgICAgIyBzZWN1cml0eS1hc3N1cmVkIHVuZGVyIGVpdGhlciBMVFMgb3IgRVNNLgogICAgICAgICAgICBmb3Igb3JpZ2luIGluIHZlci5vcmlnaW5zOgogICAgICAgICAgICAgICAgIyBUT0RPOiBpbiBvcmRlciB0byBoYW5kbGUgRklQUyBhbmQgb3RoZXIgYXJjaGl2ZXMgd2hpY2ggaGF2ZQogICAgICAgICAgICAgICAgIyByb290LWxldmVsIHBhdGggbmFtZXMsIHdlJ2xsIG5lZWQgdG8gbG9vcCBvdmVyIHZlci51cmlzCiAgICAgICAgICAgICAgICAjIGluc3RlYWQKICAgICAgICAgICAgICAgIGlmIG5vdCBvcmlnaW4uc2l0ZToKICAgICAgICAgICAgICAgICAgICBjb250aW51ZQogICAgICAgICAgICAgICAgc2l0ZSA9IHRyaW1fc2l0ZShvcmlnaW4uc2l0ZSkKICAgICAgICAgICAgICAgIGFyY2hpdmUgPSBvcmlnaW4uYXJjaGl2ZQogICAgICAgICAgICAgICAgY29tcG9uZW50ID0gb3JpZ2luLmNvbXBvbmVudAogICAgICAgICAgICAgICAgb3JpZ2luID0gb3JpZ2luLm9yaWdpbgogICAgICAgICAgICAgICAgb2ZmaWNpYWxfbWlycm9yID0gRmFsc2UKICAgICAgICAgICAgICAgIHRoaXJkcGFydHkgPSBUcnVlCiAgICAgICAgICAgICAgICAjIHRoaXJkcGFydHkgcHJvdmlkZXJzIGxpa2UgZGwuZ29vZ2xlLmNvbSBkb24ndCBzZXQgIk9yaWdpbiIKICAgICAgICAgICAgICAgIGlmIG9yaWdpbiAhPSAiVWJ1bnR1IjoKICAgICAgICAgICAgICAgICAgICB0aGlyZHBhcnR5ID0gRmFsc2UKICAgICAgICAgICAgICAgIGlmIHNpdGUgaW4gb2ZmaWNpYWxfbWlycm9yczoKICAgICAgICAgICAgICAgICAgICBzaXRlID0gIm9mZmljaWFsX21pcnJvciIKICAgICAgICAgICAgICAgIGlmICJNWV9NSVJST1IiIGluIG9zLmVudmlyb246CiAgICAgICAgICAgICAgICAgICAgaWYgc2l0ZSBpbiBvcy5lbnZpcm9uWyJNWV9NSVJST1IiXToKICAgICAgICAgICAgICAgICAgICAgICAgc2l0ZSA9ICJvZmZpY2lhbF9taXJyb3IiCiAgICAgICAgICAgICAgICB0ID0gKHNpdGUsIGFyY2hpdmUsIGNvbXBvbmVudCwgdGhpcmRwYXJ0eSkKICAgICAgICAgICAgICAgIGlmIG5vdCBzaXRlOgogICAgICAgICAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgICAgICAgICBhbGxfb3JpZ2lucy5hZGQodCkKICAgICAgICAgICAgICAgIG9yaWdpbnNfYnlfcGFja2FnZVtwa2duYW1lXS5hZGQodCkKCiAgICAgICAgICAgIGlmIERFQlVHOgogICAgICAgICAgICAgICAgcGtnX3NpdGVzLmFwcGVuZCgiJXMgJXMvJXMiICUKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgKHNpdGUsIGFyY2hpdmUsIGNvbXBvbmVudCkpCgogICAgICAgIHByaW50X2RlYnVnKCJhdmFpbGFibGUgdmVyc2lvbnMgZm9yICVzIiAlIHBrZ25hbWUpCiAgICAgICAgcHJpbnRfZGVidWcoIiwiLmpvaW4ocGtnX3NpdGVzKSkKCiAgICAjIFRoaXMgdHJhY2tzIHN1aXRlcyB3ZSBjYXJlIGFib3V0LiBTYWRseSwgaXQgYXBwZWFycyB0aGF0IHRoZSB3YXkgYXB0CiAgICAjIHN0b3JlcyBvcmlnaW5zIHRydW5jYXRlcyBhd2F5IHRoZSBwYXRoIHRoYXQgY29tZXMgYWZ0ZXIgdGhlCiAgICAjIGRvbWFpbm5hbWUgaW4gdGhlIHNpdGUgcG9ydGlvbiwgb3IgbWF5YmUgSSBhbSBqdXN0IGNsdWVsZXNzLCBidXQKICAgICMgdGhlcmUncyBubyB3YXkgdG8gdGVsbCBGSVBTIGFwYXJ0IGZyb20gRVNNLCBmb3IgaW5zdGFuY2UuCiAgICAjIFNlZSAwMFJFUE9TLnR4dCBmb3IgZXhhbXBsZXMKCiAgICAjIDIwMjAtMDMtMTggdmVyLmZpbGVuYW1lIGhhcyB0aGUgcGF0aCBzbyB3aHkgaXMgdGhhdCBubyBnb29kPwoKICAgICMgVE9ETyBOZWVkIHRvIGhhbmRsZToKICAgICMgICBNQUFTLCBseGQsIGp1anUgUFBBcwogICAgIyAgIG90aGVyIFBQQXMKICAgICMgICBvdGhlciByZXBvcwoKICAgICMgVE9ETyBoYW5kbGUgcGFydG5lci5jLmMKCiAgICAjIG1haW4gYW5kIHJlc3RyaWN0ZWQgZnJvbSByZWxlYXNlLCAtdXBkYXRlcywgLXByb3Bvc2VkLCBvciAtc2VjdXJpdHkKICAgICMgcG9ja2V0cwogICAgc3VpdGVfbWFpbiA9ICgib2ZmaWNpYWxfbWlycm9yIiwgY29kZW5hbWUsICJtYWluIiwgVHJ1ZSkKICAgIHN1aXRlX21haW5fdXBkYXRlcyA9ICgib2ZmaWNpYWxfbWlycm9yIiwgY29kZW5hbWUgKyAiLXVwZGF0ZXMiLAogICAgICAgICAgICAgICAgICAgICAgICAgICJtYWluIiwgVHJ1ZSkKICAgIHN1aXRlX21haW5fc2VjdXJpdHkgPSAoIm9mZmljaWFsX21pcnJvciIsIGNvZGVuYW1lICsgIi1zZWN1cml0eSIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICJtYWluIiwgVHJ1ZSkKICAgIHN1aXRlX21haW5fcHJvcG9zZWQgPSAoIm9mZmljaWFsX21pcnJvciIsIGNvZGVuYW1lICsgIi1wcm9wb3NlZCIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICJtYWluIiwgVHJ1ZSkKCiAgICBzdWl0ZV9yZXN0cmljdGVkID0gKCJvZmZpY2lhbF9taXJyb3IiLCBjb2RlbmFtZSwgInJlc3RyaWN0ZWQiLAogICAgICAgICAgICAgICAgICAgICAgICBUcnVlKQogICAgc3VpdGVfcmVzdHJpY3RlZF91cGRhdGVzID0gKCJvZmZpY2lhbF9taXJyb3IiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIGNvZGVuYW1lICsgIi11cGRhdGVzIiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAicmVzdHJpY3RlZCIsIFRydWUpCiAgICBzdWl0ZV9yZXN0cmljdGVkX3NlY3VyaXR5ID0gKCJvZmZpY2lhbF9taXJyb3IiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBjb2RlbmFtZSArICItc2VjdXJpdHkiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAicmVzdHJpY3RlZCIsIFRydWUpCiAgICBzdWl0ZV9yZXN0cmljdGVkX3Byb3Bvc2VkID0gKCJvZmZpY2lhbF9taXJyb3IiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBjb2RlbmFtZSArICItcHJvcG9zZWQiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAicmVzdHJpY3RlZCIsIFRydWUpCgogICAgIyB1bml2ZXJzZSBhbmQgbXVsdGl2ZXJzZSBmcm9tIHJlbGVhc2UsIC11cGRhdGVzLCAtcHJvcG9zZWQsIG9yIC1zZWN1cml0eQogICAgIyBwb2NrZXRzCiAgICBzdWl0ZV91bml2ZXJzZSA9ICgib2ZmaWNpYWxfbWlycm9yIiwgY29kZW5hbWUsICJ1bml2ZXJzZSIsIFRydWUpCiAgICBzdWl0ZV91bml2ZXJzZV91cGRhdGVzID0gKCJvZmZpY2lhbF9taXJyb3IiLCBjb2RlbmFtZSArICItdXBkYXRlcyIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICJ1bml2ZXJzZSIsIFRydWUpCiAgICBzdWl0ZV91bml2ZXJzZV9zZWN1cml0eSA9ICgib2ZmaWNpYWxfbWlycm9yIiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIGNvZGVuYW1lICsgIi1zZWN1cml0eSIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAidW5pdmVyc2UiLCBUcnVlKQogICAgc3VpdGVfdW5pdmVyc2VfcHJvcG9zZWQgPSAoIm9mZmljaWFsX21pcnJvciIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBjb2RlbmFtZSArICItcHJvcG9zZWQiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgInVuaXZlcnNlIiwgVHJ1ZSkKCiAgICBzdWl0ZV9tdWx0aXZlcnNlID0gKCJvZmZpY2lhbF9taXJyb3IiLCBjb2RlbmFtZSwgIm11bHRpdmVyc2UiLAogICAgICAgICAgICAgICAgICAgICAgICBUcnVlKQogICAgc3VpdGVfbXVsdGl2ZXJzZV91cGRhdGVzID0gKCJvZmZpY2lhbF9taXJyb3IiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIGNvZGVuYW1lICsgIi11cGRhdGVzIiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAibXVsdGl2ZXJzZSIsIFRydWUpCiAgICBzdWl0ZV9tdWx0aXZlcnNlX3NlY3VyaXR5ID0gKCJvZmZpY2lhbF9taXJyb3IiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBjb2RlbmFtZSArICItc2VjdXJpdHkiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAibXVsdGl2ZXJzZSIsIFRydWUpCiAgICBzdWl0ZV9tdWx0aXZlcnNlX3Byb3Bvc2VkID0gKCJvZmZpY2lhbF9taXJyb3IiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBjb2RlbmFtZSArICItcHJvcG9zZWQiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAibXVsdGl2ZXJzZSIsIFRydWUpCgogICAgIyBwYWNrYWdlcyBmcm9tIHRoZSBlc20gcmVzcG9zaXRvcmllcwogICAgIyBOLkIuIE9yaWdpbjogVWJ1bnR1IGlzIG5vdCBzZXQgZm9yIGVzbQogICAgc3VpdGVfZXNtX21haW4gPSAoZXNtX3NpdGUsICIlcy1pbmZyYS11cGRhdGVzIiAlIGNvZGVuYW1lLAogICAgICAgICAgICAgICAgICAgICAgIm1haW4iKQogICAgc3VpdGVfZXNtX21haW5fc2VjdXJpdHkgPSAoZXNtX3NpdGUsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAiJXMtaW5mcmEtc2VjdXJpdHkiICUgY29kZW5hbWUsICJtYWluIikKICAgIHN1aXRlX2VzbV91bml2ZXJzZSA9IChlc21fc2l0ZSwKICAgICAgICAgICAgICAgICAgICAgICAgICAiJXMtYXBwcy11cGRhdGVzIiAlIGNvZGVuYW1lLCAibWFpbiIpCiAgICBzdWl0ZV9lc21fdW5pdmVyc2Vfc2VjdXJpdHkgPSAoZXNtX3NpdGUsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIiVzLWFwcHMtc2VjdXJpdHkiICUgY29kZW5hbWUsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIm1haW4iKQoKICAgIGxpdmVwYXRjaF9lbmFibGVkID0gbGl2ZXBhdGNoX2lzX2VuYWJsZWQoKQogICAgZXNtX2VuYWJsZWQgPSBlc21faXNfZW5hYmxlZCgpCiAgICBpc19lc21faW5mcmFfdXNlZCA9IChzdWl0ZV9lc21fbWFpbiBpbiBhbGxfb3JpZ2lucykgb3IgXAogICAgICAgICAgICAgICAgICAgICAgICAoc3VpdGVfZXNtX21haW5fc2VjdXJpdHkgaW4gYWxsX29yaWdpbnMpCiAgICBpc19lc21fYXBwc191c2VkID0gKHN1aXRlX2VzbV91bml2ZXJzZSBpbiBhbGxfb3JpZ2lucykgb3IgXAogICAgICAgICAgICAgICAgICAgICAgIChzdWl0ZV9lc21fdW5pdmVyc2Vfc2VjdXJpdHkgaW4gYWxsX29yaWdpbnMpCgogICAgIyBOb3cgZG8gdGhlIGZpbmFsIGxvb3AgdGhyb3VnaAogICAgZm9yIHBrZyBpbiBjYWNoZToKICAgICAgICBpZiBub3QgcGtnLmlzX2luc3RhbGxlZDoKICAgICAgICAgICAgY29udGludWUKICAgICAgICBpZiBub3QgcGtnLmNhbmRpZGF0ZSBvciBub3QgcGtnLmNhbmRpZGF0ZS5kb3dubG9hZGFibGU6CiAgICAgICAgICAgIHBrZ3N0YXRzLnBrZ3NfdW5hdmFpbGFibGUuYWRkKHBrZy5uYW1lKQogICAgICAgICAgICBjb250aW51ZQogICAgICAgIHBrZ25hbWUgPSBwa2cubmFtZQogICAgICAgIHBrZ19vcmlnaW5zID0gb3JpZ2luc19ieV9wYWNrYWdlW3BrZ25hbWVdCgogICAgICAgICMgVGhpcyBzZXQgb2YgaXNfKiBib29sZWFucyB0cmFja3Mgc3BlY2lmaWMgc2l0dWF0aW9ucyB3ZSBjYXJlIGFib3V0IGluCiAgICAgICAgIyB0aGUgbG9naWMgYmVsb3c7IGZvciBpbnN0YW5jZSwgaWYgdGhlIHBhY2thZ2UgaGFzIGEgbWFpbiBvcmlnaW4sIG9yCiAgICAgICAgIyBpZiB0aGUgZXNtIHJlcG9zIGFyZSBlbmFibGVkLgoKICAgICAgICAjIFNvbWUgcGFja2FnZXMgZ2V0IGFkZGVkIGluIC11cGRhdGVzIGFuZCBkb24ndCBleGlzdCBpbiB0aGUgcmVsZWFzZQogICAgICAgICMgcG9ja2V0IGUuZy4gdWJ1bnR1LWFkdmFudGFnZS10b29scyBhbmQgbGliZHJtLXVwZGF0ZXMuIFRvIGJlIHNhZmUgYWxsCiAgICAgICAgIyBwb2NrZXRzIGFyZSBhbGxvd2VkLgogICAgICAgIGlzX21yX3BrZ19vcmlnaW4gPSAoc3VpdGVfbWFpbiBpbiBwa2dfb3JpZ2lucykgb3IgXAogICAgICAgICAgICAgICAgICAgICAgICAgICAoc3VpdGVfbWFpbl91cGRhdGVzIGluIHBrZ19vcmlnaW5zKSBvciBcCiAgICAgICAgICAgICAgICAgICAgICAgICAgIChzdWl0ZV9tYWluX3NlY3VyaXR5IGluIHBrZ19vcmlnaW5zKSBvciBcCiAgICAgICAgICAgICAgICAgICAgICAgICAgIChzdWl0ZV9tYWluX3Byb3Bvc2VkIGluIHBrZ19vcmlnaW5zKSBvciBcCiAgICAgICAgICAgICAgICAgICAgICAgICAgIChzdWl0ZV9yZXN0cmljdGVkIGluIHBrZ19vcmlnaW5zKSBvciBcCiAgICAgICAgICAgICAgICAgICAgICAgICAgIChzdWl0ZV9yZXN0cmljdGVkX3VwZGF0ZXMgaW4gcGtnX29yaWdpbnMpIG9yIFwKICAgICAgICAgICAgICAgICAgICAgICAgICAgKHN1aXRlX3Jlc3RyaWN0ZWRfc2VjdXJpdHkgaW4gcGtnX29yaWdpbnMpIG9yIFwKICAgICAgICAgICAgICAgICAgICAgICAgICAgKHN1aXRlX3Jlc3RyaWN0ZWRfcHJvcG9zZWQgaW4gcGtnX29yaWdpbnMpCiAgICAgICAgaXNfdW1fcGtnX29yaWdpbiA9IChzdWl0ZV91bml2ZXJzZSBpbiBwa2dfb3JpZ2lucykgb3IgXAogICAgICAgICAgICAgICAgICAgICAgICAgICAoc3VpdGVfdW5pdmVyc2VfdXBkYXRlcyBpbiBwa2dfb3JpZ2lucykgb3IgXAogICAgICAgICAgICAgICAgICAgICAgICAgICAoc3VpdGVfdW5pdmVyc2Vfc2VjdXJpdHkgaW4gcGtnX29yaWdpbnMpIG9yIFwKICAgICAgICAgICAgICAgICAgICAgICAgICAgKHN1aXRlX3VuaXZlcnNlX3Byb3Bvc2VkIGluIHBrZ19vcmlnaW5zKSBvciBcCiAgICAgICAgICAgICAgICAgICAgICAgICAgIChzdWl0ZV9tdWx0aXZlcnNlIGluIHBrZ19vcmlnaW5zKSBvciBcCiAgICAgICAgICAgICAgICAgICAgICAgICAgIChzdWl0ZV9tdWx0aXZlcnNlX3VwZGF0ZXMgaW4gcGtnX29yaWdpbnMpIG9yIFwKICAgICAgICAgICAgICAgICAgICAgICAgICAgKHN1aXRlX211bHRpdmVyc2Vfc2VjdXJpdHkgaW4gcGtnX29yaWdpbnMpIG9yIFwKICAgICAgICAgICAgICAgICAgICAgICAgICAgKHN1aXRlX211bHRpdmVyc2VfcHJvcG9zZWQgaW4gcGtnX29yaWdpbnMpCgogICAgICAgIGlzX2VzbV9pbmZyYV9wa2dfb3JpZ2luID0gKHN1aXRlX2VzbV9tYWluIGluIHBrZ19vcmlnaW5zKSBvciBcCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAoc3VpdGVfZXNtX21haW5fc2VjdXJpdHkgaW4gcGtnX29yaWdpbnMpCiAgICAgICAgaXNfZXNtX2FwcHNfcGtnX29yaWdpbiA9IChzdWl0ZV9lc21fdW5pdmVyc2UgaW4gcGtnX29yaWdpbnMpIG9yIFwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgKHN1aXRlX2VzbV91bml2ZXJzZV9zZWN1cml0eSBpbiBwa2dfb3JpZ2lucykKCiAgICAgICAgIyBBIHRoaXJkIHBhcnR5IG9uZSB3b24ndCBhcHBlYXIgaW4gYW55IG9mIHRoZSBhYm92ZSBvcmlnaW5zCiAgICAgICAgaWYgbm90IGlzX21yX3BrZ19vcmlnaW4gYW5kIG5vdCBpc191bV9wa2dfb3JpZ2luIFwKICAgICAgICAgICAgICAgIGFuZCBub3QgaXNfZXNtX2luZnJhX3BrZ19vcmlnaW4gYW5kIG5vdCBpc19lc21fYXBwc19wa2dfb3JpZ2luOgogICAgICAgICAgICBwa2dzdGF0cy5wa2dzX3RoaXJkcGFydHkuYWRkKHBrZ25hbWUpCgogICAgICAgIGlmIEZhbHNlOiAgIyBUT0RPIHBhY2thZ2UgaGFzIEVTTSBmaXBzIG9yaWdpbgogICAgICAgICAgICAjIFRPRE8gcGFja2FnZSBoYXMgRVNNIGZpcHMtdXBkYXRlcyBvcmlnaW46IE9LCiAgICAgICAgICAgICMgSWYgdXNlciBoYXMgZW5hYmxlZCBGSVBTLCBidXQgbm90IHVwZGF0ZXMsIEJBRCwgYnV0IG5lZWQgc29tZQogICAgICAgICAgICAjIHRob3VnaHQgb24gaG93IHRvIGRpc3BsYXkgaXQsIGFzIGl0IGNhbid0IGJlIHBhdGNoZWQgYXQgYWxsCiAgICAgICAgICAgIHBhc3MKICAgICAgICBlbGlmIGlzX21yX3BrZ19vcmlnaW46CiAgICAgICAgICAgIHBrZ3N0YXRzLnBrZ3NfbXIuYWRkKHBrZ25hbWUpCiAgICAgICAgZWxpZiBpc191bV9wa2dfb3JpZ2luOgogICAgICAgICAgICBwa2dzdGF0cy5wa2dzX3VtLmFkZChwa2duYW1lKQogICAgICAgIGVsc2U6CiAgICAgICAgICAgICMgVE9ETyBwcmludCBpbmZvcm1hdGlvbiBhYm91dCBwYWNrYWdlcyBpbiB0aGlzIGNhdGVnb3J5IGlmIGluCiAgICAgICAgICAgICMgZGVidWdnaW5nIG1vZGUKICAgICAgICAgICAgcGtnc3RhdHMucGtnc191bmNhdGVnb3JpemVkLmFkZChwa2duYW1lKQoKICAgICAgICAjIENoZWNrIHRvIHNlZSBpZiB0aGUgcGFja2FnZSBpcyBhdmFpbGFibGUgaW4gZXNtLWluZnJhIG9yIGVzbS1hcHBzCiAgICAgICAgIyBhbmQgYWRkIGl0IHRvIHRoZSByaWdodCBwa2dzdGF0cyBjYXRlZ29yeQogICAgICAgICMgTkI6IGFwcHMgaXMgb3JkZXJlZCBmaXJzdCBmb3IgdGVzdGluZyB0aGUgaGVsbG8gcGFja2FnZSB3aGljaCBpcyBib3RoCiAgICAgICAgIyBpbiBlc21pIGFuZCBlc21hCiAgICAgICAgaWYgcGtnbmFtZSBpbiBwa2dzX2luX2VzbWE6CiAgICAgICAgICAgIHBrZ3N0YXRzLnBrZ3NfdXBkYXRlZF9pbl9lc21hLmFkZChwa2duYW1lKQogICAgICAgIGVsaWYgcGtnbmFtZSBpbiBwa2dzX2luX2VzbWk6CiAgICAgICAgICAgIHBrZ3N0YXRzLnBrZ3NfdXBkYXRlZF9pbl9lc21pLmFkZChwa2duYW1lKQoKICAgIHRvdGFsX3BhY2thZ2VzID0gKGxlbihwa2dzdGF0cy5wa2dzX21yKSArCiAgICAgICAgICAgICAgICAgICAgICBsZW4ocGtnc3RhdHMucGtnc191bSkgKwogICAgICAgICAgICAgICAgICAgICAgbGVuKHBrZ3N0YXRzLnBrZ3NfdGhpcmRwYXJ0eSkgKwogICAgICAgICAgICAgICAgICAgICAgbGVuKHBrZ3N0YXRzLnBrZ3NfdW5hdmFpbGFibGUpKQogICAgd2lkdGggPSBsZW4oc3RyKHRvdGFsX3BhY2thZ2VzKSkKICAgIHByaW50KCIlcyBwYWNrYWdlcyBpbnN0YWxsZWQsIG9mIHdoaWNoOiIgJQogICAgICAgICAgIns6Pnt3aWR0aH19Ii5mb3JtYXQodG90YWxfcGFja2FnZXMsIHdpZHRoPXdpZHRoKSkKCiAgICAjIGZpbHRlcnMgZmlyc3QgYXMgdGhleSBwcm92aWRlIGxlc3MgaW5mb3JtYXRpb24KICAgIGlmIGFyZ3MudGhpcmRwYXJ0eToKICAgICAgICBpZiBwa2dzdGF0cy5wa2dzX3RoaXJkcGFydHk6CiAgICAgICAgICAgIHBrZ3NfdGhpcmRwYXJ0eSA9IHNvcnRlZChwIGZvciBwIGluIHBrZ3N0YXRzLnBrZ3NfdGhpcmRwYXJ0eSkKICAgICAgICAgICAgcHJpbnRfdGhpcmRwYXJ0eV9jb3VudCgpCiAgICAgICAgICAgIHByaW50X3dyYXBwZWQoJyAnLmpvaW4ocGtnc190aGlyZHBhcnR5KSkKICAgICAgICAgICAgbXNnID0gKCJQYWNrYWdlcyBmcm9tIHRoaXJkIHBhcnRpZXMgYXJlIG5vdCBwcm92aWRlZCBieSB0aGUgIgogICAgICAgICAgICAgICAgICAgIm9mZmljaWFsIFVidW50dSBhcmNoaXZlLCBmb3IgZXhhbXBsZSBwYWNrYWdlcyBmcm9tICIKICAgICAgICAgICAgICAgICAgICJQZXJzb25hbCBQYWNrYWdlIEFyY2hpdmVzIGluIExhdW5jaHBhZC4iKQogICAgICAgICAgICBwcmludCgiIikKICAgICAgICAgICAgcHJpbnRfd3JhcHBlZChtc2cpCiAgICAgICAgICAgIHByaW50KCIiKQogICAgICAgICAgICBwcmludF93cmFwcGVkKCJSdW4gJ2FwdC1jYWNoZSBwb2xpY3kgJXMnIHRvIGxlYXJuIG1vcmUgYWJvdXQgIgogICAgICAgICAgICAgICAgICAgICAgICAgICJ0aGF0IHBhY2thZ2UuIiAlIHBrZ3NfdGhpcmRwYXJ0eVswXSkKICAgICAgICAgICAgc3lzLmV4aXQoMCkKICAgICAgICBlbHNlOgogICAgICAgICAgICBwcmludF93cmFwcGVkKCJZb3UgaGF2ZSBubyBwYWNrYWdlcyBpbnN0YWxsZWQgZnJvbSBhIHRoaXJkIHBhcnR5LiIpCiAgICAgICAgICAgIHN5cy5leGl0KDApCiAgICBpZiBhcmdzLnVuYXZhaWxhYmxlOgogICAgICAgIGlmIHBrZ3N0YXRzLnBrZ3NfdW5hdmFpbGFibGU6CiAgICAgICAgICAgIHBrZ3NfdW5hdmFpbGFibGUgPSBzb3J0ZWQocCBmb3IgcCBpbiBwa2dzdGF0cy5wa2dzX3VuYXZhaWxhYmxlKQogICAgICAgICAgICBwcmludF91bmF2YWlsYWJsZV9jb3VudCgpCiAgICAgICAgICAgIHByaW50X3dyYXBwZWQoJyAnLmpvaW4ocGtnc191bmF2YWlsYWJsZSkpCiAgICAgICAgICAgIG1zZyA9ICgiUGFja2FnZXMgdGhhdCBhcmUgbm90IGF2YWlsYWJsZSBmb3IgZG93bmxvYWQgIgogICAgICAgICAgICAgICAgICAgIm1heSBiZSBsZWZ0IG92ZXIgZnJvbSBhIHByZXZpb3VzIHJlbGVhc2Ugb2YgIgogICAgICAgICAgICAgICAgICAgIlVidW50dSwgbWF5IGhhdmUgYmVlbiBpbnN0YWxsZWQgZGlyZWN0bHkgZnJvbSAiCiAgICAgICAgICAgICAgICAgICAiYSAuZGViIGZpbGUsIG9yIGFyZSBmcm9tIGEgc291cmNlIHdoaWNoIGhhcyAiCiAgICAgICAgICAgICAgICAgICAiYmVlbiBkaXNhYmxlZC4iKQogICAgICAgICAgICBwcmludCgiIikKICAgICAgICAgICAgcHJpbnRfd3JhcHBlZChtc2cpCiAgICAgICAgICAgIHByaW50KCIiKQogICAgICAgICAgICBwcmludF93cmFwcGVkKCJSdW4gJ2FwdC1jYWNoZSBzaG93ICVzJyB0byBsZWFybiBtb3JlIGFib3V0ICIKICAgICAgICAgICAgICAgICAgICAgICAgICAidGhhdCBwYWNrYWdlLiIgJSBwa2dzX3VuYXZhaWxhYmxlWzBdKQogICAgICAgICAgICBzeXMuZXhpdCgwKQogICAgICAgIGVsc2U6CiAgICAgICAgICAgIHByaW50X3dyYXBwZWQoIllvdSBoYXZlIG5vIHBhY2thZ2VzIGluc3RhbGxlZCB0aGF0IGFyZSBubyBsb25nZXIgIgogICAgICAgICAgICAgICAgICAgICAgICAgICJhdmFpbGFibGUuIikKICAgICAgICAgICAgc3lzLmV4aXQoMCkKICAgICMgT25seSBzaG93IExUUyBwYXRjaGVzIGFuZCBleHBpcmF0aW9uIG5vdGljZXMgaWYgdGhlIHJlbGVhc2UgaXMgbm90CiAgICAjIHlldCBleHBpcmVkOyBzaG93aW5nIExUUyBwYXRjaGVzIHdvdWxkIGdpdmUgYSBmYWxzZSBzZW5zZSBvZgogICAgIyBzZWN1cml0eS4KICAgIGlmIG5vdCByZWxlYXNlX2V4cGlyZWQ6CiAgICAgICAgcHJpbnQoIiVzIHJlY2VpdmUgcGFja2FnZSB1cGRhdGVzJXMgdW50aWwgJWQvJWQiICUKICAgICAgICAgICAgICAoIns6Pnt3aWR0aH19Ii5mb3JtYXQobGVuKHBrZ3N0YXRzLnBrZ3NfbXIpLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICB3aWR0aD13aWR0aCksCiAgICAgICAgICAgICAgICIgd2l0aCBMVFMiIGlmIGx0cyBlbHNlICIiLAogICAgICAgICAgICAgICBlb2wubW9udGgsIGVvbC55ZWFyKSkKICAgIGVsaWYgcmVsZWFzZV9leHBpcmVkIGFuZCBsdHM6CiAgICAgICAgcHJpbnQoIiVzICVzIHNlY3VyaXR5IHVwZGF0ZXMgd2l0aCBFU00gSW5mcmEgIgogICAgICAgICAgICAgICJ1bnRpbCAlZC8lZCIgJQogICAgICAgICAgICAgICgiezo+e3dpZHRofX0iLmZvcm1hdChsZW4ocGtnc3RhdHMucGtnc19tciksCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIHdpZHRoPXdpZHRoKSwKICAgICAgICAgICAgICAgImFyZSByZWNlaXZpbmciIGlmIGVzbV9lbmFibGVkIGVsc2UgImNvdWxkIHJlY2VpdmUiLAogICAgICAgICAgICAgICBlb2xfZXNtLm1vbnRoLCBlb2xfZXNtLnllYXIpKQogICAgaWYgbHRzIGFuZCBwa2dzdGF0cy5wa2dzX3VtOgogICAgICAgIHByaW50KCIlcyAlcyBzZWN1cml0eSB1cGRhdGVzIHdpdGggRVNNIEFwcHMgIgogICAgICAgICAgICAgICJ1bnRpbCAlZC8lZCIgJQogICAgICAgICAgICAgICgiezo+e3dpZHRofX0iLmZvcm1hdChsZW4ocGtnc3RhdHMucGtnc191bSksCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIHdpZHRoPXdpZHRoKSwKICAgICAgICAgICAgICAgImFyZSByZWNlaXZpbmciIGlmIGVzbV9lbmFibGVkIGVsc2UgImNvdWxkIHJlY2VpdmUiLAogICAgICAgICAgICAgICBlb2xfZXNtLm1vbnRoLCBlb2xfZXNtLnllYXIpKQogICAgaWYgcGtnc3RhdHMucGtnc190aGlyZHBhcnR5OgogICAgICAgIHByaW50X3RoaXJkcGFydHlfY291bnQoKQogICAgaWYgcGtnc3RhdHMucGtnc191bmF2YWlsYWJsZToKICAgICAgICBwcmludF91bmF2YWlsYWJsZV9jb3VudCgpCiAgICAjIHByaW50IHRoZSBkZXRhaWwgbWVzc2FnZXMgYWZ0ZXIgdGhlIGNvdW50IG9mIHBhY2thZ2VzCiAgICBpZiBwa2dzdGF0cy5wa2dzX3RoaXJkcGFydHk6CiAgICAgICAgbXNnID0gKCJQYWNrYWdlcyBmcm9tIHRoaXJkIHBhcnRpZXMgYXJlIG5vdCBwcm92aWRlZCBieSB0aGUgIgogICAgICAgICAgICAgICAib2ZmaWNpYWwgVWJ1bnR1IGFyY2hpdmUsIGZvciBleGFtcGxlIHBhY2thZ2VzIGZyb20gIgogICAgICAgICAgICAgICAiUGVyc29uYWwgUGFja2FnZSBBcmNoaXZlcyBpbiBMYXVuY2hwYWQuIikKICAgICAgICBwcmludCgiIikKICAgICAgICBwcmludF93cmFwcGVkKG1zZykKICAgICAgICBhY3Rpb24gPSAoIkZvciBtb3JlIGluZm9ybWF0aW9uIG9uIHRoZSBwYWNrYWdlcywgcnVuICIKICAgICAgICAgICAgICAgICAgIid1YnVudHUtc2VjdXJpdHktc3RhdHVzIC0tdGhpcmRwYXJ0eScuIikKICAgICAgICBwcmludF93cmFwcGVkKGFjdGlvbikKICAgIGlmIHBrZ3N0YXRzLnBrZ3NfdW5hdmFpbGFibGU6CiAgICAgICAgbXNnID0gKCJQYWNrYWdlcyB0aGF0IGFyZSBub3QgYXZhaWxhYmxlIGZvciBkb3dubG9hZCAiCiAgICAgICAgICAgICAgICJtYXkgYmUgbGVmdCBvdmVyIGZyb20gYSBwcmV2aW91cyByZWxlYXNlIG9mICIKICAgICAgICAgICAgICAgIlVidW50dSwgbWF5IGhhdmUgYmVlbiBpbnN0YWxsZWQgZGlyZWN0bHkgZnJvbSAiCiAgICAgICAgICAgICAgICJhIC5kZWIgZmlsZSwgb3IgYXJlIGZyb20gYSBzb3VyY2Ugd2hpY2ggaGFzICIKICAgICAgICAgICAgICAgImJlZW4gZGlzYWJsZWQuIikKICAgICAgICBwcmludCgiIikKICAgICAgICBwcmludF93cmFwcGVkKG1zZykKICAgICAgICBhY3Rpb24gPSAoIkZvciBtb3JlIGluZm9ybWF0aW9uIG9uIHRoZSBwYWNrYWdlcywgcnVuICIKICAgICAgICAgICAgICAgICAgIid1YnVudHUtc2VjdXJpdHktc3RhdHVzIC0tdW5hdmFpbGFibGUnLiIpCiAgICAgICAgcHJpbnRfd3JhcHBlZChhY3Rpb24pCiAgICAjIHByaW50IHRoZSBFU00gY2FsbHMgdG8gYWN0aW9uIGxhc3QKICAgIGlmIGx0cyBhbmQgbm90IGVzbV9lbmFibGVkOgogICAgICAgIGlmIHJlbGVhc2VfZXhwaXJlZCBhbmQgcGtnc3RhdHMucGtnc19tcjoKICAgICAgICAgICAgcGtnc191cGRhdGVkX2luX2VzbWkgPSBwa2dzdGF0cy5wa2dzX3VwZGF0ZWRfaW5fZXNtaQogICAgICAgICAgICBwcmludCgiIikKICAgICAgICAgICAgcHJpbnRfd3JhcHBlZChnZXR0ZXh0LmRuZ2V0dGV4dCgidXBkYXRlLW1hbmFnZXIiLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICJFbmFibGUgRXh0ZW5kZWQgU2VjdXJpdHkgIgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICJNYWludGVuYW5jZSAoRVNNIEluZnJhKSB0byAiCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgImdldCAlaSBzZWN1cml0eSB1cGRhdGUgKHNvIGZhcikgIgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICJhbmQgZW5hYmxlIGNvdmVyYWdlIG9mICVpICIKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAicGFja2FnZXMuIiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAiRW5hYmxlIEV4dGVuZGVkIFNlY3VyaXR5ICIKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAiTWFpbnRlbmFuY2UgKEVTTSBJbmZyYSkgdG8gIgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICJnZXQgJWkgc2VjdXJpdHkgdXBkYXRlcyAoc28gZmFyKSAiCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgImFuZCBlbmFibGUgY292ZXJhZ2Ugb2YgJWkgIgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICJwYWNrYWdlcy4iLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIGxlbihwa2dzX3VwZGF0ZWRfaW5fZXNtaSkpICUKICAgICAgICAgICAgICAgICAgICAgICAgICAobGVuKHBrZ3NfdXBkYXRlZF9pbl9lc21pKSwKICAgICAgICAgICAgICAgICAgICAgICAgICAgbGVuKHBrZ3N0YXRzLnBrZ3NfbXIpKSkKICAgICAgICAgICAgaWYgbGl2ZXBhdGNoX2VuYWJsZWQ6CiAgICAgICAgICAgICAgICBwcmludCgiXG5FbmFibGUgRVNNIEluZnJhIHdpdGg6IHVhIGVuYWJsZSBlc20taW5mcmEiKQogICAgICAgIGlmIHBrZ3N0YXRzLnBrZ3NfdW06CiAgICAgICAgICAgIHBrZ3NfdXBkYXRlZF9pbl9lc21hID0gcGtnc3RhdHMucGtnc191cGRhdGVkX2luX2VzbWEKICAgICAgICAgICAgcHJpbnQoIiIpCiAgICAgICAgICAgIHByaW50X3dyYXBwZWQoZ2V0dGV4dC5kbmdldHRleHQoInVwZGF0ZS1tYW5hZ2VyIiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAiRW5hYmxlIEV4dGVuZGVkIFNlY3VyaXR5ICIKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAiTWFpbnRlbmFuY2UgKEVTTSBBcHBzKSB0byAiCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgImdldCAlaSBzZWN1cml0eSB1cGRhdGUgKHNvIGZhcikgIgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICJhbmQgZW5hYmxlIGNvdmVyYWdlIG9mICVpICIKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAicGFja2FnZXMuIiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAiRW5hYmxlIEV4dGVuZGVkIFNlY3VyaXR5ICIKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAiTWFpbnRlbmFuY2UgKEVTTSBBcHBzKSB0byAiCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgImdldCAlaSBzZWN1cml0eSB1cGRhdGVzIChzbyBmYXIpICIKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAiYW5kIGVuYWJsZSBjb3ZlcmFnZSBvZiAlaSAiCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgInBhY2thZ2VzLiIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgbGVuKHBrZ3NfdXBkYXRlZF9pbl9lc21hKSkgJQogICAgICAgICAgICAgICAgICAgICAgICAgIChsZW4ocGtnc191cGRhdGVkX2luX2VzbWEpLAogICAgICAgICAgICAgICAgICAgICAgICAgICBsZW4ocGtnc3RhdHMucGtnc191bSkpKQogICAgICAgICAgICBpZiBsaXZlcGF0Y2hfZW5hYmxlZDoKICAgICAgICAgICAgICAgIHByaW50KCJcbkVuYWJsZSBFU00gQXBwcyB3aXRoOiB1YSBlbmFibGUgZXNtLWFwcHMiKQogICAgaWYgbHRzIGFuZCBub3QgbGl2ZXBhdGNoX2VuYWJsZWQ6CiAgICAgICAgcHJpbnQoIlxuVGhpcyBtYWNoaW5lIGlzIG5vdCBhdHRhY2hlZCB0byBhbiBVYnVudHUgQWR2YW50YWdlICIKICAgICAgICAgICAgICAic3Vic2NyaXB0aW9uLlxuU2VlIGh0dHBzOi8vdWJ1bnR1LmNvbS9hZHZhbnRhZ2UiKQo='
[[ -f /tmp/ubuntu-security-status ]] && { chmod +x /tmp/ubuntu-security-status; } || { echo ${USS_B64}|base64 -d|tee 1>/dev/null /tmp/ubuntu-security-status;chmod +x /tmp/ubuntu-security-status; }
# Create a ubuntu-security-status file
printf "\n\e[2G\e[1mRun ubuntu-security-status\e[0m\n"
if [[ -f /tmp/ubuntu-security-status ]];then
    cp /usr/share/ubuntu-release-upgrader/mirrors.cfg ${REL_DIR}/mirror.cfg
		find 2>/dev/null /var/lib/apt/lists -maxdepth 1 -regextype "posix-extended" -iregex '.*(Release$)' -exec \
			grep -m1 -lE "$(printf '^Origin:.*%s$\n' ${OSSA_ORIGINS[@]}|paste -sd'|')" {} \;| \
			sed 's|/var/lib/apt/lists/|http://|g;s|_dists_||g;s|_ubuntu.*$|/ubuntu/ |g'| \
			sort -uV|sed -r '/ubuntu.com|canonical.com|launchpad.net\/maas/d'|tee 1> /dev/null -a ${REL_DIR}/mirror.cfg	
		[[ -n ${EXTRA_ORIGINS[@]} && ${#EXTRA_ORIGINS[@]} -ge 1 ]] && { printf '%s\n' ${EXTRA_ORIGINS[@]}|tee -a ${REL_DIR}/mirror.cfg; }
    sed "s|/usr/share/ubuntu-release-upgrader/mirrors.cfg|${REL_DIR}/mirror.cfg|g" -i /tmp/ubuntu-security-status
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Running ubuntu-security-status (standard)\n\n"
    /tmp/ubuntu-security-status|tee 1>/dev/null ${UTIL_DIR}/ubuntu-security-status.standard.${OSSA_SUFFX}
    cat ${UTIL_DIR}/ubuntu-security-status.standard.${OSSA_SUFFX}|awk '/^[0-9]/,/^$/{gsub(/^/,"     &",$0);print}'
    export SEC_STATUS="$(cat ${UTIL_DIR}/ubuntu-security-status.standard.${OSSA_SUFFX}|sed -n '/^[0-9]/,/^$/p'|sed 's/^.*$/ &/g')"
    # make a more verbose report
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Running ubuntu-security-status --thirdparty\n"
    /tmp/ubuntu-security-status --thirdparty 2>&1|tee 1>/dev/null ${UTIL_DIR}/ubuntu-security-status.thirdparty.${OSSA_SUFFX}
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Running ubuntu-security-status --unavailable\n"
    /tmp/ubuntu-security-status --unavailable 2>&1|tee 1>/dev/null ${UTIL_DIR}/ubuntu-security-status.unavailable.${OSSA_SUFFX}
    [[ -s ${UTIL_DIR}/ubuntu-security-status.thirdparty.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created ubuntu-security-status output files\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not create ubuntu-security-status output files\n" ; }
    rm -f 2>/dev/null /tmp/ubuntu-security-status
else
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: ubuntu-security-status not installed. Skipping\n"
fi

######################
# DOWNLOAD OVAL DATA #
######################

[[ ${OSSA_SCAN} = true ]] && { printf "\n\e[2G\e[1mDownload OVAL Data for CVE scanning\e[0m\n"; } || { printf "\n\e[2G\e[1mDownload OVAL Data for offline CVE scanning\e[0m\n"; }
export SCAN_RELEASE=$(lsb_release -sc)
export OVAL_URI="https://people.canonical.com/~ubuntu-security/oval/oci.com.ubuntu.${SCAN_RELEASE,,}.cve.oval.xml.bz2"
export TEST_OVAL=$(curl -slSL --connect-timeout 5 --max-time 20 --retry 5 --retry-delay 1 -w %{http_code} -o /dev/null ${OVAL_URI} 2>&1)
[[ ${OSSA_DEBUG} = true ]] && { echo "${TEST_OVAL}"; }
if [[ ${TEST_OVAL:(-3)} -eq 404 ]];then
	printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: OVAL data file for Ubuntu ${SCAN_RELEASE^} is not available. Skipping download.\n"
else
	[[ ${TEST_OVAL:(-3)} -eq 200 ]] && { printf "\r\e[2G - \e[38;2;0;160;200mINFO\e[0m: Downloading OVAL data for Ubuntu ${SCAN_RELEASE^}\n";curl -slSL --connect-timeout 5 --max-time 20 --retry 5 --retry-delay 1 ${OVAL_URI} -o- |bunzip2 -d|tee 1>/dev/null ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2});[[ ${OSSA_DEBUG} = true ]] && { echo $?; } }
	[[ ${OSSA_DEBUG} = true ]] && { curl 2>&1 -lSL --connect-timeout 30 --max-time 90 --retry 5 --retry-delay 5 ${OVAL_URI} -o- |bunzip2 -d|tee 1>/dev/null ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2}); }
	[[ ${TEST_OVAL:(-3)} -eq 200 && -s ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2}) ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Copied OVAL data for for Ubuntu ${SCAN_RELEASE^} to ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2})\n"; }
fi

####################
# PERFORM CVE SCAN #
####################

[[ ${OSSA_SCAN} = true ]] && printf "\n\e[2G\e[1mPerform online CVE scan\e[0m\n"
if [[ ${OSSA_SCAN} = true && -f ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2}) ]];then
	if [[ -f ${MFST_DIR}/manifest.${OSSA_SUFFX} ]];then
		printf "\r\e[2G - \e[38;2;0;160;200mINFO\e[0m: Linking manifest to OVAL Data Directroy\n"
		ln -sf ${MFST_DIR}/manifest.${OSSA_SUFFX} ${OVAL_DIR}/${SCAN_RELEASE}.manifest
	fi
	[[ -f ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2}) ]] || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Can't find OVAL data.\n\e[5GExpected it here: ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2}).\n"; }
	[[ -h ${OVAL_DIR}/${SCAN_RELEASE}.manifest ]] || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Can't find manifest symlink.\n\e[5GExpected it here: ${OVAL_DIR}/${SCAN_RELEASE}.manifest.\n"; }
	if [[ -f ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2}) && -h ${OVAL_DIR}/${SCAN_RELEASE}.manifest ]];then
		printf "\r\e[2G - \e[38;2;0;160;200mINFO\e[0m: Initiating CVE Scan using OVAL data for Ubuntu ${SCAN_RELEASE^}\n"
		echo
		oscap oval eval --report ${RPRT_DIR}/oscap-cve-scan-report.${OSSA_SUFFX}.html ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2})| \
			awk -vF=0 -vT=0 '{if ($NF=="false") F++} {if ($NF=="true") T++} END {print "CVE Scan Results (Summary)\nCommon Vulnerabilities Addressed: "F"\nCurrent Vulnerability Exposure: "T}'| \
			tee ${UTIL_DIR}/cve-stats.${OSSA_SUFFX}|sed 's/^.*$/     &/g'
		OSCAP_RESULT=$?
		[[ ${OSSA_DEBUG} = true ]] && { echo "OSCAP EXIT CODE: ${OSCAP_RESULT}"; }
		echo
	else
		printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Missing OVAL Data and or manifest.\n"	
	fi
	[[ -s ${RPRT_DIR}/oscap-cve-scan-report.${OSSA_SUFFX}.html ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: OpenSCAP CVE Report is located @ ${RPRT_DIR}/oscap-cve-scan-report.${OSSA_SUFFX}.html\n"; }  || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Encountered issues running OpenSCAP CVE Scan.  Report not available.\n" ; }
	[[ -s ${UTIL_DIR}/cve-stats.${OSSA_SUFFX} ]] && { export CVE_STATUS="$(cat ${UTIL_DIR}/cve-stats.${OSSA_SUFFX})"; }
elif [[ ${TEST_OVAL:(-3)} -eq 404 ]];then
	printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Skipping CVE scan since OVAL data for Ubuntu ${SCAN_RELEASE^} is not available.\n";
elif [[ ${TEST_OVAL:(-3)} -eq 000 ]];then
	printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Skipping CVE scan since OVAL data for Ubuntu ${SCAN_RELEASE^} due to network issue downloading OVAL data.\n";
else
	printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Skipping CVE scan due to missing OVAL data.\n\e[5GExpected to find it @ ${OVAL_DIR}/$(basename ${OVAL_URI//.bz2}).\n";
fi

######################
# PROCESSES SNAPSHOT #
######################

printf "\n\e[2G\e[1mTake Snapshot of Current Processes (ps -auxwww)\e[0m\n"
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Running ps -auxwww\n"
ps 2>/dev/null -auxwwww|tee 1>/dev/null ${UTIL_DIR}/ps.out.${OSSA_SUFFX}
[[ -s ${UTIL_DIR}/ps.out.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created process snapshot file\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not create process snapshot file\n";OSSA_COPY_ERRORS+=( "${UTIL_DIR}/ps.out.${OSSA_SUFFX}" ); }
declare -ag PS_PW_LINES=()
while IFS= read PLINE;do PS_PW_LINE+=( "${PLINE}" );done < <(grep 2>/dev/null -onE '[Pp][Aa][Ss][Ss]?(w)| -P ' ${UTIL_DIR}/ps.out.${OSSA_SUFFX})
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Checking for embedded credentials in ${UTIL_DIR}/ps.out.${OSSA_SUFFX}\n"
	if [[ ${#PS_PW_LINES[@]} -ge 1 ]];then
		export OSSA_CREDS_DETECTED=true
else
	export OSSA_CREDS_DETECTED=false
	PS_PW_LINES=()
fi


# if script detects that SOURCES_LIST_D possibly contains credentials, scrub detected strings
# Use -o,--override option force the copy
if [[ ${OSSA_CREDS_DETECTED} = true && ${OSSA_IGNORE_CREDS} = true ]];then
	if [[ ${#PS_PW_LINES[@]} -ge 1 ]];then
		printf "\e[2G - \e[38;2;255;200;0mNOTE\e[0m: ${UTIL_DIR}/ps.out.${OSSA_SUFFX} may contain embedded credentials but password scrubbing has been overridden! \n"
		printf "\e[2G - \e[38;2;255;200;0mWARNING\e[0m: Please review following lines:strings in ${UTIL_DIR}/ps.out.${OSSA_SUFFX}:\n"
		printf '\e[14G%s\n' "${PS_PW_LINES[@]}"
		echo
		sleep 2
	else
		printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Did not detect embedded credentials in ${UTIL_DIR}/ps.out.${OSSA_SUFFX}\n"
	fi
else
	if [[ ${#PS_PW_LINES[@]} -ge 1 ]];then
		printf "\e[2G - \e[38;2;255;200;0mNOTE\e[0m: Scrubbing potential embedded credentials from ${PARTS_DIR}/*\n\e[14GUse -o,--override option to prevent data scrubbing.\n\n"
		for i in "${PS_PW_LINE[@]}";do
			printf "Deleting ${i##*:} from line ${i%%:*} in ${UTIL_DIR}/ps.out.${OSSA_SUFFX}\n"
			sed -ir 's,'"${i##*:}"',,g' ${UTIL_DIR}/ps.out.${OSSA_SUFFX}
		done
		echo
	else
		printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Did not detect embedded credentials in ${UTIL_DIR}/ps.out.${OSSA_SUFFX}\n"
	fi
fi
export OSSA_CREDS_DETECTED=false

####################
# NETSTAT SNAPSHOT #
####################

printf "\n\e[2G\e[1mTake Snapshot of Network Statistics (netstat -an)\e[0m\n"
if [[ -n $(command -v netstat) ]];then NETSTAT=$(command -v netstat);elif [[ -n $(command -v ss) ]];then NETSTAT=$(command -v ss);else NETSTAT="";fi
if [[ -n ${NETSTAT} ]];then
	printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Running netstat -an\n"
	[[ -n ${SCMD} ]] && { ${SCMD} ${NETSTAT} 2>/dev/null -anp|tee 1>/dev/null ${UTIL_DIR}/netstat.out.${OSSA_SUFFX}; } || {  ${NETSTAT} 2>/dev/null -an|tee 1>/dev/null ${UTIL_DIR}/netstat.out.${OSSA_SUFFX}; }
	[[ -s ${UTIL_DIR}/netstat.out.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created netstat snapshot file\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not create netstat snapshot file\n" ; }
else
	printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Neither \"netstat\" or \"ss\" are installed. Skipping\n"
fi

#################
# LSOF SNAPSHOT #
#################

printf "\n\e[2G\e[1mList open files (lsof)\e[0m\n"
if [[ $(command -v lsof) ]];then
	printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Running lsof\n"
	${SCMD} lsof 2>/dev/null|tee 1>/dev/null ${UTIL_DIR}/lsof.out.${OSSA_SUFFX};
	[[ -s ${UTIL_DIR}/lsof.out.${OSSA_SUFFX} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created lsof snapshot file\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not create lsof snapshot file\n" ; }
else
	printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: lsof not installed. Skipping\n"
fi


##################################
# PRINT COPY_ERRORS ARRAY TO LOG #
##################################

[[ ${#OSSA_COPY_ERRORS[@]} -ge 1 ]] && { touch ${OSSA_DIR}/copy.err.log;printf '%s\n' "${OSSA_COPY_ERRORS[@]}"|tee -a 1>/dev/null ${OSSA_DIR}/copy.err.log; }

##################
# Create Tarball #
##################

printf "\n\e[2G\e[1mArchiving and Compressing Collected Data\e[0m\n"
[[ -n ${OSSA_PW} ]] && { export TARBALL=/tmp/ossa-datafile.encrypted.${OSSA_SUFFX}.tgz; } || { export TARBALL=/tmp/ossa-datafile.${OSSA_SUFFX}.tgz; }
if [[ -n ${OSSA_PW} ]];then
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Encrypting OSSA data files using openssl\n"
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Password is \"${OSSA_PW}\"\n"
    tar czf - -C ${OSSA_DIR%/*} ${OSSA_DIR##*/} | openssl enc -e -aes256 -pbkdf2 -pass env:OSSA_PW -out ${TARBALL}
else
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Archiving and compressing OSSA Datafiles\n"
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Tarball is not encrytped. \n"
    tar -czf ${TARBALL} -C ${OSSA_DIR%/*} ${OSSA_DIR##*/}
fi
[[ -s ${TARBALL} ]] && { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Created tarball ${TARBALL}\n"; } || { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Could not create tarball ${TARBALL}\n" ; }
printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Please download ${TARBALL} to your local machine\n"

############
# CLEAN UP #
############

printf "\n\e[2G\e[1mPerforming Cleanup\e[0m\n"
if [[ ${OSSA_KEEP} = true ]];then
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Keep option specified. Not removing OSSA Data Directory\n"
else
    printf "\e[2G - \e[38;2;0;160;200mINFO\e[0m: Removing OSSA Data Directory\n"
    cd
    rm -rf ${OSSA_DIR}
  [[ -d ${OSSA_DIR} ]] && { printf "\e[2G - \e[38;2;255;0;0mERROR\e[0m: Failed to delete ${OSSA_DIR}\n" ; } || { printf "\e[2G - \e[38;2;0;255;0mSUCCESS\e[0m: Deleted ${OSSA_DIR}\n"; }
fi

#################
# END OF SCRIPT #
#################

OSSA_TIME=$(TZ=UTC date --date now-${NOW} "+%H:%M:%S")
echo

# Display countdown message so user understands screen will be cleared
[[ ${OSSA_DEBUG} = true ]] || { i=19;until [[ -n ${INPUT} || $i = 0 ]];do [[ $i -eq 1 ]] && W= || W=s;printf 1>&2 "\r\e[2G\e[1mHit ENTER or wait \e[1;33m${i} \e[0m\e[1msecond${W} to clear OSSA data from the screen\e[0m\e[K";read -s -t 1 -N 1 INPUT;let i=$i-1;printf "\e[K\r\e[K";done; }
[[ ${OSSA_DEBUG} = true ]] || { tput sgr0; tput cnorm; tput rmcup; }

# Show elapsed time
printf "\n\e[2G\e[1mOpen Source Security Assessment completed in ${OSSA_TIME}\e[0m\n\n"

# Show Package Breakdown
if [[ ${OSSA_MADISON} = true ]];then
	declare -ag COMPONENTS=(main universe multiverse restricted)
	declare -ag POCKETS=(${OSSA_RELEASE} ${OSSA_RELEASE}-updates ${OSSA_RELEASE}-security ${OSSA_RELEASE}-backports ${OSSA_RELEASE}-proposed)
	for x in ${COMPONENTS[@]};do declare -ag ${x^^}=\(\);eval ${x^^}+=\( $(grep "/${x}" ${MFST_DIR}/madison.out.${OSSA_SUFFX}|wc -l) \);for y in ${POCKETS[@]};do eval ${x^^}+=\( ${y}:$(grep "${y}/${x}" ${MFST_DIR}/madison.out.${OSSA_SUFFX}|wc -l) \);done;done
	export COMPONENT_TOTAL=$((${MAIN[0]##*:}+${UNIVERSE[0]##*:}+${MULTIVERSE[0]##*:}+${RESTRICTED[0]##*:}))
	export RELEASE_TOTAL=$((${MAIN[1]##*:}+${UNIVERSE[1]##*:}+${MULTIVERSE[1]##*:}+${RESTRICTED[1]##*:}))
	export UPDATES_TOTAL=$((${MAIN[2]##*:}+${UNIVERSE[2]##*:}+${MULTIVERSE[2]##*:}+${RESTRICTED[2]##*:}))
	export SECURITY_TOTAL=$((${MAIN[3]##*:}+${UNIVERSE[3]##*:}+${MULTIVERSE[3]##*:}+${RESTRICTED[3]##*:}))
	export BACKPORTS_TOTAL=$((${MAIN[4]##*:}+${UNIVERSE[4]##*:}+${MULTIVERSE[4]##*:}+${RESTRICTED[4]##*:}))
	export PROPOSED_TOTAL=$((${MAIN[5]##*:}+${UNIVERSE[5]##*:}+${MULTIVERSE[5]##*:}+${RESTRICTED[5]##*:}))	
	((for ((i=0; i<${#POCKETS[@]}; i++)); do printf '%s\n' ${POCKETS[i]};done|paste -sd"|"|sed 's/^/Ubuntu '${OSSA_RELEASE^}'|'${OSSA_HOST}'|/g'
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[0]} ${MAIN[0]##*:} ${MAIN[1]##*:} ${MAIN[2]##*:} ${MAIN[3]##*:} ${MAIN[4]##*:} ${MAIN[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[1]} ${UNIVERSE[0]##*:} ${UNIVERSE[1]##*:} ${UNIVERSE[2]##*:} ${UNIVERSE[3]##*:} ${UNIVERSE[4]##*:} ${UNIVERSE[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[2]} ${MULTIVERSE[0]##*:} ${MULTIVERSE[1]##*:} ${MULTIVERSE[2]##*:} ${MULTIVERSE[3]##*:} ${MULTIVERSE[4]##*:} ${MULTIVERSE[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' ${COMPONENTS[3]} ${RESTRICTED[0]##*:} ${RESTRICTED[1]##*:} ${RESTRICTED[2]##*:} ${RESTRICTED[3]##*:} ${RESTRICTED[4]##*:} ${RESTRICTED[5]##*:}
	printf '%s|%s|%s|%s|%s|%s|%s\n' Totals ${COMPONENT_TOTAL} ${RELEASE_TOTAL} ${UPDATES_TOTAL} ${SECURITY_TOTAL} ${BACKPORTS_TOTAL} ${PROPOSED_TOTAL}
	)|column -nexts"|"| \
	sed -re '1s/Ubuntu '${OSSA_RELEASE^}'/'$(printf "\e[1;48;2;233;84;32m\e[1;38;2;255;255;255m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_RELEASE}'/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_HOST}'/'$(printf "\e[1;48;2;255;255;255m\e[1;38;2;233;84;32m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_RELEASE}'-updates/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_RELEASE}'-security/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/' \
		-re '1s/'${OSSA_RELEASE}'-backports/'$(printf "\e[38;2;255;200;0m")'&'$(printf "\e[0m")'/g' \
		-re '1s/'${OSSA_RELEASE}'-proposed/'$(printf "\e[38;2;255;0;0m")'&'$(printf "\e[0m")'/g' \
		-re 's/main|universe/'$(printf "\e[38;2;0;255;0m")'&'$(printf "\e[0m")'/g' \
		-re 's/multiverse.*$|restricted.*$/'$(printf "\e[38;2;255;0;0m")'&'$(printf "\e[0m")'/g')|sed 's/^.*$/ &/g'
fi
echo
#show security status
[[ -n ${SEC_STATUS} ]] && { echo "${SEC_STATUS}"; }
[[ -s ${UTIL_DIR}/ubuntu-security-status.standard.${OSSA_SUFFX} ]] && { cat ${UTIL_DIR}/ubuntu-security-status.standard.${OSSA_SUFFX} |grep -E '^En|so far|^$|Advan'|sed 's/^.*$/ &/g'; }

#show cve stats
echo
[[ -n ${CVE_STATUS} ]] && { echo "${CVE_STATUS}"|sed 's/^.*$/ &/g'; }
echo

# Show tarball location
[[ -n ${OSSA_PW} ]] && { printf "\n\e[2GEncrypted data collected during the Open Source Security Assessment is located at\n\e[2G${TARBALL}\e[0m\n\n"; } || { printf "\e[2GData collected during the Open Source Security Assessment is located at\n\e[2G${TARBALL}\e[0m\n\n"; }

[[ ${OSSA_DEBUG} = true ]] && { set +x; }