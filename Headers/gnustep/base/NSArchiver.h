/* Interface for NSArchiver for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   
   This file is part of the GNU Objective C Class Library.
   
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

#ifndef __NSArchiver_h_OBJECTS_INCLUDE
#define __NSArchiver_h_OBJECTS_INCLUDE

#include <Foundation/NSCoder.h>

@class NSMutableData, NSData, NSString;

@interface NSArchiver : NSCoder

/* Initializing an archiver */
- (id) initForWritingWithMutableData: (NSMutableData*)mdata;

/* Archiving Data */
+ (NSData*) archivedDataWithRootObject: (id)rootObject;
+ (BOOL) archiveRootObject: (id)rootObject toFile: (NSString*)path;

/* Getting data from the archiver */
+ unarchiveObjectWithData: (NSData*) data;
+ unarchiveObjectWithFile: (NSString*) path;
- (NSMutableData*) archiverData;

/* Substituting Classes */
+ (NSString*) classNameEncodedForTrueClassName: (NSString*) trueName;
- (void) enocdeClassName: (NSString*)trueName
           intoClassName: (NSString*)inArchiveName;

@end


@interface NSUnarchiver : NSCoder

/* Initializing an unarchiver */
- (id) initForReadingWithData: (NSData*)data;

/* Decoding objects */
+ (id) unarchiveObjectWithData: (NSData*)data;
+ (id) unarchiveObjectWithFile: (NSString*)path;

/* Managing */
- (BOOL) isAtEnd;
- (NSZone*) objectZone;
- (void) setObjectZone: (NSZone*)zone;
- (unsigned int) systermVersion;

/* Substituting Classes */
+ (NSString*) classNameDecodedForArchiveClassName: (NSString*)nameInArchive;
+ (void) decodeClassName: (NSString*)nameInArchive
	     asClassName: (NSString*)trueName;
- (NSString*) classNameDecodedForArchiveClassName: (NSString*)nameInArchive;
- (void) decodeClassName: (NSString*)nameInArchive 
	     asClassName: (NSString*)trueName;

@end


/* Exceptions */
extern NSString *NSInconsistentArchiveException;


/* NSObject extensions for archiving */
@interface NSObject (NSArchiver)
- (Class) classForArchiver;
- replacementObjectForArchiver: (NSArchiver*) archiver;
@end

#endif	/* __NSArchiver_h_OBJECTS_INCLUDE */
