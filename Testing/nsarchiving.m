#include <foundation/NSArchiver.h>
#include <foundation/NSArray.h>
#include <foundation/NSString.h>

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
