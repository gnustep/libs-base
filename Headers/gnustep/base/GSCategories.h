#ifndef	INCLUDED_GS_CATEGORIES_H
#define	INCLUDED_GS_CATEGORIES_H
/** Declaration of extension methods to standard classes

   Copyright (C) 2003 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

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

   AutogsdocSource: Additions/GSCategories.m

*/

#ifndef	NO_GNUSTEP

#ifndef NeXT_Foundation_LIBRARY
#include <Foundation/NSCalendarDate.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#else
#include <Foundation/Foundation.h>
#endif

@interface NSCalendarDate (GSCategories)

- (int) weekOfYear;

@end

@interface NSData (GSCategories)

- (NSString*) hexadecimalRepresentation;
- (id) initWithHexadecimalRepresentation: (NSString*)string;
- (NSData*) md5Digest;

@end

@interface NSString (GSCategories)
- (NSString*) stringByDeletingPrefix: (NSString*)prefix;
- (NSString*) stringByDeletingSuffix: (NSString*)suffix;
- (NSString*) stringByTrimmingLeadSpaces;
- (NSString*) stringByTrimmingTailSpaces;
- (NSString*) stringByTrimmingSpaces;
- (NSString*) stringByReplacingString: (NSString*)replace
                           withString: (NSString*)by;
@end

@interface NSMutableString (GSCategories)
- (void) deleteSuffix: (NSString*)suffix;
- (void) deletePrefix: (NSString*)prefix;
- (void) replaceString: (NSString*)replace
            withString: (NSString*)by;
- (void) trimLeadSpaces;
- (void) trimTailSpaces;
- (void) trimSpaces;
@end

@interface NSNumber(GSCategories)
+ (NSValue*) valueFromString: (NSString *)string;
@end

/* This is also defined in NSObject.h, but added here for use with the
   additions library */
#ifndef NSOBJECT_GSCATEGORIES_INTERFACE
@interface NSObject (GSCategories)
- notImplemented:(SEL)aSel;
- (id) subclassResponsibility: (SEL)aSel;
- (id) shouldNotImplement: (SEL)aSel;

- (NSComparisonResult) compare: (id)anObject;
@end
#endif

#endif	/* NO_GNUSTEP */
#endif	/* INCLUDED_GS_CATEGORIES_H */
