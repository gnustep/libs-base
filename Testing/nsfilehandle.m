#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>

int
main ()
{
  id pool;
  id src;
  id dst;
  id d0;
  id d1;

  pool = [[NSAutoreleasePool alloc] init];

  src = [[NSFileHandle fileHandleForReadingAtPath:@"nsfilehandle.m"] retain];
  assert(src != nil);
  dst = [[NSFileHandle fileHandleForWritingAtPath:@"nsfilehandle.dat"] retain];
  if (dst == nil)
    {
      creat("nsfilehandle.dat", 0644);
      dst = [[NSFileHandle fileHandleForWritingAtPath:@"nsfilehandle.dat"] retain];
    }
  assert(dst != nil);

  d0 = [[src readDataToEndOfFile] retain];
  [dst writeData:d0];
  [src release];
  [dst release];
  [pool release];

  pool = [[NSAutoreleasePool alloc] init];
  src = [[NSFileHandle fileHandleForReadingAtPath:@"nsfilehandle.dat"] retain];
  d1 = [[src readDataToEndOfFile] retain];
  [src release];
  [pool release];

  unlink("nsfilehandle.dat");

  if ([d0 isEqual:d1])
    printf("Test passed (length:%d)\n", [d1 length]);
  else
    printf("Test failed\n");

  exit (0);
}
