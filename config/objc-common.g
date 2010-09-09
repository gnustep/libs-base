/* Common information for all objc runtime tests.
 */
#include <objc/objc.h>
#include <objc/objc-api.h>

#include <objc/Object.h>

#ifdef __GNUSTEP_RUNTIME__
#include <objc/hooks.h>
#endif

#if !defined(NeXT_RUNTIME) && !defined(__GNUSTEP_RUNTIME__)
@implementation NXConstantString
- (const char*) cString
{
  return 0;
}
- (unsigned int) length
{
  return 0;
}
@end
#endif

/* Provide dummy implementations for NSObject and NSConstantString
 * for runtime implementations which won't link without them.
 */

@interface NSObject 
 id isa;
@end
@implementation NSObject
@end

@interface NSConstantString : NSObject
@end
@implementation NSConstantString
@end
