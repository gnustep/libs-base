/*
 * secure_coding.m - the NSKeyedUnarchiver secure-coding entry points
 * (unarchivedObjectOfClasses:fromData:error: and friends) must enforce the
 * allowed-class set and NSSecureCoding conformance, returning nil and an
 * NSError on a violation rather than instantiating an arbitrary class.
 *
 * The enforcement uses a purpose-built NSSecureCoding class, and the plist
 * substrate classes (NSString, NSNumber, NSData, NSDate, NSArray,
 * NSDictionary, NSSet) adopt NSSecureCoding so that containers of secure
 * classes can be decoded securely.
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

  START_SET("a plist container adopting NSSecureCoding is decoded")
    /* An array of a custom secure class.  Before the plist classes
     * adopted NSSecureCoding this failed, because NSArray was not
     * marked as supporting it. */
    SCWidget	*w = [[SCWidget alloc] init];
    NSData	*data;
    NSError	*err = nil;
    id		obj;

    [w setName: @"in-array"];
    data = archive([NSArray arrayWithObject: w]);
    [w release];

    /* The dedicated array entry point permits NSArray implicitly. */
    obj = [NSKeyedUnarchiver
      unarchivedArrayOfObjectsOfClasses: [NSSet setWithObject: [SCWidget class]]
                               fromData: data error: &err];
    PASS(obj != nil && [obj isKindOfClass: [NSArray class]] && [obj count] == 1
      && [[obj objectAtIndex: 0] isKindOfClass: [SCWidget class]] && err == nil,
      "unarchivedArrayOfObjectsOfClasses: decodes an array of a secure class");

    /* The general entry point requires NSArray to be listed as well. */
    err = nil;
    obj = [NSKeyedUnarchiver
      unarchivedObjectOfClasses: [NSSet setWithObjects:
        [NSArray class], [SCWidget class], nil]
                       fromData: data error: &err];
    PASS(obj != nil && [obj isKindOfClass: [NSArray class]] && err == nil,
      "an array is decoded when NSArray and the element class are listed");

    /* A container is not implicit: without NSArray the decode fails. */
    err = nil;
    obj = [NSKeyedUnarchiver
      unarchivedObjectOfClasses: [NSSet setWithObject: [SCWidget class]]
                       fromData: data error: &err];
    PASS(obj == nil && err != nil,
      "an array is rejected when NSArray is not in the allowed set");

    /* The allowed set applies tree-wide: the element class must be listed. */
    err = nil;
    obj = [NSKeyedUnarchiver
      unarchivedObjectOfClasses: [NSSet setWithObject: [NSArray class]]
                       fromData: data error: &err];
    PASS(obj == nil && err != nil,
      "an array is rejected when its element class is not in the allowed set");
  END_SET("a plist container adopting NSSecureCoding is decoded")

  START_SET("a dictionary of a secure class is decoded")
    SCWidget	*w = [[SCWidget alloc] init];
    NSData	*data;
    NSError	*err = nil;
    id		obj;

    [w setName: @"in-dict"];
    data = archive([NSDictionary dictionaryWithObject: w forKey: @"k"]);
    [w release];

    obj = [NSKeyedUnarchiver
      unarchivedDictionaryWithKeysOfClasses: [NSSet setWithObject: [NSString class]]
                             objectsOfClasses: [NSSet setWithObject: [SCWidget class]]
                                     fromData: data error: &err];
    PASS(obj != nil && [obj isKindOfClass: [NSDictionary class]]
      && [[obj objectForKey: @"k"] isKindOfClass: [SCWidget class]] && err == nil,
      "unarchivedDictionaryWithKeysOfClasses:objectsOfClasses: decodes a dictionary");
  END_SET("a dictionary of a secure class is decoded")

  START_SET("mutable variants inherit NSSecureCoding")
    /* The mutable classes are not changed directly; they inherit both the
     * protocol conformance and +supportsSecureCoding from their immutable
     * superclass. */
    PASS([NSMutableString conformsToProtocol: @protocol(NSSecureCoding)]
      && [NSMutableString supportsSecureCoding]
      && [NSMutableData conformsToProtocol: @protocol(NSSecureCoding)]
      && [NSMutableArray conformsToProtocol: @protocol(NSSecureCoding)]
      && [NSMutableDictionary conformsToProtocol: @protocol(NSSecureCoding)]
      && [NSMutableSet conformsToProtocol: @protocol(NSSecureCoding)]
      && [NSMutableSet supportsSecureCoding],
      "the mutable variants inherit NSSecureCoding conformance");

    SCWidget		*w = [[SCWidget alloc] init];
    NSMutableArray	*ma;
    NSData		*data;
    NSError		*err = nil;
    id			obj;

    [w setName: @"mutable"];
    ma = [NSMutableArray arrayWithObject: w];
    [w release];
    data = archive(ma);
    obj = [NSKeyedUnarchiver
      unarchivedArrayOfObjectsOfClasses: [NSSet setWithObject: [SCWidget class]]
                               fromData: data error: &err];
    PASS(obj != nil && [obj count] == 1
      && [[obj objectAtIndex: 0] isKindOfClass: [SCWidget class]] && err == nil,
      "a mutable array of a secure class is decoded");
  END_SET("mutable variants inherit NSSecureCoding")

  return 0;
}
