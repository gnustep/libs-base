/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <Foundation/Foundation.h>

static int errors = 0;

@interface Handler : NSObject
- (BOOL) fileManager: (NSFileManager*)manager
shouldProceedAfterError: (NSString*)error;
- (BOOL) fileManager: (NSFileManager*)manager
willProcessPath: (NSString*)path;
@end

@implementation Handler
- (BOOL) fileManager: (NSFileManager*)manager
shouldProceedAfterError: (NSString*)error
{
  NSLog(@"Error - %@", error);
  errors++;
  return NO;
}
- (BOOL) fileManager: (NSFileManager*)manager
willProcessPath: (NSString*)path
{
  NSLog(@"Processing %@", path);
  errors++;
  return NO;
}
@end

int
main ()
{
  CREATE_AUTORELEASE_POOL(arp);
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSString	*src;
  NSString	*dst;
  Handler	*handler = AUTORELEASE([Handler new]);

  src = [defs stringForKey: @"CopySrc"];
  dst = [defs objectForKey: @"CopyDst"];
  if (src != nil && dst != nil)
    {
      if ([mgr copyPath: src toPath: dst handler: handler] ==  NO)
	{
	  NSLog(@"Copy %@ to %@ failed", src, dst);
          errors++;
	}
    }

  src = [defs stringForKey: @"LinkSrc"];
  dst = [defs objectForKey: @"LinkDst"];
  if (src != nil && dst != nil)
    {
      if ([mgr linkPath: src toPath: dst handler: handler] ==  NO)
	{
	  NSLog(@"Link %@ to %@ failed", src, dst);
          errors++;
	}
    }

  src = [defs stringForKey: @"Remove"];
  if (src != nil)
    {
      if ([mgr removeFileAtPath: src handler: handler] ==  NO)
	{
	  NSLog(@"Remove %@ failed", src);
          errors++;
	}

    }

  RELEASE(arp);
  if (errors == 0)
    printf("Tests passed\n");
  exit (0);
}
