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

#include <objects/Queue.h>

int main ()
{
	Array *a;
	CircularArray *c;
	Queue *q;

	a = [Array new];

	[a prependObject: [Object new]];
	[a prependObject: [Object new]];
	[a prependObject: [Object new]];
	printf("count: %d\n", [a count]);
	[a insertObject: [Object new] atIndex: 2]; // ok!
	printf("count: %d\n", [a count]);

	c = [[CircularArray alloc] initWithType:@encode(int)];
	[c prependElement: 3];
	[c prependElement: 2];
	[c prependElement: 1];
	[c insertElement:0 atIndex:2]; // core dump!

	q = [Queue new];
	[q enqueueObject: [Object new]];
	[q enqueueObject: [Object new]];
	[q enqueueObject: [Object new]];
	printf("count: %d\n", [q count]);
	[q insertObject: [Object new] atIndex: 2]; // core dump!
	printf("count: %d\n", [q count]);
	return 0;
}
