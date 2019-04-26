#!/bin/awk -f

# @author Andrea Gasparini

BEGIN { 
		arguments=ARGV[1]																					# primo argomento dato (fuori dal for per evitare troppi " ")
		for ( i=2; i<ARGC; i++ ) arguments=arguments" "ARGV[i];												# concatena gli argomenti dati allo script in una stringa
		print "Eseguito con argomenti " arguments
		print "Eseguito con argomenti " arguments > "/dev/stderr"
		
		if ( length(ARGV[2])==0 ) { print "Errore: dare almeno 2 file di input" > "/dev/stderr"; exit 0; }	# se il secondo argomento è null (lunghezza zero)
		
		FS="="; strip_comments=0; only_figs=0; also_figs=0; 
	  } 	

FNR==NR { 														# FNR e NR sono contatori delle linee processate, FNR si resetta ad ogni nuovo file 
			if ( $1=="strip_comments" && $2==1 ) 				# per questo motivo saranno uguali solo processando il primo file 								
				strip_comments=1;								# le operazioni verranno eseguite solo per le linee del primo file (di configurazione)
			else if ( $1=="only_figs" && $2==1 ) 
				only_figs=1;
			else if ( $1=="also_figs" && $2==1 ) 
				also_figs=1;
				
			if ( only_figs==1 && also_figs==0 ) { print "Errore di configurazione: only_figs=1 e also_figs=0" > "/dev/stderr"; exit 0; }
		}
		
FNR+3==NR { FS=" "; }											# per lo stesso motivo, essendo il primo file sempre composto da 3 righe (anche se vuote)
																# le operazioni verranno eseguite solo per le linee del secondo file (di log)
																
																
																
END { 
		# print strip_comments, only_figs, also_figs 				#DEBUG
	}				




						#########################################################################################	
						#										APPUNTI											#
						#																						#
						# FS="=" --> field separator															#
						# NR --> record number																	#
						# FNR --> record number in the actual file												#
						# BEGIN { print "\nInizio dell'analisi del testo: \n"; ORS="\n---> done\n" }			#
						# { total=total+1 }																		#
						# /LANG/ { print "Riga numero " NR ": " $1, $3 }										#
						# END { ORS="\n"; print "\nRighe analizzate: " NR "\nRighe risultanti: " total "\n" }	#
						#																						#
						#########################################################################################
