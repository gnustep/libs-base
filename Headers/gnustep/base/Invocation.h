#ifndef __Invocation_h_GNUSTEP_BASE_INCLUDE
#define __Invocation_h_GNUSTEP_BASE_INCLUDE

/* 
   Use these for notifications!
   Don't forget to make these archivable / transportable.
   WARNING: All the (char*) type arguments and return values may
   extraneous stuff after the first type.
*/

#include <gnustep/base/preface.h>
#include <gnustep/base/Collection.h>
#include <gnustep/base/Invoking.h>

@interface Invocation : NSObject <Invoking>
{
  char *return_type;		/* may actually contain full argframe type */
  unsigned return_size;
  void *return_value;
}
- initWithReturnType: (const char *)encoding;
- (const char *) returnType;
- (unsigned) returnSize;
- (void) getReturnValue: (void*) addr;
@end

@interface ArgframeInvocation : Invocation
{
  arglist_t argframe;
  BOOL args_retained;
  /* Use return_type to hold full argframe type. */
}
- initWithArgframe: (arglist_t)frame type: (const char *)e;
- initWithType: (const char *)e;

- (void) retainArguments;
- (BOOL) argumentsRetained;

- (const char *) argumentTypeAtIndex: (unsigned)i;
- (unsigned) argumentSizeAtIndex: (unsigned)i;
- (void) getArgument: (void*)addr atIndex: (unsigned)i;
- (void) setArgumentAtIndex: (unsigned)i 
    toValueAt: (const void*)addr;
@end

@interface MethodInvocation : ArgframeInvocation
{
  id *target_pointer;
  SEL *sel_pointer;
}

- initWithArgframe: (arglist_t)frame selector: (SEL)s;
- initWithSelector: (SEL)s;
- initWithTarget: target selector: (SEL)s, ...;
- (void) invokeWithTarget: t;
- (SEL) selector;
- (void) setSelector: (SEL)s;
- target;
- (void) setTarget: t;
@end

/* Same as MethodInvocation, except that when sent 
   [ -invokeWithObject: anObj], anObj does not become the target
   for the invocation's selector, it becomes the first object 
   argument of the selector. */
@interface ObjectMethodInvocation : MethodInvocation
{
  id *arg_object_pointer;
}
@end

@interface VoidFunctionInvocation : Invocation
{
  void (*function)();
}
- initWithVoidFunction: (void(*)())f;
@end


@interface ObjectFunctionInvocation : Invocation
{
  id (*function)(id);
}
- initWithObjectFunction: (id(*)(id))f;
@end


#if 0
@interface FunctionInvocation : ArgframeInvocation
{
  void (*function)();
}
- initWithFunction: (void(*)())f
    argframe: (arglist_t)frame type: (const char *)e;
- initWithFunction: (void(*)())f;
@end
#endif

#endif /* __Invocation_h_GNUSTEP_BASE_INCLUDE */
