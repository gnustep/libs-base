
#include "foundation/NSMethodSignature.h"
#include "objc/objc-malloc.h"

static int
types_get_size_of_arguments(const char *types)
{
  const char* type = objc_skip_typespec (types);
  return atoi (type);
}

static int
types_get_number_of_arguments (const char *types)
{
  int i = 0;
  const char* type = types;
  while (*type)
    {
      type = objc_skip_argspec (type);
      i += 1;
    }
  return i - 1;
}

@implementation NSMethodSignature

+ (NSMethodSignature*) signatureWithObjCTypes: (const char*)types
{
  int len;
  NSMethodSignature *newMs = [NSMethodSignature alloc];
  len = strlen(types);
  OBJC_MALLOC(newMs->types, char, len);
  bcopy(types, newMs->types, len);
  len = str??();
  OBJC_MALLOC(newMs->returnTypes, char, len);
  bcopy(types, newMs->returnTypes, len);
  newMs->argFrameLength = types_get_size_of_arguments(types);
  newMs->returnFrameLength = objc_size_of_type(types);
  newMs->numArgs = types_get_number_of_arguments(types);
  return newMs;
}

- (NSArgumentInfo) argumentInfoAtIndex: (unsigned)index
{
  return 0;
}

- (unsigned) frameLength
{
  return argFrameLength;
}

- (BOOL) isOneway
{
  [self notImplemented:_cmd];
  return NO;
}

- (unsigned) methodReturnLength
{
  return returnFrameLength;
}

- (char*) methodReturnType
{
  return "";
}

- (unsigned) numberOfArguments
{
  return numArgs;
}

- free
{
  OBJC_FREE(types);
  return [super free];
}

@end
