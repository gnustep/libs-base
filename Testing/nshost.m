#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSHost.h>

void
displayHost(NSHost* h)
{
  NSArray*	a;
  int		i;

  printf("\n");
  a = [h names];
  for (i = 0; i < [a count]; i++)
    printf("%s\n", [[a objectAtIndex:i] cStringNoCopy]);
  a = [h addresses];
  for (i = 0; i < [a count]; i++)
    printf("%s\n", [[a objectAtIndex:i] cStringNoCopy]);
}

int
main ()
{
  NSHost*	a;
  NSHost*	c;
  NSHost*	n;

  c = [NSHost currentHost];
  displayHost(c);
  n = [NSHost hostWithName:[c name]];
  displayHost(n);
  a = [NSHost hostWithAddress:[c address]];
  displayHost(a);

  printf("c:%lx, n:%lx, a:%lx\n", c, n, a);

  [NSHost setHostCacheEnabled:NO];

  [n release];
  n = [NSHost hostWithName:[c name]];
  displayHost(n);
  printf("c:%lx, n:%lx, a:%lx\n", c, n, a);

  exit (0);
}
