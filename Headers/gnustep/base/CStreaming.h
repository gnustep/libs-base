/* Protocol for GNU Objective C byte streams that can code C types and indentn
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: April 1995
   
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

#ifndef __CStreaming_h__GNUSTEP_BASE_INCLUDE
#define __CStreaming_h__GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <base/Streaming.h>

@protocol CStreaming <Streaming>

- (void) encodeValueOfCType: (const char*) type 
         at: (const void*) d 
         withName: (NSString*) name;
- (void) decodeValueOfCType: (const char*) type 
         at: (void*) d 
         withName: (NSString* *) namePtr;

- (void) encodeWithName: (NSString*) name
	 valuesOfCTypes: (const char *) types, ...;
- (void) decodeWithName: (NSString* *)name
	 valuesOfCTypes: (const char *)types, ...;

- (void) encodeName: (NSString*) name;
- (void) decodeName: (NSString* *) name;

- (void) encodeIndent;
- (void) decodeIndent;

- (void) encodeUnindent;
- (void) decodeUnindent;

- (id <Streaming>) stream;

+ (int) defaultFormatVersion;

@end

#endif /* __CStreaming_h__GNUSTEP_BASE_INCLUDE */

