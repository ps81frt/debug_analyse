#  Mise à jours Firmware
#programs=(fwupd)
#
#for program in "${programs[@]}"; do
#    if ! command -v "$program" > /dev/null 2>&1; then
#        sudo apt install "$program" -y
#    fi
#done
# fwupdmgr  get-devices
# fwupdmgr  refresh --force
# fwupdmgr  get-updates | less

###########################
# Auto-Signature Noyaux dkms
# Prerequis
# sudo apt install dkms mokutil openssl
# Controle activation
# mokutil --sb-state
# Creation dossier contenant le signature
# mkdir -p /var/lib/shim-signed/mok
# cd /var/lib/shim-signed/mok
# openssl req -nodes -new -x509 -newkey rsa:2048 -keyout mok.priv -outform DER -out mok.der -days 36500 -subj "/CN=$(hostname)/"
# mokutil --import /var/lib/shim-signed/mok/mok.der
# Retenir le mot de passe
# reboot
# nano /etc/dkms/framework.conf
# modifier en
# mok_signing_key=/var/lib/shim-signed/mok/mok.priv
# mok_certificate=/var/lib/shim-signed/mok/mok.der

# dkms status

# supprimer et reinstaller le module afin qu'il soit signé
# dkms remove xxxx
# dkms install xxxx
# modprobe -v xxxx
# update-initramfs -u

# MODULES.
# cat /lib/modules/$(uname -r)/modules.builtin
# lsmod
# modinfo parport
# modinfo -n parport
#
#
#
#

ResultFile=/tmp/Rapport-GRUB_$(hostname)_$(date +%Y-%m-%d_%H:%M).log

function genReportGRUB () {

uname -a

echo 
date
echo
echo "=================DMIDECODE======================"
echo
dmidecode --string='bios-vendor'
dmidecode --string='bios-version'
dmidecode --string='system-manufacturer'
dmidecode --string='system-product-name'
dmidecode --string='system-version'
dmidecode --string='baseboard-manufacturer'
dmidecode --string='baseboard-product-name'
echo
echo "====================BLKID=========================="
echo
echo "========>>>> FULL DEV"
blkid -o list
echo
echo "========>>>  /dev/sda"
echo
echo "-------------------------------------------------------------"
blkid /dev/sd* full
echo "-------------------------------------------------------------"
echo
echo "====================LSBLK======================"
echo
lsblk -fe7
echo
lsblk -S
echo
echo "===================FICHIER BOOT======================"
echo
sudo mkdir /mnt/InfoBoot
truc=$(sudo blkid | grep vfat | cut -d " " -f2 | awk -F '"' '{print $2}')
sudo mount -U ${truc} /mnt/InfoBoot
ls -R /mnt/InfoBoot
sleep 3
sudo umount /mnt/InfoBoot
sleep 2
sudo rm -rf /mnt/InfoBoot/
sleep 2
echo
echo "==================== GRUB ENTRY================"
echo
awk -F\' '/menuentry / {print $2}' /boot/grub/grub.cfg | cat -n
echo
cat /etc/grub2.cfg
echo
echo "====================== GRUB.cfg ========================"
echo
cat /boot/grub/grub.cfg
echo
echo "======================GRUB 40_CUSTOM========================"
echo
cat /etc/grub.d/40_custom

echo "======================KERNEL-DEB========================"
echo
dpkg --list | grep linux-image | awk '{print $2}'
echo
echo "======================KERNEL-ARCH========================"
echo
pacman -Q | grep linux  
echo
echo "======================FSTAB========================"
echo
cat /etc/fstab | sed '1,6d'
echo
echo "=============================================="
echo
findmnt -t ext4,xfs,btrfs,f2fs,vfat,ntfs,hfsplus,iso9660,udf,nfs,cifs,zfs
echo
echo "=============================================="
echo
findmnt --fstab
echo
echo "==============================================="
echo "/proc/cmdline "
cat /proc/cmdline
echo
echo "================type de demarrage =============="
[ -d /sys/firmware/efi ] && echo "UEFI Boot Detected" || echo "Legacy BIOS Boot Detected"
echo
uptime

}

genReportGRUB | tee -a $ResultFile

echo "Les resultats de l'analyse se trouve ${ResultFile}"
