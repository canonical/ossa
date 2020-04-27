#!/bin/bash
set -e
[[ -z ${1} || ${1} =~ '-h' ]] && { printf "Usage: ./${0##*/} user@host\n";exit 2; } || { export SSH_HOST="${1}"; }
trap 'tput cnorm;trap - INT TERM EXIT KILL QUIT;exit 0' INT TERM EXIT KILL QUIT;
tput civis
PROG=${0##*/}
echo -e "\nRunning ${PROG//.sh/}. Please wait..."
# Start Timer
TZ=UTC export NOW=$(date +%s)sec
ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o CheckHostIP=no ${SSH_HOST} bash -c '\
declare -ag FILES
# Cleanup remote computer when complete
#trap '"'"'(cd /tmp && rm -f ${FILES[@]//\/tmp\/});trap - INT TERM EXIT QUIT KILL;exit 0'"'"' INT TERM EXIT QUIT KILL;
export SFX=$(hostname -s)
# Get apt and dpkg file locations from apt-config
export SOURCES_LIST=$(apt-config dump|awk '"'"'/^Dir[ ]|^Dir::Etc[ ]|^Dir::Etc::sourcel/{gsub(/"|;$/,"");print "/"$2}'"'"'|sed -r '"'"':a;N;$! ba;s/\/\/|\n//g'"'"')
export SOURCES_LIST_D=$(apt-config dump|awk '"'"'/^Dir[ ]|^Dir::Etc[ ]|^Dir::Etc::sourcep/{gsub(/"|;$/,"");print "/"$2}'"'"'|sed -r '"'"':a;N;$! ba;s/\/\/|\n//g'"'"')
export DPKG_STATUS=$(apt-config dump|awk '"'"'/^Dir::State::status[ ]/{gsub(/"|;$/,"");print $2}'"'"')
export APT_LISTS_DIR=$(apt-config dump|awk '"'"'/^Dir[ ]|^Dir::State[ ]|^Dir::State::lists[ ]/{gsub(/"|;$/,"");print "/"$2}'"'"'|sed -r '"'"':a;N;$! ba;s/\/\/|\n//g'"'"')

# Get Source, Source Parts, Dpkg Status, Release, and Package files from apt
find 2>/dev/null ${SOURCES_LIST%/*} ${SOURCES_LIST_D} ${DPKG_STATUS%/*} ${APT_LISTS_DIR%*/} -type f -regextype "posix-extended" -iregex '"'"'.*(status$|\.list$|Release$|Packages$)'"'"'|\
	sort -uV|sed -r "/mirror.list|$(dirname ${DPKG_STATUS//\//\\\/})/info/d"|tar 2>/dev/null -cf /tmp/apt-files.${SFX}.tar --files-from -
[[ $? -eq 0 && -f /tmp/apt-files.${SFX}.tar ]] && FILES+=( "/tmp/apt-files.${SFX}.tar" )

# Check if netstat or ss is installed, then gather a dump
if (command -v netstat &>/dev/null);then NETSTAT=$(command -v netstat);elif (command -v ss &>/dev/null);then NETSTAT=$(command -v ss);else NETSTAT="";fi
[[ -n ${NETSTAT} ]] && { $NETSTAT 2>/dev/null -an > /tmp/netstat-an.${SFX};[[ $? -eq 0 && -f /tmp/netstat-an.${SFX} ]] && FILES+=( "/tmp/netstat-an.${SFX}" ); }

# Get a dump of dpkg -l
dpkg 2>/dev/null -l > /tmp/dpkg-l.${SFX};[[ $? -eq 0 && -f /tmp/dpkg-l.${SFX} ]] && FILES+=( "/tmp/dpkg-l.${SFX}" );

# Dump repos in use
apt-cache 2>/dev/null policy > /tmp/apt-policy.${SFX};[[ $? -eq 0 && -f /tmp/apt-policy.${SFX} ]] && FILES+=( "/tmp/apt-policy.${SFX}" );

# Dump list of snaps in use
[[ $(command -v snap) ]] && { snap 2>/dev/null list > /tmp/snap-list.${SFX};[[ $? -eq 0 && -f /tmp/snap-list.${SFX} ]] && FILES+=( "/tmp/snap-list.${SFX}" ); }
# Get two different ps listings
ps 2>/dev/null -auxwww > /tmp/ps-auxwww.${SFX};[[ $? -eq 0 && -f /tmp/ps-auxwww.${SFX} ]] && FILES+=( "/tmp/ps-auxwww.${SFX}" );
ps 2>/dev/null -eao pid,ppid,user,stat,etimes,cmd --sort=cmd > /tmp/ps-eao.${SFX};[[ $? -eq 0 && -f /tmp/ps-eao.${SFX} ]] && FILES+=( "/tmp/ps-eao.${SFX}" );

# Get a copy of ubuntu release information
[[ -f /etc/lsb-release ]] && { cp /etc/lsb-release /tmp/lsb-release.${SFX};[[ $? -eq 0 && -f /tmp/lsb-release.${SFX} ]] && FILES+=( "/tmp/lsb-release.${SFX}" ); }
[[ ! -f /etc/lsb-release && $(command -v lsb_release) ]] && { for i in ID RELEASE CODENAME DESCRIPTION;do echo "DISTRIB_${i}=\"$(lsb_release -s$(echo ${i,,}|cut -c1))\""; done|tee 1>/dev/null /tmp/lsb-release.${SFX};[[ $? -eq 0 && -f /tmp/lsb-release.${SFX} ]] && FILES+=( "/tmp/lsb-release.${SFX}" ); }

# Create tarball of files and store on local computer
tar -C /tmp -cf - "${FILES[@]//\/tmp\/}"'|gzip -c|tee 1>/dev/null /tmp/${PROG//.sh}.${SSH_HOST##*@}.tgz;
echo -e "\n${PROG//.sh} completed in $(TZ=UTC date --date now-${NOW} "+%H:%M:%S").\n";
echo -e "Data collected by ${PROG//.sh} is located at /tmp/${PROG//.sh}.${SSH_HOST##*@}.tgz.\n";