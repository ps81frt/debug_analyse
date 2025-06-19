#!/bin/bash

# Script de vérification de l'état des disques
OUTPUT_FILE="disk_health_$(date +%Y%m%d_%H%M%S).txt"

# Fonction pour vérifier et installer les paquets nécessaires
check_and_install_packages() {
    echo "Vérification des paquets nécessaires..."
    
    PACKAGES_TO_CHECK=("sg3-utils" "smartmontools" "hdparm" "lshw" "util-linux")
    PACKAGES_TO_INSTALL=()
    
    for package in "${PACKAGES_TO_CHECK[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            PACKAGES_TO_INSTALL+=("$package")
        fi
    done
    
    if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
        echo "Installation des paquets manquants: ${PACKAGES_TO_INSTALL[*]}"
        sudo apt update
        sudo apt install -y "${PACKAGES_TO_INSTALL[@]}"
        echo "Installation terminée."
    else
        echo "Tous les paquets nécessaires sont déjà installés."
    fi
    echo ""
}

# Vérifier et installer les paquets
check_and_install_packages

echo "=== RAPPORT D'ÉTAT DES DISQUES ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "Système: $(uname -a)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "=== LISTE DES DISQUES ===" >> "$OUTPUT_FILE"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,SERIAL >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== INFORMATIONS DÉTAILLÉES DES DISQUES ===" >> "$OUTPUT_FILE"
lshw -class disk >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== DISQUES SCSI/SATA (sg3-utils) ===" >> "$OUTPUT_FILE"
echo "--- Scan des périphériques SCSI ---" >> "$OUTPUT_FILE"
sg_scan >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "--- Informations SCSI détaillées ---" >> "$OUTPUT_FILE"
for device in /dev/sd*; do
    if [[ $device =~ /dev/sd[a-z]$ ]]; then
        echo "=== $device ===" >> "$OUTPUT_FILE"
        sg_inq "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
        
        echo "--- Capacité $device ---" >> "$OUTPUT_FILE"
        sg_readcap "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
        
        echo "--- Mode Sense $device ---" >> "$OUTPUT_FILE"
        sg_modes "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
    fi
done

echo "=== SMART STATUS ===" >> "$OUTPUT_FILE"
for device in /dev/sd*; do
    if [[ $device =~ /dev/sd[a-z]$ ]]; then
        echo "=== SMART $device ===" >> "$OUTPUT_FILE"
        smartctl -i "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
        
        echo "--- SMART Health $device ---" >> "$OUTPUT_FILE"
        smartctl -H "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
        
        echo "--- SMART Attributes $device ---" >> "$OUTPUT_FILE"
        smartctl -A "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
        
        echo "--- SMART Test Results $device ---" >> "$OUTPUT_FILE"
        smartctl -l selftest "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
    fi
done

echo "=== INFORMATIONS HDPARM ===" >> "$OUTPUT_FILE"
for device in /dev/sd*; do
    if [[ $device =~ /dev/sd[a-z]$ ]]; then
        echo "=== HDPARM $device ===" >> "$OUTPUT_FILE"
        hdparm -I "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
        
        echo "--- Vitesse $device ---" >> "$OUTPUT_FILE"
        hdparm -t "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
    fi
done

echo "=== DISQUES NVME ===" >> "$OUTPUT_FILE"
if ls /dev/nvme* >/dev/null 2>&1; then
    for device in /dev/nvme*n1; do
        echo "=== $device ===" >> "$OUTPUT_FILE"
        nvme id-ctrl "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
        
        echo "--- SMART NVMe $device ---" >> "$OUTPUT_FILE"
        nvme smart-log "$device" >> "$OUTPUT_FILE" 2>&1
        echo "" >> "$OUTPUT_FILE"
    done
else
    echo "Aucun disque NVMe détecté" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "=== ESPACE DISQUE ===" >> "$OUTPUT_FILE"
df -h >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== MONTAGES ACTIFS ===" >> "$OUTPUT_FILE"
mount >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== PARTITIONS ===" >> "$OUTPUT_FILE"
fdisk -l >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== TEMPÉRATURE DES DISQUES ===" >> "$OUTPUT_FILE"
for device in /dev/sd*; do
    if [[ $device =~ /dev/sd[a-z]$ ]]; then
        echo "Température $device:" >> "$OUTPUT_FILE"
        smartctl -A "$device" | grep -i temperature >> "$OUTPUT_FILE" 2>&1
        hddtemp "$device" >> "$OUTPUT_FILE" 2>&1
    fi
done
echo "" >> "$OUTPUT_FILE"

echo "=== ERREURS SYSTÈME LIÉES AUX DISQUES ===" >> "$OUTPUT_FILE"
dmesg | grep -i -E "(error|fail|timeout)" | grep -i -E "(sd|nvme|ata|scsi)" | tail -20 >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== FIN DU RAPPORT ===" >> "$OUTPUT_FILE"
echo "Rapport sauvegardé dans: $OUTPUT_FILE"
