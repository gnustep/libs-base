
/* Interface for NSKeyvalueCoding for GNUStep
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	2000
   
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

#ifndef __NSKeyValueCoding_h_GNUSTEP_BASE_INCLUDE
#define __NSKeyValueCoding_h_GNUSTEP_BASE_INCLUDE

#include	<Foundation/NSObject.h>

@class NSArray;
@class NSDictionary;
@class NSString;

#ifndef	STRICT_OPENSTEP

@interface NSObject (NSKeyValueCoding)

+ (BOOL) accessInstanceVariablesDirectly;
+ (BOOL) useStoredAccessor;

- (id) handleQueryWithUnboundKey: (NSString*)aKey;
- (void) handleTakeValue: (id)anObject forUnboundKey: (NSString*)aKey;
- (id) storedValueForKey: (NSString*)aKey;
- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey;
- (void) takeValue: (id)anObject forKey: (NSString*)aKey;
- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey;
- (void) takeValuesFromDictionary: (NSDictionary*)aDictionary;
- (void) unableToSetNilForKey: (NSString*)aKey;
- (id) valueForKey: (NSString*)aKey;
- (id) valueForKeyPath: (NSString*)aKey;
- (NSDictionary*) valuesForKeys: (NSArray*)keys;

@end

#endif
#endif

