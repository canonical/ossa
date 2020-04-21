#!/bin/bash
set -e
[[ -z ${1} || ${1} =~ '-h' ]] && { printf "Usage: ${0##*/} user@host\n";exit 2; } || { SSH_HOST="${1}"; }
trap 'tput cnorm;trap - INT TERM EXIT KILL QUIT;exit 0' INT TERM EXIT KILL QUIT;
tput civis
PROG=${0##*/}
echo -e "\nRunning ${PROG//.sh/}. Please wait..."
ssh -o UserKnownHostsFile=/tmp/foo -o StrictHostKeyChecking=no -o CheckHostIP=no ${SSH_HOST} bash -c '\
trap '"'"'(cd /tmp && rm -f ${FILES});trap - INT TERM EXIT QUIT KILL;exit 0'"'"' INT TERM EXIT QUIT KILL;
find 2>/dev/null /etc/apt -type f -iname "*.list"|tar 2>/dev/null -cf /tmp/apt-sources.$$.tar --files-from -
find 2>/dev/null /var/lib/apt/lists -maxdepth 1 -regextype "posix-extended" -iregex '"'"'.*(Release$|Packages$)'"'"'|tar 2>/dev/null -cf /tmp/apt-lists.$$.tar --files-from -
if (command -v netstat &>/dev/null);then NETSTAT=$(command -v ss);elif (command -v ss &>/dev/null);then NETSTAT=$(command -v ss);else NETSTAT="";fi
[[ -n ${NETSTAT} ]] && { $NETSTAT 2>/dev/null -an > /tmp/netstat-an.$$; } || { echo "Neither \"netstat\" or \"ss\" are installed" > /tmp/netstat-an.$$; }
dpkg 2>/dev/null -l > /tmp/dpkg-l.$$;
apt-cache 2>/dev/null policy > /tmp/apt-policy.$$;
[[ $(command -v snap) ]] && { snap 2>/dev/null list > /tmp/snap-list.$$; } || { echo "snapd not installed" > /tmp/snap-list.$$; }
ps 2>/dev/null -auxwww > /tmp/ps-auxwww.$$;
[[ -f /var/lib/dpkg/status ]] && { DPKG_STATUS_TMP=/tmp/dpkg-status.$$;cp /var/lib/dpkg/status ${DPKG_STATUS_TMP}; } || { DPKG_STATUS_TMP=; }
[[ -f /etc/lsb-release ]] && { LSB_RELEASE_TMP=/tmp/lsb-release.$$;cp /etc/lsb-release ${LSB_RELEASE_TMP}; } || { [[ $(command -v lsb_release) ]] && { for i in ID RELEASE CODENAME DESCRIPTION;do echo "DISTRIB_${i}=\"$(lsb_release -s$(echo ${i,,}|cut -c1))\""; done|tee 1>/dev/null ${LSB_RELEASE_TMP}; } || { LSB_RELEASE_TMP=; }; }
FILES="${DPKG_STATUS_TMP##*/} ${LSB_RELEASE_TMP##*/} netstat-an.$$ dpkg-l.$$ snap-list.$$ apt-policy.$$ ps-auxwww.$$ apt-lists.$$.tar apt-sources.$$.tar"
tar -C /tmp -cf - ${FILES}'|gzip -c|tee 1>/dev/null /tmp/ossa-lite.tgz
echo -e "\nOpen Source Security Assessment Lite has completed.\n"
echo -e "Please send /tmp/ossa-lite.tgz to your Canonical representative.\n"