/* archiving class for serialization and persistance.
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1995
   
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

#include <gnustep/base/preface.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSGArchiver.h>
#include <Foundation/NSData.h>
#include <gnustep/base/Coder.h>

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
  if (self == [NSArchiver class])
    NSArchiver_concrete_class = [NSGArchiver class];
}


/* Allocating and Initializing an archiver */

+ allocWithZone:(NSZone *)zone
{
  return NSAllocateObject([self _concreteClass], 0, zone);
}

/* This is the designated initializer */
- (id) initForWritingWithMutableData: (NSMutableData*)mdata
{
  [self subclassResponsibility:_cmd];
  return self;
}


/* Archiving Data */

+ (NSData*) archivedDataWithRootObject: (id)rootObject
{
  id d = [[NSMutableData alloc] init];
  id a = [[NSArchiver alloc] initForWritingWithMutableData:d];
  [a encodeRootObject:rootObject];
  return [d autorelease];
}

+ (BOOL) archiveRootObject: (id)rootObject toFile: (NSString*)path
{
  /* xxx fix this return value */
  id d = [self archivedDataWithRootObject:rootObject];
  [d writeToFile:path atomically:NO];
  return YES;
}

- (unsigned int) versionForClassName: (NSString*)className;
{
  [self subclassResponsibility:_cmd];
  return 0;
}


/* Getting data from the archiver */

+ unarchiveObjectWithData: (NSData*) data
{
  return [[self _concreteClass] unarchiveObjectWithData: data];
}

+ unarchiveObjectWithFile: (NSString*) path
{
  return [[self _concreteClass] unarchiveObjectWithFile: path];
}

- (NSMutableData*) archiverData
{
  [self subclassResponsibility:_cmd];
  return nil;
}


/* Substituting Classes */

+ (NSString*) classNameEncodedForTrueClassName: (NSString*)trueName
{
  return [[self _concreteClass] classNameEncodedForTrueClassName: trueName];
}

- (void) enocdeClassName: (NSString*)trueName
   intoClassName: (NSString*)inArchiveName
{
  [self subclassResponsibility:_cmd];
}

@end


@implementation NSUnarchiver 

static Class NSUnarchiver_concrete_class;

+ (void) _setConcreteClass: (Class)c
{
  NSUnarchiver_concrete_class = c;
}

+ (Class) _concreteClass
{
  return NSUnarchiver_concrete_class;
}

+ (void) initialize
{
  if (self == [NSUnarchiver class])
    NSUnarchiver_concrete_class = [NSGUnarchiver class];
}

// Initializing an unarchiver

+ allocWithZone:(NSZone *)zone
{
  return NSAllocateObject([self _concreteClass], 0, zone);
}

- (id) initForReadingWithData: (NSData*)data
{
  [self subclassResponsibility:_cmd];
  return nil;
}

// Decoding objects

+ (id) unarchiveObjectWithData: (NSData*)data
{
  return [[self _concreteClass] unarchiveObjectWithData: data];
}

+ (id) unarchiveObjectWithFile: (NSString*)path
{
  return [[self _concreteClass] unarchiveObjectWithFile: path];
}

/* Managing */

- (BOOL) isAtEnd
{
  [self subclassResponsibility:_cmd];
  return NO;
}

- (NSZone*) objectZone
{
  [self subclassResponsibility:_cmd];
  return NULL;
}

- (void) setObjectZone: (NSZone*)zone
{
  [self subclassResponsibility:_cmd];
}

- (unsigned int) systemVersion
{
  [self subclassResponsibility:_cmd];
  return 0;
}

/* Substituting Classes */

+ (NSString*) classNameDecodedForArchiveClassName: (NSString*)nameInArchive
{
  return [[self _concreteClass] 
	   classNameDecodedForArchiveClassName: nameInArchive];
}
+ (void) decodeClassName: (NSString*)nameInArchive
	     asClassName: (NSString*)trueName
{
  return [[self _concreteClass]
	   decodeClassName: nameInArchive asClassName: trueName];
}

- (NSString*) classNameDecodedForArchiveClassName: (NSString*)nameInArchive
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (void) decodeClassName: (NSString*)nameInArchive 
	     asClassName: (NSString*)trueName
{
  [self subclassResponsibility:_cmd];
}

@end


/* Exceptions */
NSString *NSInconsistentArchiveException = @"NSInconsistentArchiveException";


/* NSObject extensions for archiving */

@implementation NSObject (NSArchiver)

- (Class) classForArchiver
{
  return [self classForCoder];
}

- replacementObjectForArchiver: (NSArchiver*) archiver
{
  return [self replacementObjectForCoder: archiver];
}

@end

