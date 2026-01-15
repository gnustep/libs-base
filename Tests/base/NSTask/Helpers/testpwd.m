#import <Foundation/Foundation.h>

/* Helper program that prints the current working directory
 * Used to test that setCurrentDirectoryPath works correctly with posix_spawn
 */
int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSString *currentDir = [mgr currentDirectoryPath];
  
  GSPrintf(stdout, @"%@\n", currentDir);
  fflush(stdout);
  
  [arp release];
  return 0;
}
