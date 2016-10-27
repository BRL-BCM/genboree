#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>

int main(int argc, char**argv) {
  int length;
  char *buffer;
  int i;
  char *seed = "rsync -avz --rsh='ssh -l root -F /root/.ssh/config -i /root/.ssh/brlKey'";
  int pos;
  int exitStatus;
 
  setuid(0);
  system("/bin/ls /root");
  length=0;
  for (i=1; i<argc; i++) {
    length+= strlen(argv[i])+1;
  }
  length+= strlen(seed)+1;
  printf("total length=%d\n", length);
  buffer = (char*)malloc(length*sizeof(char));
  sprintf(&buffer[0], "%s", seed);
  for (i=1; i<argc; i++) {
    pos = strlen(buffer);
    sprintf(&buffer[pos]," %s", argv[i]); 
  }
  printf("final command is |%s|\n", buffer);
  exitStatus = system(buffer);
  free(buffer);
  exit(WEXITSTATUS(exitStatus));
}
