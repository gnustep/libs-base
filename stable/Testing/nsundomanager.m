/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/

#include <Foundation/Foundation.h>

@interface	UndoObject: NSObject
{
  int	state;
}
- (void) setState: (int)aState;
- (int) state;
@end
@implementation	UndoObject
- (void) setState: (int)aState
{
  state = aState;
}
- (int) state
{
  return state;
}
@end

int
main ()
{
  CREATE_AUTORELEASE_POOL(arp);
  NSUndoManager	*u = [NSUndoManager new];
  UndoObject	*o = [UndoObject new];
  BOOL		failed = NO;

  [u registerUndoWithTarget: o selector: @selector(setState:) object: (id)1];
  [u undo];
  if ([o state] != 1)
    {
      NSLog(@"Failed undo");
      failed = YES;
    }
  RELEASE(arp);
  if (failed == NO)
    {
      NSLog(@"Test passed");
    }
  exit (0);
}
