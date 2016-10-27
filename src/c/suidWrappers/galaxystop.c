#include <stdlib.h>
#include <unistd.h>

// Compile:   gcc -O3 -fPIC -o galaxystop galaxystop.c
//            chmod 440 galaxystop
// Ensure:    mkdir /usr/local/brl/local/bin/private
//            chmod 2550 /usr/local/brl/local/bin/private
//            chown genbadmin:genbadmingrp /usr/local/brl/local/bin/private
// Deploy:    cp galaxystop /usr/local/brl/local/bin/private/
//            chmod 4550 /usr/local/brl/local/bin/private/galaxystop

int main()
{
	setuid(0);

	execl("/usr/local/brl/local/etc/init.d/galaxy_init", "galaxy_stop", "stop", NULL);

	exit(0); /* <-- never reached */
}
