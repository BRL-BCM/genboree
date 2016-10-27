#include <stdlib.h>
#include <unistd.h>

// Compile:  gcc -O3 -fPIC -o pipeline_runnerstart pipeline_runnerstart.c
// Ensure:   mkdir /usr/local/brl/local/bin/private
//           chmod 550 /usr/local/brl/local/bin/private
//           chown genbadmin:genbadmingrp /usr/local/brl/local/bin/private
// Deploy:   cp pipeline_runnerstart /usr/local/brl/local/bin/private/
//           chmod 550 /usr/local/brl/local/bin/private/pipeline_runnerstart

int main()
{
	setuid(0);

	execl("/usr/local/brl/local/etc/init.d/pipeline_runner_init", "pipeline_runner_start", "start", NULL);

	exit(0); /* <-- never reached */
}
