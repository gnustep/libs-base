#include <Foundation/NSData.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>

int
main()
{
  id d;
  id pool;

  pool = [[NSAutoreleasePool alloc] init];

  d = [NSData dataWithContentsOfMappedFile:@"nsdata.m"];
  if (d == nil)
    printf("Unable to map file");
  printf("Mapped %d bytes\n", [d length]);
  [pool release];

  exit(0);
}
