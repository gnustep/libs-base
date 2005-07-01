/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
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
