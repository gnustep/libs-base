#import "Testing.h"

#ifndef OBJC_NEW_PROPERTIES
int main(void)
{
  START_SET("Properties")
    SKIP("Your compiler does not support declared properties");
  END_SET("Properties")
  return 0;
}
#else
#import <Foundation/Foundation.h>

@interface A : NSObject
{
@private
  NSObject *n;
  NSObject *a;
}
@property (nonatomic,readwrite,retain) NSObject *n;
@property (readwrite,retain) NSObject *a;
@end

@implementation A
- (NSObject *)n
{
  return [[n retain] autorelease];
}
- (void)setN:(NSObject *)newN
{
  if (n != newN)
    {
      [n release];
      n = [newN retain];
    }
}
- (NSObject *)a
{
  return [[a retain] autorelease];
}
- (void)setA:(NSObject *)newA
{
  @synchronized(self)
    {
      if (a != newA)
        {
          [a release];
          a = [newA retain];
        }
    }
}
- (void)dealloc
{
  [a release];
  [n release];
  [super dealloc];
}
@end
@interface B : NSObject
// If we've got non-fragile ABI support, try not declaring the ivars
#if !__has_feature(objc_nonfragile_abi)
{
  id a, b, c, d;
}
#endif
@property (nonatomic,readwrite,retain) id a;
@property (readwrite,retain) id b;
@property (nonatomic,readwrite,copy) id c;
@property (readwrite,copy) id d;
@end
@implementation B
@synthesize a,b,c,d;
- (void)dealloc
{
  [a release];
  [b release];
  [c release];
  [d release];
  [super dealloc];
}
@end

int main(int argc, char **argv)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  id testObject = [@"str" mutableCopy];

  A *a = [[A alloc] init];
  // Note: use of dot syntax here is only for testing purposes.  This case -
  // in the test suite and outside of the main code - does not invoke
  // requirement to buy all of the other GNUstep developers a beer.
  a.a = testObject;
  PASS(a.a == testObject, "Setting manually created atomic property");
  a.n = testObject;
  PASS(a.n == testObject, "Setting manually created nonatomic property");
  DESTROY(a);
  B *b = [B new];
  b.a = testObject;
  PASS(b.a == testObject, "Setting synthesized atomic property");
  b.b = testObject;
  PASS(b.b == testObject, "Setting synthesized nonatomic property");
  b.c = testObject;
  PASS(b.c != testObject, "Synthesized nonatomic copy method did not do simple assign");
  PASS([testObject isEqualToString: b.c], "Synthesized nonatomic copy method did copy");
  b.d = testObject;
  PASS(b.d != testObject, "Synthesized atomic copy method did not do simple assign");
  PASS([testObject isEqualToString: b.d], "Synthesized atomic copy method did copy");
  [b release];
  return 0;
}
#endif

