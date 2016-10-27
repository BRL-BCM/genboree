#include <stdlib.h>
#include <unistd.h>

// Compile:   gcc -O3 -fPIC -o galaxyrestart galaxyrestart.c
//            chmod 440 galaxyrestart
// Ensure:    mkdir /usr/local/brl/local/bin/private
//            chmod 2550 /usr/local/brl/local/bin/private
//            chown genbadmin:genbadmingrp /usr/local/brl/local/bin/private
// Deploy:    cp galaxyrestart /usr/local/brl/local/bin/private/
//            chmod 4550 /usr/local/brl/local/bin/private/galaxyrestart

int main()
{
	setuid(0);

	execl("/usr/local/brl/local/etc/init.d/galaxy_init", "galaxy_restart", "restart", NULL);

	exit(0); /* <-- never reached */
}
