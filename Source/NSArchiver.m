/* archiving class for serialization and persistance.
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

#include <objects/stdobjects.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSGArchiver.h>
#include <Foundation/NSData.h>
#include <objects/NSCoder.h>

@implementation NSArchiver

static Class NSArchiver_concrete_class;

+ (void) _setConcreteClass: (Class)c
{
  NSArchiver_concrete_class = c;
}

+ (Class) _concreteClass
{
  return NSArchiver_concrete_class;
}

+ (void) initialize
{
  NSArchiver_concrete_class = [NSGArchiver class];
}

// Initializing an archiver

/* This is the designated initializer */
- (id) initForWritingWithMutableData: (NSMutableData*)mdata
{
  [self notImplemented:_cmd];
  return nil;
}

// Archiving Data

+ (NSData*) archivedDataWithRootObject: (id)rootObject
{
  /* xxx a quick kludge implementation */
  id d = [[NSMutableData alloc] init];
  id a = [[NSArchiver alloc] initForWritingWithMutableData:d];
  [a encodeRootObject:rootObject];
  return [d autorelease];
}

+ (BOOL) archiveRootObject: (id)rootObject toFile: (NSString*)path
{
  /* xxx a quick kludge implementation */
  id d = [self archivedDataWithRootObject:rootObject];
  [d writeToFile:path atomically:NO];
  return YES;
}


// Getting data from the archiver

- (NSMutableData*) archiverData
{
  [self notImplemented:_cmd];
  return nil;
}


// Substituting Classes

+ (NSString*) classNameEncodedForTrueClassName: (NSString*)trueName
{
  [self notImplemented:_cmd];
  return nil;
}

- (void) enocdeClassName: (NSString*)trueName
   intoClassName: (NSString*)inArchiveName
{
  [self notImplemented:_cmd];
}

@end
