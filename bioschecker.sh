#!/bin/bash

# Script de vérification des options BIOS/UEFI
OUTPUT_FILE="bios_check_$(date +%Y%m%d_%H%M%S).txt"

echo "=== RAPPORT DE VÉRIFICATION BIOS/UEFI ===" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "Système: $(uname -a)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "=== INFORMATIONS BIOS ===" >> "$OUTPUT_FILE"
sudo dmidecode -t bios >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== INFORMATIONS SYSTÈME ===" >> "$OUTPUT_FILE"
sudo dmidecode -t system >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== INFORMATIONS PROCESSEUR ===" >> "$OUTPUT_FILE"
sudo dmidecode -t processor >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== FONCTIONNALITÉS CPU ===" >> "$OUTPUT_FILE"
lscpu >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== FLAGS PROCESSEUR ===" >> "$OUTPUT_FILE"
grep "flags" /proc/cpuinfo | head -1 >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== VIRTUALISATION ===" >> "$OUTPUT_FILE"
echo "Support virtualisation:" >> "$OUTPUT_FILE"
grep -E "(vmx|svm)" /proc/cpuinfo >/dev/null && echo "✓ Virtualisation supportée" >> "$OUTPUT_FILE" || echo "✗ Virtualisation non détectée" >> "$OUTPUT_FILE"
lscpu | grep Virtualization >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== SECURE BOOT ===" >> "$OUTPUT_FILE"
if command -v mokutil >/dev/null 2>&1; then
    mokutil --sb-state >> "$OUTPUT_FILE" 2>&1
else
    echo "mokutil non installé - impossible de vérifier Secure Boot" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "=== TPM ===" >> "$OUTPUT_FILE"
if ls /dev/tpm* >/dev/null 2>&1; then
    echo "✓ TPM détecté:" >> "$OUTPUT_FILE"
    ls /dev/tpm* >> "$OUTPUT_FILE" 2>&1
    if [ -d /sys/class/tpm/tpm0 ]; then
        cat /sys/class/tpm/tpm*/device/description >> "$OUTPUT_FILE" 2>&1
    fi
else
    echo "✗ Aucun TPM détecté" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "=== FIRMWARE/UEFI ===" >> "$OUTPUT_FILE"
if [ -d /sys/firmware/efi ]; then
    echo "✓ Système UEFI détecté" >> "$OUTPUT_FILE"
    efibootmgr -v >> "$OUTPUT_FILE" 2>&1
else
    echo "✗ Système BIOS Legacy" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "=== MATÉRIEL GÉNÉRAL ===" >> "$OUTPUT_FILE"
lshw -class system >> "$OUTPUT_FILE" 2>&1
echo "" >> "$OUTPUT_FILE"

echo "=== RÉSUMÉ SYSTÈME ===" >> "$OUTPUT_FILE"
if command -v inxi >/dev/null 2>&1; then
    inxi -F >> "$OUTPUT_FILE" 2>&1
else
    echo "inxi non installé - résumé non disponible" >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "=== FIN DU RAPPORT ===" >> "$OUTPUT_FILE"
echo "Rapport sauvegardé dans: $OUTPUT_FILE"
