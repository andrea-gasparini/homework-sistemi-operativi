#!/bin/bash

# TO-DO
### gli argomenti devono essere limitati superiormente
### gli argomenti passati a -b non devono essere minori di 2
### il controllo sulle opzioni multiple (-e -b) va effettuato su qualunque lettera

help="Uso: 1.sh [opzioni] directory"
boolean=false
				
# FUNZIONE controlla che non vengano passate due opzioni contemporaneamente
checkOptions() { if [ "$boolean" = true ] || [[ "$OPTARG" == "-"[a-z] ]] || [[ "$OPTARG" == [a-z] ]]; then
					# se vengono passate due opzioni
					echo "$help" 1>&2
					exit 10
				fi }
				
				
# FUNZIONE controlla che non vengano dati più parametri di quelli previsit
checkParams() { if [ ! -z $1 ]; then
					echo "$help" 1>&2
					exit 10
				fi }
					
					

while getopts ":e:b:" opt; do
	case $opt in
		e)
			checkOptions # chiamata alla funzione
	
			cmd=$opt
			dir=$OPTARG
			
			checkParams $3 # chiamata alla funzione
			
			boolean=true
			;;
		b)
			checkOptions # chiamata alla funzione
			
			cmd=$opt
			dir=$3
			dirb=$OPTARG
			
			checkParams $4 # chiamata alla funzione
			
			boolean=true
			
			if [ -z $3 ]; then
				# se viene passata un'opzione che necessita un argomento, ma senza passare l'argomento
				echo "$help" 1>&2
				exit 10
			fi
			;;
		\?) 
			# se viene passata un'opzione non esistente
			echo "$help" 1>&2
			exit 10
			;;
		:)
			# se non viene passato l'argomento obbligatorio
			echo "$help" 1>&2
			exit 10
			;;
	esac 
done

if [ -z $cmd ]; then
	if [ -z $1 ]; then
		echo "$help" 1>&2
		exit 10
	else
		checkParams $2 # chiamata alla funzione
		dir=$1
	fi
fi




if [ ! -d $dir ]; then
	echo "L'argomento $dir non e' valido in quanto non e' una directory" 1>&2
	exit 100
elif [ -f $dir ]; then
	echo "L'argomento $dir non e' valido in quanto e' un file regolare" 1>&2
	exit 100
elif [ ! -r $dir ] || [ ! -x $dir ]; then
	echo "L'argomento $dir non e' valido in quanto non ha i permessi richiesti" 1>&2 
	exit 100
fi 
				

if [ ! -z $cmd ] && [ $cmd == "b" ]; then
	if [ -d $dirb ]; then
		if [ ! -r $dirb ] || [ ! -w $dirb ] || [ ! -x $dirb ]; then
			echo "L'argomento $dirb non e' valido in quanto non ha i permessi richiesti" 1>&2
			exit 200
		fi
	else
		# se non esiste una directory con quel nome ma un file sì?
		echo "creo dir"
		mkdir $dirb
		chmod 700 $dirb	
	fi
fi
