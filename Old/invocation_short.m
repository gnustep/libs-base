#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <base/Invocation.h>

#define TYPE short

struct pair {
  TYPE i;
  TYPE j;
};

@interface Pair: NSObject
- (TYPE)member:(Class)c;
- (TYPE)plus: (struct pair) pair;
- (TYPE)plus_ptr: (struct pair*) pair_ptr;
@end

@implementation  Pair
- (TYPE)member:(Class)c
{
  if ([self class] == c)
    return YES;
  else
    return NO;
}
- (TYPE)plus: (struct pair) pair
{
  return (pair.i + pair.j);
}
- (TYPE)plus_ptr: (struct pair*) pair_ptr
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
[4, 5] Adding NS_MESSAGE

   NSMethodSignature.m
[6] Modifiying -(NSArgumentInfo)argumentInfoAtIndex:(unsigned)index */

void test1();
void test2();
void test3();
void test4();
void test5();
void test6();

int
main ()
{
  test1();
  test2();
  test3();
  test4();
  test5();
  test6();
}

void
test1()
{
  Pair * ipair = [Pair  new];
  SEL sel = @selector(member:);
  Class c = [Pair class];
  Invocation * inv;
  TYPE result;
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
  Pair * ipair = [Pair  new];
  SEL sel = @selector(plus:);
  SEL sel_ptr = @selector(plus_ptr:);
  struct pair pair0;
  struct pair * pair0_ptr;
  Invocation * inv;
  TYPE result;

  pair0.i = 3;
  pair0.j = 4;

  inv = [[MethodInvocation alloc]
	  initWithTarget: ipair
	  selector: sel, pair0];
  [inv invoke];
  [inv getReturnValue: &result];
  fprintf(stderr, "test2-1 %d == 7\n", result);

  pair0_ptr = &pair0;
  pair0_ptr->i = 2;
  pair0_ptr->j = 3;
  inv = [[MethodInvocation alloc]
	  initWithTarget: ipair
	  selector: sel_ptr, &pair0];
  [inv invoke];
  [inv getReturnValue: &result];
  fprintf(stderr, "test2-2 %d == 5\n", result);
}

void
test3()
{
  Pair * ipair = [Pair  new];
  struct pair pair0;
  NSInvocation * inv;
  TYPE x;
  pair0.i = 1;
  pair0.j = 2;
  inv = NS_INVOCATION(Pair ,
		      plus:,
		      pair0);
  [inv setTarget: ipair];
  [inv invoke];
  [inv getReturnValue: &x];
  fprintf(stderr, "test3 3 == %d\n", x);
}

void
test4()
{
  Pair * ipair = [Pair  new];
  struct pair pair0;
  NSInvocation * inv;
  TYPE x;
  pair0.i = 3;
  pair0.j = 8;
  inv = NS_MESSAGE(ipair ,
		   plus_ptr:,
		   &pair0);	// Method with args
  [inv invoke];
  [inv getReturnValue: &x];
  fprintf(stderr, "test4 11 == %d\n", x);
}

void
test5()
{
  Pair * ipair = [Pair  new];
  NSInvocation * inv;
  int x;

  inv = NS_MESSAGE(ipair,
		   hash);	// Method with NO args
  [inv invoke];
  [inv getReturnValue: &x];
  fprintf(stderr, "test5 hash value of an object == %d\n", x);
}

void
test6()
{
  NSObject * 	foo	 = [NSObject  new];
  NSArgumentInfo info;
  SEL sel = @selector(isKindOfClass:);
  NSMethodSignature * ms = [foo methodSignatureForSelector: sel];
  info = [ms argumentInfoAtIndex: 0];
  fprintf(stderr, "test6 (%d, %d, %s)\n", info.offset, info.size, info.type);
  info = [ms argumentInfoAtIndex: 1];
  fprintf(stderr, "test6 (%d, %d, %s)\n", info.offset, info.size, info.type);
  info = [ms argumentInfoAtIndex: 2];
  fprintf(stderr, "test6 (%d, %d, %s)\n", info.offset, info.size, info.type);
}

#undef TYPE
