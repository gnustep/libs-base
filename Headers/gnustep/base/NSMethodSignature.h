#ifndef __NSMethodSignature_h_INCLUDE_GNU
#define __NSMethodSignature_h_INCLUDE_GNU

#include <foundation/NSObject.h>

@interface NSMethodSignature : NSObject
{
  char *types;
  char *returnTypes;
  unsigned argFrameLength;
  unsigned returnFrameLength;
  unsigned numArgs;
}

+ (NSMethodSignature*) signatureWithObjCTypes: (const char*)types;

- (NSArgumentInfo) argumentInfoAtIndex: (unsigned)index;
- (unsigned) frameLength;
- (BOOL) isOneway;
- (unsigned) methodReturnLength;
- (char*) methodReturnType;
- (unsigned) numberOfArguments;

@end

#endif /* __NSMethodSignature_h_INCLUDE_GNU */
