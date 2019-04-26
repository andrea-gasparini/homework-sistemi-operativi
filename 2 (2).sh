#!/bin/bash

help="Usage: 2.sh bytes walltime sampling commands files"

bytes=$1
walltime=$2
sampling=$3

declare -i k=3; nRip=0
for param in $*; do params+=( "$param" ); done				# crea un array contenente tutti i parametri dati allo script
while [ $nRip -lt 3 ] && [ $k -lt ${#params[@]} ]			# finche' il numero di ripetizioni di ';' è minore di 3 non siamo all'ultimo comando
do
	nRip=$(awk -F";" '{ print NF-1 }' <<< ${params[k]})		# imposta ';' come separatore e assegna il numero dei fields-1 (ovvero il numero di occorrenze del carattere nella stringa)
	var=${params[k]}
	if [ $nRip -lt 2 ]; then								# se ci sono meno di due ';' siamo sempre nello stesso comando
		command="$command $var"								# quindi aggiungo ad una stringa command il valore attuale
	else													# se ci sono 2 o più ';' siamo all'ultimo parametro del comando
		commands+=( "$command ${var//;}" )					# quindi aggiungo ad un vettore dei comandi, il comando con aggiunto l'ultimo parametro, eliminando eventuali ';' di troppo
		command=""											# e svuoto la stringa del comando attuale
	fi
	k+=1													# passa al parametro successivo dello script (parte da 3 perche' i precedenti sono "bytes", "walltime" e "sampling")
done

while [ $k -lt ${#params[@]} ]; do files+=( "${params[k]}" ); k+=1; done	# crea un array files con i parameti restanti

middleFiles=$((${#files[@]}/2))

regexInt='^[0-9]*$'
if ! [[ $bytes =~ $regexInt ]] || ! [[ $walltime =~ $regexInt ]] || ! [[ $sampling =~ $regexInt ]] || [ ${#commands[@]} -eq 0 ]; then		# controlla che i primi 3 parametri siano composti da soli numeri e che 
	echo "$help 15" 1>&2
	exit 15																																	# se manca uno dei 5 parametri o se ce ne sono in eccesso
fi

if [ ${#commands[@]} -ne $middleFiles ]; then	# se il numero di files non è pari a due volte quello dei comandi (metà per stderr e metà per stdout)
	echo "$help 30" 1>&2
	exit 30
fi

stdout=(${files[@]:0:$middleFiles})				# la prima meta' dell'array files e' dedicata allo standard output dei comandi
stderr=(${files[@]:$middleFiles:${#files[@]}})	# la seconda meta' per lo standard error

for ((i=0; i<${#commands[@]}; i++));		#DEBUG - gli scorrimenti negli array vanno eseguiti con gli indici dato che il for per elementi considera lo spazio come separatore
do											#DEBUG - inoltre sarà utile per avere coerenza fra i 3 array con un solo indicek
	echo ${commands[i]}						#DEBUG
	echo ${stdout[i]}						#DEBUG
	echo ${stderr[i]}						#DEBUG
done										#DEBUG - N.B. l'indice rimane all'ultimo valore impostato anche al di fuori del for

for ((i=0; i<${#commands[@]}; i++));	
do											
	if ! hash $( awk '{ print $1 }' <<< ${commands[i]} ) &>/dev/null; then	# per ogni comando controlla se sia valido (il solo comando e non il resto di opzioni e parametri) # command -v funziona anche sui comandi interi
		commands[i]="not existing command"									#CONTROLLARE IL GRADER - CONTROLLARE CHE VADA BENE SOLO IL CHECK SUL COMANDO O VADA FATTO SULL'INTERA STRINGA
	fi																		#CONTROLLARE IL GRADER - I PARAMETRI DOVREBBERO ESSERE SEMPRE VALIDI PERCIO' DOVREBBE ANDAR BENE LASCIARE SOLO ${commands[i]}
done	

#~ for ((i=0; i<${#commands[@]}; i++));
#~ do

#~ done					
