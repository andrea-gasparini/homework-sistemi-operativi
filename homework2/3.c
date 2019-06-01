#include <stdio.h>		// gestione I/O 
#include <string.h>		// gestione stringhe
#include <stdlib.h>		// allocazione memoria e utilizzo exit()
#include <unistd.h> 	// utilizzo getopt() e access()
#include <math.h>		// utilizzo pow()
#include <unistd.h>		// utilizzo exec*()
#include <sys/wait.h>	// utilizzo wait()
#include <sys/stat.h>

/**
 * @author Andrea Gasparini
 */
 
int writeToFileOut(int cnt, FILE *tmp_awk, FILE *out, int i1, int i2);	// scrive sul file di out e offusca i caratteri compresi tra i1 e i2

void printErr30(char *f_in, char *f_out); // stampa su stderr l'errore 30 e crea un file vuoto

void printSysCallErr(char *); // stampa su stderr il perror dell'ultima SysCall & exit(100)

int main(int argc, char **argv)
{
	int i1 = atoi(argv[4]);
	int i2 = atoi(argv[5]);
	
	if (argc != 6)	// 5 argomenti richiesti (+ il nome del programma)
	{
		fprintf(stderr, "Usage: %s filein fileout awk_script i1 i2\n", argv[0]);
		exit(10);
	}
	
	if (access(argv[1], F_OK) != 0 || access(argv[1], R_OK) != 0)	// se filein non esiste o non è accessibile in lettura
	{
		fprintf(stderr, "Unable to open file %s because of: ", argv[1]);
		perror("");
		exit(20);
	}
	
	unsigned char n_bytes[8];	// i primi 8 byte 
	FILE *stream = fopen(argv[1],"rb");	// apertura del file in lettura per file binari
	if (stream == NULL) printSysCallErr("fopen");	
	if (fread(n_bytes, 4, 2, stream) < 0) printSysCallErr("fread");	// lettura dei primi 2 elementi da 4 byte	
	
	struct stat st;
	if (stat(argv[1], &st) < 0) printSysCallErr("stat");
	if (st.st_size < 8) printErr30(argv[1], argv[2]);	// se f_in non e' ben formattato (contiene meno di 8 byte)
	
	int n_values[2];
	for (int i = 0; i < sizeof(n_bytes); i += 4)	// conversione dei due interi 
		n_values[i/4] = n_bytes[i] + (int)n_bytes[i+1] * (int)pow(2, 8) +
						(int)n_bytes[i+2] * (int)pow(2, 16) + (int)n_bytes[i+3] * (int)pow(2, 24);
						
	if (st.st_size < (8 + n_values[0] + n_values[1])) printErr30(argv[1], argv[2]); // se f_in non e' ben formattato (contiene meno di n1 + n2 + 8 byte)
	
	FILE *tmp = fopen("tmp", "w");	// file temporaneo in cui va il contentuto di f_in "deoffuscato"
	if (tmp == NULL) 
	{
		fprintf(stderr, "Unable to open file %s because of: ", argv[2]);
		perror("");
		exit(70);
	}
	
	unsigned char n1_bytes[n_values[0]], n2_bytes[n_values[1]], others[1];
	if (fread(n1_bytes, 1, n_values[0], stream) < 0) printSysCallErr("fread");
	for (int i = 0; i < n_values[0]; i++) // lettura primi n1 byte
		fprintf(tmp, "%c", (char) n1_bytes[i]);
	
	if (fread(n2_bytes, 1, n_values[1], stream) < 0) printSysCallErr("fread");
	for (int i = 0; i < n_values[1]; i++) // lettura byte da complementare
		fprintf(tmp, "%c", (char) ~n2_bytes[i]);
	
	while(1 == fread(others, 1, 1, stream)) // lettura byte rimanenti
		fprintf(tmp, "%c", (char) others[0]);
		
	fclose(tmp);
	fclose(stream);
	
	FILE *tmp_out_awk = fopen("tmp_out_awk", "w+");	// file temporaneo per lo stdout di awk
	if (tmp_out_awk == NULL) printSysCallErr("fopen");
	int fd_tmp_out_awk = fileno(tmp_out_awk);
	
	FILE *tmp_err_awk = fopen("tmp_err_awk", "w+");	// file temporaneo per lo stderr di awk
	if (tmp_err_awk == NULL) printSysCallErr("fopen");
	int fd_tmp_err_awk = fileno(tmp_err_awk);
	
	pid_t pid_figlio = fork();
	if (pid_figlio < 0)
		printSysCallErr("fork");
	else if (pid_figlio == (pid_t) 0)
	{
		dup2(fd_tmp_out_awk, 1);
		dup2(fd_tmp_err_awk, 2);
		execl("/usr/bin/gawk", "gawk", argv[3], "tmp", (char *) NULL);	
	}
	
	wait(NULL);	// sospende il processo corrente finche' il figlio non termina
	FILE *out = fopen(argv[2], "wb");	// file finale di output
	if (out == NULL) printSysCallErr("fopen");
	
	rewind(tmp_out_awk);
	rewind(tmp_err_awk);
	
	struct stat st_out, st_err;
	if (stat("tmp_out_awk", &st_out) < 0) printSysCallErr("stat");
	if (stat("tmp_err_awk", &st_err) < 0) printSysCallErr("stat");
	
	_Bool exit80 = 0;
	
	if (st_out.st_size + st_err.st_size < i1 +i2)	// se la risposta di awk non ha almeno i1+i2 bytes
	{
		int new_bytes[] = {0, 0};
		fwrite(new_bytes, 1, 8, out);
		exit80 = 1;
	}
	else
	{
		fwrite(&i1, 1, 4, out);
		fwrite(&i2, 1, 4, out);
	}
	
	int cnt = 8;
	cnt = writeToFileOut(cnt, tmp_out_awk, out, i1, i2);
	cnt = writeToFileOut(cnt, tmp_err_awk, out, i1, i2);
	
	fclose(tmp_out_awk);
	fclose(tmp_err_awk);
	fclose(out);
	remove("tmp");
	remove("tmp_out_awk");
	remove("tmp_err_awk");
	
	exit80 ? exit(80) : exit(0);
}

int writeToFileOut(int cnt, FILE *tmp_awk, FILE *out, int i1, int i2) // scrive sul file di out e offusca i caratteri compresi tra i1 e i2
{
	unsigned char ch[1];
	while(1 == fread(ch, 1, 1, tmp_awk))
	{
		if (cnt >= (8 + i1) && cnt < (8 + i1 +i2))
		{
			unsigned char compl[1];
			compl[0] = ~ch[0];
			fwrite(&compl[0], 1, 1, out);
		}
		else
			fwrite(&ch[0], 1, 1, out);
		cnt++;
	}
	return cnt;
}

void printErr30(char *f_in, char *f_out) // stampa su stderr l'errore 30 e crea un file vuoto
{
	fprintf(stderr, "Wrong format for input binary file %s\n", f_in);
	FILE *out = fopen(f_out, "w");	// file finale di output di dimensione 0
	if (out == NULL) printSysCallErr("fopen");
	fclose(out);
	exit(30);
}

void printSysCallErr(char *system_call_name) // stampa su standard error l'errore della SysCall & exit(100)
{
	fprintf(stderr, "System call %s failed because of: ", system_call_name);
	perror("");
	exit(100);
}
