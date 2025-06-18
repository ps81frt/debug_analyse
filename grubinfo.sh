#!/bin/bash

# Result log file
ResultFile="/tmp/Rapport-GRUB_$(hostname)_$(date +%Y-%m-%d_%H:%M).log"

# Enhanced progress bar with ---C pattern
progress_bar_enhanced() {
    local duration=$1
    local message="${2:-Processing}"
    local width=40
    local interval=0.2
    local steps=$((duration * 5))
    local pattern="---C"
    local pattern_len=${#pattern}

    echo -n "$message: ["
    for ((i=0; i<width; i++)); do
        echo -n " "
    done
    echo -n "]"
    echo -ne "\r$message: ["

    for ((i=1; i<=steps; i++)); do
        local progress=$(( (i * width) / steps ))
        local done=$progress
        local left=$((width - done))

        # Build done part using repeated pattern truncated to length 'done'
        local done_part=""
        while [ ${#done_part} -lt $done ]; do
            done_part+=$pattern
        done
        done_part=${done_part:0:$done}

        # Build left part with spaces
        local left_part=""
        for ((j=0; j<left; j++)); do
            left_part+=" "
        done

        # Print progress bar
        echo -ne "$done_part$left_part"

        # Print percentage
        local percent=$(( (i * 100) / steps ))
        echo -ne "] $percent%%"

        sleep $interval
        echo -ne "\r$message: ["
    done
    echo -e "] Done!"
}

# Function to generate the GRUB report
genReportGRUB () {
    echo "|===============================|"
    echo "|        uname -a               |"
    echo "|===============================|"
    uname -a
    echo

    echo "|===============================|"
    echo "|          date                 |"
    echo "|===============================|"
    date
    echo

    echo "|===============================|"
    echo "|        DMIDECODE              |"
    echo "|===============================|"
    dmidecode --string='bios-vendor'
    dmidecode --string='bios-version'
    dmidecode --string='system-manufacturer'
    dmidecode --string='system-product-name'
    dmidecode --string='system-version'
    dmidecode --string='baseboard-manufacturer'
    dmidecode --string='baseboard-product-name'
    echo

    echo "|===============================|"
    echo "|          BLKID                |"
    echo "|===============================|"
    echo "========>>>> FULL DEV"
    blkid -o list
    echo
    echo "========>>>  /dev/sda"
    echo "-------------------------------------------------------------"
    blkid /dev/sd* full
    echo "-------------------------------------------------------------"
    echo

    echo "|===============================|"
    echo "|          LSBLK                |"
    echo "|===============================|"
    lsblk -fe7
    echo
    lsblk -S
    echo

    echo "|===============================|"
    echo "|       FICHIER BOOT            |"
    echo "|===============================|"
    sudo mkdir -p /mnt/InfoBoot
    local truc=$(sudo blkid | grep vfat | cut -d " " -f2 | awk -F '"' '{print $2}')
    sudo mount -U ${truc} /mnt/InfoBoot
    ls -R /mnt/InfoBoot
    sleep 3
    sudo umount /mnt/InfoBoot
    sleep 2
    sudo rm -rf /mnt/InfoBoot/
    sleep 2
    echo

    echo "|===============================|"
    echo "|        GRUB ENTRY             |"
    echo "|===============================|"
    awk -F\' '/menuentry / {print $2}' /boot/grub/grub.cfg | cat -n
    echo

    echo "|===============================|"
    echo "|        /etc/grub2.cfg         |"
    echo "|===============================|"
    cat /etc/grub2.cfg
    echo

    echo "|===============================|"
    echo "|        /boot/grub/grub.cfg    |"
    echo "|===============================|"
    cat /boot/grub/grub.cfg
    echo

    echo "|===============================|"
    echo "|        /etc/grub.d/40_custom  |"
    echo "|===============================|"
    cat /etc/grub.d/40_custom
    echo

    echo "|===============================|"
    echo "|       KERNEL-DEB              |"
    echo "|===============================|"
    dpkg --list | grep linux-image | awk '{print $2}'
    echo

    echo "|===============================|"
    echo "|       KERNEL-ARCH             |"
    echo "|===============================|"
    pacman -Q | grep linux  
    echo

    echo "|===============================|"
    echo "|         FSTAB                 |"
    echo "|===============================|"
    sed '1,6d' /etc/fstab
    echo

    echo "|===============================|"
    echo "|       Mounted Filesystems     |"
    echo "|===============================|"
    findmnt -t ext4,xfs,btrfs,f2fs,vfat,ntfs,hfsplus,iso9660,udf,nfs,cifs,zfs
    echo

    echo "|===============================|"
    echo "|       Filesystem Table (fstab) |"
    echo "|===============================|"
    findmnt --fstab
    echo

    echo "|===============================|"
    echo "|         /proc/cmdline         |"
    echo "|===============================|"
    cat /proc/cmdline
    echo

    echo "|===============================|"
    echo "|       Boot Mode Detection     |"
    echo "|===============================|"
    [ -d /sys/firmware/efi ] && echo "UEFI Boot Detected" || echo "Legacy BIOS Boot Detected"
    echo

    echo "|===============================|"
    echo "|           Uptime              |"
    echo "|===============================|"
    uptime
}

# Show banner
echo "==============================="
echo "  Advanced GRUB Report Utility "
echo "==============================="

# Run progress bar for 8 seconds with message
progress_bar_enhanced 8 "Collecting GRUB and System Info"

# Run the report and save output to file
genReportGRUB | tee -a "$ResultFile"

echo
echo "Analysis complete! Results saved in: $ResultFile"
