/*
 * secure_coding.m - the NSKeyedUnarchiver secure-coding entry points
 * (unarchivedObjectOfClasses:fromData:error: and friends) must enforce the
 * allowed-class set and NSSecureCoding conformance, returning nil and an
 * NSError on a violation rather than instantiating an arbitrary class.
 *
 * These use a purpose-built NSSecureCoding class: the standard Foundation
 * classes do not yet adopt NSSecureCoding, so an archive of, say, an NSArray
 * cannot yet be decoded securely.  The enforcement itself is what is tested
 * here.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

@interface SCWidget : NSObject <NSSecureCoding>
{
  NSString	*_name;
}
- (NSString*) name;
- (void) setName: (NSString*)aName;
@end

@implementation SCWidget
+ (BOOL) supportsSecureCoding { return YES; }
- (NSString*) name { return _name; }
- (void) setName: (NSString*)aName { [_name autorelease]; _name = [aName copy]; }
- (void) dealloc { [_name release]; [super dealloc]; }
- (void) encodeWithCoder: (NSCoder*)aCoder
{ [aCoder encodeObject: _name forKey: @"name"]; }
- (id) initWithCoder: (NSCoder*)aCoder
{
  if ((self = [super init]) != nil)
    {
      _name = [[aCoder decodeObjectForKey: @"name"] copy];
    }
  return self;
}
@end

/* A subclass, to confirm a subclass of an allowed class is accepted. */
@interface SCWidgetSub : SCWidget
@end
@implementation SCWidgetSub
@end

/* Conforms to NSCoding but not NSSecureCoding. */
@interface SCSneaky : NSObject <NSCoding>
@end
@implementation SCSneaky
- (void) encodeWithCoder: (NSCoder*)aCoder { (void)aCoder; }
- (id) initWithCoder: (NSCoder*)aCoder { (void)aCoder; return [super init]; }
@end

static NSData *
archive(id obj)
{
  return [NSKeyedArchiver archivedDataWithRootObject: obj];
}

int main(void)
{
  START_SET("secure decoding enforces the allowed classes")
    SCWidget	*w = [[SCWidget alloc] init];
    NSData	*data;
    NSError	*err;
    id		obj;

    [w setName: @"secret"];
    data = archive(w);
    [w release];

    err = nil;
    obj = [NSKeyedUnarchiver
      unarchivedObjectOfClasses: [NSSet setWithObject: [SCWidget class]]
                       fromData: data error: &err];
    PASS(obj != nil && [obj isKindOfClass: [SCWidget class]] && err == nil,
      "a class in the allowed set is decoded");

    err = nil;
    obj = [NSKeyedUnarchiver
      unarchivedObjectOfClasses: [NSSet setWithObject: [NSString class]]
                       fromData: data error: &err];
    PASS(obj == nil && err != nil
      && [[err domain] isEqualToString: NSCocoaErrorDomain]
      && [err code] == NSCoderReadCorruptError,
      "a class not in the allowed set is rejected with an error");

    err = nil;
    obj = [NSKeyedUnarchiver
      unarchivedObjectOfClasses: [NSSet set]
                       fromData: data error: &err];
    PASS(obj == nil && err != nil,
      "an empty allowed set rejects a custom class");
  END_SET("secure decoding enforces the allowed classes")

  START_SET("secure decoding requires NSSecureCoding conformance")
    SCSneaky	*s = [[SCSneaky alloc] init];
    NSData	*data = archive(s);
    NSError	*err = nil;
    id		obj;

    [s release];
    obj = [NSKeyedUnarchiver
      unarchivedObjectOfClasses: [NSSet setWithObject: [SCSneaky class]]
                       fromData: data error: &err];
    PASS(obj == nil && err != nil,
      "a class that does not support secure coding is rejected even when listed");
  END_SET("secure decoding requires NSSecureCoding conformance")

  START_SET("a subclass of an allowed class is accepted")
    SCWidgetSub	*w = [[SCWidgetSub alloc] init];
    NSData	*data;
    NSError	*err = nil;
    id		obj;

    [w setName: @"sub"];
    data = archive(w);
    [w release];
    obj = [NSKeyedUnarchiver
      unarchivedObjectOfClasses: [NSSet setWithObject: [SCWidget class]]
                       fromData: data error: &err];
    PASS(obj != nil && [obj isKindOfClass: [SCWidgetSub class]] && err == nil,
      "a subclass of an allowed class is decoded");
  END_SET("a subclass of an allowed class is accepted")

  START_SET("plist primitives are implicitly allowed")
    NSData	*data = archive(@"hello");
    NSError	*err = nil;
    id		obj;

    obj = [NSKeyedUnarchiver
      unarchivedObjectOfClasses: [NSSet setWithObject: [NSNumber class]]
                       fromData: data error: &err];
    PASS_EQUAL(obj, @"hello",
      "a plist primitive is decoded even when its class is not listed");
  END_SET("plist primitives are implicitly allowed")

  return 0;
}
