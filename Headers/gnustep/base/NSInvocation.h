#ifndef __NSInvocation_h_INCLUDE_GNU
#define __NSInvocation_h_INCLUDE_GNU

#include <objc/Object.h>

@interface NSInvocation : Object
{
  id methodSignature;
  arglist_t argFrame;
  retval_t retFrame;
}

+ (NSInvocation*) invocationWithMethodSignature: (MethodSignature*)ms;

- (void) getArgument: (void*)argumentLocation atIndex: (int)index;
- (void) getReturnValue: (void*)returnLocation;

- (MethodSignature*) methodSignature;
- (SEL) selector;
- (void) setArgument: (void*)argumentLocation atIndex: (int)index;
- (void) setReturnValue: (void*)returnLocation;
- (void) setSelector: (SEL)aSelector;
- (void) setTarget: (id)target;
- (id) target;

- (void) invoke;
- (void) invokeWithTarget: (id)target;

@end

#endif /* __NSInvocation_h_INCLUDE_GNU */
