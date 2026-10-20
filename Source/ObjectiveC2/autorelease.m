
/* Emulation of the ARC runtime's autorelease pool functions for runtimes
 * which don't provide them, implemented with NSAutoreleasePool objects.
 */

#import "common.h"
#import "Foundation/NSAutoreleasePool.h"

void *
objc_autoreleasePoolPush(void)
{
  return [NSAutoreleasePool new];
}

void
objc_autoreleasePoolPop(void *pool)
{
  /* Releasing a pool also releases any pools created after it.
   */
  [(NSAutoreleasePool*)pool release];
}
