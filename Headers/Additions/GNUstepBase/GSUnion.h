/*
 * GSUnion.h
 * File to set up a typedef for a union capable of containing various types.
 * Copyright (C) 1999  Free Software Foundation, Inc.
 * 
 * Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
 * Created:	Apr 1999
 * 
 * This file is part of the GNUstep Base Library.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02111 USA. */

/* Need Foundation/NSObjCRuntime.h for type declarations.
 */
#import <Foundation/NSObjCRuntime.h>

/* These are not defined in older Mac OS X systems */
#ifndef NSINTEGER_DEFINED
typedef int NSInteger;
typedef unsigned int NSUInteger;
#define NSINTEGER_DEFINED 1
#endif

/*
 *	Definitions for bitmap mask of types of element in union.
 */
#ifndef	GSUNION_OBJ

#define	GSUNION_OBJ	0x0001
#define	GSUNION_CLS	0x0002
#define	GSUNION_SEL	0x0004
#define	GSUNION_CHAR	0x0008
#define	GSUNION_SHORT	0x0010
#define	GSUNION_INT	0x0020
#define	GSUNION_LONG	0x0040
#define	GSUNION_PTR	0x0080
#define	GSUNION_8B	0x0100
#define	GSUNION_16B	0x0200
#define	GSUNION_32B	0x0400
#define	GSUNION_64B	0x0800

#define	GSUNION_ALL	0x0fff

#endif	/* GSUNION_OBJ */


/*
 * Produce a typedef for a union with name 'GSUNION' containing elements
 * specified in the GSUNION_TYPES mask, and optionally with an extra
 * element 'ext' of the type specified in GSUNION_EXTRA
 *
 * You can include this file more than once in order to produce different
 * typedefs as long as you redefine 'GSUNION' before each inclusion.
 */

#if	defined(GSUNION) && defined(GSUNION_TYPES)

typedef	union {
  NSUInteger    addr;
#if	((GSUNION_TYPES) & GSUNION_OBJ)
  id		obj;
  NSObject	*nso;
#endif
#if	((GSUNION_TYPES) & GSUNION_CLS)
  Class		cls;
#endif
#if	((GSUNION_TYPES) & GSUNION_SEL)
  SEL		sel;
#endif
#if	((GSUNION_TYPES) & GSUNION_CHAR)
  char		schr;
  unsigned char	uchr;
#endif
#if	((GSUNION_TYPES) & GSUNION_SHORT)
  short		ssht;
  unsigned short	usht;
#endif
#if	((GSUNION_TYPES) & GSUNION_INT)
  int		sint;
  unsigned	uint;
#endif
#if	((GSUNION_TYPES) & GSUNION_LONG)
  long 		slng;
  unsigned long	ulng;
#endif
#if	((GSUNION_TYPES) & GSUNION_PTR)
  void		*ptr;
  const void	*cptr;
  char		*str;
  const char	*cstr;
#endif
#if	((GSUNION_TYPES) & GSUNION_8B)
  int8_t	s8;
  uint8_t	u8;
#endif
#if	((GSUNION_TYPES) & GSUNION_16B)
  int16_t	s16;
  uint16_t	u16;
#endif
#if	((GSUNION_TYPES) & GSUNION_32B)
  int32_t	s32;
  uint32_t	u32;
#endif
#if	((GSUNION_TYPES) & GSUNION_64B)
  int64_t	s64;
  uint64_t	u64;
#endif
#if	defined(GSUNION_EXTRA)
  GSUNION_EXTRA	ext;
#endif
  BOOL		bool;	/* Guaranteed present */
} GSUNION;

#endif

