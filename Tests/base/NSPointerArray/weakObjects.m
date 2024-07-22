#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSPointerArray.h>
#if __has_include(<objc/capabilities.h>)
#include <objc/capabilities.h>
#endif

int main()
{
  START_SET("NSPointerArray weak objects")
#if !__APPLE__  // We assume that apple systems support zeroing weak pointers
#ifdef OBJC_CAP_ARC
  if (!objc_test_capability(OBJC_CAP_ARC))
#endif
  {
    SKIP("ARC support unavailable")
  }
#endif
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSPointerArray        *array = [NSPointerArray weakObjectsPointerArray];
  int                   index;
  NSAutoreleasePool     *arp2 = [NSAutoreleasePool new];

  id testObj = [[[NSObject alloc] init] autorelease];
  for (index = 0; index < 10; index++)
    {
      [array addPointer: testObj];
    }
  PASS([[array allObjects] count] == index,
    "Array retains active weak reference");

  [arp2 release]; arp2 = nil;

  PASS([[array allObjects] count] == 0,
    "Array removes dead weak reference");

  [arp release]; arp = nil;
  END_SET("NSPointerArray weak objects")
  return 0;
}
