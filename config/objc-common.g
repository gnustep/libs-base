/* Common information for all objc runtime tests.
 */
#include <objc/objc.h>
#include <objc/objc-api.h>

#include <objc/Object.h>

#ifndef NeXT_RUNTIME
#include <objc/NXConstStr.h>
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

@interface NSObject : Object
@end
@implementation NSObject
@end

@interface NSConstantString : NSObject
@end
@implementation NSConstantString
@end
