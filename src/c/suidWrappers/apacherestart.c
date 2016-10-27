#include <stdlib.h>
#include <unistd.h>

int main()
{
	setuid(0);

	execl("/usr/local/brl/local/etc/init.d/apachectl", "httpd_restart", "restart", NULL);

	exit(0); /* <-- never reached */
}

