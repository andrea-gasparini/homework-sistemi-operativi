#!/bin/awk -f

# @author Andrea Gasparini

BEGIN { 
		arguments=ARGV[1]																				# primo argomento dato dopo il nomefile (fuori dal for per evitare troppi " ")
		for ( i=2; i<ARGC; i++ ) arguments=arguments" "ARGV[i];											# concatena gli argomenti dati allo script in una stringa
		print "Eseguito con argomenti " arguments
		print "Eseguito con argomenti " arguments > "/dev/stderr"
		
		if ( length(ARGV[2])==0 ) { print "Errore: dare almeno 2 file di input" > "/dev/stderr"; exit 0; }	# se il secondo argomento è null (lunghezza zero)
		
		strip_comments=0; only_figs=0; also_figs=0;
	  } 	

FNR==NR {																								# FNR e NR sono contatori delle linee processate, FNR si resetta ad ogni nuovo file
			indexEqual=index($0,"=")																	# per questo motivo saranno uguali solo processando il primo file 								
			if ( substr($0,1,indexEqual-1)=="strip_comments" && substr($0,indexEqual+1)=="1" ) 			# le operazioni verranno eseguite solo per le linee del primo file (di configurazione)
				strip_comments=1;																		
			else if ( substr($0,1,indexEqual-1)=="only_figs" && substr($0,indexEqual+1)=="1" ) 
				only_figs=1;
			else if ( substr($0,1,indexEqual-1)=="also_figs" && substr($0,indexEqual+1)=="1" ) 
				also_figs=1; 
			
			if ( FNR==3 && only_figs==1 && also_figs==0 ) { print "Errore di configurazione: only_figs=1 e also_figs=0" > "/dev/stderr"; exit 0; }
		}		
		
FNR+3==NR   {																	# per lo stesso motivo, essendo il primo file sempre composto da 3 righe (anche se vuote)
				startIndex=index($0,"(."); texIndex=index($0,".tex")			# le operazioni verranno eseguite solo per le linee del secondo file (di log)
				newSubstr=$0

				if ( length(tmp)!=0 )
				{
					firstSpaceIndex=index($0," ");
					tmp=tmp""substr($0,1,firstSpaceIndex-1)
					if ( index(tmp,".tex")!=0 )
						print tmp
					newSubstr=substr($0,firstSpaceIndex)
					startIndex=index(newSubstr,"(."); texIndex=index(newSubstr,".tex")
					tmp=""
				}
				
				
				if ( startIndex>0 && texIndex>0 )
				{
					print substr(newSubstr,startIndex+1,texIndex-startIndex+3)
					newSubstr=substr($0,texIndex-startIndex+4)
					startIndex=index(newSubstr,"(."); texIndex=index(newSubstr,".tex")
					if ( startIndex>0 && texIndex>0 )
						print substr(newSubstr,startIndex+1,texIndex-startIndex+3)
					else if ( startIndex>0 && texIndex==0 )	
						tmp=substr(newSubstr,startIndex+1)
					
				}
				else if ( startIndex>0 && texIndex==0 )	
					tmp=substr(newSubstr,startIndex+1)				
			}	
			
