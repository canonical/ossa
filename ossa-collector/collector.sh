#!/bin/bash
set -e
export SSH_OPTS="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o CheckHostIP=no"
[[ ${DEBUG} = true ]] && set -x
[[ ${DEBUG} = true ]] && export SSH_OPTS="-vvvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o CheckHostIP=no"
[[ -z ${1} || ${1} =~ '-h' ]] && { printf "Usage: ./${0##*/} user@host\n";exit 2; } || { export SSH_HOST="${1}"; }
trap 'tput cnorm;trap - INT TERM EXIT KILL QUIT;exit 0' INT TERM EXIT KILL QUIT;
tput civis
PROG=${0##*/}
declare -c TITLE="${PROG//.sh}"
echo -e "\nRunning OSSA ${TITLE} against ${SSH_HOST##*@}. Please wait..."
# Start Timer
TZ=UTC export NOW=$(date +%s)sec
ssh ${SSH_OPTS} ${SSH_HOST} bash -c '\
trap '"'"'(cd /tmp && rm -f "${FILES[@]//\/tmp\/}");trap - INT TERM EXIT QUIT KILL;exit 0'"'"' INT TERM EXIT QUIT KILL;
declare -ag FILES;
export SFX=$(hostname -s);
export SOURCES_LIST=$(apt-config dump|awk '"'"'/^Dir[ ]|^Dir::Etc[ ]|^Dir::Etc::sourcel/{gsub(/"|;$/,"");print "/"$2}'"'"'|sed -r '"'"':a;N;$! ba;s/\/\/|\n//g'"'"')
export SOURCES_LIST_D=$(apt-config dump|awk '"'"'/^Dir[ ]|^Dir::Etc[ ]|^Dir::Etc::sourcep/{gsub(/"|;$/,"");print "/"$2}'"'"'|sed -r '"'"':a;N;$! ba;s/\/\/|\n//g'"'"')
export DPKG_STATUS=$(apt-config dump|awk '"'"'/^Dir::State::status[ ]/{gsub(/"|;$/,"");print $2}'"'"')
export APT_LISTS_DIR=$(apt-config dump|awk '"'"'/^Dir[ ]|^Dir::State[ ]|^Dir::State::lists[ ]/{gsub(/"|;$/,"");print "/"$2}'"'"'|sed -r '"'"':a;N;$! ba;s/\/\/|\n//g'"'"')
find 2>/dev/null ${SOURCES_LIST%/*} ${SOURCES_LIST_D} ${DPKG_STATUS%/*} ${APT_LISTS_DIR%*/} /etc/hosts /etc/hostname -type f -regextype "posix-extended" -iregex '"'"'.*(hosts$|hostname$|status$|\.list$|Release$|Packages$)'"'"'|sort -uV|sed -r "/mirror.list|$(dirname ${DPKG_STATUS//\//\\\/})/info/d"|tar 2>/dev/null -cf /tmp/apt-files.${SFX}.tar --files-from -
[[ $? -eq 0 && -f /tmp/apt-files.${SFX}.tar ]] && FILES+=( "apt-files.${SFX}.tar" )
if (command -v netstat &>/dev/null);then NETSTAT=$(command -v netstat);elif (command -v ss &>/dev/null);then NETSTAT=$(command -v ss);else NETSTAT="";fi
[[ -n ${NETSTAT} ]] && { $NETSTAT 2>/dev/null -an > /tmp/netstat-an.${SFX};[[ $? -eq 0 && -f /tmp/netstat-an.${SFX} ]] && FILES+=( "netstat-an.${SFX}" ); }
dpkg 2>/dev/null -l > /tmp/dpkg-l.${SFX};[[ $? -eq 0 && -f /tmp/dpkg-l.${SFX} ]] && FILES+=( "dpkg-l.${SFX}" );
apt-cache 2>/dev/null policy > /tmp/apt-policy.${SFX};[[ $? -eq 0 && -f /tmp/apt-policy.${SFX} ]] && FILES+=( "apt-policy.${SFX}" );
[[ $(command -v snap) ]] && { snap 2>/dev/null list > /tmp/snap-list.${SFX};[[ $? -eq 0 && -f /tmp/snap-list.${SFX} ]] && FILES+=( "snap-list.${SFX}" ); }
ps 2>/dev/null -auxwww > /tmp/ps-auxwww.${SFX};[[ $? -eq 0 && -f /tmp/ps-auxwww.${SFX} ]] && FILES+=( "ps-auxwww.${SFX}" );
ps 2>/dev/null -eao pid,ppid,user,stat,etimes,cmd --sort=cmd > /tmp/ps-eao.${SFX};[[ $? -eq 0 && -f /tmp/ps-eao.${SFX} ]] && FILES+=( "ps-eao.${SFX}" );
[[ -f /etc/lsb-release ]] && { cp /etc/lsb-release /tmp/lsb-release.${SFX};[[ $? -eq 0 && -f /tmp/lsb-release.${SFX} ]] && FILES+=( "lsb-release.${SFX}" ); }
[[ ! -f /etc/lsb-release && $(command -v lsb_release) ]] && { for i in ID RELEASE CODENAME DESCRIPTION;do echo "DISTRIB_${i}=\"$(lsb_release -s$(echo ${i,,}|cut -c1))\""; done|tee 1>/dev/null /tmp/lsb-release.${SFX};[[ $? -eq 0 && -f /tmp/lsb-release.${SFX} ]] && FILES+=( "lsb-release.${SFX}" ); }
export FLIST=$(printf "%s\n" ${FILES[@]}|paste -sd " ")
tar -C /tmp -cf - ${FLIST}'|gzip -c|tee 1>/dev/null /tmp/ossa-${PROG//.sh}-data.${SSH_HOST##*@}.tgz;
echo -e "\nOSSA ${TITLE} for ${SSH_HOST##*@} completed in $(TZ=UTC date --date now-${NOW} "+%H:%M:%S").\n";
echo -e "Data collected by the OSSA ${TITLE} is located at \n/tmp/ossa-${PROG//.sh}-data.${SSH_HOST##*@}.tgz.\n";
[[ ${DEBUG} = true ]] && set +x
