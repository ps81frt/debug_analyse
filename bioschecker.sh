# Oneline
# { echo "=== Vérification des paquets ==="; PACKAGES=("mesa-utils" "vulkan-tools" "pciutils" "lshw" "dmidecode"); MISSING=(); for pkg in "${PACKAGES[@]}"; do dpkg -l | grep -q "^ii  $pkg " || MISSING+=("$pkg"); done; if [ ${#MISSING[@]} -gt 0 ]; then echo "Installation des paquets manquants: ${MISSING[*]}"; sudo apt update && sudo apt install -y "${MISSING[@]}"; fi; echo "=== RAPPORT BIOS $(date) ==="; sudo dmidecode -t bios; echo "=== SYSTÈME ==="; sudo dmidecode -t system; echo "=== CPU ==="; lscpu; echo "=== VIRTUALISATION ==="; grep -E "(vmx|svm)" /proc/cpuinfo && echo "Virtualisation OK" || echo "Pas de virtualisation"; echo "=== SECURE BOOT ==="; mokutil --sb-state 2>/dev/null || echo "mokutil non disponible"; echo "=== TPM ==="; ls /dev/tpm* 2>/dev/null || echo "Pas de TPM"; echo "=== UEFI ==="; efibootmgr -v 2>/dev/null || echo "Système BIOS Legacy"; echo "=== CARTE GRAPHIQUE ==="; lspci | grep -i -E "vga|3d|display"; lspci -v | grep -A 15 -i -E "vga|3d"; echo "--- GPU via lshw ---"; lshw -class display 2>/dev/null; echo "--- Pilotes ---"; lsmod | grep -i -E "(nvidia|amdgpu|radeon|nouveau|intel)"; echo "--- OpenGL ---"; glxinfo | grep -E "(OpenGL renderer|OpenGL version)" 2>/dev/null || echo "glxinfo non disponible"; echo "--- Vulkan ---"; vulkaninfo --summary 2>/dev/null || echo "vulkaninfo non disponible"; echo "--- NVIDIA ---"; nvidia-smi 2>/dev/null || echo "nvidia-smi non disponible"; } > ~/bios_check_$(date +%Y%m%d_%H%M%S).log 2>&1 && echo "Rapport créé dans: ~/bios_check_$(date +%Y%m%d_%H%M%S).log"

#!/bin/bash

# Script de vérification des options BIOS/UEFI
OUTPUT_FILE="/tmp/bios_check_$(date +%Y%m%d_%H%M%S).log"

# Fonction pour vérifier et installer les paquets nécessaires
check_and_install_packages() {
    echo "Vérification des paquets nécessaires..."
    
    PACKAGES_TO_CHECK=("mesa-utils" "vulkan-tools" "pciutils" "lshw" "dmidecode")  
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

#-----------------------------------------------------------------
#echo "=== CARTE GRAPHIQUE ===" >> "$OUTPUT_FILE"
#echo "--- Informations GPU via lspci ---" >> "$OUTPUT_FILE"
#lspci | grep -i vga >> "$OUTPUT_FILE" 2>&1
#lspci | grep -i 3d >> "$OUTPUT_FILE" 2>&1
#echo "" >> "$OUTPUT_FILE"
#
#echo "--- Détails complets GPU ---" >> "$OUTPUT_FILE"
#lspci -v | grep -A 20 -i vga >> "$OUTPUT_FILE" 2>&1
#lspci -v | grep -A 20 -i 3d >> "$OUTPUT_FILE" 2>&1
#echo "" >> "$OUTPUT_FILE"
#
#echo "--- Informations GPU via lshw ---" >> "$OUTPUT_FILE"
#lshw -class display >> "$OUTPUT_FILE" 2>&1
#echo "" >> "$OUTPUT_FILE"
#
#echo "--- Pilotes graphiques ---" >> "$OUTPUT_FILE"
#lsmod | grep -i -E "(nvidia|amdgpu|radeon|nouveau|intel)" >> "$OUTPUT_FILE" 2>&1
#echo "" >> "$OUTPUT_FILE"
#
#echo "--- OpenGL/Vulkan Support ---" >> "$OUTPUT_FILE"
#if command -v glxinfo >/dev/null 2>&1; then
#    echo "OpenGL Renderer:" >> "$OUTPUT_FILE"
#    glxinfo | grep -E "(OpenGL renderer|OpenGL version|OpenGL vendor)" >> "$OUTPUT_FILE" 2>&1
#else
#    echo "glxinfo non installé (paquet mesa-utils)" >> "$OUTPUT_FILE"
#fi
#
#if command -v vulkaninfo >/dev/null 2>&1; then
#    echo "Vulkan Support:" >> "$OUTPUT_FILE"
#    vulkaninfo --summary >> "$OUTPUT_FILE" 2>&1
#else
#    echo "vulkaninfo non installé (paquet vulkan-tools)" >> "$OUTPUT_FILE"
#fi
#echo "" >> "$OUTPUT_FILE"
#
#echo "--- Cartes graphiques via dmidecode ---" >> "$OUTPUT_FILE"
#sudo dmidecode -t 9 | grep -A 10 -i "vga\|display\|graphic" >> "$OUTPUT_FILE" 2>&1
#echo "" >> "$OUTPUT_FILE"
#
#echo "--- NVIDIA (si présent) ---" >> "$OUTPUT_FILE"
#if command -v nvidia-smi >/dev/null 2>&1; then
#    nvidia-smi >> "$OUTPUT_FILE" 2>&1
#else
#    echo "nvidia-smi non disponible" >> "$OUTPUT_FILE"
#fi
#echo "" >> "$OUTPUT_FILE"
#
#echo "--- AMD GPU (si présent) ---" >> "$OUTPUT_FILE"
#if [ -f /sys/class/drm/card0/device/pp_dpm_sclk ]; then
#    echo "AMD GPU détecté:" >> "$OUTPUT_FILE"
#    cat /sys/class/drm/card*/device/pp_dpm_sclk >> "$OUTPUT_FILE" 2>&1
#else
#    echo "Pas de GPU AMD détecté" >> "$OUTPUT_FILE"
#fi
#echo "" >> "$OUTPUT_FILE"
#
#echo "--- Mémoire vidéo ---" >> "$OUTPUT_FILE"
#if [ -d /sys/class/drm ]; then
#    for card in /sys/class/drm/card*; do
#        if [ -f "$card/device/mem_info_vram_total" ]; then
#            echo "VRAM $(basename $card): $(cat $card/device/mem_info_vram_total)" >> "$OUTPUT_FILE" 2>&1
#        fi
#    done
#fi
#echo "" >> "$OUTPUT_FILE"
#-----------------------------------------------------------------
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
