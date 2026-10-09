#import "ObjectTesting.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSError.h"
#import "Foundation/NSKeyedArchiver.h"
#import "Foundation/NSString.h"

/* +archivedDataWithRootObject:requiringSecureCoding:error: is the modern
 * archiving entry point.  It used to answer nil whenever secure coding was
 * asked for - without setting the error - even for objects that adopt
 * NSSecureCoding.
 */
@interface NotSoSecure : NSObject <NSCoding>
@end

@implementation NotSoSecure
- (void) encodeWithCoder: (NSCoder *)coder { }
- (id) initWithCoder: (NSCoder *)coder { return self; }
@end

int main(void)
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSArray		*root;
  NSData		*data;
  NSError		*error = nil;
  id			back;

  root = [NSArray arrayWithObjects: @"one", @"two", nil];

  data = [NSKeyedArchiver archivedDataWithRootObject: root
			       requiringSecureCoding: YES
					       error: &error];
  PASS(data != nil, "an object that adopts NSSecureCoding can be archived");
  PASS(error == nil, "no error is reported when the archive succeeded");

  if (data != nil)
    {
      back = [NSKeyedUnarchiver unarchiveObjectWithData: data];
      PASS_EQUAL(back, root, "the archive reads back as what went in");
    }

  /* And a class that does not adopt it is refused through the error rather
   * than by silently answering nil.
   */
  error = nil;
  data = [NSKeyedArchiver archivedDataWithRootObject:
      [[[NotSoSecure alloc] init] autorelease]
			       requiringSecureCoding: YES
					       error: &error];
  PASS(data == nil, "a class that does not adopt NSSecureCoding is refused");
  PASS(error != nil, "the refusal is reported through the error");

  [arp release];
  return 0;
}
