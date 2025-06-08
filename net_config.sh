# Dépendances
# Traceroute
which traceroute || sudo apt install traceroute
#!/bin/bash

TargetHost4=9.9.9.9
TargetHost6=2620:fe::fe

ResultFile=/tmp/Rapport-reseau_$(hostname)_$(date +%Y-%m-%d_%H:%M).log

while test $# -gt 0 ; do
    case "$1" in
        -p|--pause) 
            Pause="echo 'veuillez taper Entrée pour continuer.' ; Lecture";
            shift ;;
        -h|--help)
            ShowHelp;
            exit ;; 
        -t|--targethost) shift;
            TargetHost4=$1;
            if [[ "$TargetHost4" == "" ]] ; then
                ShowHelp
                exit 2
            fi ;
            shift ;;
        -6|--IPv6) 
            IPv6=true
            shift ;;
        --host6) shift;
            TargetHost6=$1;
            if [[ "$TargetHost6" == "" ]] ; then
                ShowHelp
                exit 2
            fi ;
            shift ;;
         *) ShowHelp;
            exit 2 ;;
    esac
done

function CommandListIPv4 {
    CommandList=(
        "date"
        "uname -a"
        "cat /etc/os-release"
        "ufw status"
        "cat /etc/sysctl.conf | grep -v '#' | grep "\S""
        "iptables --list --numeric --verbose"
        "ls /etc/netplan/*"
        "cat /etc/netplan/*"
        "cat /etc/sysconfig/network*/ifcfg-*"
        "cat /etc/network/interfaces"
        "cat /etc/resolv.conf"
        "cat /etc/hosts"
        "time nslookup $TargetHost4"
        "time nslookup quad9.net"
        "ip -4 neigh"
        "ip -4 address list"
        "ip -4 route show"
        "ip -4 neighbour show"
        "ss -4 --tcp --process --all --numeric"
        "ss -4 --udp --process --all --numeric"
        "ping -4 -c 5 $TargetHost4"
        "ping -c 5 localhost"
        "if which mtr > /dev/null ; then mtr -4 -n -r $TargetHost4 ; else traceroute -4 -M icmp $TargetHost4 ; fi"
    )
}

function CommandListIPv6 {
    CommandList=(
        "ip -6 neigh"
        "ip -6 address list"
        "ip -6 route show"
        "ip -6 neighbour show"
        "ss -6 --tcp --process --all --numeric"
        "ss -6 --udp --process --all --numeric"
        "ip6tables --list --numeric --verbose"
        "ping6 -c 5 localhost"
        "if which mtr > /dev/null ; then mtr -6 -n -r $TargetHost6 ; else traceroute -6 -M icmp $TargetHost6 ; fi"
        "time nslookup $TargetHost6"
        "ping6 -c 5 $TargetHost6"
    )
}

function CheckNetwork {
    if [[ $1 == "4" ]] ; then 
        CommandListIPv4
    elif [[ $1 == "6" ]] ; then 
        CommandListIPv6
    fi 
    for i in $(seq 0 $((${#CommandList[*]}-1))) ; do 
        TopLine=$(echo ${CommandList[$i]} | tr '[:print:]' '=')
        echo
        echo "========${TopLine}========"
        echo "======= ${CommandList[$i]} ======= "
        echo
        eval ${CommandList[$i]} 
        echo
        eval $Pause
    done
}

CheckNetwork 4 2>&1 | tee -a $ResultFile

if [[ ${IPv6} == "true" ]] || [[ ${TargetHost6} != "2a02:247a::42:34" ]] ; then
    CheckNetwork 6 2>&1 | tee -a $ResultFile
fi

echo "Les resultats de l'analyse se trouve ${ResultFile}"
