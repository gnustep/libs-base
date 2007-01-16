/* Test Class for NSBundle.
   Copyright (C) 1993,1994,1995 Free Software Foundation, Inc.

  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Jul 1995

   This file is part of the GNUstep Base Library.

*/
#include "SecondClass.h"
#include <Foundation/NSString.h>

@implementation SecondClass

- init
{
    [super init];
    h = 25;
    return self;
}

- printName

{
  printf("Hi my name is %s\n", [[self description] cString]);
  return self;
}

@end
