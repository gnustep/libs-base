#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSArchiver.h>

typedef struct {
  char	c;
  int	i;
} small;

typedef struct {
    int		i;
    char	*s;
    float	f;
} large;

@interface Target: NSObject
- (char) loopChar: (char)v;
- (double) loopDouble: (double)v;
- (float) loopFloat: (float)v;
- (int) loopInt: (int)v;
- (large) loopLarge: (large)v;
- (long) loopLong: (long)v;
- (large) loopLargePtr: (large*)v;
- (id) loopObject: (id)v;
- (short) loopShort: (short)v;
- (small) loopSmall: (small)v;
- (small) loopSmallPtr: (small*)v;
- (char*) loopString: (char*)v;

- (double) loopMulti: (float)f int: (float)v ch: (char)c;

- (char) retChar;
- (double) retDouble;
- (float) retFloat;
- (int) retInt;
- (large) retLarge;
- (long) retLong;
- (id) retObject;
- (short) retShort;
- (small) retSmall;
- (char*) retString;
@end

@implementation	Target
- (char) loopChar: (char)v
{
  return v+1;
}
- (double) loopDouble: (double)v
{
  return v+1.0;
}
- (float) loopFloat: (float)v
{
  return v+1.0;
}
- (int) loopInt: (int)v
{
  return v+1;
}
- (large) loopLarge: (large)v
{
  return v;
}
- (long) loopLong: (long)v
{
  return v+1;
}
- (large) loopLargePtr: (large*)v
{
  return *v;
}
- (id) loopObject: (id)v
{
  return v;
}
- (short) loopShort: (short)v
{
  return v+1;
}
- (small) loopSmall: (small)v
{
  return v;
}
- (small) loopSmallPtr: (small*)v
{
  return *v;
}
- (char*) loopString: (char*)v
{
  return v;
}

- (double) loopMulti: (float)f int: (float)v ch: (char)c
{
  return v+1.0;
}

- (char) retChar
{
  return (char)99;
}
- (double) retDouble
{
  return 123.456;
}
- (float) retFloat
{
  return 123.456;
}
- (int) retInt
{
  return 123456;
}
- (large) retLarge
{
  static large l = {
    99, "large", 99.99
  };
  return l;
}
- (long) retLong
{
  return 123456;
}
- (id) retObject
{
  return self;
}
- (short) retShort
{
  return 12345;
}
- (small) retSmall
{
  static small s = {
    11, 22
  };
  return s;
}
- (char*) retString
{
  return "string";
}
@end

@interface	MyProxy : NSObject
{
  id	obj;
}
- (void) forwardInvocation: (NSInvocation*)inv;
- (id) initWithTarget: (id)target;
@end

@implementation	MyProxy
- (id) initWithTarget: (id)target
{
  obj = target;
  return self;
}
- (void) forwardInvocation: (NSInvocation*)inv
{
  NSData	*d = [NSArchiver archivedDataWithRootObject: inv];
  NSInvocation	*i = [NSUnarchiver unarchiveObjectWithData: d];
  unsigned	l;
  void		*b;

  [i invokeWithTarget: obj];
  d = [NSArchiver archivedDataWithRootObject: i];
  i = [NSUnarchiver unarchiveObjectWithData: d];
  l = [[i methodSignature] methodReturnLength];
  if (l < sizeof(void *))
    l = sizeof(void *);
  b = (void *)objc_malloc(l);
  [i getReturnValue: b];
  [inv setReturnValue: b];
  objc_free(b);
}
@end

int
main ()
{
  large	la;
  small	sm;
  large	tmpla;
  large	*laptr = &tmpla;
  small	tmpsm;
  small	*smptr = &tmpsm;
  int	i;
  char	c;
  short	s;
  long	l;
  float	f;
  double	d;
  id		o;
  char*	str;
  NSInvocation	*inv;
  NSMethodSignature	*sig;
  Target		*t;
  id			p;
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

printf("Starting\n");
  t = [Target new];
  p = [[MyProxy alloc] initWithTarget: t];
printf("Calling proxy\n");
[p loopInt: 1];

#define	SETUP(X) \
  sig = [t methodSignatureForSelector: @selector(X)]; \
  inv = [NSInvocation invocationWithMethodSignature: sig]; \
  [inv setSelector: @selector(X)];

  tmpsm.c = 8;
  tmpsm.i = 9;

  tmpla.i = 1;
  tmpla.s = "hello";
  tmpla.f = 1.23;

  SETUP(retChar);
  [inv invokeWithTarget: t];
  printf("Expect: 99, ");
  [inv getReturnValue: &c];
  printf("invoke: %d ", c);
  c = [p retChar];
  printf("forward: %d\n", c);

  SETUP(retShort);
  [inv invokeWithTarget: t];
  printf("Expect: 12345, ");
  [inv getReturnValue: &s];
  printf("invoke: %d ", s);
  s = [p retShort];
  printf("forward: %d\n", s);

  SETUP(retInt);
  [inv invokeWithTarget: t];
  printf("Expect: 123456, ");
  [inv getReturnValue: &i];
  printf("invoke: %d ", i);
  i = [p retInt];
  printf("forward: %d\n", i);

  SETUP(retLong);
  [inv invokeWithTarget: t];
  printf("Expect: 123456, ");
  [inv getReturnValue: &l];
  printf("invoke: %ld ", l);
  l = [p retLong];
  printf("forward: %ld\n", l);

  SETUP(retFloat);
  [inv invokeWithTarget: t];
  printf("Expect: 123.456, ");
  [inv getReturnValue: &f];
  printf("invoke: %.3f ", f);
  f = [p retFloat];
  printf("forward: %.3f\n", f);

  SETUP(retDouble);
  [inv invokeWithTarget: t];
  printf("Expect: 123.456, ");
  [inv getReturnValue: &d];
  printf("invoke: %.3f ", d);
  d = [p retDouble];
  printf("forward: %.3f\n", d);

  SETUP(retObject);
  [inv invokeWithTarget: t];
  printf("Expect: %x, ", t);
  [inv getReturnValue: &o];
  printf("invoke: %x ", o);
  o = [p retObject];
  printf("forward: %x\n", o);

  SETUP(retString);
  [inv invokeWithTarget: t];
  printf("Expect: 'string', ");
  [inv getReturnValue: &str];
  printf("invoke: '%s' ", str);
  str = [p retString];
  printf("forward: '%s'\n", str);

  SETUP(retSmall);
  [inv invokeWithTarget: t];
  printf("Expect: {11,22}, ");
  [inv getReturnValue: &sm];
  printf("invoke: {%d,%d} ", sm.c, sm.i);
  sm = [p retSmall];
  printf("forward: {%d,%d}\n", sm.c, sm.i);

  SETUP(retLarge);
  [inv invokeWithTarget: t];
  printf("Expect: {99,large,99.99}, ");
  [inv getReturnValue: &la];
  printf("invoke: {%d,%s,%.2f} ", la.i, la.s, la.f);
  la = [p retLarge];
  printf("forward: {%d,%s,%.2f}\n", la.i, la.s, la.f);




  SETUP(loopChar:);
  c = 0;
  [inv setArgument: &c atIndex: 2];
  [inv invokeWithTarget: t];
  printf("Expect: 1, ");
  [inv getReturnValue: &c];
  printf("invoke: %d ", c);
  c = [p loopChar: 0];
  printf("forward: %d\n", c);

  SETUP(loopShort:);
  s = 1;
  [inv setArgument: &s atIndex: 2];
  [inv invokeWithTarget: t];
  printf("Expect: 2, ");
  [inv getReturnValue: &s];
  printf("invoke: %d ", s);
  s = [p loopShort: 1];
  printf("forward: %d\n", s);

  SETUP(loopInt:);
  i = 2;
  [inv setArgument: &i atIndex: 2];
  [inv invokeWithTarget: t];
  printf("Expect: 3, ");
  [inv getReturnValue: &i];
  printf("invoke: %d ", i);
  i = [p loopInt: 2];
  printf("forward: %d\n", i);

  SETUP(loopLong:);
  l = 3;
  [inv setArgument: &l atIndex: 2];
  [inv invokeWithTarget: t];
  printf("Expect: 4, ");
  [inv getReturnValue: &l];
  printf("invoke: %d ", l);
  l = [p loopLong: 3];
  printf("forward: %d\n", l);

  SETUP(loopFloat:);
  f = 4.0;
  [inv setArgument: &f atIndex: 2];
  [inv invokeWithTarget: t];
  printf("Expect: 5.0, ");
  [inv getReturnValue: &f];
  printf("invoke: %.1f ", f);
  f = [p loopFloat: 4.0];
  printf("forward: %.1f\n", f);

  SETUP(loopDouble:);
  d = 5.0;
  [inv setArgument: &d atIndex: 2];
  [inv invokeWithTarget: t];
  printf("Expect: 6.0, ");
  [inv getReturnValue: &d];
  printf("invoke: %.1f ", d);
  d = [p loopDouble: 5.0];
  printf("forward: %.1f\n", d);

  SETUP(loopMulti:int:ch:);
  printf("Expect: 6.0, ");
  f = [p loopMulti: 3.0 int: 5.0  ch: 'a'];
  printf("forward: %.1f\n", f);

  SETUP(loopObject:);
  [inv setArgument: &p atIndex: 2];
  [inv invokeWithTarget: t];
  printf("Expect: %x, ", p);
  [inv getReturnValue: &o];
  printf("invoke: %x ", o);
  o = [p loopObject: p];
  printf("forward: %x\n", o);

  SETUP(loopString:);
  str = "Hello";
  [inv setArgument: &str atIndex: 2];
  [inv invokeWithTarget: t];
  printf("Expect: 'Hello', ");
  [inv getReturnValue: &str];
  printf("invoke: '%s' ", str);
  str = [p loopString: str];
  printf("forward: '%s'\n", str);

  SETUP(loopSmall:);
  printf("Expect: {8,9}, ");
  [inv setArgument: &tmpsm atIndex: 2];
  [inv invokeWithTarget: t];
  [inv getReturnValue: &sm];
  printf("invoke: {%d,%d} ", sm.c, sm.i);
  sm = [p loopSmall: tmpsm];
  printf("forward: {%d,%d}\n", sm.c, sm.i);

  SETUP(loopLarge:);
  printf("Expect: {1,hello,1.23}, ");
  [inv setArgument: &tmpla atIndex: 2];
  [inv invokeWithTarget: t];
  [inv getReturnValue: &la];
  printf("invoke: {%d,%s,%.2f} ", la.i, la.s, la.f);
  la = [p loopLarge: tmpla];
  printf("forward: {%d,%s,%.2f}\n", la.i, la.s, la.f);

  SETUP(loopSmallPtr:);
  printf("Expect: {8,9}, ");
  [inv setArgument: &smptr atIndex: 2];
  [inv invokeWithTarget: t];
  [inv getReturnValue: &sm];
  printf("invoke: {%d,%d} ", sm.c, sm.i);
  sm = [p loopSmallPtr: smptr];
  printf("forward: {%d,%d}\n", sm.c, sm.i);

  SETUP(loopLargePtr:);
  printf("Expect: {1,hello,1.23}, ");
  [inv setArgument: &laptr atIndex: 2];
  [inv invokeWithTarget: t];
  [inv getReturnValue: &la];
  printf("invoke: {%d,%s,%.2f} ", la.i, la.s, la.f);
  la = [p loopLargePtr: laptr];
  printf("forward: {%d,%s,%.2f}\n", la.i, la.s, la.f);

  [arp release];
  return 0;
}

