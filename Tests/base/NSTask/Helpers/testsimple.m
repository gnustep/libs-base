#import <Foundation/Foundation.h>

/* Simple helper program that exits with a specific code
 * Usage: testsimple [exit_code]
 * Default exit code is 0
 */
int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  int exitCode = 0;
  
  if (argc >= 2)
    {
      exitCode = atoi(argv[1]);
    }
  
  GSPrintf(stdout, @"Exiting with code %d\n", exitCode);
  fflush(stdout);
  
  [arp release];
  return exitCode;
}
