# Si vous voulez partager le contenu installer pastebinit 
# sudo apt install pastebinit
# Commande pour export
# sudo rapportV1.2.sh | pastebinit
# partager le lien qui se trouvera a la dernière ligne de l'execution du script
# https://dspaste.com/xxxxxx

#wget https://raw.githubusercontent.com/ps81frt/debug_analyse/refs/heads/main/rapport_v1.2.sh
#sudo bash rapport_v1.2.sh > $(date +%Y-%m-%d_%H-%M)_Rapport.txt


#!/bin/bash

# bash./info.sh




programs=(pastebinit)
for program in "${programs[@]}"; do
    if ! command -v "$program" > /dev/null 2>&1; then
        sudo apt install "$program" -y
    fi
done
programs2=(iotop)
for programio in "${programs2[@]}"; do
    if ! command -v "$programio" > /dev/null 2>&1; then
        sudo apt install "$programio" -y
    fi
done
programs3=(sysstat)
for programiss in "${programs3[@]}"; do
    if ! command -v "$programiss" > /dev/null 2>&1; then
        sudo apt install "$programiss" -y
    fi
done
programs4=(procps)
for programproc in "${programs4[@]}"; do
    if ! command -v "$programproc" > /dev/null 2>&1; then
        sudo apt install "$programproc" -y
    fi
done
#
#_________________________________________________________
#

ResultFile=/tmp/Rapport-Global_$(hostname)_$(date +%Y-%m-%d_%H:%M).log
function genRapport () {


if [[ $# -ne 0 ]]; then
	echo "Usage: $0" >&2
	exit 1
fi

# Check if on Linux
if ! echo "$OSTYPE" | grep -iq '^linux'; then
	echo "Error: This script must be run on Linux." >&2
	exit 1
fi

# toiec <KiB>
toiec() {
	echo "$(printf "%'d" $(($1 >> 10))) MiB$([[ $1 -ge 1048576 ]] && echo " ($(numfmt --from=iec --to=iec-i "${1}K")B)")"
}

# tosi <KiB>
#tosi() {
#	echo "$(printf "%'d" $(((($1 << 10) / 1000) / 1000))) MB$([[ $1 -ge 1000000 ]] && echo " ($(numfmt --from=iec --to=si "${1}K")B)")"
#}



. /etc/os-release


echo -e "\nLinux Distribution:\t\t${PRETTY_NAME:-$ID-$VERSION_ID}"

KERNEL=$(</proc/sys/kernel/osrelease) # uname -r
echo -e "Linux Kernel:\t\t\t$KERNEL"

file=/sys/class/dmi/id # /sys/devices/virtual/dmi/id
if [[ -d $file ]]; then
	if [[ -r "$file/sys_vendor" ]]; then
		MODEL=$(<"$file/sys_vendor")
	elif [[ -r "$file/board_vendor" ]]; then
		MODEL=$(<"$file/board_vendor")
	elif [[ -r "$file/chassis_vendor" ]]; then
		MODEL=$(<"$file/chassis_vendor")
	fi
	if [[ -r "$file/product_name" ]]; then
		MODEL+=" $(<"$file/product_name")"
	fi
	if [[ -r "$file/product_version" ]]; then
		MODEL+=" $(<"$file/product_version")"
	fi
elif [[ -r /sys/firmware/devicetree/base/model ]]; then
	read -r -d '' MODEL </sys/firmware/devicetree/base/model
fi
if [[ -n $MODEL ]]; then
	echo -e "Computer Model:\t\t\t$MODEL"
fi

mapfile -t CPU < <(sed -n 's/^model name[[:blank:]]*: *//p' /proc/cpuinfo | uniq)
if [[ -z $CPU ]]; then
	mapfile -t CPU < <(lscpu | grep -i '^model name' | sed -n 's/^.\+:[[:blank:]]*//p' | uniq)
fi
if [[ -n $CPU ]]; then
	echo -e "Processor (CPU):\t\t${CPU[0]}$([[ ${#CPU[*]} -gt 1 ]] && printf '\n\t\t\t\t%s' "${CPU[@]:1}")"
fi

CPU_THREADS=$(nproc --all) # getconf _NPROCESSORS_CONF # $(lscpu | grep -i '^cpu(s)' | sed -n 's/^.\+:[[:blank:]]*//p')
declare -A lists
for file in /sys/devices/system/cpu/cpu[0-9]*/topology/core_cpus_list; do
	if [[ -r $file ]]; then
		lists[$(<"$file")]=1
	fi
done
if ! ((${#lists[*]})); then
	for file in /sys/devices/system/cpu/cpu[0-9]*/topology/thread_siblings_list; do
		if [[ -r $file ]]; then
			lists[$(<"$file")]=1
		fi
	done
fi
CPU_CORES=${#lists[*]}
# CPU_CORES=$(lscpu -ap | grep -v '^#' | cut -d, -f2 | sort -nu | wc -l)
lists=()
for file in /sys/devices/system/cpu/cpu[0-9]*/topology/package_cpus_list; do
	if [[ -r $file ]]; then
		lists[$(<"$file")]=1
	fi
done
if ! ((${#lists[*]})); then
	for file in /sys/devices/system/cpu/cpu[0-9]*/topology/core_siblings_list; do
		if [[ -r $file ]]; then
			lists[$(<"$file")]=1
		fi
	done
fi
CPU_SOCKETS=${#lists[*]}
# CPU_SOCKETS=$(lscpu -ap | grep -v '^#' | cut -d, -f3 | sort -nu | wc -l) # $(lscpu | grep -i '^\(socket\|cluster\)(s)' | sed -n 's/^.\+:[[:blank:]]*//p' | tail -n 1)
echo -e "CPU Sockets/Cores/Threads:\t$CPU_SOCKETS/$CPU_CORES/$CPU_THREADS"

CPU_CACHES=()
declare -A CPU_NUM_CACHES CPU_CACHE_SIZES CPU_TOTAL_CACHE_SIZES
# CPU_L1I_CACHE_SIZE=$(getconf LEVEL1_ICACHE_SIZE)
# CPU_L1D_CACHE_SIZE=$(getconf LEVEL1_DCACHE_SIZE)
# CPU_L2_CACHE_SIZE=$(getconf LEVEL2_CACHE_SIZE)
# CPU_L3_CACHE_SIZE=$(getconf LEVEL3_CACHE_SIZE)
# CPU_ResultFile=/tmp/Rapport-disque_$(hostname)_$(date +%Y-%m-%d_%H:%M).log
#()
for dir in /sys/devices/system/cpu/cpu[0-9]*/cache; do
	if [[ -d $dir ]]; then
		for file in "$dir"/index[0-9]*/size; do
			if [[ -r $file ]]; then
				size=$(numfmt --from=iec <"$file")
				file=${file%/*}
				level=$(<"$file/level")
				type=$(<"$file/type")
				if [[ $type == Data ]]; then
					type=d
				elif [[ $type == Instruction ]]; then
					type=i
				else
					type=''
				fi
				name="L$level$type"
				key="$(<"$file/shared_cpu_list") $name"
				if [[ -z ${lists[$key]} ]]; then
					if [[ -z ${CPU_TOTAL_CACHE_SIZES[$name]} ]]; then
						CPU_CACHES+=("$name")
					fi
					((++CPU_NUM_CACHES[$name]))
					CPU_CACHE_SIZES[$name]=$size
					((CPU_TOTAL_CACHE_SIZES[$name] += size))
					lists[$key]=1
				fi
			fi
		done
	fi
done
if ((${#CPU_CACHES[*]})); then
	echo -e -n "CPU Caches:\t\t\t"
	for i in "${!CPU_CACHES[@]}"; do
		cache=${CPU_CACHES[i]}
		((i)) && printf '\t\t\t\t'
		echo "$cache: $(printf "%'d" $((CPU_CACHE_SIZES[$cache] >> 10))) KiB × ${CPU_NUM_CACHES[$cache]} ($(numfmt --to=iec-i "${CPU_TOTAL_CACHE_SIZES[$cache]}")B)"
	done
fi

ARCHITECTURE=$(getconf LONG_BIT)
echo -e "Architecture:\t\t\t$HOSTTYPE (${ARCHITECTURE}-bit)" # arch, uname -m

MEMINFO=$(</proc/meminfo)
TOTAL_PHYSICAL_MEM=$(echo "$MEMINFO" | awk '/^MemTotal:/ { print $2 }') # (( $(getconf PAGE_SIZE) * $(getconf _PHYS_PAGES) ))
echo -e "Total memory (RAM):\t\t$(toiec "$TOTAL_PHYSICAL_MEM") ($(tosi "$TOTAL_PHYSICAL_MEM"))"

TOTAL_SWAP=$(echo "$MEMINFO" | awk '/^SwapTotal:/ { print $2 }')
echo -e "Total swap space:\t\t$(toiec "$TOTAL_SWAP") ($(tosi "$TOTAL_SWAP"))"

DISKS=$(lsblk -dbn 2>/dev/null | awk '$6=="disk"')
if [[ -n $DISKS ]]; then
	DISK_NAMES=($(echo "$DISKS" | awk '{ print $1 }'))
	DISK_SIZES=($(echo "$DISKS" | awk '{ print $4 }'))
	echo -e -n "Disk space:\t\t\t"
	for i in "${!DISK_NAMES[@]}"; do
		((i)) && printf '\t\t\t\t'
		echo -e "${DISK_NAMES[i]}: $(printf "%'d" $((DISK_SIZES[i] >> 20))) MiB$([[ ${DISK_SIZES[i]} -ge 1073741824 ]] && echo " ($(numfmt --to=iec-i "${DISK_SIZES[i]}")B)") ($(printf "%'d" $(((DISK_SIZES[i] / 1000) / 1000))) MB$([[ ${DISK_SIZES[i]} -ge 1000000000 ]] && echo " ($(numfmt --to=si "${DISK_SIZES[i]}")B)"))"
	done
fi

for lspci in lspci /sbin/lspci; do
	if command -v $lspci >/dev/null; then
		mapfile -t GPU < <($lspci 2>/dev/null | grep -i 'vga\|3d\|2d' | sed -n 's/^.*: //p')
		break
	fi
done
if [[ -n $GPU ]]; then
	echo -e "Graphics Processor (GPU):\t${GPU[0]}$([[ ${#GPU[*]} -gt 1 ]] && printf '\n\t\t\t\t%s' "${GPU[@]:1}")"
fi

echo -en "Subsystem:"&& printf "%22s" && lspci -k | grep -EA2 'VGA|3D|2D|Display' | sed -n '2s/^.*: //p'
echo -en "Kernel driver:"&& printf "%18s" && lspci -k | grep -EA2 'VGA|3D|2D|Display' | sed -n '3s/^.*: //p'
echo -en "Kernel modules:"&& printf "%17s" && lspci -k | grep -EA2 'VGA|3D|2D|Display' | sed -n '4s/^.*: //p'

#echo -en "Computer name:\t\t\t$HOSTNAME" # uname -n # hostname # /proc/sys/kernel/hostname

if command -v iwgetid >/dev/null; then
	NETWORKNAME=$(iwgetid -r || true)
fi
if [[ -n $NETWORKNAME ]]; then
	echo -e "Network name (SSID):\t\t$NETWORKNAME"
fi

HOSTNAME_FQDN=$(hostname -f) # hostname -A
echo -e "Hostname:\t\t\t$HOSTNAME_FQDN"

mapfile -t IPv4_ADDRESS < <(ip -o -4 a show up scope global | awk '{ print $2,$4 }')
if [[ -n $IPv4_ADDRESS ]]; then
	IPv4_INERFACES=($(printf '%s\n' "${IPv4_ADDRESS[@]}" | awk '{ print $1 }'))
	IPv4_ADDRESS=($(printf '%s\n' "${IPv4_ADDRESS[@]}" | awk '{ print $2 }'))
	echo -e -n "IPv4 address$([[ ${#IPv4_ADDRESS[*]} -gt 1 ]] && echo "es"):\t\t\t"
	for i in "${!IPv4_INERFACES[@]}"; do
		((i)) && printf '\t\t\t\t'
		echo -e "${IPv4_INERFACES[i]}: ${IPv4_ADDRESS[i]%/*}"
	done
fi
mapfile -t IPv6_ADDRESS < <(ip -o -6 a show up scope global | awk '{ print $2,$4 }')
if [[ -n $IPv6_ADDRESS ]]; then
	IPv6_INERFACES=($(printf '%s\n' "${IPv6_ADDRESS[@]}" | awk '{ print $1 }'))
	IPv6_ADDRESS=($(printf '%s\n' "${IPv6_ADDRESS[@]}" | awk '{ print $2 }'))
	echo -e -n "IPv6 address$([[ ${#IPv6_ADDRESS[*]} -gt 1 ]] && echo "es"):\t\t\t"
	for i in "${!IPv6_INERFACES[@]}"; do
		((i)) && printf '\t\t\t\t'
		echo -e "${IPv6_INERFACES[i]}: ${IPv6_ADDRESS[i]%/*}"
	done
fi

# ip -o l show up | grep -v 'loopback' | awk '{ print $2,$(NF-2) }'
INERFACES=($(ip -o a show up primary scope global | awk '{ print $2 }' | uniq))
NET_INERFACES=()
NET_ADDRESSES=()
for inerface in "${INERFACES[@]}"; do
	file="/sys/class/net/$inerface"
	if [[ -r "$file/address" ]]; then
		NET_INERFACES+=("$inerface")
		NET_ADDRESSES+=("$(<"$file/address")")
	fi
done

<<comment
if [[ -n $NET_INERFACES ]]; then
	echo -e -n "MAC address$([[ ${#NET_INERFACES[*]} -gt 1 ]] && echo "es"):\t\t\t"
	for i in "${!NET_INERFACES[@]}"; do
		((i)) && printf '\t\t\t\t'
		echo -e "${NET_INERFACES[i]}: ${NET_ADDRESSES[i]}"
	done
fi
comment
# echo -en "MacAddress :                    " ; cat /sys/class/net/ens33/address
#if [[ -r /var/lib/dbus/machine-id ]]; then
#	COMPUTER_ID=$(</var/lib/dbus/machine-id)
#	echo -e "Computer ID:\t\t\t$COMPUTER_ID"
#fi

TIME_ZONE=$(timedatectl 2>/dev/null | grep -i 'time zone:\|timezone:' | sed -n 's/^.*: //p') # timedatectl show --value -p Timezone
if [[ -z $TIME_ZONE ]]; then
	if [[ -r /etc/timezone ]]; then
		TIME_ZONE=$(</etc/timezone)
	elif [[ -L /etc/localtime ]]; then
		TIME_ZONE=$(realpath --relative-to /usr/share/zoneinfo /etc/localtime)
	fi
	TIME_ZONE+=" ($(date '+%Z, %z'))"
fi
echo -e "Time zone:\t\t\t$TIME_ZONE"

echo -e "Language:\t\t\t$LANG"

if command -v systemd-detect-virt >/dev/null && CONTAINER=$(systemd-detect-virt -c); then
	echo -e "Virtualization container:\t$CONTAINER"
fi

if command -v systemd-detect-virt >/dev/null && VM=$(systemd-detect-virt -v); then
	echo -e "Virtual Machine (VM) hypervisor:$VM"
fi

echo -e "Bash Version:\t\t\t$BASH_VERSION"

if [[ -c /dev/tty ]]; then
	stty raw min 0 time 10 </dev/tty
	read -p $'\x05' -rs -t 1 TERMINAL </dev/tty || true
	stty cooked </dev/tty
fi
echo -e "\rTerminal:\t\t\t$TERM${TERMINAL:+ ($TERMINAL)}"

echo

##############################################################

echo "✔️===== CPU USAGE (top 10 processes) ====="
echo ""
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 11

echo -e "\n===== CPU CORE STATS ====="
if command -v mpstat &>/dev/null; then
    mpstat -P ALL 1 1
else
    echo "⚠️ mpstat not installed. Install with: sudo apt install sysstat"
fi

echo -e "\n===== LOAD AVERAGE ====="
uptime
echo ""
##############################################################
echo "✔️===== DISK USAGE ====="
echo ""
df -h | grep -v tmpfs

echo -e "\n✔️===== TOP 10 LARGEST FILES IN ROOT (/) ====="
sudo du -ahx / | sort -rh | head -n 10

echo -e "\n✔️===== INODE USAGE ====="
df -i
##############################################################
echo ""
echo "✔️===== DISK I/O USING IOSTAT ====="
echo ""
if command -v iostat &>/dev/null; then
    iostat -xz 1 3
else
    echo "⚠️ iostat not installed. Install with: sudo apt install sysstat"
fi

echo ""
echo -e "\n✔️===== DISK I/O USING IOTOP (Live Top) ====="
echo ""
if command -v iotop &>/dev/null; then
    echo "Showing top 10 I/O processes for 5 seconds..."
    sudo iotop -b -n 5 -d 1 | head -n 30
else
    echo "⚠️ iotop not installed. Install with: sudo apt install iotop"
fi

echo ""
echo -e "\n✔️===== IO SNAPSHOT WITH VMSTAT ====="
echo ""
if command -v vmstat &>/dev/null; then
    vmstat 1 3
else
    echo "⚠️ vmstat not installed. Install with: sudo apt install procps"
fi
##############################################################
echo ""
echo "✔️===== MEMORY USAGE ====="
echo ""
free -h
echo ""
echo -e "\n✔️===== TOP MEMORY CONSUMING PROCESSES ====="
echo ""
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 11
echo ""
echo -e "\n✔️===== VMSTAT SNAPSHOT ====="
echo ""
if command -v vmstat &>/dev/null; then
    vmstat 1 3
else
    echo "⚠️ vmstat not installed. Install with: sudo apt install procps"
fi
##############################################################

echo ""
echo "✔️===== NETWORK INTERFACES (ip addr) ====="
echo ""
ip addr show

echo ""
echo -e "\n✔️===== ROUTING TABLE (ip route) ====="
echo ""
ip route show

echo ""
echo -e "\n✔️===== DNS RESOLUTION TEST (resolv.conf + ping) ====="
echo ""
echo "Configured DNS servers:"
cat /etc/resolv.conf | grep nameserver

echo -e "\nTesting DNS resolution..."
ping -c 2 google.com &>/dev/null && echo "✅ DNS resolution OK" || echo "❌ DNS resolution FAILED"

echo ""
echo -e "\n✔️===== ACTIVE LISTENING PORTS (ss -tuln) ====="
echo ""
ss -tuln

echo ""
echo -e "\n✔️===== ESTABLISHED CONNECTIONS ====="
echo ""
ss -tun state established

echo ""
echo -e "\n✔️===== INTERFACE STATS (ip -s link) ====="
echo ""
ip -s link
##############################################################
echo ""
echo "✔️===== SYSTEMD FAILED SERVICES ====="
echo ""
sudo systemctl --failed

echo ""
echo -e "\n✔️===== INACTIVE BUT NOT DISABLED SERVICES ====="
echo ""
sudo systemctl list-units --type=service --state=inactive | grep -v "disabled" || echo "✅ All inactive services are disabled."

echo ""
echo -e "\n✔️===== ENABLED SERVICES SET TO START ON BOOT ====="
echo ""
sudo systemctl list-unit-files --type=service | grep enabled

echo ""
echo -e "\n✔️===== TOP 10 LONGEST RUNNING SERVICES ====="
echo ""
systemctl list-units --type=service --no-pager --no-legend | awk '{print $1}' | \
xargs -n1 -I{} systemctl show -p Id,ActiveEnterTimestampMonotonic {} 2>/dev/null | \
grep -E 'Id=|ActiveEnterTimestampMonotonic=' | \
paste - - | \
sort -k2 -nr | head -n 10 | cut -d= -f2

##############################################################

echo ""
echo -e "\n ✔️===== Liste paquets endommager ==="
echo ""
dpkg -l | grep -v ^ii;
echo ""
echo -e "\n ✔️===== Liste Kernel ==============="
echo; dpkg -l | awk '!/^rc/ && / linux-(c|g|h|i|lo|m|si|t)/{print $1,$2,$3,$4 | "sort -k3V | column -t"}' ; echo -e "\nNoyau courant : $(uname -mr)"
echo ""
echo -e "\n✔️=======    GRUB      =========="
echo ""
sed '/#/d' /etc/default/grub | tr -s '\n'
echo ""
echo -e "\n ✔️===== Liste Disk ================="
echo ""
df -Thx tmpfs ;
echo ""
echo -e "\n ✔️===== Dossier Crash =============="
echo ""
ls /var/crash/;
echo ""
echo -e "\n✔️===== SYSTEM BOOT LOGS (LAST 3 BOOTS) ====="
echo ""
sudo journalctl --list-boots | head -n 6
echo ""
echo -e "\n✔️======= Rapport  FULL       ======="
echo ""
sudo journalctl -p0 -p1 -p2 -p3 ;
echo ""
echo -e "\n✔️======= Rapport BOOT    =========="
echo ""
sudo journalctl -b -p0 -p1 -p2 -p3 ; 
echo ""
echo -e "\n✔️======= Rapport KERNEL   =========="
echo ""
sudo dmesg --level=err,warn -T -f kern,syslog,daemon
#echo ""
#echo "\n✔️=========Rapport du 10 eme demarrage precedent =========="
#echo ""
#apport-unpack /var/crash/_usr_bin_firefox.1000.crash /tmp/crash-report;
#apport-retrace --stdout /var/crash/_usr_bin_nautilus.1000.crash
echo ""
#echo -e "\n✔️======= CONTENU VAR/CRASH   =========="
#ls /var/crash

uptime

}
genRapport | tee -a $ResultFile

echo "Les resultats de l'analyse se trouve ${ResultFile}"
