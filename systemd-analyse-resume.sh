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

    total_sec=0
    while read -r line; do
        time_part=$(echo "$line" | awk '{print $1}')
        if [[ $time_part == *ms ]]; then
            ms=${time_part%ms}
            sec=$(echo "scale=3; $ms/1000" | bc)
        elif [[ $time_part == *s ]]; then
            sec=${time_part%s}
        else
            sec=0
        fi
        total_sec=$(echo "$total_sec + $sec" | bc)
    done < <(head -n $TOP_N "$tmpfile")

    echo "-----------------------------------------------------------"
    echo "Temps total cumulé pour les top $TOP_N services : ${total_sec}s"

    total_services=$(wc -l < "$tmpfile")
    echo "Nombre total de services listés : $total_services"

} | tee "$logfile"

rm "$tmpfile"

echo
echo "Résumé enregistré dans le fichier : $logfile"
