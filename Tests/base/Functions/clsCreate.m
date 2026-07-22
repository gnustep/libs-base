#import <Foundation/Foundation.h>
#import "Testing.h"

static NSString *desc = @"[MyObject]";

static NSString *
myObjectDescription(id self, SEL _cmd)
{
  return desc;
}

int
main(void)
{
  ENTER_POOL
  id obj;
  Class cls;

  cls = (Class)objc_allocateClassPair([NSObject class], "MyObject", 0);
  if (cls != Nil)
    {
      objc_registerClassPair(cls);
      class_addMethod(cls, @selector(description),
	(IMP)myObjectDescription, "@@:");
      obj = [cls new];
      PASS([obj description] == desc,
	"New class's description method is called correctly")
      RELEASE(obj);
    }

  LEAVE_POOL
  return 0;
}
