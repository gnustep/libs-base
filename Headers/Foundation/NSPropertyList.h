/** Interface for NSPropertyList for GNUstep
   Copyright (C) 2004 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: January 2004
   
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

   AutogsdocSource: NSPropertyList.m

   */ 

#ifndef __NSPropertyList_h_GNUSTEP_BASE_INCLUDE
#define __NSPropertyList_h_GNUSTEP_BASE_INCLUDE

#ifndef	STRICT_OPENSTEP

#include <Foundation/NSObject.h>

@class NSData, NSString;

/**
 * Describes the mutability to use when generating objects during
 * deserialisation of a property list.
 */
typedef enum {
  NSPropertyListImmutable,
/** <strong>NSPropertyListImmutable</strong>
 * all objects in created list are immutable
 */
  NSPropertyListMutableContainers,
/** <strong>NSPropertyListMutableContainers</strong>
 * dictionaries and arrays are mutable
 */
  NSPropertyListMutableContainersAndLeaves
/** <strong>NSPropertyListMutableContainersAndLeaves</strong>
 * dictionaries, arrays, strings and data objects are mutable
 */
} NSPropertyListMutabilityOptions;

/**
 * Specifies the serialisation format for a serialised property list.
 */
typedef enum {
  NSPropertyListGNUstepFormat,
/** <strong>NSPropertyListGNUstepFormat</strong>
 * extension of OpenStep format */
  NSPropertyListGNUstepBinaryFormat,
/** <strong>NSPropertyListGNUstepBinaryFormat</strong>
 * efficient, hardware independent */
  NSPropertyListOpenStepFormat,
/** <strong>NSPropertyListOpenStepFormat</strong>
 * the most human-readable format */
  NSPropertyListXMLFormat_v1_0,
/** <strong>NSPropertyListXMLFormat_v1_0</strong>
 * portable and readable */
  NSPropertyListBinaryFormat_v1_0,
/** <strong>NSPropertyListBinaryFormat_v1_0</strong>
 * not yet supported */
} NSPropertyListFormat;

/**
 * <p>The NSPropertyListSerialization class provides facilities for
 * serialising and deserializing property list data in a number of
 * formats.
 * </p>
 * <p>You do not work with instances of this class, instead you use a
 * small number of claass methods to serialized and deserialize
 * property lists.
 * </p>
 */
@interface NSPropertyListSerialization : NSObject
{
}

/**
 * Creates and returns a data object containing a serialized representation
 * of plist.  The argument aFormat is used to determine the way in which the
 * data is serialised, and the anErrorString argument is a pointer in which
 * an error message is returned on failure (nil is returned on success).
 */
+ (NSData*) dataFromPropertyList: (id)aPropertyList
			  format: (NSPropertyListFormat)aFormat
		errorDescription: (NSString**)anErrorString;

/**
 * Returns a flag indicating whether it is possible to serialize aPropertyList
 * in the format aFormat.
 */
+ (BOOL) propertyList: (id)aPropertyList
     isValidForFormat: (NSPropertyListFormat)aFormat;

/**
 * Deserialises dataItem and returns the resulting property list
 * (or nil if the data does not contain a property list serialised
 * in a supported format).<br />
 * The argument anOption is ised to control whether the objects making
 * up the deserialized property list are mutable or not.<br />
 * The argument aFormat is either null or a pointer to a location
 * in which the format of the serialized property list will be returned.<br />
 * Either nil or an error message will be returned in anErrorString.
 */
+ (id) propertyListFromData: (NSData*)data
	   mutabilityOption: (NSPropertyListMutabilityOptions)anOption
		     format: (NSPropertyListFormat*)aFormat
	   errorDescription: (NSString**)anErrorString;

@end

#endif	/* STRICT_OPENSTEP */
#endif	/* __NSPropertyList_h_GNUSTEP_BASE_INCLUDE*/
