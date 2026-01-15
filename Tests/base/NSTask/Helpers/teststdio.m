#import <Foundation/Foundation.h>
#include <stdio.h>

/* Helper program that tests stdin/stdout/stderr redirection
 * Reads from stdin and writes to stdout and stderr
 */
int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  char buffer[1024];
  
  // Write to stdout
  GSPrintf(stdout, @"STDOUT: Ready to read\n");
  fflush(stdout);
  
  // Read from stdin
  if (fgets(buffer, sizeof(buffer), stdin) != NULL)
    {
      // Echo to stdout
      GSPrintf(stdout, @"STDOUT: %s", buffer);
      fflush(stdout);
      
      // Echo to stderr
      GSPrintf(stderr, @"STDERR: %s", buffer);
      fflush(stderr);
    }
  
  [arp release];
  return 0;
}
