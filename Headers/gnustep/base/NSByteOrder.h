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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#ifndef __NSByteOrder_h_GNUSTEP_BASE_INCLUDE
#define __NSByteOrder_h_GNUSTEP_BASE_INCLUDE


/*
 *	OPENSTEP type definitions for Byte ordering.
 */
typedef unsigned long		NSSwappedFloat;
typedef unsigned long long	NSSwappedDouble;

typedef enum {
    NSLittleEndian,
    NSBigEndian
} NSByteOrder;

/*
 *	Function prototypes.
 */

#if (__GNUC__ == 2) && (__GNUC_MINOR__ <= 6) && !defined(__attribute__)
#  define __attribute__(x)
#endif

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
	NSSwappedDouble sd;
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
    union swap {
	unsigned int	num;
	unsigned char	byt[4];
    } dst;
    union swap	*src = (union swap*)&in;
    dst.byt[0] = src->byt[3];
    dst.byt[1] = src->byt[2];
    dst.byt[2] = src->byt[1];
    dst.byt[3] = src->byt[0];
    return dst.num;
}

static inline unsigned long long
NSSwapLongLong(unsigned long long in)
{
    union swap {
	unsigned long	num;
	unsigned char	byt[8];
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

static inline unsigned long
NSSwapLong(unsigned long in)
{
    union swap {
	unsigned long	num;
	unsigned char	byt[4];
    } dst;
    union swap	*src = (union swap*)&in;
    dst.byt[0] = src->byt[3];
    dst.byt[1] = src->byt[2];
    dst.byt[2] = src->byt[1];
    dst.byt[3] = src->byt[0];
    return dst.num;
}

static inline unsigned short
NSSwapShort(unsigned short in)
{
    union swap {
	unsigned short	num;
	unsigned char	byt[2];
    } dst;
    union swap	*src = (union swap*)&in;
    dst.byt[0] = src->byt[1];
    dst.byt[1] = src->byt[0];
    return dst.num;
}

static inline NSSwappedDouble
NSSwapDouble(NSSwappedDouble num)
{
    return NSSwapLongLong(num);
}

static inline NSSwappedFloat
NSSwapFloat(NSSwappedFloat num)
{
    return NSSwapLong(num);
}

#ifdef	WORDS_BIGENDIAN

static inline NSByteOrder
NSHostByteOrder(void)
{
    return NSBigEndian;
}

/*
 *	Swap Big endian to host
 */
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
    return NSLittleEndian;
}


/*
 *	Swap Big endian to host
 */
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
