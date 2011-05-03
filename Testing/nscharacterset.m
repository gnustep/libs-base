/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSAutoreleasePool.h>

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSCharacterSet *alpha = [NSCharacterSet alphanumericCharacterSet];

  if (alpha)
    printf("obtained alphanumeric character set\n");
  else
    printf("unable to obtain alphanumeric character set\n");

  [arp release];
  exit(0);
}
