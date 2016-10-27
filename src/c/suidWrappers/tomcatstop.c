#include <stdlib.h>
#include <unistd.h>

int main()
{
	setuid(0);

	execl("/usr/local/brl/local/etc/init.d/tomcat", "tomcat_stop", "stop", NULL);

	exit(0); /* <-- never reached */
}

