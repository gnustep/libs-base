/* Implementation additive congruential pseudo-random num generating
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994

   This file is part of the GNU Objective C Class Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#include <gnustep/base/RNGAdditiveCongruential.h>
#include <gnustep/base/objc-malloc.h>
#include <gnustep/base/Coder.h>
#include <limits.h>

/* Additive Congruential Method,
   from Robert Sedgewick, "Algorithms" */

/* The Chi^2 test results for this RNG is bad.
   xxx Find the bug. */

@implementation RNGAdditiveCongruential

- initWithTableSize: (int)s tapsAtOffsets: (int)t1 :(int)t2
{
  [super init];
  table_size = s;
  tap1 = t1;
  tap2 = t2;
  OBJC_MALLOC(table, long, table_size);
  [self setRandomSeed:0];
  return self;
}

- (void) encodeWithCoder: anEncoder
{
  [self notImplemented:_cmd];
}

- initWithCoder: aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

- (void) dealloc
{
  OBJC_FREE(table);
  [super dealloc];
}

- init
{
  [self initWithTableSize:55 tapsAtOffsets:31 :55];
  return self;
}

#define BITS_PER_CHAR 8
#define HIGH_BYTE(X) ((X) / (1 << (sizeof(X)-1) * BITS_PER_CHAR))

- (long) nextRandom
{
  int i;
  long result = 0;

  /* Grab only the high bytes---they are the most random */
  for (i = 0; i < sizeof(long); i++)
    {
      index = (index + 1) % table_size;
      table[index] = (table[(index + table_size - tap1) % table_size]
		      +
		      table[(index + table_size - tap2) % table_size]);
      result = (result << BITS_PER_CHAR) + HIGH_BYTE(table[index]);
    }
  return result;
}

- (void) setRandomSeed: (long)s
{
  /* Fill the table with the linear congruential method, 
     from Robert Sedgewick, "Algorithms" */
  /* b must be x21, with x even, one less number of digits than ULONG_MAX */
  unsigned long b = ((ULONG_MAX / 1000) * 200) + 21;
  unsigned char *byte_table = (unsigned char*) table;
  int byte_table_size = table_size * sizeof(*table);
  int i;

  for (i = 0; i < byte_table_size; i++)
    {
      s = s * b + 1;
      byte_table[i] = HIGH_BYTE(s);
    }

  /* Reset index to beginning */
  index = 0;
  return;
}

@end
