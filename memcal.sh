# Affiche tous les process et memoire d'une Application.
#
#ps -ely | tr -s ' ' | cut -d ' ' -f8,13 | grep bash
#
# Affiche la memoire totale d'une application.
#
#ps -ely | awk '$13 == "bash"' | awk '{SUM+= $8/1024} END {print SUM}' | cut -d "." -f1



#!/bin/bash
PROCESS="${@}"

if [[ -z ${PROCESS} ]]
then 
    echo "Vous devez donner le nom d'un ou plusieurs pocessus en parametres"
else
    for EXPRESSION in $(echo ${PROCESS})
    do
            RAMUSAGE=$(ps -ely | awk -v process=${EXPRESSION} '$13 == process' | awk '{SUM+= $8/1024} END {print SUM}' | cut -d '.' -f1)

            if [[ -z ${RAMUSAGE}  ]]
                then
                echo "le processus ${EXPRESSION} n existe pas"
            else
                echo "RAM consommée pour ${EXPRESSION} : ${RAMUSAGE} MB"
            fi
    done
fi