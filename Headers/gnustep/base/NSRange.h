/* Interface for NSObject for GNUStep
 * Copyright (C) 1995 Free Software Foundation, Inc.
 * 
 * Written by:  Adam Fedor <fedor@boulder.colorado.edu>
 * Date: 1995
 * 
 * This file is part of the GNUstep Base Library.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 * 
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */ 

#ifndef __NSRange_h_GNUSTEP_BASE_INCLUDE
#define __NSRange_h_GNUSTEP_BASE_INCLUDE

/**** Included Headers *******************************************************/

#include <Foundation/NSObject.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef struct _NSRange NSRange;
struct _NSRange
{
  unsigned int location;
  unsigned int length;
};

/**** Function Prototypes ****************************************************/

static inline unsigned
NSMaxRange(NSRange range) __attribute__ ((unused));

static inline unsigned
NSMaxRange(NSRange range) 
{
  return range.location + range.length;
}

static inline BOOL 
NSLocationInRange(unsigned location, NSRange range) __attribute__ ((unused));

static inline BOOL 
NSLocationInRange(unsigned location, NSRange range) 
{
  return (location >= range.location) && (location < NSMaxRange(range));
}

/* Create an NSRange having the specified LOCATION and LENGTH. */
extern NSRange
NSMakeRange(unsigned int location, unsigned int length);

extern NSRange
NSUnionRange(NSRange range1, NSRange range2);

extern NSRange
NSIntersectionRange(NSRange range1, NSRange range2);

@class NSString;

extern NSString *
NSStringFromRange(NSRange range);

#endif /* __NSRange_h_GNUSTEP_BASE_INCLUDE */
