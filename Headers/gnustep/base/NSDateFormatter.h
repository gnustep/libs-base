/* Interface for NSDateFormatter for GNUStep
   Copyright (C) 1998 Free Software Foundation, Inc.

   Header Written by:  Camille Troillard <tuscland@wanadoo.fr>
   Created: November 1998
   Modified by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   
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

#ifndef __NSDateFormatter_h_GNUSTEP_BASE_INCLUDE
#define __NSDateFormatter_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

#ifndef	STRICT_OPENSTEP

#include <Foundation/NSFormatter.h>

@interface NSDateFormatter : NSFormatter <NSCoding, NSCopying>
{
  NSString	*dateFormat;
  BOOL		allowsNaturalLanguage;
}

/* Initializing an NSDateFormatter */
- (id) initWithDateFormat: (NSString *)format
     allowNaturalLanguage: (BOOL)flag;

/* Determining Attributes */
- (BOOL) allowsNaturalLanguage;
- (NSString *) dateFormat;
@end

#endif

#endif /* _NSDateFormatter_h_GNUSTEP_BASE_INCLUDE */
