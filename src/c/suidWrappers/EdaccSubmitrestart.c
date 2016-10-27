#include <stdlib.h>
#include <unistd.h>

// Compile:  gcc -O3 -fPIC -o EdaccSubmitrestart EdaccSubmitrestart.c
// Ensure:   mkdir /usr/local/brl/local/bin/private
//           chmod 550 /usr/local/brl/local/bin/private
//           chown genbadmin:genbadmingrp /usr/local/brl/local/bin/private
// Deploy:   cp EdaccSubmitrestart /usr/local/brl/local/bin/private/
//           chmod 550 /usr/local/brl/local/bin/private/EdaccSubmitrestart


int main()
{
	setuid(0);

	execl("/usr/local/brl/local/etc/init.d/EdaccSubmit_init", "EdaccSubmit_restart", "restart", NULL);

	exit(0); /* <-- never reached */
}
