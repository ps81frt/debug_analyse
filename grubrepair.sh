#!/bin/bash
# 
# =========================================================================
# grubepair.sh - Outil de diagnostic et de réparation de démarrage GRUB
# =========================================================================
#
# Auteur       : itops
# Date         : 2024-11-03
# Version      : 1.5
# Licence      : MIT License (ou autre)
#
# Description  :
#   Ce script effectue un diagnostic complet du système concernant le démarrage,
#   détecte le mode UEFI ou BIOS, vérifie la présence des paquets GRUB nécessaires,
#   collecte des informations systèmes et propose une réparation automatique de GRUB.
#
# Utilisation  :
#   Exécuter en root (sudo) : sudo bash grubepair.sh
#
# Remarques    :
#   - Doit être lancé avec les privilèges administrateur.
#   - Génère un rapport complet dans /tmp avec horodatage.
#   - Supporte les systèmes UEFI et BIOS Legacy.
#
# ========================================================================
# --- Variables Globales ---
SCRIPT_PATH="$(realpath "$0")"
ResultFile="/tmp/MonBootRepair_$(hostname)_$(date +%Y-%m-%d_%Hh%M).log"
BOOT_MODE=""
ROOT_DEVICE=""
ROOT_PARTITION=""
BOOT_PARTITION=""
EFI_PARTITION=""

# --- Fonctions Utilitaires ---

progress_bar_enhanced() {
    local duration=$1
    local message="${2:-Traitement}"
    local width=40
    local interval=0.2
    local steps=$((duration * 5))
    local pattern="---C"
    local pattern_len=${#pattern}

    echo -n "$message: ["
    for ((i=0; i<width; i++)); do echo -n " "; done
    echo -n "]"
    echo -ne "\\r$message: ["

    for ((i=1; i<=steps; i++)); do
        local progress=$(( (i * width) / steps ))
        local done=$progress
        local left=$((width - done))

        local done_part=""
        while [ ${#done_part} -lt $done ]; do done_part+=$pattern; done
        done_part=${done_part:0:$done}

        local left_part=""
        for ((j=0; j<left; j++)); do left_part+=" "; done

        echo -ne "$done_part$left_part"
        sleep "$interval"
        echo -ne "\\r$message: ["
    done
    echo -e "${pattern:0:$width}] OK"
}

cleanup_on_error() {
    echo ""
    echo "--- ERREUR : Nettoyage et sortie."
    exit 1
}

show_me_complete() {
    echo ""
    echo "========================================================="
    echo "               RAPPORT COMPLET ETAT SYSTEME              "
    echo "========================================================="
    echo ""

    echo "=== INFORMATIONS SYSTEME ==="
    echo "Date: $(date)"
    echo "Uptime:" ; uptime ;
    echo "Version du noyau: $(uname -r)" ;
    echo "Distribution: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')" ;
    echo ""

    echo "=== DISQUES ET PARTITIONS ==="
    echo "DF -h:" ; df -h ;
    echo ""
    echo "LSBLK:" ; lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,UUID,PARTUUID ;
    echo ""
    echo "BLKID:" ; blkid | sort ;
    echo ""

    echo "=== FSTAB ==="
    [ -f "/etc/fstab" ] && cat "/etc/fstab" | grep -vE "^#|^$" || echo "ERREUR: /etc/fstab non trouve." ;
    echo ""

    echo "=== GRUB INFOS ==="
    echo "/etc/default/grub (extrait):" ;
    [ -f "/etc/default/grub" ] && cat "/etc/default/grub" | grep -vE "^#|^$" || echo "ERREUR: /etc/default/grub non trouve." ;
    echo ""
    echo "/boot/grub/grub.cfg (extrait):" ;
    if [ -f "/boot/grub/grub.cfg" ]; then
        head -n 20 "/boot/grub/grub.cfg" ;
        echo "..." ;
        tail -n 20 "/boot/grub/grub.cfg" ;
    else
        echo "ERREUR: /boot/grub/grub.cfg non trouve." ;
    fi ;
    echo ""

    echo "=== ENTREES UEFI (si applicable) ==="
    if [ "$BOOT_MODE" = "UEFI" ]; then
        command -v efibootmgr &>/dev/null && efibootmgr -v || echo "efibootmgr non trouve." ;
    else
        echo "Mode BIOS Legacy. efibootmgr non applicable." ;
    fi ;
    echo ""

    echo "=== SERVICES SYSTEMD ECHOUES ==="
    systemctl --failed ;
    echo ""

    echo "=== JOURNAL BOOT RECENT (extraits) ==="
    journalctl -b -p err -p warning -n 50 --no-pager ;
    echo ""
}

detect_boot_mode() {
    echo "" ; echo "=================================" ;
    echo ">>> DETECTION MODE DEMARRAGE" ;
    echo "=================================" ; echo "" ;

    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="UEFI" ;
        echo "Mode: UEFI" ;
        EFI_PARTITION=$(df -h | grep "/boot/efi" | awk '{print $1}') ;
        [ -z "$EFI_PARTITION" ] && { EFI_PARTITION=$(blkid -t TYPE="vfat" -o device --match-token PARTLABEL="EFI System Partition" | head -n 1) ; [ -z "$EFI_PARTITION" ] && EFI_PARTITION=$(blkid -t TYPE="vfat" -o device --match-token PARTTYPE="c12a7328-f81f-11d2-ba4b-00a0c93ec93b" | head -n 1) ; [ -n "$EFI_PARTITION" ] && echo "Avertissement: /boot/efi non monte. EFI detectee via blkid: $EFI_PARTITION" || echo "--- ERREUR: Partition EFI introuvable." ; } ;
        [ -n "$EFI_PARTITION" ] && echo "Partition EFI : $EFI_PARTITION" ;
    else
        BOOT_MODE="BIOS" ;
        echo "Mode: BIOS Legacy" ;
    fi ;
    echo "" ;
}

detect_root_device_and_partition() {
    echo "" ; echo "=================================" ;
    echo ">>> DISQUE ET PARTITION RACINE" ;
    echo "=================================" ; echo "" ;

    ROOT_PARTITION=$(df / | awk 'NR==2 {print $1}') ;
    [ -z "$ROOT_PARTITION" ] && { echo "--- ERREUR: Partition racine introuvable." ; cleanup_on_error ; } ;
    echo "Partition racine: $ROOT_PARTITION" ;

    # Initialisation variable disque principal
    ROOT_DEVICE=""

    # Première tentative : parent direct
    PARENT_DEVICE=$(lsblk -no PKNAME "$ROOT_PARTITION" 2>/dev/null)

    if [ -n "$PARENT_DEVICE" ]; then
        echo "Parent device (PKNAME) direct: $PARENT_DEVICE"
        ROOT_DEVICE="/dev/$PARENT_DEVICE"
    else
        echo "Pas de parent direct via PKNAME."

        # Si root est un device mapper (LVM), tenter de remonter la chaîne
        if [[ "$ROOT_PARTITION" == /dev/mapper/* ]]; then
            echo "Partition racine est un device mapper, tentative de remontée..."

            # Remonter la chaîne des parents
            current_dev="$ROOT_PARTITION"
            while true; do
                parent=$(lsblk -no PKNAME "$current_dev" 2>/dev/null)
                if [ -z "$parent" ]; then
                    echo "Disque physique trouvé : $current_dev"
                    ROOT_DEVICE="$current_dev"
                    break
                else
                    echo "Parent de $current_dev est $parent"
                    current_dev="/dev/$parent"
                fi
            done
        else
            echo "--- ERREUR: Impossible de déterminer le disque principal pour $ROOT_PARTITION"
            cleanup_on_error
        fi
    fi

    # Vérification finale que ROOT_DEVICE est un bloc device valide
    if [ ! -b "$ROOT_DEVICE" ]; then
        echo "--- ERREUR: Disque principal ($ROOT_DEVICE) non valide."
        cleanup_on_error
    fi

    echo "Disque principal: $ROOT_DEVICE"
    echo ""
}

detect_boot_partition() {
    echo "" ; echo "=================================" ;
    echo ">>> PARTITION /boot" ;
    echo "=================================" ; echo "" ;

    if mountpoint -q /boot && [ "$(df /boot | awk 'NR==2 {print $1}')" != "$(df / | awk 'NR==2 {print $1}')" ]; then
        BOOT_PARTITION=$(df /boot | awk 'NR==2 {print $1}') ;
        echo "Partition /boot: $BOOT_PARTITION" ;
    else
        echo "/boot non distincte ou non montee, supposee etre la racine: $ROOT_PARTITION" ;
        BOOT_PARTITION="$ROOT_PARTITION" ;
    fi ;
    echo "" ;
}

collect_grub_and_system_info() {
    echo "" ; echo "=================================" ;
    echo ">>> DIAGNOSTIC GRUB ET SYSTEME" ;
    echo "=================================" ; echo "" ;

    echo "=== DEPENDANCES GRUB ===" ;
    local missing_deps=() ;
    for cmd in grub-install update-grub blkid efibootmgr mount umount chroot; do
        if ! command -v "$cmd" &>/dev/null; then missing_deps+=("$cmd"); fi ;
    done ;
    [ ${#missing_deps[@]} -gt 0 ] && echo "ATTENTION: Commandes manquantes : ${missing_deps[*]}" || echo "Dependances essentielles presentes." ;
    echo "" ;

    echo "=== /etc/default/grub ===" ;
    [ -f "/etc/default/grub" ] && cat "/etc/default/grub" | grep -vE "^#|^$" || echo "ERREUR: /etc/default/grub non trouve." ;
    echo "" ;

    echo "=== /etc/grub.d/ ===" ;
    [ -d "/etc/grub.d" ] && ls -l "/etc/grub.d/" || echo "ERREUR: /etc/grub.d/ non trouve." ;
    echo "" ;

    echo "=== /boot/grub/grub.cfg (EXTRAIT) ===" ;
    if [ -f "/boot/grub/grub.cfg" ]; then
        head -n 20 "/boot/grub/grub.cfg" ;
        echo "..." ;
        tail -n 20 "/boot/grub/grub.cfg" ;
    else
        echo "ERREUR: /boot/grub/grub.cfg non trouve." ;
    fi ;
    echo "" ;

    echo "=== /etc/fstab ===" ;
    [ -f "/etc/fstab" ] && cat "/etc/fstab" | grep -vE "^#|^$" || echo "ERREUR: /etc/fstab non trouve." ;
    echo "" ;

    echo "=== BLKID ===" ;
    blkid | sort ;
    echo "" ;

    echo "=== LSBLK ===" ;
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,UUID,PARTUUID ;
    echo "" ;

    echo "=== ENTREES DE DEMARRAGE UEFI (SI APPLICABLE) ===" ;
    if [ "$BOOT_MODE" = "UEFI" ]; then
        command -v efibootmgr &>/dev/null && efibootmgr -v || echo "efibootmgr non trouve." ;
    else
        echo "Mode BIOS Legacy. efibootmgr non applicable." ;
    fi ;
    echo "" ;
}

install_grub_dependencies() {
    echo ""
    echo "================================="
    echo ">>> VERIFICATION DES PAQUETS GRUB"
    echo "================================="
    echo ""

    local PACKAGES=("grub-pc" "grub-common")
    [ "$BOOT_MODE" = "UEFI" ] && PACKAGES=("grub-efi" "grub-efi-amd64" "efibootmgr")

    echo "Mode de démarrage détecté : $BOOT_MODE"
    echo "Vérification des paquets requis : ${PACKAGES[*]}"

    for pkg in "${PACKAGES[@]}"; do
        if ! dpkg -l | grep -qw "$pkg"; then
            echo "Paquet manquant : $pkg — tentative d'installation"
            apt-get update && apt-get install -y "$pkg"
        else
            echo "Paquet déjà présent : $pkg"
        fi
    done
    echo ""
}

repair_grub() {
    echo ""
    echo "================================="
    echo ">>> REPARATION DE GRUB"
    echo "================================="
    echo ""

    [ -z "$ROOT_PARTITION" ] && echo "Partition racine non définie. Abandon." && return 1
    [ -z "$ROOT_DEVICE" ] && echo "Disque principal non défini. Abandon." && return 1

    echo "Montage de la partition racine : $ROOT_PARTITION"
    mount "$ROOT_PARTITION" /mnt || { echo "Erreur : impossible de monter /mnt" ; return 1 ; }

    echo "Montage des systèmes virtuels nécessaires..."
    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys

    if [ "$BOOT_MODE" = "UEFI" ]; then
        if [ -n "$EFI_PARTITION" ]; then
            echo "Montage de la partition EFI : $EFI_PARTITION"
            mkdir -p /mnt/boot/efi
            mount "$EFI_PARTITION" /mnt/boot/efi || echo "Avertissement : échec du montage de /boot/efi"
        else
            echo "Avertissement : aucune partition EFI détectée."
        fi
    fi

    echo "Chroot dans le système monté et réparation..."
    chroot /mnt /bin/bash -c "
        echo 'Réinstallation de GRUB...'
        grub-install $ROOT_DEVICE
        echo 'Mise à jour de la configuration GRUB...'
        update-grub
    "

    echo "Démontage des systèmes montés..."
    umount -l /mnt/boot/efi 2>/dev/null
    umount -l /mnt/sys
    umount -l /mnt/proc
    umount -l /mnt/dev
    umount -l /mnt

    echo "GRUB a été réinstallé. Redémarre le système pour tester."
    echo ""
}

# --- Menu simple pour l'utilisateur ---
menu() {
  while true; do
    clear
    echo "=== MonBootRepair - Menu ==="
    echo "1) Afficher le rapport complet"
    echo "2) Lancer la réparation automatique de GRUB"
    echo "3) Quitter"
    echo -n "Choix : "
    read choix

    case "$choix" in
      1)
        show_me_complete
        read -p "Appuyez sur Entrée pour revenir au menu..."
        ;;
      2)
        repair_grub
        read -p "Appuyez sur Entrée pour revenir au menu..."
        ;;
      3)
        echo "Sortie."
        exit 0
        ;;
      *)
        echo "Choix invalide."
        sleep 1
        ;;
    esac
  done
}

# --- Fonction principale ---
main() {
    [ "$EUID" -ne 0 ] && { echo "ATTENTION: Script à executer en root. Relancez avec: sudo bash $SCRIPT_PATH \"$@\"" ; exit 1 ; } ;

    exec > >(tee -a "$ResultFile") 2>&1

    trap cleanup_on_error INT TERM ERR ;

    echo "=========================================================" ;
    echo "             MonBootRepair - Demarrage du rapport" ;
    echo "                 Date: $(date)" ;
    echo "                 Fichier de log: $ResultFile" ;
    echo "=========================================================" ; echo "" ;

    progress_bar_enhanced 5 "Initialisation et verification systeme" ;

    detect_boot_mode ;
    install_grub_dependencies ;
    detect_root_device_and_partition ;
    detect_boot_partition ;

    echo "" ; echo "===============================" ;
    echo ">>> RESUME DETECTION" ;
    echo "===============================" ;
    echo "Mode Boot: $BOOT_MODE" ;
    echo "Disque principal: $ROOT_DEVICE" ;
    echo "Partition racine: $ROOT_PARTITION" ;
    echo "Partition /boot: $BOOT_PARTITION" ;
    echo "" ;

    collect_grub_and_system_info ;

    echo "" ;
    echo "==> Diagnostic termine. Lancez la reparation si besoin via le menu." ;
    echo "" ;

    menu
}

# --- Lancement ---
main "$@"
