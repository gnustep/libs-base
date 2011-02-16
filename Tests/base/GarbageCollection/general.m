#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int
main()
{
  NSGarbageCollector	*collector = [NSGarbageCollector defaultCollector];
  NSZone		*z;

  if (collector == nil) return 0;	// No garbage collection.

  PASS([collector zone] == NSDefaultMallocZone(),
    "collector zone is default");
  PASS([[NSObject new] zone] == NSDefaultMallocZone(),
    "object zone is default");
  PASS((z = NSCreateZone(1024, 128, YES)) == NSDefaultMallocZone(),
    "created zone is default");
  PASS((z = NSCreateZone(1024, 128, YES)) == NSDefaultMallocZone(),
    "created zone is default");
  NSRecycleZone(z);

  return 0;
}
