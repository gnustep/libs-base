/* Interface for Berkeley random()-compatible generation for Objective-C

   Reworked by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

   This file is part of the GNUstep Base Library.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
*/ 

#ifndef __RNGBerkeley_h_GNUSTEP_BASE_INCLUDE
#define __RNGBerkeley_h_GNUSTEP_BASE_INCLUDE

/*
 * Copyright (c) 1983 Regents of the University of California.
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
 * It was reworked for the GNU Objective-C Library by Andrew Kachites McCallum
 */

#include <base/preface.h>
#include <base/RandomGenerating.h>

@interface RNGBerkeley : NSObject <RandomGenerating>
{
  int foo[2];
  long int randtbl[32];  /* Size must match DEG_3 + 1 from RNGBerkeley.m */
  long int *fptr;
  long int *rptr;
  long int *state;
  int rand_type;
  int rand_deg;
  int rand_sep;
  long int *end_ptr;
}

- (void) _srandom: (unsigned int)x;
- (void*) _initstateSeed: (unsigned int)seed 
     state: (void*)arg_state 
     size: (size_t)n;
- (void*) _setstate: (void*)arg_state;

@end

#endif /* __RNGBerkeley_h_GNUSTEP_BASE_INCLUDE */
