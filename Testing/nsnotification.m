/* The simplest of tests for the NSNotification and NSNotificationCenter
   classes.  These tests should be expanded. 

   (The Tcp*Port classes, however, do test the notification mechanism 
    further.) */

#include <Foundation/NSNotification.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>

@interface Observer : NSObject
- (void) gotNotificationFoo: not;
@end

@implementation Observer

- (void) gotNotificationFoo: (NSNotification*)not
{
  printf ("Got %s\n", [[not name] cStringNoCopy]);
}

- (void) gotNotificationFooNoObject: (NSNotification*)not
{
  printf ("Got %s without object\n", [[not name] cStringNoCopy]);
}

@end

id foo = @"NotificationTestFoo";

int main ()
{
  id o1 = [NSObject new];
  id observer1 = [Observer new];
  id arp;

  arp = [NSAutoreleasePool new];

  [[NSNotificationCenter defaultCenter]
    addObserver: observer1
    selector: @selector(gotNotificationFoo:)
    name: foo
    object: o1];

  [[NSNotificationCenter defaultCenter]
    addObserver: observer1
    selector: @selector(gotNotificationFooNoObject:)
    name: foo
    object: nil];


  /* This will cause two messages to be printed, one for each request above. */
  [[NSNotificationCenter defaultCenter]
    postNotificationName: foo
    object: o1];

  /* This will cause one message to be printed. */
  [[NSNotificationCenter defaultCenter]
    postNotificationName: foo
    object: nil];

  
  [[NSNotificationCenter defaultCenter]
    removeObserver: observer1
    name: nil
    object: o1];

  /* This will cause message to be printed. */
  [[NSNotificationCenter defaultCenter]
    postNotificationName: foo
    object: o1];

  [[NSNotificationCenter defaultCenter]
    removeObserver: observer1];

  /* This will cause no messages to be printed. */
  [[NSNotificationCenter defaultCenter]
    postNotificationName: foo
    object: o1];

  [arp release];

  exit (0);
}
