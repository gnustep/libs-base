/* GSByteOrder.h - GNUstep primitive byte-swapping functions
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1998

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef __GSByteOrder_h_GNUSTEP_BASE_INCLUDE
#define __GSByteOrder_h_GNUSTEP_BASE_INCLUDE

#import	<GNUstepBase/GSConfig.h>
#include <stdint.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if (__GNUC__ == 2) && (__GNUC_MINOR__ <= 6) && !defined(__attribute__)
#  define __attribute__(x)
#endif

/*
 *	GNUstep functions for primitive byte swapping.
 *	These reverse the bytes of a value regardless of host byte order.
 */
static inline uint16_t
GSSwapI16(uint16_t in) __attribute__((unused));
static inline uint32_t
GSSwapI32(uint32_t in) __attribute__((unused));
static inline uint64_t
GSSwapI64(uint64_t in) __attribute__((unused));
static inline gsu128
GSSwapI128(gsu128 in) __attribute__((unused));

#if (__GNUC__ == 3) && (__GNUC_MINOR__ == 1)
/* gcc 3.1 with option -O2 generates bad (i386?) code when compiling
   the following inline functions inside a .m file.  A call to a
   dumb function seems to work. */
extern void _gcc3_1_hack(void);
#endif

static inline uint16_t
GSSwapI16(uint16_t in)
{
  union swap {
    uint16_t	num;
    uint8_t	byt[2];
  } dst;
  union swap	*src = (union swap*)&in;
#if (__GNUC__ == 3) && (__GNUC_MINOR__ == 1)
  _gcc3_1_hack();
#endif
  dst.byt[0] = src->byt[1];
  dst.byt[1] = src->byt[0];
  return dst.num;
}

static inline uint32_t
GSSwapI32(uint32_t in)
{
  union swap {
    uint32_t	num;
    uint8_t	byt[4];
  } dst;
  union swap	*src = (union swap*)&in;
#if (__GNUC__ == 3) && (__GNUC_MINOR__ == 1)
  _gcc3_1_hack();
#endif
  dst.byt[0] = src->byt[3];
  dst.byt[1] = src->byt[2];
  dst.byt[2] = src->byt[1];
  dst.byt[3] = src->byt[0];
  return dst.num;
}

static inline uint64_t
GSSwapI64(uint64_t in)
{
  union swap {
    uint64_t	num;
    uint8_t	byt[8];
  } dst;
  union swap	*src = (union swap*)&in;
#if (__GNUC__ == 3) && (__GNUC_MINOR__ == 1)
  _gcc3_1_hack();
#endif
  dst.byt[0] = src->byt[7];
  dst.byt[1] = src->byt[6];
  dst.byt[2] = src->byt[5];
  dst.byt[3] = src->byt[4];
  dst.byt[4] = src->byt[3];
  dst.byt[5] = src->byt[2];
  dst.byt[6] = src->byt[1];
  dst.byt[7] = src->byt[0];
  return dst.num;
}

static inline gsu128
GSSwapI128(gsu128 in)
{
  union swap {
    gsu128	num;
    uint8_t	byt[16];
  } dst;
  union swap	*src = (union swap*)&in;
#if (__GNUC__ == 3) && (__GNUC_MINOR__ == 1)
  _gcc3_1_hack();
#endif
  dst.byt[0] = src->byt[15];
  dst.byt[1] = src->byt[14];
  dst.byt[2] = src->byt[13];
  dst.byt[3] = src->byt[12];
  dst.byt[4] = src->byt[11];
  dst.byt[5] = src->byt[10];
  dst.byt[6] = src->byt[9];
  dst.byt[7] = src->byt[8];
  dst.byt[8] = src->byt[7];
  dst.byt[9] = src->byt[6];
  dst.byt[10] = src->byt[5];
  dst.byt[11] = src->byt[4];
  dst.byt[12] = src->byt[3];
  dst.byt[13] = src->byt[2];
  dst.byt[14] = src->byt[1];
  dst.byt[15] = src->byt[0];
  return dst.num;
}

#if	defined(__cplusplus)
}
#endif

#endif /* __GSByteOrder_h_GNUSTEP_BASE_INCLUDE */
