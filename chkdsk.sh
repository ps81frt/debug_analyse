#!/bin/bash

#---
#Requires: ntfsprogs (ntfs-3g)
#---

dpkg -l | grep -qw ntfs-3g || sudo apt install ntfs-3g


clear

# Contrôle si $UID (root)
if [ "$UID" -ne "0" ]
then
    echo -e "Les droits du superutilisateur sont requis !controler les erreurs NTFS!\n"
    exit 1
fi

win=$(blkid | grep 'TYPE="ntfs"' | cut -f1 -d':')

if [ -z "$win" ]
    then 
    echo -e "Volume NTFS introuvable, quitter...\n" 
    exit 1 
fi
    for vol in $win
    do umount -l $vol 2>/dev/null
    ntfsfix -d $vol; mount $vol 2>/dev/null
    echo
done

exit 0
