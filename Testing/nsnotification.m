/* The simplest of tests for the NSNotification and NSNotificationCenter
   classes.  These tests should be expanded. 

   (The Tcp*Port classes, however, do test the notification mechanism 
    further.) */

#include <Foundation/Foundation.h>

@interface Observer : NSObject
- (void) gotNotificationFoo: not;
@end

@implementation Observer

- (void) gotNotificationFoo: (NSNotification*)not
{
  printf ("Got %s\n", [[not name] cString]);
}

- (void) gotNotificationFooNoObject: (NSNotification*)not
{
  printf ("Got %s without object\n", [[not name] cString]);
}

@end

id foo = @"NotificationTestFoo";

int main ()
{
  id o1;
  id observer1;
  id arp;

  arp = [NSAutoreleasePool new];
NSLog(@"Make string object");
  o1 = [NSString new];
NSLog(@"Make Observer object");
  observer1 = [Observer new];

NSLog(@"Add observer to process centre");

  [[NSNotificationCenter defaultCenter]
    addObserver: observer1
    selector: @selector(gotNotificationFoo:)
    name: foo
    object: o1];

NSLog(@"Add observer to distributed centre");
  [[NSDistributedNotificationCenter defaultCenter]
    addObserver: observer1
    selector: @selector(gotNotificationFoo:)
    name: foo
    object: o1];

NSLog(@"Add observer to process centre");
  [[NSNotificationCenter defaultCenter]
    addObserver: observer1
    selector: @selector(gotNotificationFooNoObject:)
    name: foo
    object: nil];

NSLog(@"Add observer to distributed centre");
  [[NSDistributedNotificationCenter defaultCenter]
    addObserver: observer1
    selector: @selector(gotNotificationFooNoObject:)
    name: foo
    object: nil];


NSLog(@"Post to process centre");
  /* This will cause two messages to be printed, one for each request above. */
  [[NSNotificationCenter defaultCenter]
    postNotificationName: foo
    object: o1];

NSLog(@"Post to distributed centre");
  /* This will cause two messages to be printed, one for each request above. */
  [[NSDistributedNotificationCenter defaultCenter]
    postNotificationName: foo
    object: o1];

NSLog(@"Post to process centre");
  /* This will cause one message to be printed. */
  [[NSNotificationCenter defaultCenter]
    postNotificationName: foo
    object: nil];

NSLog(@"Post to distributed centre");
  /* This will cause one message to be printed. */
  [[NSDistributedNotificationCenter defaultCenter]
    postNotificationName: foo
    object: nil];

  
NSLog(@"Remove observer from process centre");
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

  [[NSDistributedNotificationCenter defaultCenter]
    addObserver: observer1
    selector: @selector(gotNotificationFooNoObject:)
    name: foo
    object: nil];

  [[NSDistributedNotificationCenter defaultCenter]
    postNotificationName: foo
    object: @"hello"];

  [arp release];

  exit (0);
}
