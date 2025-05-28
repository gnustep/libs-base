#import "ObjectTesting.h"
#import <Foundation/NSHost.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSString	*s;
  NSHost *current;
  NSHost *localh;
  NSHost *tmp; 

  tmp = [NSHost hostWithName: @"www.w3.org"];
  PASS(tmp != nil, "NSHost gets www.w3.org");
  NSLog(@"www.w3.org is %@", tmp);

  tmp = [NSHost hostWithName: @"www.gnustep.org"];
  PASS(tmp != nil, "NSHost gets www.gnustep.org");
  NSLog(@"www.gnustep.org is %@", tmp);

  current = [NSHost currentHost];
  PASS(current != nil && [current isKindOfClass: [NSHost class]],
       "NSHost understands +currentHost");
  NSLog(@"+currentHost is %@", current);
 
#if	defined(GNUSTEP_BASE_LIBRARY)
  localh = [NSHost localHost];
  PASS(localh != nil && [localh isKindOfClass: [NSHost class]],
       "NSHost understands +localHost");
  NSLog(@"+localHost is %@", localh);
#else
  localh = current;
#endif

  tmp = [NSHost hostWithName: @"::1"];
  PASS([[tmp address] isEqual: @"::1"], "+hostWithName: works for IPV6 addr");
  NSLog(@"::1 is %@", tmp);

  s = [current name];
  tmp = [NSHost hostWithName: s];
  PASS([tmp isEqualToHost: current], "NSHost understands +hostWithName:");
  NSLog(@"+hostWithName: %@ is %@", s, tmp);
  
  s = [current address];
  tmp = [NSHost hostWithAddress: s];
  PASS([tmp isEqualToHost: current], "NSHost understands +hostWithAddress:");
  NSLog(@"+hostWithAddress: %@ is %@", s, tmp);
  
  tmp = [NSHost hostWithName: @"127.0.0.1"];
  PASS(tmp != nil && [tmp isEqualToHost: localh], 
       "NSHost understands [+hostWithName: 127.0.0.1]");
  NSLog(@"127.0.0.1 is %@", tmp);
  
  [arp release]; arp = nil;
  return 0;
}
