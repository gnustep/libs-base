/* A demonstration of writing and reading with NSArchiver */

#include <Foundation/NSArchiver.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSUtilities.h>

int main()
{
  id set;
  id arp;
  
  arp = [[NSAutoreleasePool alloc] init];

  /* Create a Set of int's */
  set = [[NSSet alloc] initWithObjects:
	  @"apple", @"banana", @"carrot", @"dal", @"escarole", @"fava", nil];

  /* Display the set */
  printf("Writing:\n");
  {
    id o, e = [set objectEnumerator];
    while ((o = [e nextObject]))
      printf("%@\n", o);    
  }

  /* Write it to a file */
  [NSArchiver archiveRootObject: set toFile: @"./nsarchiver.dat"];

  /* Release the object that was coded */
  [set release];

  /* Read it back in from the file */
  set = [NSUnarchiver unarchiveObjectWithFile: @"./nsarchiver.dat"];

  /* Display what we read, to make sure it matches what we wrote */
  printf("\nReading:\n");
  {
    id o, e = [set objectEnumerator];
    while (o = [e nextObject])
      printf("%@\n", o);    
  }

  /* Do the autorelease. */
  [arp release];
  
  exit(0);
}
