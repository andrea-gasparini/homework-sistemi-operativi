#!/bin/bash

# @author Andrea Gasparini

scriptname=$0
help="Usage: $scriptname bytes walltime sampling commands files"
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
if ! [[ $bytes =~ $regexInt ]] || ! [[ $walltime =~ $regexInt ]] || ! [[ $sampling =~ $regexInt ]] || [ ${#commands[@]} -eq 0 ]; then		# controlla che i primi 3 parametri siano composti da soli numeri 
	echo "$help" 1>&2																														# e che gli altri siano stati dati correttamente
	exit 15																																	
fi

if [ ${#commands[@]} -ne $middleFiles ]; then		# se il numero di files non è pari a due volte quello dei comandi (metà per stderr e metà per stdout)
	echo "$help" 1>&2
	exit 30
fi

stdout=(${files[@]:0:$middleFiles})					# la prima meta' dell'array files e' dedicata allo standard output dei comandi
stderr=(${files[@]:$middleFiles:${#files[@]}})		# la seconda meta' per lo standard error

for ((i=0; i<${#commands[@]}; i++));	
do											
	if ! hash $( awk '{ print $1 }' <<< ${commands[i]} ) 2>/dev/null; then		# controlla se il comando e' valido (il solo comando e non il resto di opzioni e parametri) # command -v funziona anche sui comandi interi
		commands[i]="not existing command"									
	fi																		
done	

for ((i=0; i<${#commands[@]}; i++));
do
	if [ "${commands[i]}" != "not existing command" ]; then 	
		eval "${commands[i]} 1>${stdout[i]} 2>${stderr[i]} &"		# lancia il comando in background e redirige standard output e standard error
		pids+=( "$!" )												# aggiunge il pid del processo ad un array
	fi
done					

for pid in ${pids[@]}; do pidString="$pidString $pid"; done		# crea una stringa composta da tutti i pid, ognuno separato da uno spazio			
echo $pidString 1>&3											# scrive sul file descriptor 3 tutti i pid

declare -i killedCnt=0										  						# contatore dei processi killati
while [ $killedCnt -lt ${#pids[@]} ] && [ ! -f done.txt ]							# esegue le operazioni di controllo finché non sono stati killati tutti i processi o finché non viene trovato un file regolare done.txt nella cwd
do
	for ((i=0; i<${#pids[@]}; i++));
	do
		if [ "${pids[i]}" != "killed" ]; then										# se il processo non è stato già killato (segna killed nell'array al posto del pid quando killa)
			elapsedSeconds=$(ps -p ${pids[i]} -o etimes | grep -o [[:digit:]].*)	# prende il solo valore numerico in secondi del processo
			if [ -z $elapsedSeconds ]; then 										# se è nullo significa che è già terminato
				pids[i]="killed"													# percio' lo segna come killed
				killedCnt+=1													
				if [ $killedCnt -eq ${#pids[@]} ]; then								# e se ha terminato i processi da controllare
					break 2															# esce dal ciclo piu' esterno
				fi
			fi
			elapsedMinutes=$(($elapsedSeconds/60))									
			
			actualKB=$(ps -p ${pids[i]} -o size | grep -o [[:digit:]].*)			# prende il solo valore numerico in kiloBytes della dimensione del processo
			actualBytes=$(($actualKB*1024))											# e lo converte in Bytes
			
			if [ $bytes -gt 0 ] && [ $actualBytes -gt $bytes ]; then				# se la dimensione del processo è maggiore di quella imposta come limite
				kill -SIGINT ${pids[i]}												# killa il processo simulando la pressione di CTRL-C
				pids[i]="killed"													# e lo segna come killed all'interno dell'array dei pid
				killedCnt+=1
			fi
			
			if [ $walltime -gt 0 ] && [ $elapsedMinutes -gt $walltime ] && [ "${pids[i]}" != "killed" ]; then
				kill -SIGINT ${pids[i]}
				pids[i]="killed"			
				killedCnt+=1
			fi
		fi
	done
	sleep $sampling		# attende $sampling secondi prima di effettuare nuovamente i controlli				
done

if [ -f done.txt ]; then						# se esiste un file regolare done.txt
	echo "File done.txt trovato"	
	exit 0
elif [ $killedCnt -eq ${#pids[@]} ]; then		# se i processi sono stati terminati tutti
	echo "Tutti i processi sono terminati"
	exit 1
fi
