/* Implementation of Berkeley random()-compatible generation for Objective-C

   Reworked by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
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

/*
 * Copyright (c) 1983, 1995 Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms are permitted
 * provided that the above copyright notice and this paragraph are
 * duplicated in all such forms and that any documentation,
 * advertising materials, and other materials related to such
 * distribution and use acknowledge that the software was developed
 * by the University of California, Berkeley.  The name of the
 * University may not be used to endorse or promote products derived
 * from this software without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 * WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 */

/*
 * This is derived from the Berkeley source:
 *	@(#)random.c	5.5 (Berkeley) 7/6/88
 * It was reworked for the GNU C Library by Roland McGrath.
 * It was reworked for the GNU Objective-C Library by R. Andrew McCallum
 */

#include <gnustep/base/RNGBerkeley.h>
#include <gnustep/base/Coder.h>
#include <errno.h>
#include <limits.h>
#include <stddef.h>
#include <stdlib.h>

//#include <sys/time.h>

/* Deal with bcopy: */
#if STDC_HEADERS || HAVE_STRING_H
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && HAVE_MEMORY_H
#include <memory.h>
#endif /* not STDC_HEADERS and HAVE_MEMORY_H */
#define index strchr
#define rindex strrchr
#define bcopy(s, d, n) memcpy ((d), (s), (n))
#define bcmp(s1, s2, n) memcmp ((s1), (s2), (n))
#define bzero(s, n) memset ((s), 0, (n))
#else /* not STDC_HEADERS and not HAVE_STRING_H */
#include <strings.h>
/* memory.h and strings.h conflict on some systems.  */
#endif /* not STDC_HEADERS and not HAVE_STRING_H */


/* An improved random number generation package.  In addition to the standard
   rand()/srand() like interface, this package also has a special state info
   interface.  The initstate() routine is called with a seed, an array of
   bytes, and a count of how many bytes are being passed in; this array is
   then initialized to contain information for random number generation with
   that much state information.  Good sizes for the amount of state
   information are 32, 64, 128, and 256 bytes.  The state can be switched by
   calling the setstate() function with the same array as was initiallized
   with initstate().  By default, the package runs with 128 bytes of state
   information and generates far better random numbers than a linear
   congruential generator.  If the amount of state information is less than
   32 bytes, a simple linear congruential R.N.G. is used.  Internally, the
   state information is treated as an array of longs; the zeroeth element of
   the array is the type of R.N.G. being used (small integer); the remainder
   of the array is the state information for the R.N.G.  Thus, 32 bytes of
   state information will give 7 longs worth of state information, which will
   allow a degree seven polynomial.  (Note: The zeroeth word of state
   information also has some other information stored in it; see setstate
   for details).  The random number generation technique is a linear feedback
   shift register approach, employing trinomials (since there are fewer terms
   to sum up that way).  In this approach, the least significant bit of all
   the numbers in the state table will act as a linear feedback shift register,
   and will have period 2^deg - 1 (where deg is the degree of the polynomial
   being used, assuming that the polynomial is irreducible and primitive).
   The higher order bits will have longer periods, since their values are
   also influenced by pseudo-random carries out of the lower bits.  The
   total period of the generator is approximately deg*(2**deg - 1); thus
   doubling the amount of state information has a vast influence on the
   period of the generator.  Note: The deg*(2**deg - 1) is an approximation
   only good for large deg, when the period of the shift register is the
   dominant factor.  With deg equal to seven, the period is actually much
   longer than the 7*(2**7 - 1) predicted by this formula.  */



/* For each of the currently supported random number generators, we have a
   break value on the amount of state information (you need at least thi
   bytes of state info to support this random number generator), a degree for
   the polynomial (actually a trinomial) that the R.N.G. is based on, and
   separation between the two lower order coefficients of the trinomial.  */


/* Linear congruential.  */
#define	TYPE_0		0
#define	BREAK_0		8
#define	DEG_0		0
#define	SEP_0		0

/* x**7 + x**3 + 1.  */
#define	TYPE_1		1
#define	BREAK_1		32
#define	DEG_1		7
#define	SEP_1		3

/* x**15 + x + 1.  */
#define	TYPE_2		2
#define	BREAK_2		64
#define	DEG_2		15
#define	SEP_2		1

/* x**31 + x**3 + 1.  */
#define	TYPE_3		3
#define	BREAK_3		128
#define	DEG_3		31
#define	SEP_3		3

/* x**63 + x + 1.  */
#define	TYPE_4		4
#define	BREAK_4		256
#define	DEG_4		63
#define	SEP_4		1

/* Array versions of the above information to make code run faster.
   Relies on fact that TYPE_i == i.  */

#define	MAX_TYPES	5	/* Max number of types above.  */

static int degrees[MAX_TYPES] = { DEG_0, DEG_1, DEG_2, DEG_3, DEG_4 };
static int seps[MAX_TYPES] = { SEP_0, SEP_1, SEP_2, SEP_3, SEP_4 };



/* Initially, everything is set up as if from:
	initstate(1, randtbl, 128);
   Note that this initialization takes advantage of the fact that srandom
   advances the front and rear pointers 10*rand_deg times, and hence the
   rear pointer which starts at 0 will also end up at zero; thus the zeroeth
   element of the state information, which contains info about the current
   position of the rear pointer is just
	(MAX_TYPES * (rptr - state)) + TYPE_3 == TYPE_3.  */

#if 0 /* moved to RNGBerkeley.h -am */
static long int randtbl[DEG_3 + 1] =
  {
    TYPE_3,
    -851904987, -43806228, -2029755270, 1390239686, -1912102820,
    -485608943, 1969813258, -1590463333, -1944053249, 455935928, 508023712,
    -1714531963, 1800685987, -2015299881, 654595283, -1149023258,
    -1470005550, -1143256056, -1325577603, -1568001885, 1275120390,
    -607508183, -205999574, -1696891592, 1492211999, -1528267240,
    -952028296, -189082757, 362343714, 1424981831, 2039449641,
  };
#endif /* moved to RNGBerkeley.h -am */

/* FPTR and RPTR are two pointers into the state info, a front and a rear
   pointer.  These two pointers are always rand_sep places aparts, as they
   cycle through the state information.  (Yes, this does mean we could get
   away with just one pointer, but the code for random is more efficient
   this way).  The pointers are left positioned as they would be from the call:
	initstate(1, randtbl, 128);
   (The position of the rear pointer, rptr, is really 0 (as explained above
   in the initialization of randtbl) because the state table pointer is set
   to point to randtbl[1] (as explained below).)  */

#if 0 /* moved to RNGBerkeley.h -am */
static long int *fptr = &randtbl[SEP_3 + 1];
static long int *rptr = &randtbl[1];
#endif /* moved to RNGBerkeley.h -am */


/* The following things are the pointer to the state information table,
   the type of the current generator, the degree of the current polynomial
   being used, and the separation between the two pointers.
   Note that for efficiency of random, we remember the first location of
   the state information, not the zeroeth.  Hence it is valid to access
   state[-1], which is used to store the type of the R.N.G.
   Also, we remember the last location, since this is more efficient than
   indexing every time to find the address of the last element to see if
   the front and rear pointers have wrapped.  */

#if 0 /* moved to RNGBerkeley.h -am */
static long int *state = &randtbl[1];

static int rand_type = TYPE_3;
static int rand_deg = DEG_3;
static int rand_sep = SEP_3;

static long int *end_ptr = &randtbl[sizeof(randtbl) / sizeof(randtbl[0])];
#endif /* moved to RNGBerkeley.h -am */


@implementation RNGBerkeley

- init
{
  static long int static_randtbl[DEG_3 + 1] =
    {
      TYPE_3,
      -851904987, -43806228, -2029755270, 1390239686, -1912102820,
      -485608943, 1969813258, -1590463333, -1944053249, 455935928, 508023712,
      -1714531963, 1800685987, -2015299881, 654595283, -1149023258,
      -1470005550, -1143256056, -1325577603, -1568001885, 1275120390,
      -607508183, -205999574, -1696891592, 1492211999, -1528267240,
      -952028296, -189082757, 362343714, 1424981831, 2039449641,
    };
  [super init];
  bcopy(static_randtbl, randtbl, sizeof(randtbl));
  fptr = &randtbl[SEP_3 + 1];
  rptr = &randtbl[1];
  state = &randtbl[1];
  rand_type = TYPE_3;
  rand_deg = DEG_3;
  rand_sep = SEP_3;
  end_ptr = &randtbl[sizeof(randtbl) / sizeof(randtbl[0])];
  return self;
}

/* Initialize the random number generator based on the given seed.  If the
   type is the trivial no-state-information type, just remember the seed.
   Otherwise, initializes state[] based on the given "seed" via a linear
   congruential generator.  Then, the pointers are set to known locations
   that are exactly rand_sep places apart.  Lastly, it cycles the state
   information a given number of times to get rid of any initial dependencies
   introduced by the L.C.R.N.G.  Note that the initialization of randtbl[]
   for default usage relies on values produced by this routine.  */
- (void) _srandom: (unsigned int)x
{
  state[0] = x;
  if (rand_type != TYPE_0)
    {
      register long int i;
      for (i = 1; i < rand_deg; ++i)
	state[i] = (1103515145 * state[i - 1]) + 12345;
      fptr = &state[rand_sep];
      rptr = &state[0];
      for (i = 0; i < 10 * rand_deg; ++i)
	[self nextRandom];	/* (void) __random(); */
    }
}

- (void) setRandomSeed: (long)aSeed
{
  [self _srandom:aSeed];
  return;
}


/* Initialize the state information in the given array of N bytes for
   future random number generation.  Based on the number of bytes we
   are given, and the break values for the different R.N.G.'s, we choose
   the best (largest) one we can and set things up for it.  srandom is
   then called to initialize the state information.  Note that on return
   from srandom, we set state[-1] to be the type multiplexed with the current
   value of the rear pointer; this is so successive calls to initstate won't
   lose this information and will be able to restart with setstate.
   Note: The first thing we do is save the current state, if any, just like
   setstate so that it doesn't matter when initstate is called.
   Returns a pointer to the old state.  */
- (void*) _initstateSeed: (unsigned int)seed 
    state: (void*)arg_state 
    size: (size_t)n
{
  void* ostate = (void*) &state[-1];

  if (rand_type == TYPE_0)
    state[-1] = rand_type;
  else
    state[-1] = (MAX_TYPES * (rptr - state)) + rand_type;
  if (n < BREAK_1)
    {
      if (n < BREAK_0)
	{
	  errno = EINVAL;
	  return NULL;
	}
      rand_type = TYPE_0;
      rand_deg = DEG_0;
      rand_sep = SEP_0;
    }
  else if (n < BREAK_2)
    {
      rand_type = TYPE_1;
      rand_deg = DEG_1;
      rand_sep = SEP_1;
    }
  else if (n < BREAK_3)
    {
      rand_type = TYPE_2;
      rand_deg = DEG_2;
      rand_sep = SEP_2;
    }
  else if (n < BREAK_4)
    {
      rand_type = TYPE_3;
      rand_deg = DEG_3;
      rand_sep = SEP_3;
    }
  else
    {
      rand_type = TYPE_4;
      rand_deg = DEG_4;
      rand_sep = SEP_4;
    }

  state = &((long int *) arg_state)[1];	/* First location.  */
  /* Must set END_PTR before srandom.  */
  end_ptr = &state[rand_deg];
  [self _srandom:seed];		/*__srandom(seed); */
  if (rand_type == TYPE_0)
    state[-1] = rand_type;
  else
    state[-1] = (MAX_TYPES * (rptr - state)) + rand_type;

  return ostate;
}


/* Restore the state from the given state array.
   Note: It is important that we also remember the locations of the pointers
   in the current state information, and restore the locations of the pointers
   from the old state information.  This is done by multiplexing the pointer
   location into the zeroeth word of the state information. Note that due
   to the order in which things are done, it is OK to call setstate with the
   same state as the current state
   Returns a pointer to the old state information.  */
- (void*) _setstate: (void*)arg_state
{
  register long int *new_state = (long int *) arg_state;
  register int type = new_state[0] % MAX_TYPES;
  register int rear = new_state[0] / MAX_TYPES;
  void* ostate = (void*) &state[-1];

  if (rand_type == TYPE_0)
    state[-1] = rand_type;
  else
    state[-1] = (MAX_TYPES * (rptr - state)) + rand_type;

  switch (type)
    {
    case TYPE_0:
    case TYPE_1:
    case TYPE_2:
    case TYPE_3:
    case TYPE_4:
      rand_type = type;
      rand_deg = degrees[type];
      rand_sep = seps[type];
      break;
    default:
      /* State info munged.  */
      errno = EINVAL;
      return NULL;
    }

  state = &new_state[1];
  if (rand_type != TYPE_0)
    {
      rptr = &state[rear];
      fptr = &state[(rear + rand_sep) % rand_deg];
    }
  /* Set end_ptr too.  */
  end_ptr = &state[rand_deg];

  return ostate;
}


/* If we are using the trivial TYPE_0 R.N.G., just do the old linear
   congruential bit.  Otherwise, we do our fancy trinomial stuff, which is the
   same in all ther other cases due to all the global variables that have been
   set up.  The basic operation is to add the number at the rear pointer into
   the one at the front pointer.  Then both pointers are advanced to the next
   location cyclically in the table.  The value returned is the sum generated,
   reduced to 31 bits by throwing away the "least random" low bit.
   Note: The code takes advantage of the fact that both the front and
   rear pointers can't wrap on the same call by not testing the rear
   pointer if the front one has wrapped.  Returns a 31-bit random number.  */

- (long) nextRandom
{
  if (rand_type == TYPE_0)
    {
      state[0] = ((state[0] * 1103515245) + 12345) & LONG_MAX;
      return state[0];
    }
  else
    {
      long int i;
      *fptr += *rptr;
      /* Chucking least random bit.  */
      i = (*fptr >> 1) & LONG_MAX;
      ++fptr;
      if (fptr >= end_ptr)
	{
	  fptr = state;
	  ++rptr;
	}
      else
	{
	  ++rptr;
	  if (rptr >= end_ptr)
	    rptr = state;
	}
      return i;
    }
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

@end
