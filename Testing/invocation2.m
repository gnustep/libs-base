#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSString.h>
#include <gnustep/base/Invocation.h>

struct intpair {
  int i;
  int j;
};

@interface IntPair: NSObject
- (int)member:(Class)c;
- (int)plus: (struct intpair) pair;
- (int)plus_ptr: (struct intpair*) pair_ptr;
@end

@implementation  IntPair
- (int)member:(Class)c
{
  if ([self class] == c)
    return YES;
  else
    return NO;
}
- (int)plus: (struct intpair) pair
{
  return (pair.i + pair.j);
}
- (int)plus_ptr: (struct intpair*) pair_ptr
{
  return (pair_ptr->i + pair_ptr->j);
}
@end
/* Invocation.m
- initWithTarget: target selector: (SEL)s, ...
[1] Adding CASE_TYPE(_C_CLASS, Class);
[2] Adding default: block

   NSInvocation.h
[3] Adding NS_INVOCATION
[4] Adding NS_MESSAGE

   NSMethodSignature.m
[5] Modifiying -(NSArgumentInfo)argumentInfoAtIndex:(unsigned)index */	

void test1();
void test2();
void test3();
void test4();
void test5();

int
main ()
{
  test1();
  test2();
  test3();
  test4();
  test5();
}

void
test1()
{
  IntPair * ipair = [IntPair  new];	
  SEL sel = @selector(member:);
  Class c = [IntPair class];
  Invocation * inv;
  int result;
  inv = [[MethodInvocation alloc] 
	  initWithTarget: ipair
	  selector: sel, c];
  [inv invoke];
  [inv getReturnValue: &result];
  fprintf(stderr, "test1 YES == %s\n", result? "YES": "NO");
}

void 
test2()
{
  IntPair * ipair = [IntPair  new];	
  SEL sel = @selector(plus:);
  SEL sel_ptr = @selector(plus_ptr:);
  struct intpair pair0;
  struct intpair * pair0_ptr;
  Invocation * inv;
  int result;

  pair0.i = 3;
  pair0.j = 4;

  inv = [[MethodInvocation alloc] 
	  initWithTarget: ipair
	  selector: sel, &pair0];
  [inv invoke];
  [inv getReturnValue: &result];
  fprintf(stderr, "test2-1 %d == 7\n", result);

  pair0_ptr = &pair0;
  pair0_ptr->i = 2;
  pair0_ptr->j = 3;
  inv = [[MethodInvocation alloc] 
	  initWithTarget: ipair
	  selector: sel, &pair0];
  [inv invoke];
  [inv getReturnValue: &result];
  fprintf(stderr, "test2-2 %d == 5\n", result);  
}
     
void
test3()
{
  IntPair * ipair = [IntPair  new];	
  struct intpair pair0;
  NSInvocation * inv;
  int x;
  pair0.i = 1;
  pair0.j = 2;
  inv = NS_INVOCATION(IntPair , 
		      @selector(plus:), 
		      &pair0);
  [inv setTarget: ipair];
  [inv invoke];
  [inv getReturnValue: &x];
  fprintf(stderr, "test3 3 == %d\n", x);
}

void
test4()
{
  IntPair * ipair = [IntPair  new];	
  struct intpair pair0;
  NSInvocation * inv;
  int x;
  pair0.i = 3;
  pair0.j = 8;
  inv = NS_MESSAGE(ipair , 
		   @selector(plus:), 
		   &pair0);
  [inv invoke];
  [inv getReturnValue: &x];
  fprintf(stderr, "test4 11 == %d\n", x);
}

void
test5()
{
  NSObject * 	foo	 = [NSObject  new];	
  NSArgumentInfo info;
  SEL sel = @selector(isKindOfClass:);
  NSMethodSignature * ms = [foo methodSignatureForSelector: sel];
  info = [ms argumentInfoAtIndex: 0];
  fprintf(stderr, "test5 (%d, %d, %s)\n", info.offset, info.size, info.type);
  info = [ms argumentInfoAtIndex: 1];
  fprintf(stderr, "test5 (%d, %d, %s)\n", info.offset, info.size, info.type);
  info = [ms argumentInfoAtIndex: 2];
  fprintf(stderr, "test5 (%d, %d, %s)\n", info.offset, info.size, info.type);  
}
