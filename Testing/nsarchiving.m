#include <Foundation/NSArchiver.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>

int
main ()
{
  id a = [NSArray arrayWithObjects:
		  [NSObject class],
		  [NSArray class],
		  nil];
  [NSArchiver archiveRootObject:a toFile:@"./nsarchiving.data"];
  [a release];

  /* NSUnarchiver not available yet. */

  exit (0);
}
