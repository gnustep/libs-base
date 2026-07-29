/* An object whose -encodeWithCoder: raises has to leave the archiver as it
   was.  While an object encodes itself the archiver points its current scope
   at a dictionary belonging to its array of objects; if that is not given
   back when the object refuses, the archiver releases the dictionary a second
   time on the way out, which corrupts the heap and takes the next allocation
   with it.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import "ObjectTesting.h"

@interface Refuser : NSObject <NSCoding>
@end

@implementation Refuser

- (void) encodeWithCoder: (NSCoder *)coder
{
  [NSException raise: NSInternalInconsistencyException
              format: @"this object refuses to be encoded"];
}

- (id) initWithCoder: (NSCoder *)coder
{
  return self;
}

@end

static BOOL
archiveRaises(id object)
{
  BOOL raised = NO;

  NS_DURING
    {
      [NSKeyedArchiver archivedDataWithRootObject: object];
    }
  NS_HANDLER
    {
      raised = YES;
    }
  NS_ENDHANDLER

  return raised;
}

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  Refuser *refuser = AUTORELEASE([Refuser new]);
  NSArray *holder;
  NSData *data;
  id back;

  holder = [NSArray arrayWithObjects: @"first", refuser, nil];

  PASS(archiveRaises(refuser),
       "archiving an object that refuses to encode raises");
  PASS(archiveRaises(holder),
       "archiving a collection holding one raises");

  /* The archiver has to be left in one piece.  Before the archiver gave the
     scope back this ran on a corrupted heap.
  */
  data = [NSKeyedArchiver archivedDataWithRootObject:
    [NSArray arrayWithObjects: @"one", @"two", nil]];
  PASS([data length] > 0, "an archive can still be written afterwards");

  back = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS_EQUAL(back, ([NSArray arrayWithObjects: @"one", @"two", nil]),
             "and it reads back as what went in");

  [arp release];
  return 0;
}
