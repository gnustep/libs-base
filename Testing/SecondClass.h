/* Test Class for NSBundle.
   Copyright (C) 1993,1994,1995 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Jul 1995

   This file is part of the GNU Objective C Class Library.

*/
#include <Foundation/NSObject.h>

@interface SecondClass : NSObject
{
    int h;
    char *dummy;
}

- init;
- printName;

@end
