#ifndef __Invocation_h_OBJECTS_INCLUDE
#define __Invocation_h_OBJECTS_INCLUDE

/* 
   Use these for notifications!
   Don't forget to make these archivable / transportable.
   WARNING: All the (char*) type arguments and return values may
   extraneous stuff after the first type.
*/

#include <objects/stdobjects.h>
#include <objects/Collection.h>

@interface Invocation : NSObject
{
  char *encoding;
  unsigned return_size;
  void *return_value;
}
- initWithReturnType: (const char *)encoding;
- (void) invoke;
- (void) invokeWithObject: anObj;
- (const char *) returnType;
- (unsigned) returnSize;
- (void) getReturnValue: (void*) addr;
@end

@interface ArgframeInvocation : Invocation
{
  arglist_t argframe;
  /* char *function_encoding; Using return_encoding */
}
- initWithArgframe: (arglist_t)frame type: (const char *)e;
- initWithType: (const char *)e;
- (const char *) argumentTypeAtIndex: (unsigned)i;
- (unsigned) argumentSizeAtIndex: (unsigned)i;
- (void) getArgument: (void*)addr atIndex: (unsigned)i;
- (void) setArgumentAtIndex: (unsigned)i 
    toValueAt: (const void*)addr;
@end

@interface MethodInvocation : ArgframeInvocation
- initWithArgframe: (arglist_t)frame selector: (SEL)s;
- initWithSelector: (SEL)s;
- initWithTarget: target selector: (SEL)s, ...;
- (void) invokeWithTarget: t;
- (SEL) selector;
- (void) setSelector: (SEL)s;
- target;
- (void) setTarget: t;
@end

@interface VoidFunctionInvocation : Invocation
{
  void (*function)();
}
- initWithFunction: (void(*)())f;
@end

#if 0

@interface VoidObjectFunctionInvocation : Invocation
{
  void (*function)(id);
  id object;
}
- initWithFunction: (void(*)())f;
@end

@interface ObjectObjectFunctionInvocation : Invocation
{
  id (*function)(id);
}
- initWithFunction: (void(*)())f;
@end

@interface FunctionInvocation : ArgframeInvocation
{
  void (*function)();
}
- initWithFunction: (void(*)())f
    argframe: (arglist_t)frame type: (const char *)e;
- initWithFunction: (void(*)())f;
@end

#endif

#endif /* __Invocation_h_OBJECTS_INCLUDE */
