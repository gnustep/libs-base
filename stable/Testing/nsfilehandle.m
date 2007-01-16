/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSURL.h>
#include <assert.h>

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
  [(NSFileHandle*)dst writeData: d0];
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

  pool = [[NSAutoreleasePool alloc] init];
  src = [NSURL URLWithString: @"http://www.w3.org/index.html"];
  d0 = [src resourceDataUsingCache: NO];
  NSLog(@"Data is %@", d0);
  [pool release];
  
  exit (0);
}
