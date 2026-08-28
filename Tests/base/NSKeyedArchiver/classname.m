/* A class may be archived under a name for which there is no class here, as
   OS X compatible archives require.  The description of the class still has
   to be the one of the class being encoded.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>
#import "Testing.h"
#import "ObjectTesting.h"

@interface GSRenamed : NSObject
{
  NSString	*_text;
}
- (id) initWithText: (NSString *)text;
- (NSString *) text;
@end

@implementation GSRenamed

- (id) initWithText: (NSString *)text
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_text, text);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_text);
  [super dealloc];
}

- (NSString *) text
{
  return _text;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [coder encodeObject: _text forKey: @"Text"];
}

- (id) initWithCoder: (NSCoder *)coder
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_text, [coder decodeObjectForKey: @"Text"]);
    }
  return self;
}

@end

/* The class description an archive of the object holds. */
static NSDictionary *
classDescription(id object, NSString *name)
{
  NSData	*data = [NSKeyedArchiver archivedDataWithRootObject: object];
  NSDictionary	*plist;
  id		entry;

  plist = [NSPropertyListSerialization propertyListWithData: data
						    options: 0
						     format: NULL
						      error: NULL];
  for (entry in [plist objectForKey: @"$objects"])
    {
      if ([entry isKindOfClass: [NSDictionary class]]
	&& [[entry objectForKey: @"$classname"] isEqual: name])
	{
	  return entry;
	}
    }
  return nil;
}

int
main(int argc, char **argv)
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  GSRenamed		*object;
  NSDictionary		*description;
  id			decoded;

  object = AUTORELEASE([[GSRenamed alloc] initWithText: @"text"]);
  [NSKeyedArchiver setClassName: @"AbsentElsewhere" forClass: [GSRenamed class]];

  description = classDescription(object, @"AbsentElsewhere");
  PASS(description != nil, "an object is archived under the name given for it");
  PASS([[description objectForKey: @"$classes"] count] > 0,
       "a name with no class of its own still describes the class hierarchy");
  PASS([[description objectForKey: @"$classes"] containsObject: @"NSObject"],
       "and the hierarchy is the one of the class being encoded");

  [NSKeyedUnarchiver setClass: [GSRenamed class] forClassName: @"AbsentElsewhere"];
  decoded = [NSKeyedUnarchiver unarchiveObjectWithData:
    [NSKeyedArchiver archivedDataWithRootObject: object]];
  PASS([decoded isKindOfClass: [GSRenamed class]],
       "and the object read back is of the class the name stands for");
  PASS_EQUAL([decoded text], @"text", "carrying what it was given");

  [arp release];
  return 0;
}
