# Affiche tous les process et memoire d'une Application.
#
#ps -ely | tr -s ' ' | cut -d ' ' -f8,13 | grep bash
#
# Affiche la memoire totale d'une application.
#
#ps -ely | awk '$13 == "bash"' | awk '{SUM+= $8/1024} END {print SUM}' | cut -d "." -f1
# Voir en temp réel toutes les 250ms
# watch interval==.25 ./memcalc2.sh --user xxx

#!/bin/bash

OPTION=${1}
PROCESS="${@:2}"

if [[ ${OPTION} = "--service" ]]
then

	if [[ -z ${PROCESS} ]]
	then
		echo "Vous devez donner le nom d'un ou plusieurs processus en paramètre"
	else
		for EXPRESSION in $(echo ${PROCESS})
		do
            RAMUSAGE=$(ps -ely | awk -v process=${EXPRESSION} '$13 == process' | awk '{SUM+= $8/1024} END {print SUM}' | cut -d '.' -f1)
			#RAMUSAGE=$(ps -ely |awk -v process=${EXPRESSION} '$13 == process' |awk '{SUM += $8/1024} END {print SUM}' |cut -d '.' -f1)
			if [[ -z ${RAMUSAGE} ]]
			then
				echo "le processus ${EXPRESSION} n'existe pas"
			else
				echo "RAM consommée pour ${EXPRESSION} : ${RAMUSAGE} MB"
			fi
		done
	fi

elif [[ ${OPTION} = "--pid" ]]
then
	if [[ -z ${PROCESS} ]]
        then
                echo "Vous devez donner le numéro d'un ou plusieurs PIDs en paramètre"
        else
                for EXPRESSION in $(echo ${PROCESS})
                do
                        RAMUSAGE=$(ps -ely |awk -v pid=${EXPRESSION} '$3 == pid' |awk '{SUM += $8/1024} END {print SUM}' |cut -d '.' -f1)
			SERVICE=$(ps -ely |awk -v pid=${EXPRESSION} '$3 == pid' | awk '{print $13}')

                        if [[ -z ${RAMUSAGE} ]]
                        then
                                echo "le pid ${EXPRESSION} n'existe pas"
                        else
				echo "RAM consommée pour le pid ${EXPRESSION} (${SERVICE}) : ${RAMUSAGE} MB"
                        fi
                done
        fi

elif [[ ${OPTION} = "--user" ]]
then
        if [[ -z ${PROCESS} ]]
        then
                echo "Vous devez donner le nom d'un ou plusieurs utilisateurs en paramètre"
        else
                for EXPRESSION in $(echo ${PROCESS})
                do
                        RAMUSAGE=$(ps -elyf |awk -v user=${EXPRESSION} '$2 == user' |awk '{SUM += $8/1024} END {print SUM}' |cut -d '.' -f1)

                        if [[ -z ${RAMUSAGE} ]]
                        then
                                echo "l'utilisateur ${EXPRESSION} n'existe pas ou ne consomme pas actuellement de RAM"
                        else
                                echo "RAM consommée par l'utilisateur ${EXPRESSION} : ${RAMUSAGE} MB"
                        fi
                done
        fi


else
	echo "Vous devez indiquer comme premier paramètre --service, --user ou --pid"
fi
