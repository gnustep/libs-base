/* NSByteOrder functions for GNUStep
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1998

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#ifndef __NSByteOrder_h_GNUSTEP_BASE_INCLUDE
#define __NSByteOrder_h_GNUSTEP_BASE_INCLUDE

#include <GSConfig.h>

/*
 *	OPENSTEP type definitions for Byte ordering.
 */
typedef gsu32	NSSwappedFloat;
typedef gsu64	NSSwappedDouble;

typedef enum {
  NS_UnknownByteOrder,
  NS_LittleEndian,
  NS_BigEndian
} NSByteOrder;

/*
 *	Function prototypes.
 */

#if (__GNUC__ == 2) && (__GNUC_MINOR__ <= 6) && !defined(__attribute__)
#  define __attribute__(x)
#endif

/*
 *	First the GNUstep functions for byte swapping
 */
static inline gsu16
GSSwapI16(gsu16 in) __attribute__((unused));
static inline gsu32
GSSwapI32(gsu32 in) __attribute__((unused));
static inline gsu64
GSSwapI64(gsu64 in) __attribute__((unused));
static inline gsu128
GSSwapI128(gsu128 in) __attribute__((unused));

static inline gsu16
GSSwapBigI16ToHost(gsu16 in) __attribute__((unused));
static inline gsu32
GSSwapBigI32ToHost(gsu32 in) __attribute__((unused));
static inline gsu64
GSSwapBigI64ToHost(gsu64 in) __attribute__((unused));
static inline gsu128
GSSwapBigI128ToHost(gsu128 in) __attribute__((unused));

static inline gsu16
GSSwapHostI16ToBig(gsu16 in) __attribute__((unused));
static inline gsu32
GSSwapHostI32ToBig(gsu32 in) __attribute__((unused));
static inline gsu64
GSSwapHostI64ToBig(gsu64 in) __attribute__((unused));
static inline gsu128
GSSwapHostI128ToBig(gsu128 in) __attribute__((unused));

static inline gsu16
GSSwapLittleI16ToHost(gsu16 in) __attribute__((unused));
static inline gsu32
GSSwapLittleI32ToHost(gsu32 in) __attribute__((unused));
static inline gsu64
GSSwapLittleI64ToHost(gsu64 in) __attribute__((unused));
static inline gsu128
GSSwapLittleI128ToHost(gsu128 in) __attribute__((unused));

static inline gsu16
GSSwapHostI16ToLittle(gsu16 in) __attribute__((unused));
static inline gsu32
GSSwapHostI32ToLittle(gsu32 in) __attribute__((unused));
static inline gsu64
GSSwapHostI64ToLittle(gsu64 in) __attribute__((unused));
static inline gsu128
GSSwapHostI128ToLittle(gsu128 in) __attribute__((unused));


static inline gsu16
GSSwapI16(gsu16 in)
{
  union swap {
    gsu16	num;
    gsu8	byt[2];
  } dst;
  union swap	*src = (union swap*)&in;
  dst.byt[0] = src->byt[1];
  dst.byt[1] = src->byt[0];
  return dst.num;
}

static inline gsu32
GSSwapI32(gsu32 in)
{
  union swap {
    gsu32	num;
    gsu8	byt[4];
  } dst;
  union swap	*src = (union swap*)&in;
  dst.byt[0] = src->byt[3];
  dst.byt[1] = src->byt[2];
  dst.byt[2] = src->byt[1];
  dst.byt[3] = src->byt[0];
  return dst.num;
}

static inline gsu64
GSSwapI64(gsu64 in)
{
  union swap {
    gsu64	num;
    gsu8	byt[8];
  } dst;
  union swap	*src = (union swap*)&in;
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
    gsu8	byt[16];
  } dst;
  union swap	*src = (union swap*)&in;
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

/*
 *	Now the OpenStep functions
 */
static inline NSSwappedDouble
NSConvertHostDoubleToSwapped(double num) __attribute__((unused));
static inline NSSwappedFloat
NSConvertHostFloatToSwapped(float num) __attribute__((unused));
static inline double
NSConvertSwappedDoubleToHost(NSSwappedDouble num) __attribute__((unused));
static inline float
NSConvertSwappedFloatToHost(NSSwappedFloat num) __attribute__((unused));
static inline unsigned int
NSSwapInt(unsigned int in) __attribute__((unused));
static inline unsigned long long
NSSwapLongLong(unsigned long long in) __attribute__((unused));
static inline unsigned long
NSSwapLong(unsigned long in) __attribute__((unused));
static inline unsigned short
NSSwapShort(unsigned short in) __attribute__((unused));
static inline NSSwappedDouble
NSSwapDouble(NSSwappedDouble num) __attribute__((unused));
static inline NSSwappedFloat
NSSwapFloat(NSSwappedFloat num) __attribute__((unused));
static inline NSByteOrder
NSHostByteOrder(void) __attribute__((unused));
static inline double
NSSwapBigDoubleToHost(NSSwappedDouble num) __attribute__((unused));
static inline float
NSSwapBigFloatToHost(NSSwappedFloat num) __attribute__((unused));
static inline unsigned int
NSSwapBigIntToHost(unsigned int num) __attribute__((unused));
static inline unsigned long long
NSSwapBigLongLongToHost(unsigned long long num) __attribute__((unused));
static inline unsigned long
NSSwapBigLongToHost(unsigned long num) __attribute__((unused));
static inline unsigned short
NSSwapBigShortToHost(unsigned short num) __attribute__((unused));
static inline NSSwappedDouble
NSSwapHostDoubleToBig(double num) __attribute__((unused));
static inline NSSwappedFloat
NSSwapHostFloatToBig(float num) __attribute__((unused));
static inline unsigned int
NSSwapHostIntToBig(unsigned int num) __attribute__((unused));
static inline unsigned long long
NSSwapHostLongLongToBig(unsigned long long num) __attribute__((unused));
static inline unsigned long
NSSwapHostLongToBig(unsigned long num) __attribute__((unused));
static inline unsigned short
NSSwapHostShortToBig(unsigned short num) __attribute__((unused));
static inline double
NSSwapLittleDoubleToHost(NSSwappedDouble num) __attribute__((unused));
static inline float
NSSwapLittleFloatToHost(NSSwappedFloat num) __attribute__((unused));
static inline unsigned int
NSSwapLittleIntToHost(unsigned int num) __attribute__((unused));
static inline unsigned long long
NSSwapLittleLongLongToHost(unsigned long long num) __attribute__((unused));
static inline unsigned long
NSSwapLittleLongToHost(unsigned long num) __attribute__((unused));
static inline unsigned short
NSSwapLittleShortToHost(unsigned short num) __attribute__((unused));
static inline NSSwappedDouble
NSSwapHostDoubleToLittle(double num) __attribute__((unused));
static inline NSSwappedFloat
NSSwapHostFloatToLittle(float num) __attribute__((unused));
static inline unsigned int
NSSwapHostIntToLittle(unsigned int num) __attribute__((unused));
static inline unsigned long long
NSSwapHostLongLongToLittle(unsigned long long num) __attribute__((unused));
static inline unsigned long
NSSwapHostLongToLittle(unsigned long num) __attribute__((unused));
static inline unsigned short
NSSwapHostShortToLittle(unsigned short num) __attribute__((unused));
static inline NSByteOrder
NSHostByteOrder(void) __attribute__((unused));
static inline double
NSSwapBigDoubleToHost(NSSwappedDouble num) __attribute__((unused));
static inline float
NSSwapBigFloatToHost(NSSwappedFloat num) __attribute__((unused));
static inline unsigned int
NSSwapBigIntToHost(unsigned int num) __attribute__((unused));
static inline unsigned long long
NSSwapBigLongLongToHost(unsigned long long num) __attribute__((unused));
static inline unsigned long
NSSwapBigLongToHost(unsigned long num) __attribute__((unused));
static inline unsigned short
NSSwapBigShortToHost(unsigned short num) __attribute__((unused));
static inline NSSwappedDouble
NSSwapHostDoubleToBig(double num) __attribute__((unused));
static inline NSSwappedFloat
NSSwapHostFloatToBig(float num) __attribute__((unused));
static inline unsigned int
NSSwapHostIntToBig(unsigned int num) __attribute__((unused));
static inline unsigned long long
NSSwapHostLongLongToBig(unsigned long long num) __attribute__((unused));
static inline unsigned long
NSSwapHostLongToBig(unsigned long num) __attribute__((unused));
static inline unsigned short
NSSwapHostShortToBig(unsigned short num) __attribute__((unused));
static inline double
NSSwapLittleDoubleToHost(NSSwappedDouble num) __attribute__((unused));
static inline float
NSSwapLittleFloatToHost(NSSwappedFloat num) __attribute__((unused));
static inline unsigned int
NSSwapLittleIntToHost(unsigned int num) __attribute__((unused));
static inline unsigned long long
NSSwapLittleLongLongToHost(unsigned long long num) __attribute__((unused));
static inline unsigned long
NSSwapLittleLongToHost(unsigned long num) __attribute__((unused));
static inline unsigned short
NSSwapLittleShortToHost(unsigned short num) __attribute__((unused));
static inline NSSwappedDouble
NSSwapHostDoubleToLittle(double num) __attribute__((unused));
static inline NSSwappedFloat
NSSwapHostFloatToLittle(float num) __attribute__((unused));
static inline unsigned int
NSSwapHostIntToLittle(unsigned int num) __attribute__((unused));
static inline unsigned long long
NSSwapHostLongLongToLittle(unsigned long long num) __attribute__((unused));
static inline unsigned long
NSSwapHostLongToLittle(unsigned long num) __attribute__((unused));
static inline unsigned short
NSSwapHostShortToLittle(unsigned short num) __attribute__((unused));


/*
 *	Basic byte swapping routines and type conversions
 */
static inline NSSwappedDouble
NSConvertHostDoubleToSwapped(double num)
{
  union dconv {
    double		number;
    NSSwappedDouble     sd;
  };
  return ((union dconv *)&num)->sd;
}

static inline NSSwappedFloat
NSConvertHostFloatToSwapped(float num)
{
  union fconv {
    float		number;
    NSSwappedFloat	sf;
  };
  return ((union fconv *)&num)->sf;
}

static inline double
NSConvertSwappedDoubleToHost(NSSwappedDouble num)
{
  union dconv {
    double		number;
    NSSwappedDouble	sd;
  };
  return ((union dconv *)&num)->number;
}

static inline float
NSConvertSwappedFloatToHost(NSSwappedFloat num)
{
  union fconv {
    float		number;
    NSSwappedFloat	sf;
  };
  return ((union fconv *)&num)->number;
}

static inline unsigned int
NSSwapInt(unsigned int in)
{
#if	GS_SIZEOF_INT == 2
  return GSSwapI16(in);
#else
#if	GS_SIZEOF_INT == 4
  return GSSwapI32(in);
#else
#if	GS_SIZEOF_INT == 8
  return GSSwapI64(in);
#else
  return GSSwapI128(in);
#endif
#endif
#endif
}

static inline unsigned long long
NSSwapLongLong(unsigned long long in)
{
#if	GS_SIZEOF_LONG_LONG == 2
  return GSSwapI16(in);
#else
#if	GS_SIZEOF_LONG_LONG == 4
  return GSSwapI32(in);
#else
#if	GS_SIZEOF_LONG_LONG == 8
  return GSSwapI64(in);
#else
  return GSSwapI128(in);
#endif
#endif
#endif
}

static inline unsigned long
NSSwapLong(unsigned long in)
{
#if	GS_SIZEOF_LONG == 2
  return GSSwapI16(in);
#else
#if	GS_SIZEOF_LONG == 4
  return GSSwapI32(in);
#else
#if	GS_SIZEOF_LONG == 8
  return GSSwapI64(in);
#else
  return GSSwapI128(in);
#endif
#endif
#endif
}

static inline unsigned short
NSSwapShort(unsigned short in)
{
#if	GS_SIZEOF_SHORT == 2
  return GSSwapI16(in);
#else
#if	GS_SIZEOF_SHORT == 4
  return GSSwapI32(in);
#else
#if	GS_SIZEOF_SHORT == 8
  return GSSwapI64(in);
#else
  return GSSwapI128(in);
#endif
#endif
#endif
}

static inline NSSwappedDouble
NSSwapDouble(NSSwappedDouble num)
{
  return GSSwapI64(num);
}

static inline NSSwappedFloat
NSSwapFloat(NSSwappedFloat num)
{
  return GSSwapI32(num);
}

#if	GS_WORDS_BIGENDIAN

static inline NSByteOrder
NSHostByteOrder(void)
{
  return NS_BigEndian;
}

/*
 *	Swap Big endian to host
 */
static inline gsu16
GSSwapBigI16ToHost(gsu16 in)
{
  return in;
}
static inline gsu32
GSSwapBigI32ToHost(gsu32 in)
{
  return in;
}
static inline gsu64
GSSwapBigI64ToHost(gsu64 in)
{
  return in;
}
static inline gsu128
GSSwapBigI128ToHost(gsu128 in)
{
  return in;
}

static inline double
NSSwapBigDoubleToHost(NSSwappedDouble num)
{
  return NSConvertSwappedDoubleToHost(num);
}

static inline float
NSSwapBigFloatToHost(NSSwappedFloat num)
{
  return NSConvertSwappedFloatToHost(num);
}

static inline unsigned int
NSSwapBigIntToHost(unsigned int num)
{
  return num;
}

static inline unsigned long long
NSSwapBigLongLongToHost(unsigned long long num)
{
  return num;
}

static inline unsigned long
NSSwapBigLongToHost(unsigned long num)
{
  return num;
}

static inline unsigned short
NSSwapBigShortToHost(unsigned short num)
{
  return num;
}

/*
 *	Swap Host to Big endian
 */
static inline gsu16
GSSwapHostI16ToBig(gsu16 in)
{
  return in;
}
static inline gsu32
GSSwapHostI32ToBig(gsu32 in)
{
  return in;
}
static inline gsu64
GSSwapHostI64ToBig(gsu64 in)
{
  return in;
}
static inline gsu128
GSSwapHostI128ToBig(gsu128 in)
{
  return in;
}

static inline NSSwappedDouble
NSSwapHostDoubleToBig(double num)
{
  return NSConvertHostDoubleToSwapped(num);
}

static inline NSSwappedFloat
NSSwapHostFloatToBig(float num)
{
  return NSConvertHostFloatToSwapped(num);
}

static inline unsigned int
NSSwapHostIntToBig(unsigned int num)
{
  return num;
}

static inline unsigned long long
NSSwapHostLongLongToBig(unsigned long long num)
{
  return num;
}

static inline unsigned long
NSSwapHostLongToBig(unsigned long num)
{
  return num;
}

static inline unsigned short
NSSwapHostShortToBig(unsigned short num)
{
  return num;
}

/*
 *	Swap Little endian to Host
 */
static inline gsu16
GSSwapLittleI16ToHost(gsu16 in)
{
  return GSSwapI16(in);
}
static inline gsu32
GSSwapLittleI32ToHost(gsu32 in)
{
  return GSSwapI32(in);
}
static inline gsu64
GSSwapLittleI64ToHost(gsu64 in)
{
  return GSSwapI64(in);
}
static inline gsu128
GSSwapLittleI128ToHost(gsu128 in)
{
  return GSSwapI128(in);
}

static inline double
NSSwapLittleDoubleToHost(NSSwappedDouble num)
{
  return NSConvertSwappedDoubleToHost(NSSwapDouble(num));
}

static inline float
NSSwapLittleFloatToHost(NSSwappedFloat num)
{
  return NSConvertSwappedFloatToHost(NSSwapFloat(num));
}

static inline unsigned int
NSSwapLittleIntToHost(unsigned int num)
{
  return NSSwapInt(num);
}

static inline unsigned long long
NSSwapLittleLongLongToHost(unsigned long long num)
{
  return NSSwapLongLong(num);
}

static inline unsigned long
NSSwapLittleLongToHost(unsigned long num)
{
  return NSSwapLong(num);
}

static inline unsigned short
NSSwapLittleShortToHost(unsigned short num)
{
  return NSSwapShort(num);
}

/*
 *	Swap Host to Little endian
 */
static inline gsu16
GSSwapHostI16ToLittle(gsu16 in)
{
  return GSSwapI16(in);
}
static inline gsu32
GSSwapHostI32ToLittle(gsu32 in)
{
  return GSSwapI32(in);
}
static inline gsu64
GSSwapHostI64ToLittle(gsu64 in)
{
  return GSSwapI64(in);
}
static inline gsu128
GSSwapHostI128ToLittle(gsu128 in)
{
  return GSSwapI128(in);
}

static inline NSSwappedDouble
NSSwapHostDoubleToLittle(double num)
{
  return NSSwapDouble(NSConvertHostDoubleToSwapped(num));
}

static inline NSSwappedFloat
NSSwapHostFloatToLittle(float num)
{
  return NSSwapFloat(NSConvertHostFloatToSwapped(num));
}

static inline unsigned int
NSSwapHostIntToLittle(unsigned int num)
{
  return NSSwapInt(num);
}

static inline unsigned long long
NSSwapHostLongLongToLittle(unsigned long long num)
{
  return NSSwapLongLong(num);
}

static inline unsigned long
NSSwapHostLongToLittle(unsigned long num)
{
  return NSSwapLong(num);
}

static inline unsigned short
NSSwapHostShortToLittle(unsigned short num)
{
  return NSSwapShort(num);
}


#else

static inline NSByteOrder
NSHostByteOrder(void)
{
  return NS_LittleEndian;
}


/*
 *	Swap Big endian to host
 */
static inline gsu16
GSSwapBigI16ToHost(gsu16 in)
{
  return GSSwapI16(in);
}
static inline gsu32
GSSwapBigI32ToHost(gsu32 in)
{
  return GSSwapI32(in);
}
static inline gsu64
GSSwapBigI64ToHost(gsu64 in)
{
  return GSSwapI64(in);
}
static inline gsu128
GSSwapBigI128ToHost(gsu128 in)
{
  return GSSwapI128(in);
}
static inline double
NSSwapBigDoubleToHost(NSSwappedDouble num)
{
  return NSConvertSwappedDoubleToHost(NSSwapDouble(num));
}

static inline float
NSSwapBigFloatToHost(NSSwappedFloat num)
{
  return NSConvertSwappedFloatToHost(NSSwapFloat(num));
}

static inline unsigned int
NSSwapBigIntToHost(unsigned int num)
{
  return NSSwapInt(num);
}

static inline unsigned long long
NSSwapBigLongLongToHost(unsigned long long num)
{
  return NSSwapLongLong(num);
}

static inline unsigned long
NSSwapBigLongToHost(unsigned long num)
{
  return NSSwapLong(num);
}

static inline unsigned short
NSSwapBigShortToHost(unsigned short num)
{
  return NSSwapShort(num);
}

/*
 *	Swap Host to Big endian
 */
static inline gsu16
GSSwapHostI16ToBig(gsu16 in)
{
  return GSSwapI16(in);
}
static inline gsu32
GSSwapHostI32ToBig(gsu32 in)
{
  return GSSwapI32(in);
}
static inline gsu64
GSSwapHostI64ToBig(gsu64 in)
{
  return GSSwapI64(in);
}
static inline gsu128
GSSwapHostI128ToBig(gsu128 in)
{
  return GSSwapI128(in);
}
static inline NSSwappedDouble
NSSwapHostDoubleToBig(double num)
{
  return NSSwapDouble(NSConvertHostDoubleToSwapped(num));
}

static inline NSSwappedFloat
NSSwapHostFloatToBig(float num)
{
  return NSSwapFloat(NSConvertHostFloatToSwapped(num));
}

static inline unsigned int
NSSwapHostIntToBig(unsigned int num)
{
  return NSSwapInt(num);
}

static inline unsigned long long
NSSwapHostLongLongToBig(unsigned long long num)
{
  return NSSwapLongLong(num);
}

static inline unsigned long
NSSwapHostLongToBig(unsigned long num)
{
  return NSSwapLong(num);
}

static inline unsigned short
NSSwapHostShortToBig(unsigned short num)
{
  return NSSwapShort(num);
}

/*
 *	Swap Little endian to Host
 */
static inline gsu16
GSSwapLittleI16ToHost(gsu16 in)
{
  return in;
}
static inline gsu32
GSSwapLittleI32ToHost(gsu32 in)
{
  return in;
}
static inline gsu64
GSSwapLittleI64ToHost(gsu64 in)
{
  return in;
}
static inline gsu128
GSSwapLittleI128ToHost(gsu128 in)
{
  return in;
}

static inline double
NSSwapLittleDoubleToHost(NSSwappedDouble num)
{
  return NSConvertSwappedDoubleToHost(num);
}

static inline float
NSSwapLittleFloatToHost(NSSwappedFloat num)
{
  return NSConvertSwappedFloatToHost(num);
}

static inline unsigned int
NSSwapLittleIntToHost(unsigned int num)
{
  return num;
}

static inline unsigned long long
NSSwapLittleLongLongToHost(unsigned long long num)
{
  return num;
}

static inline unsigned long
NSSwapLittleLongToHost(unsigned long num)
{
  return num;
}

static inline unsigned short
NSSwapLittleShortToHost(unsigned short num)
{
  return num;
}

/*
 *	Swap Host to Little endian
 */
static inline gsu16
GSSwapHostI16ToLittle(gsu16 in)
{
  return in;
}
static inline gsu32
GSSwapHostI32ToLittle(gsu32 in)
{
  return in;
}
static inline gsu64
GSSwapHostI64ToLittle(gsu64 in)
{
  return in;
}
static inline gsu128
GSSwapHostI128ToLittle(gsu128 in)
{
  return in;
}

static inline NSSwappedDouble
NSSwapHostDoubleToLittle(double num)
{
  return NSConvertHostDoubleToSwapped(num);
}

static inline NSSwappedFloat
NSSwapHostFloatToLittle(float num)
{
  return NSConvertHostFloatToSwapped(num);
}

static inline unsigned int
NSSwapHostIntToLittle(unsigned int num)
{
  return num;
}

static inline unsigned long long
NSSwapHostLongLongToLittle(unsigned long long num)
{
  return num;
}

static inline unsigned long
NSSwapHostLongToLittle(unsigned long num)
{
  return num;
}

static inline unsigned short
NSSwapHostShortToLittle(unsigned short num)
{
  return num;
}

#endif


#endif /* __NSByteOrder_h_GNUSTEP_BASE_INCLUDE */
