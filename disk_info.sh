#!/bin/bash

ResultFile=/tmp/Rapport-disque_$(hostname)_$(date +%Y-%m-%d_%H:%M).log

# Dependences
dpkg -l | grep -qw lsscsi || sudo apt install lsscsi
dpkg -l | grep -qw sg3-utils || sudo apt install sg3-utils
dpkg -l | grep -qw gddrescue || sudo apt install gddrescue
dpkg -l | grep -qw kpartx || sudo apt install kpartx
dpkg -l | grep -qw ddrescueview || sudo apt install ddrescueview


function Checkdisk {
# Infos générales
echo "df -TH ____________________________"
echo
sudo df -TH
echo
echo "lsblk -S ____________________________"
echo
sudo lsblk -S
sleep 3
echo
echo "lsscsi -g ____________________________"
echo
sudo lsscsi -g
echo
echo "sg_scan -i ____________________________"
echo
sudo sg_scan -i
echo
echo "dmesg__________________________________"
echo
sudo dmesg | grep -E "(mpt|scsi|sd)"
echo
#echo "syslog____________________________" 
#echo
#sudo grep -E "(mpt|scsi|sd)" --color=always /var/log/syslog
echo
echo "____________________________"
}
Checkdisk | tee -a $ResultFile

echo "Les resultats de l'analyse se trouve ${ResultFile}"
