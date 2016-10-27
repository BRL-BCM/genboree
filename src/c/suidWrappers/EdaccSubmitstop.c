#include <stdlib.h>
#include <unistd.h>

// Compile:  gcc -O3 -fPIC -o EdaccSubmitstop EdaccSubmitstop.c
// Ensure:   mkdir /usr/local/brl/local/bin/private
//           chmod 550 /usr/local/brl/local/bin/private
//           chown genbadmin:genbadmingrp /usr/local/brl/local/bin/private
// Deploy:   cp EdaccSubmitstop /usr/local/brl/local/bin/private/
//           chmod 550 /usr/local/brl/local/bin/private/EdaccSubmitstop


int main()
{
	setuid(0);

	execl("/usr/local/brl/local/etc/init.d/EdaccSubmit_init", "EdaccSubmit_stop", "stop", NULL);

	exit(0); /* <-- never reached */
}
