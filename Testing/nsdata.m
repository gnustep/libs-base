#include <Foundation/NSData.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>

int
main()
{
  id a;
  id d;
  id o;
  id pool;

  [NSAutoreleasePool enableDoubleReleaseCheck:YES];

  pool = [[NSAutoreleasePool alloc] init];

  d = [NSData dataWithContentsOfMappedFile:@"nsdata.m"];
  if (d == nil)
    printf("Unable to map file");
  printf("Mapped %d bytes\n", [d length]);

  o = [d copy];
  printf("Copied %d bytes\n", [o length]);
  [o release];

  o = [d mutableCopy];
  printf("Copied %d bytes\n", [o length]);
  [o release];

  d = [NSData dataWithContentsOfFile:@"nsdata.m"];
  if (d == nil)
    printf("Unable to read file");
  printf("Read %d bytes\n", [d length]);

  o = [d copy];
  printf("Copied %d bytes\n", [o length]);
  [o release];

  o = [d mutableCopy];
  printf("Copied %d bytes\n", [o length]);
  [o release];

  d = [NSData dataWithSharedBytes: [d bytes] length: [d length]];
  if (d == nil)
    printf("Unable to make shared data");
  printf("Shared data of %d bytes\n", [d length]);

  o = [d copy];
  printf("Copied %d bytes\n", [o length]);
  [o release];

  o = [d mutableCopy];
  printf("Copied %d bytes\n", [o length]);
  [o release];

  d = [NSMutableData dataWithSharedBytes: [d bytes] length: [d length]];
  if (d == nil)
    printf("Unable to make mutable shared data");
  printf("Mutable shared data of %d bytes\n", [d length]);

  o = [d copy];
  printf("Copied %d bytes\n", [o length]);
  [o release];

  o = [d mutableCopy];
  printf("Copied %d bytes\n", [o length]);
  [o release];

  [d appendBytes: "Hello world" length: 11];
  printf("Extended by 11 bytes to %d bytes\n", [d length]);

  d = [NSMutableData dataWithShmID: [d shmID] length: [d length]];
  if (d == nil)
    printf("Unable to make mutable data with old ID\n");
  printf("data with shmID gives data length %d\n", [d length]);

  a = [[NSArchiver new] autorelease];
  [a encodeRootObject: d];
  printf("Encoded data into archive\n");
  a = [[NSUnarchiver alloc] initForReadingWithData: [a archiverData]];
  o = [a decodeObject];
  printf("Decoded data from archive - length %d\n", [o length]);
  [a release];

  [d setCapacity: 2000000];
  printf("Set capacity of shared memory item to %d\n", [d capacity]);

  [pool release];

  exit(0);
}

