#include <objects/stdobjects.h>
#include <objects/behavior.h>
#include <Foundation/NSCoder.h>

@interface Foo : NSObject
+ fooClass;
- foo;
- (void) encodeWithCoder: c;
@end

@interface Foo2 : NSObject
+ foo2Class;
- foo2;
@end

@interface Foo2Sub : Foo2
+ foo2SubClass;
- foo2Sub;
@end

@implementation Foo
+ (void) initialize
{
  class_add_behavior([Foo class], [Foo2Sub class]);
}
+ fooClass
{
  printf("fooClass\n");
  return self;
}
- foo
{
  printf("foo\n");
  return self;
}
- duplicate
{
  printf("Foo duplicate\n");
  return self;
}
- (void) encodeWithCoder: c
{
  (void) &c;
}
@end

@implementation Foo2
+ foo2Class
{
  printf("foo2Class\n");
  return self;
}
- foo2
{
  printf("foo2\n");
  return self;
}
- duplicate
{
  printf("Foo2 duplicate\n");
  return self;
}
@end

@implementation Foo2Sub
+ foo2SubClass
{
  printf("foo2SubClass\n");
  return self;
}
- foo2Sub
{
  printf("foo2Sub\n");
  return self;
}
@end

int main()
{
  id f = [Foo new];

  [f encodeWithCoder:nil];
  set_behavior_debug(1);

  [f foo2];
  [[f class] foo2Class];
  [f foo2Sub];
  [[f class] foo2SubClass];
  [f duplicate];

  exit(0);
}

/*
Local Variables:
compile-command: "gcc beh.m -I.. -L.. -lobjects -lobjc -o beh"
End:
*/
