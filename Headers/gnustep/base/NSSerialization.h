/* Protocol for NSSerialization for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   Updated by:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
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

#ifndef __NSSerialization_h_GNUSTEP_BASE_INCLUDE
#define __NSSerialization_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

@class NSData, NSMutableData;

@protocol NSObjCTypeSerializationCallBack
- (void) deserializeObjectAt: (id*)object
		  ofObjCType: (const char *)type
		    fromData: (NSData*)data
		    atCursor: (unsigned*)cursor;
- (void) serializeObjectAt: (id*)object
		ofObjCType: (const char *)type
		  intoData: (NSMutableData*)data;
@end

@interface NSSerializer: NSObject
+ (NSData*) serializePropertyList: (id)propertyList;
+ (void) serializePropertyList: (id)propertyList
		      intoData: (NSMutableData*)d;
@end

#ifndef	NO_GNUSTEP
/*
 *	GNUstep extends serialization by having the option to make the
 *	resulting data more compact by ensuring that repeated strings
 *	are only stored once.  If the property-list has a lot of repeated
 *	strings in it, this will be both faster and more space efficient
 *	but it will be slower if the property-list has few repeated
 *	strings.  The default is NOT to generate compact versions of the data.
 *
 *	The [+shouldBeCompact:] method sets default behavior.
 *	The [+serializePropertyList:intoData:compact:] method lets you
 *	override the default behavior.
 */
@interface NSSerializer (GNUstep)
+ (void) shouldBeCompact: (BOOL)flag;
+ (void) serializePropertyList: (id)propertyList
		      intoData: (NSMutableData*)d
		       compact: (BOOL)flag;
@end
#endif

@interface NSDeserializer: NSObject
+ (id) deserializePropertyListFromData: (NSData*)data
			      atCursor: (unsigned int*)cursor
		     mutableContainers: (BOOL)flag;
+ (id) deserializePropertyListFromData: (NSData*)data
		     mutableContainers: (BOOL)flag;
+ (id) deserializePropertyListLazilyFromData: (NSData*)data
				    atCursor: (unsigned*)cursor
				      length: (unsigned)length
			   mutableContainers: (BOOL)flag;

@end

#ifndef	NO_GNUSTEP
/*
 *	GNUstep extends deserialization by having the option to make the
 *	resulting data more compact by ensuring that repeated strings
 *	are only stored once.  If the property-list has a lot of repeated
 *	strings in it, this will be more space efficient but it will be
 *	slower (though other parts of your code may speed up through more
 *	efficient equality testing of uniqued strings).
 *	The default is NOT to deserialize uniqued strings.
 *
 *	The [+uniquing:] method turns uniquing on/off.
 *	Uniquing is done using a global NSCountedSet - see NSCountedSet for
 *	details.
 */
@class	NSMutableSet;
@interface NSDeserializer (GNUstep)
+ (void) uniquing: (BOOL)flag;
@end

#endif

#endif /* __NSSerialization_h_GNUSTEP_BASE_INCLUDE */
