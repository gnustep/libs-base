// Fri Oct 23 03:02:52 MET DST 1998 	dave@turbocat.de

#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSHost.h>
#include    <Foundation/NSAutoreleasePool.h>

void
displayHost(NSHost* h)
{
  NSArray*	a;
  int		i;

  printf("\n");
  a = [h names];
  for (i = 0; i < [a count]; i++)
    printf("%s\n", [[a objectAtIndex:i] cString]);
  a = [h addresses];
  for (i = 0; i < [a count]; i++)
    printf("%s\n", [[a objectAtIndex:i] cString]);
}

int
main ()
{
  NSHost*	a;
  NSHost*	c;
  NSHost*	n;
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  [NSAutoreleasePool enableDoubleReleaseCheck:YES];
  c = [NSHost currentHost];
  displayHost(c);
  n = [NSHost hostWithName:[c name]];
  displayHost(n);
  a = [NSHost hostWithAddress:[c address]];
  displayHost(a);

  printf("c:%lx, n:%lx, a:%lx\n", c, n, a);
  printf("c isEqual: n ... %d\n", [c isEqual: n]);
  printf("n isEqual: c ... %d\n", [n isEqual: c]);
  printf("c isEqual: a ... %d\n", [c isEqual: a]);
  printf("a isEqual: c ... %d\n", [a isEqual: c]);
  printf("n isEqual: a ... %d\n", [n isEqual: a]);
  printf("a isEqual: n ... %d\n", [a isEqual: n]);

  [NSHost setHostCacheEnabled:NO];

  n = [NSHost hostWithName:[c name]];
  displayHost(n);
  printf("c:%lx, n:%lx, a:%lx\n", c, n, a);
  printf("c isEqual: n ... %d\n", [c isEqual: n]);
  printf("n isEqual: c ... %d\n", [n isEqual: c]);
  printf("c isEqual: a ... %d\n", [c isEqual: a]);
  printf("a isEqual: c ... %d\n", [a isEqual: c]);
  printf("n isEqual: a ... %d\n", [n isEqual: a]);
  printf("a isEqual: n ... %d\n", [a isEqual: n]);

  [arp release];
  exit (0);
}
