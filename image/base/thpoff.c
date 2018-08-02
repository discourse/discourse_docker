// PUBLIC DOMAIN CODE
//
// A tiny program that disable transparent huge pages on arbitrary processes
// thpoff echo 1 : will run echo 1 with SET_THP_DISABLE true on the process
#include <stdio.h>
#include <sys/prctl.h>
#include <unistd.h>
#include <errno.h>

int main( int argc, char **argv) {
    if (argc < 2) {
	fprintf(stderr, "ERROR: expecting at least 1 argument!\n");
	return -1;
    }
    prctl(PR_SET_THP_DISABLE, 1, 0, 0, 0);

    char* newargv[argc];
    int i;

    newargv[argc-1] = NULL;
    for (i=1; i<argc; i++) {
	newargv[i-1] = argv[i];
    }

    execvp(argv[1], newargv);

    if (errno == ENOENT) {
	fprintf(stderr, "ERROR: file not found\n");
	return -1;
    } else if (errno == EACCES) {
	fprintf(stderr, "ERROR: can not run file\n");
	return -1;
    } else if (errno > 0) {
	fprintf(stderr, "ERROR: %i errno while attempting to run file\n", errno);
	return -1;
    }

    return 0;
}
