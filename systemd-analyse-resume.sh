#!/bin/bash
# Compatible Debian, Red Hat, Arch, etc.

TOP_N=20
tmpfile=$(mktemp)
logfile="/tmp/resume_demarrage_systemd_$(date +%Y%m%d_%H%M%S).log"

systemd-analyze blame --no-pager > "$tmpfile"

{
    echo "Résumé du démarrage - Top $TOP_N services les plus lents :"
    echo "-----------------------------------------------------------"
    head -n $TOP_N "$tmpfile"
    
    total_sec=$(head -n $TOP_N "$tmpfile" | awk '
    {
        time_str = $1
        if (time_str ~ /ms$/) {
            gsub(/ms$/, "", time_str)
            total += time_str / 1000
        } else if (time_str ~ /s$/) {
            gsub(/s$/, "", time_str)
            total += time_str
        } else if (time_str ~ /min$/) {
            gsub(/min$/, "", time_str)
            total += time_str * 60
        }
    }
    END { printf "%.3f", total }
    ')
    
    echo "-----------------------------------------------------------"
    echo "Temps total cumulé pour les top $TOP_N services : ${total_sec}s"
    total_services=$(wc -l < "$tmpfile")
    echo "Nombre total de services listés : $total_services"
} | tee "$logfile"

rm "$tmpfile"
echo
echo "Résumé enregistré dans le fichier : $logfile"
