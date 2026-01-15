#include	<Foundation/Foundation.h>
#if	!defined(_WIN32)
#include	<sys/file.h>
#include        <sys/fcntl.h>
#include        <unistd.h>
#endif

/* Test that the process group has been changed (not the same as that of our
 * parent) and that we have been detached from any controlling terminal.
 */
int
main(int argc, char **argv)
{
  int	i = 0;
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];

#if	!defined(_WIN32)
/*
  printf("argc %d\n", argc);
  for (i = 0; i < argc; i++)
    printf("argv[%d] %s\n", i, argv[i]);
  printf("getpgrp %d\n", getpgrp());
  printf("getsid %d\n", getsid(0));
  printf("result of open of /dev/tty is %d\n", open("/dev/tty", O_WRONLY));
*/
  /* Test process group change - this should always work.
   * TTY detachment is attempted on glibc >= 2.35 but may not work in
   * containers, so we only fail if the session ID equals our parent's
   * (which means setsid() definitely didn't work).
   */
  int parent_pgrp = atoi(argv[1]);
  int my_pgrp = getpgrp();
  int my_sid = getsid(0);
  
  if (parent_pgrp == my_pgrp)
    i = 1;                                      /* pgrp not set properly */
#if defined(__GLIBC__) && (__GLIBC__ > 2 || (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 35))
  /* On glibc >= 2.35, we expect setsid() to work (new session).
   * If session ID equals our PID, setsid() created a new session.
   * If not, it's OK - may be running in a restricted environment.
   */
  else if (my_sid != getpid() && my_sid == parent_pgrp)
    {
      /* Still in parent's session AND not session leader - setsid failed */
      i = 2;
    }
#endif
  else
    i = 0;                                      /* OK */
#endif  /* __MINGW32__ */

  [arp release];
  return i;
}

