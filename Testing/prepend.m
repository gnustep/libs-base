/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
/*
From: Matthias Klose <doko@cs.tu-berlin.de>
Date: Mon, 1 Aug 1994 21:17:20 +0200
To: mccallum@cs.rochester.edu
Subject: bug in libcoll-940725
Reply-to: doko@cs.tu-berlin.de

Hello, the following code core dumps on Solaris 2.3 (compiled with gcc
2.5.8 -g -O and with -g) and on NeXTstep 3.2 (gcc 2.5.8).
Any hints?
*/

#include <GNUstepBase/Queue.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>

int main ()
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  Array *a;
  CircularArray *c;
  Queue *q;

  a = [Array new];

  [a prependObject: [NSObject new]];
  [a prependObject: [NSObject new]];
  [a prependObject: [NSObject new]];
  printf("count: %d\n", [a count]);
  [a insertObject: [NSObject new] atIndex: 2]; // ok!
  printf("count: %d\n", [a count]);

  c = [CircularArray new];
  [c prependObject: [NSNumber numberWithInt:3]];
  [c prependObject: [NSNumber numberWithInt:2]];
  [c prependObject: [NSNumber numberWithInt:1]];
  [c insertObject:[NSNumber numberWithInt:0] atIndex:2]; // core dump!

  q = [Queue new];
  [q enqueueObject: [NSObject new]];
  [q enqueueObject: [NSObject new]];
  [q enqueueObject: [NSObject new]];
  printf("count: %d\n", [q count]);
  [q insertObject: [NSObject new] atIndex: 2]; // core dump!
  printf("count: %d\n", [q count]);

  [pool release];
  exit (0);
}
