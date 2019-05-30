#include <stdio.h>		// gestione I/O 
#include <string.h>		// gestione stringhe
#include <stdlib.h>		// allocazione memoria e utilizzo exit()
#include <dirent.h>		// gestione directory, scandir() e alphasort()
#include <unistd.h> 	// utilizzo getopt() e access()
#include <sys/stat.h>	// utilizzo stat()
#include <sys/vfs.h>	// utilizzo statfs() per x_bytes

struct options	// rappresenta le opzioni disponibili per il programma
{
	_Bool opt_d;
	_Bool opt_R;		// 0 = false, 1 = true
	_Bool opt_l;
	_Bool l_arg_value;	// argomento dell'opzione -l (0 -> permessi, hard link count, dimensione e nome
};						//							  1 -> permessi e nome)

void printDirR(char *, char *, struct options, int, int);

char** printDir(char *, char *, struct options, int, int);	// stampa e restituisce un array di stringhe con le folders

void printDirL(struct stat, _Bool, char*, char *);	// dati nome del file e relativo path, ne stampa permessi ed eventuale symlink

char* calcPermString(struct stat);	// restituisce una stringa che rappresenta i permessi del file/dir

char* createTmpDir(char *, char *);	// concatena due stringhe "dir" con un "/" nel mezzo

int compareStrings(const void *, const void *);	// funzione di comparazione stringhe per qsort()

_Bool isDirectory(char *); // ritorna 1 se path è una directory

_Bool isFile(char *); 	// ritorna 1 se path è un file

void printSysCallErr(char *); // stampa su sterr il perror dell'ultima SysCall & exit(100)

void printHelp(char *);	// printa su stderr la sintassi d'uso corretta del programma

int main(int argc, char *argv[])
{
	int opt; 
	struct options opts;
	opts.opt_d = 0;
	opts.opt_R = 0;
	opts.opt_l = 0;
	const int blocksize = getenv("BLOCKSIZE") == NULL ? 1024 : atoi(getenv("BLOCKSIZE"));
	int x_bytes = 4096;	// nel calcolo della riga total viene poi ricalcolato per ogni file 
	
    while((opt = getopt(argc, argv, ":dRl:")) != -1)	// ritorna -1 se non sono presenti altre opzioni
    {	
        switch(opt)  
        {  
            case 'd':  
				opts.opt_d = 1;	
                break; 
            case 'R':  
				opts.opt_R = 1;		
                break;  
            case 'l':  
				opts.opt_l = 1;
				if (optarg[0] == '0' && optarg[1] == '\0')	// argomento "mod" di -l
					opts.l_arg_value = 0;	// permessi, hard link count, dimensione e nome
				else
					opts.l_arg_value = 1;	// per qualsiasi altro valore solo permessi e nome
                break;  
            case ':':  					// caso in cui manchi l'argomento ad un opt che lo richiede (-l)
            case '?':  					// caso in cui venga passata un'opt non esistente
                printHelp(argv[0]);		// printa su stderr la sintassi d'uso corretta del programma
                break;  
        }  
    }
    
    int not_existing_files_cnt = 0;
    int file_cnt = 0;
    int folder_cnt = 0;
    int n_path_names = argc-optind;		// numero degli argomenti del cmd non compresi nelle opzioni
    if (n_path_names > 0)
    {
		char **path_names = malloc(n_path_names * sizeof(char *));
		if (path_names == NULL) printSysCallErr("malloc");

		for (int i = 0; optind < argc; optind++)
		{
			path_names[i] = malloc((strlen(argv[optind])+1) * sizeof(char));
			if (path_names[i] == NULL) printSysCallErr("malloc");
			strcpy(path_names[i++], argv[optind]);	// inserisce i restanti argomenti del comando (no opt) in un array
		}	
		
		for (int i = 0; i < n_path_names; i++)	// controlla che fra gli argomenti non ci siano file o dir non esistenti
			if (access(path_names[i], F_OK) == -1)
			{
				not_existing_files_cnt++;	// ne tiene il conto per dare exit status e stampa su stderr
				fprintf(stderr, "%s: cannot access '%s': No such file or directory\n", argv[0], path_names[i]);
				path_names[i] = realloc(path_names[i], (strlen("PATHCANCELLATO")+1) * sizeof(char));
				if (path_names[i] == NULL)	printSysCallErr("realloc");
				strcpy(path_names[i], "PATHCANCELLATO");	
			}
			
		qsort(path_names, n_path_names, sizeof(char *), compareStrings);	
			
		if (!opts.opt_d)
		{
			for (int i = 0; i < n_path_names; i++)	
				if (isFile(path_names[i]) == 1) // se e' un file
				{
					file_cnt++;
					if (opts.opt_l == 1) 	// se l'opzione -l e' stata data stampa anche le informazioni
					{						// permessi, hard link count, dimensione e nome || permessi e nome
						struct stat st;				
						if(lstat(path_names[i], &st) < 0)
							printSysCallErr("lstat");
						else
						{   
							char *perm_string = calcPermString(st);
							printDirL(st, opts.l_arg_value, path_names[i], path_names[i]); 
							free(perm_string);
						}		
					}
					else
						printf("%s\n", path_names[i]); 
					path_names[i] = realloc(path_names[i], (strlen("PATHCANCELLATO")+1) * sizeof(char));
					if (path_names[i] == NULL)	printSysCallErr("realloc");
					strcpy(path_names[i], "PATHCANCELLATO");
				}
			if (file_cnt > 0 && file_cnt < n_path_names) // se sono stati stampati nomi di file e ci sono altre dir da analizzare, separa con un \n
				printf("\n");
		}
				
		if (n_path_names == 1 && strcmp(path_names[0], "PATHCANCELLATO") != 0)	// se c'e' un solo argomento non printa "argomento:" prima del contenuto
		{
			opts.opt_R == 1 ? printDirR(path_names[0], argv[0], opts, blocksize, x_bytes) : free(printDir(path_names[0], argv[0], opts, blocksize, x_bytes));
			free(path_names[0]);
		}
		else
			for (int i = 0; i < n_path_names; i++)	
			{
				if (strcmp(path_names[i], "PATHCANCELLATO") != 0)
				{
					if (folder_cnt > 0 && !opts.opt_d && !opts.opt_R) 
						printf("\n");	// -d formatta file e folder senza \n
					if (!opts.opt_d && !opts.opt_R) 
						printf("%s:\n", path_names[i]);	// senza -d si printa "argomento:" prima di ognuno
					opts.opt_R == 1 ? printDirR(path_names[i], argv[0], opts, blocksize, x_bytes) : free(printDir(path_names[i], argv[0], opts, blocksize, x_bytes));
					folder_cnt++;
				}
				free(path_names[i]);
			}
		free(path_names);
	}
	else
    {
		char *dot_str = malloc(2 * sizeof(char));
		if (dot_str == NULL) printSysCallErr("malloc");						
		strcpy(dot_str, ".");	// [ '.', '\0' ]
		opts.opt_R == 1 ? printDirR(dot_str, argv[0], opts, blocksize, x_bytes) : free(printDir(dot_str, argv[0], opts, blocksize, x_bytes));	// se n_path_names e' 0 non sono state specificate directory, percio' si esegue su cwd
		free(dot_str);
	}

	exit(not_existing_files_cnt);
}	

int cntR = 0;

void printDirR(char *dir, char *program_name, struct options opts, int blocksize, int x_bytes)
{
	if (!opts.opt_d && cntR == 0)
	{
		printf("%s:\n", dir);
		cntR++;
	}
	else if (!opts.opt_d)
		printf("\n%s:\n", dir);
	char **sub_folders = printDir(dir, program_name, opts, blocksize, x_bytes);	
	if (sub_folders == NULL) 
		return;
	for (int i = 0; sub_folders[i] != NULL; i++)	// l'ultimo elemento e' stato impostato a NULL
	{
		printDirR(sub_folders[i], program_name, opts, blocksize, x_bytes);
		free(sub_folders[i]);
	}
	free(sub_folders);
}

char** printDir(char *dir, char *program_name, struct options opts, int blocksize, int x_bytes)
{
	int cnt_sub_folders = 0;
	char **sub_folders = NULL;	// ** malloc = n elementi
								// * malloc = length elemento	
	if (opts.opt_d == 1)
	{
		if (opts.opt_l == 1) 	// se l'opzione -l e' stata data stampa anche le informazioni
		{						// permessi, hard link count, dimensione e nome || permessi e nome
			struct stat st;				
			if(lstat(dir, &st) < 0)
				printSysCallErr("lstat");
			else
				printDirL(st, opts.l_arg_value, dir, dir);
		}
		else
			printf("%s\n", dir); 
	}
	else
	{
		struct dirent **name_list;
		int n = scandir(dir, &name_list, 0, alphasort);	// numero di elementi presenti nella cwd
		if (n < 0) 
			printSysCallErr("scandir");
		else 
		{
			if (opts.opt_l == 1)
			{						// con -l prima di tutto stampa la riga total
				int total = 0;
				int tmp_total= 0;
				for (int i = 0; i < n; i++) 	
				{
					if ((strcmp(name_list[i]->d_name, ".") != 0) &&	// filtra la cwd
					(strcmp(name_list[i]->d_name, "..") != 0) &&	// filtra la dir superiore
					(name_list[i]->d_name[0] != '.'))				// filtra i file nascosti (che hanno '.' come primo char)
					{
						struct stat st;
						char *tmp_dir = createTmpDir(dir, name_list[i]->d_name);
						if(lstat(tmp_dir, &st) < 0)
							printSysCallErr("lstat");
						else
						{ 
							if (!S_ISLNK(st.st_mode)) // se non e' un link simbolico
							{
								struct statfs stfs;
								if (statfs(tmp_dir, &stfs) < 0) printSysCallErr("statft");
								x_bytes = (int) stfs.f_bsize;
								tmp_total = st.st_size == x_bytes ? st.st_size/x_bytes : (st.st_size/x_bytes)+1;
								total += tmp_total*x_bytes;
							}
						}
						free(tmp_dir);
					}
				}
				printf("total %d\n", total/blocksize);
			}
			
			for (int i = 0; i < n; i++) 	
			{								
				if ((strcmp(name_list[i]->d_name, ".") != 0) &&	// filtra la cwd
				(strcmp(name_list[i]->d_name, "..") != 0) &&	// filtra la dir superiore
				(name_list[i]->d_name[0] != '.'))				// filtra i file nascosti (che hanno '.' come primo char)
				{
					if (opts.opt_l == 1) 	// se l'opzione -l e' stata data stampa anche le informazioni
					{					// permessi, hard link count, dimensione e nome || permessi e nome
						struct stat st;
						char *tmp_dir = createTmpDir(dir, name_list[i]->d_name);
						if(lstat(tmp_dir, &st) < 0) 
							printSysCallErr("lstat");
						else
							printDirL(st, opts.l_arg_value, name_list[i]->d_name, tmp_dir);
						free(tmp_dir);
					}
					else
						printf("%s\n", name_list[i]->d_name); 
						
					char *tmp_dir = createTmpDir(dir, name_list[i]->d_name);
					if (opts.opt_R && isDirectory(tmp_dir))	// sub_folder su cui applicare -R
					{
						sub_folders = realloc(sub_folders, (cnt_sub_folders+2) * sizeof(char *));	// spazio per allocare un NULL
						if (sub_folders == NULL) printSysCallErr("realloc");
						sub_folders[cnt_sub_folders] = malloc((strlen(tmp_dir)+1) * sizeof(char));	// lunghezza nome folder
						if (sub_folders[cnt_sub_folders] == NULL) printSysCallErr("malloc");
						sub_folders[cnt_sub_folders+1] = NULL;	// necessario per tenere conto successivamente del n di el.
						strcpy(sub_folders[cnt_sub_folders], tmp_dir);
						cnt_sub_folders++;
					}
					free(tmp_dir);
				}
			}
			for (int i = 0; i < n; i++) 
					free(name_list[i]); 
			free(name_list);
		}
	}
	return sub_folders;
}

void printDirL(struct stat st, _Bool l_arg_value, char *name, char *path) // dati nome del file e relativo path, ne stampa permessi ed eventuale symlink
{
	char *perm_string = calcPermString(st);
	if (l_arg_value == 0)		// con mod = 0 -> permessi, hard link count, dimensione e nome
		printf("%s\t%d\t%d\t%s", perm_string, (int) st.st_nlink, (int) st.st_size, name); 
	else 							// con mod != 0 -> permessi e nome
		printf("%s\t%s", perm_string, name); 
	if (S_ISLNK(st.st_mode))
	{
		int link_string_size = st.st_size + 1;
		char *link_string = malloc(link_string_size * sizeof(char));
		if (link_string == NULL) printSysCallErr("malloc");
		int nbytes = (int) readlink(path, link_string, link_string_size);
		if (nbytes < 0) 
			printSysCallErr("readlink");
		printf(" -> %.*s\n", nbytes, link_string);
		free(link_string);
	}
	else
		printf("\n");
	free(perm_string);
}

char* createTmpDir(char *s1, char *s2)
{
	char *tmp_dir = malloc((strlen(s1)+strlen(s2)+2) * sizeof(char));
	if (tmp_dir == NULL) printSysCallErr("malloc");
	strcpy(tmp_dir, s1);
	strcat(tmp_dir, "/");
	strcat(tmp_dir, s2);
	return tmp_dir;
}

int compareStrings(const void *s1, const void *s2)
{
	const char *ps1 = *(const char**)s1;
	const char *ps2 = *(const char**)s2;
	return strcmp(ps1, ps2);
}

char* calcPermString(struct stat st)
{
	char *perm_string = malloc(11 * sizeof(char *));
	if (perm_string == NULL) printSysCallErr("malloc");
	perm_string[0] = (S_ISLNK(st.st_mode)) ? 'l' : ((S_ISDIR(st.st_mode)) ? 'd' : '-');
	perm_string[1] = (S_IRUSR & st.st_mode) ? 'r' : '-';
	perm_string[2] = (S_IWUSR & st.st_mode) ? 'w' : '-';
	perm_string[3] = (S_IXUSR & st.st_mode) ? ((S_ISUID & st.st_mode) ? 's' : 'x') : ((S_ISUID & st.st_mode) ? 'S' :  '-');
	perm_string[4] = (S_IRGRP & st.st_mode) ? 'r' : '-';
	perm_string[5] = (S_IWGRP & st.st_mode) ? 'w' : '-';
	perm_string[6] = (S_IXGRP & st.st_mode) ? ((S_ISGID & st.st_mode) ? 's' : 'x') : ((S_ISGID & st.st_mode) ? 'S' : '-');
	perm_string[7] = (S_IROTH & st.st_mode) ? 'r' : '-';
	perm_string[8] = (S_IWOTH & st.st_mode) ? 'w' : '-';
	perm_string[9] = (S_IXOTH & st.st_mode) ? ((S_ISVTX & st.st_mode) ? 't' : 'x') : ((S_ISVTX & st.st_mode) ? 'T' : '-');
	perm_string[10] = '\0';
	return perm_string;
}

_Bool isDirectory(char *path)	// ritorna 1 se path è una directory
{
	struct stat st;
	return stat(path, &st) != 0 ? 0 : S_ISDIR(st.st_mode);	// is a directory
}

_Bool isFile(char *path)	// ritorna 1 se path è un file
{
	struct stat st;
	return stat(path, &st) != 0 ? 0 : S_ISREG(st.st_mode);	// is a regular file
}

void printSysCallErr(char *system_call_name) // stampa su standard error l'errore della SysCall & exit(100)
{
	fprintf(stderr, "System call %s failed because of: ", system_call_name);
	perror("");
	exit(100);
}

void printHelp(char *program_name)	// printa su stderr la sintassi corretta
{
	fprintf(stderr, "Usage: %s [-dR] [-l mod] [files]\n", program_name);
	exit(20);
}
