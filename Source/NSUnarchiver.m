/* Implementation of NSUnrchiver for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.
   
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

#include <Foundation/NSUnarchiver.h>

@implementation NSUnarchiver 

// Initializing an unarchiver

- (id) initForReadingWithData: (NSData*)data
{
  [self notImplemented:_cmd];
  return nil;
}

// Decoding objects

+ (id) unarchiveObjectWithData: (NSData*)data
{
  [self notImplemented:_cmd];
  return nil;
}

+ (id) unarchiveObjectWithFile: (NSString*)path
{
  [self notImplemented:_cmd];
  return nil;
}

- (void) decodeArrayOfObjCType: (const char*)type 
			 count: (unsigned int)count
			    at: (void*)array
{
  [self notImplemented:_cmd];
}


// Managing

- (BOOL) isAtEnd
{
  [self notImplemented:_cmd];
  return NO;
}

- (NSZone*) objectZone
{
  [self notImplemented:_cmd];
  return NULL;
}

- (void) setObjectZone: (NSZone*)zone
{
  [self notImplemented:_cmd];
}

- (unsigned int) systermVersion
{
  [self notImplemented:_cmd];
  return 0;
}

// Substituting Classes

+ (NSString*) classNameDecodedForArchiveClassName: (NSString*)nameInArchive
{
  [self notImplemented:_cmd];
  return nil;
}
+ (void) decodeClassName: (NSString*)nameInArchive
	     asClassName: (NSString*)trueName
{
  [self notImplemented:_cmd];
}

- (NSString*) classNameDecodedForArchiveClassName: (NSString*)nameInArchive
{
  [self notImplemented:_cmd];
  return nil;
}

- (void) decodeClassName: (NSString*)nameInArchive 
	     asClassName: (NSString*)trueName
{
  [self notImplemented:_cmd];
}

@end
