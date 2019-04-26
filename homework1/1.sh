#!/bin/bash

# @author Andrea Gasparini

help="Uso: 1.sh [opzioni] directory"
boolean=false
				
# FUNZIONE controlla che non vengano passate due opzioni contemporaneamente
checkOptions() { if [ "$boolean" = true ] || [[ "$OPTARG" == "-"[a-z] ]]; then
					 echo "$help" 1>&2
					 exit 10
				 fi }
				
				
# FUNZIONE controlla che non vengano dati più parametri di quelli previsti
checkParams() { if [ $1 ]; then
					echo "$help" 1>&2
					exit 10
				fi }
					
					
while getopts ":e:b:" opt; do
	case $opt in
		e)
			checkOptions
	
			cmd=$opt
			dir=$OPTARG
			
			checkParams $3
			
			boolean=true
			;;
		b)
			checkOptions
			
			cmd=$opt
			dir=$3
			dirb=$OPTARG
			
			checkParams $4
			
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
		checkParams $2
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
				

if [ $cmd ] && [ $cmd == "b" ]; then
	if [ -d $dirb ]; then
		if [ ! -r $dirb ] || [ ! -w $dirb ] || [ ! -x $dirb ]; then
			echo "L'argomento $dirb non e' valido in quanto non ha i permessi richiesti" 1>&2
			exit 200
		fi
	else
		mkdir $dirb
		chmod 700 $dirb	
	fi
fi

mkdir F && mkdir F/dates

matchdate="[0-9][0-9][0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-9][0-5][0-9]"

find $dir -regex '.*_[0-9][0-9][0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-9][0-5][0-9]_.*[jpg|JPG|txt|TXT]' > F/alldir.txt

LC_ALL=C sort F/alldir.txt > F/alldirSorted.txt
rm F/alldir.txt

cat F/alldirSorted.txt | grep -o $matchdate | while read line
do 
	awk -v pattern=$line '$0 ~ pattern' F/alldirSorted.txt > F/dates/$line.txt
done

declare -a toRemove

# FUNZIONE se presente, segna "deleted" nella posizione di F in cui trova l'elemento dato in input 
delFromF() {	
				declare -i i=0
				for k in ${F[@]}
				do
					if [ $k == $1 ]; then
						F[i]="deleted"
						break
					fi	
					i+=1
				done
			}

for filedir in F/dates/*.txt # per ogni file data
do
	declare -a F
	readarray F < $filedir # crea un array F con gli elementi presenti nel relativo file data
	
	# CONTROLLO LINK SIMBOLICI

	for file in ${F[@]} # per ogni file in F
	do
		if [ -L $file ]; then # se il file è un link simbolico
			date=`echo $file | grep -o $matchdate` # estrae la data dal nome del file
			dateLink=`readlink $file | grep -o $matchdate` # estrae la data dal nome del file linkato
			if [ $date == $dateLink ]; then
				toRemove+=( "$file" ) # aggiunge il file all'array di quelli da rimuovere

				delFromF $file

			fi
		fi
	done	
	
	# CONTROLLO HARD LINK

	declare -a removedInodes

	for file in ${F[@]}
	do
		if [ $file != "deleted" ]; then # se non è stato precedentemente cancellato
		
			inodeNum="$(stat --format=%i $file)" # trova l'inode number del file
			
			echo $file >> tmp.txt
			
			for fileInode in ${F[@]} # leggo nuovamente per cercare quelli con lo stesso iNode
			do
				if [ $fileInode != $file ] && [ $fileInode != "deleted" ]; then # il file stesso ha ovviamente lo stesso iNode e non viene considerato
					if [ $inodeNum -eq $(stat --format=%i $fileInode) ]; then # se gli iNode combaciano
						echo $fileInode >> tmp.txt # in un txt temporaneo vanno tutte le dir dei file con stesso iNode
					fi											
				fi
			done
			
			LC_ALL=C sort tmp.txt > tmpSorted.txt # il file temporaneo viene ordinato lessicograficamente
			rm tmp.txt 
			
			if [[ $(wc -l <tmpSorted.txt) -gt 1 ]]; then # se il file temporaneo ha più di una riga significa che ci sono degli hard link (-l limita l'out al solo numero di righe)
				hardLink=`tail -n 1 tmpSorted.txt` # l'ultima riga del file temporaneo ordinato rappresenta la dir del file con path lessicograficamente più grande, perciò da prendere in considerazione
				rm tmpSorted.txt
				
				alreadyInToRemove=false # variabile d'appoggio per controllare se è stato già aggiunto la stessa dir del file agli elementi da rimuovere da F
				
				for el in ${toRemove[@]} 
				do
					if [ $hardLink == $el ]; then # se un elemento dell'array dei file da rimuovere è lo stesso di quello preso in considerazione
						alreadyInToRemove=true 
					fi
				done
				
				for removedInode in ${removedInodes[@]}
				do
					if [ $inodeNum -eq $removedInode ]; then # se è stato già rimosso un file con lo stesso Inode
						alreadyInToRemove=true
					fi
				done
				
				if [ $alreadyInToRemove = false ]; then # se l'elemento non è già presente nell'array
					toRemove+=( "$hardLink" )
					removedInodes+=( "$inodeNum" )
					
					delFromF $hardLink					
				fi
			fi		
		fi	
	done
	
	# CONTROLLO STESSO CONTENUTO

	for file in ${F[@]}
	do
		if [ $file != "deleted" ]; then # se non è stato precedentemente cancellato
		
			echo $file >> tmp.txt
			
			for fileCmp in ${F[@]} # leggo nuovamente per cercare quelli con lo stesso contenuto
			do
				if [ $fileCmp != $file ] && [ $fileCmp != "deleted" ]; then # il file stesso ha ovviamente lo stesso contenuto e non viene considerato
					if cmp -s $fileCmp $file; then # se i file hanno lo stesso contenuto (-s non mostra nessun output)
						echo $fileCmp >> tmp.txt # in un txt temporaneo vanno tutte le dir dei file con stesso contenuto	
					fi
				fi
			done
			
			LC_ALL=C sort tmp.txt > tmpSorted.txt # il file temporaneo viene ordinato lessicograficamente
		
			rm tmp.txt
			
			if [[ $(wc -l <tmpSorted.txt) -gt 1 ]]; then # se il file temporaneo ha più di una riga significa che ci sono file con lo stesso contenuto
			
				head -n -1 tmpSorted.txt > tmpSortedEx.txt
				rm tmpSorted.txt
				
				alreadyInToRemove=false # variabile d'appoggio per controllare se è stato già aggiunto la stessa dir del file agli elementi da rimuovere da F
				
				while read line
				do
				
					for el in ${toRemove[@]} 
					do
						if [ $line == $el ]; then # se un elemento dell'array dei file da rimuovere è lo stesso di quello preso in considerazione
							alreadyInToRemove=true 
							break
						fi
					done
					
					if [ $alreadyInToRemove = false ]; then
						toRemove+=( "$line" )

						delFromF $line
						break
					fi
				done <tmpSortedEx.txt
				
				rm tmpSortedEx.txt
			fi
		fi
	done
done

rm tmpSorted.txt 

rm -rf F

OLDIFS=$IFS

# FUNZIONE elimina i link simbolici presenti nella directory data in input e elimina quelli che linkano ad un file non esistente
removeDeadSymLinks() { 
						IFS=$'\n'; arraySymLinks=( $(find $1 -type l) ); IFS=$OLDIFS	# trova tutti i link simbolici a partire dalla directory passata come parametro e li inserisce in un array
						for symLink in ${arraySymLinks[@]} 								# per ogni link simbolico
						do
							if [ -z $(readlink -e $symLink) ]; then 					# ritorna null se non esiste il file linkato, grazie all'opzione -e ( -- canonicalize-existing ) 
								rm -rf $symLink											# rimuovo il link sorgente che ha una destinazione non esistente
							fi
						done
					  }

toRemoveSorted=($(printf '%s\n' "${toRemove[@]}" | LC_ALL=C sort)) 	# ordina lessicograficamente l'array
(IFS='|'; printf '%s\n' "${toRemoveSorted[*]}")						# scrive su stdout la lista dei file di interesse presenti nell'array, separati da "|"

case $cmd in
	e)	# EFFETTUA SOLO LA STAMPA SU STDOUT, ESEGUITA IN OGNI CASO PRIMA DEL CASE
		;;
	b)	
		for el in ${toRemove[@]}
		do
			IFS='/'; arrayDir=( $el ); unset arrayDir[0]; unset arrayDir[-1]; IFS=$OLDIFS # crea un array i cui elementi sono i nomi delle cartelle in cui è contenuto il file (che erano separati da "/")
			
			createDir=$dirb # createDir è inizializzato al nome della cartella data in input allo script
			
			for pieceOfDir in ${arrayDir[@]}
			do
				createDir="$createDir/$pieceOfDir" # vengono aggiunti a createDir i nomi delle sottocartelle, per poter ricreare il path com'era in origine
			done
			
			mkdir -p $createDir # crea la directory come in originale
			mv $el $createDir 	# sposta l'elemento originale nella nuova directory
			
		done
		
		removeDeadSymLinks $dirb

		;;
	*)	
		for el in ${toRemove[@]}
		do
			rm $el
		done
		;;
esac

removeDeadSymLinks $dir
