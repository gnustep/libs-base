#include "NSInvocation.h"

@implementation NSInvocation

+ (NSInvocation*) invocationWithMethodSignature: (MethodSignature*)ms
   frame: (arglist_t)aFrame
{
  NSInvocation *newInv = [self invocationWithMethodSignature:ms];
  bcopy(aFrame->arg_ptr, newInv->agrFrame->arg_ptr, [ms frameLength]);
  ...
  return newInv;
}

+ (NSInvocation*) invocationWithMethodSignature: (MethodSignature*)ms
{
  int argsize = [ms frameLength];
  int retsize = [ms methodReturnLength];
  NSInvocation* newInv = [self alloc];

  newInv->methodSignature = ms;
  newInv->argFrame = malloc(argsize);
  newInv->argFrame->arg_ptr = malloc(argsize);
  newInv->retFrame = malloc(retsize);
  return newInv;
}

- (void) getArgument: (void*)argumentLocation atIndex: (int)index
{
  *argumentLocation = 
}

- (void) getReturnValue: (void*)returnLocation
{
  bcopy(retFrame, returnLocation, [methodSignature methodReturnLength]);
  return;
}

- (MethodSignature*) methodSignature
{
  return methodSignature;
}

- (SEL) selector
{
  SEL s;
  [self getArgument:&s atIndex:1];
  return s;
}

- (void) setArgument: (void*)argumentLocation atIndex: (int)index;
- (void) setReturnValue: (void*)returnLocation
{
  bcopy(returnLocation, retFrame, [methodSignature methodReturnLength]);
  return;
}

- (void) setSelector: (SEL)aSelector
{
  [self setArgument:&aSelector atIndex:1];
  return;
}

- (void) setTarget: (id)aTarget
{
  target = aTarget;
  return;
}

- (id) target
{
  id t;
  [self getArgument:&t atIndex:0];
  return t;
}

- (void) invoke
{
  char *type;
  Method* m;
  id target;
  SEL sel;
  IMP imp;

  target = *(id*)method_get_first_argument(m, argFrame, &type);

 = [target methodForSelector:
  __builtin_apply(

- (void) invokeWithTarget: (id)target
		  {

@end
