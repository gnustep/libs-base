/* Implementation of GNU Objective-C coder object for use serializing
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
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
#include <gnustep/base/Coder.h>
#include <gnustep/base/CoderPrivate.h>
#include <gnustep/base/MemoryStream.h>
#include <gnustep/base/Coding.h>
#include <gnustep/base/Dictionary.h>
#include <gnustep/base/Stack.h>
#include <gnustep/base/Set.h>
#include <gnustep/base/NSString.h>
#include <gnustep/base/Streaming.h>
#include <gnustep/base/Stream.h>
#include <gnustep/base/CStreaming.h>
#include <gnustep/base/CStream.h>
#include <gnustep/base/TextCStream.h>
#include <gnustep/base/BinaryCStream.h>
#include <gnustep/base/StdioStream.h>
#include <gnustep/base/Archiver.h>
#include <Foundation/NSException.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSData.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSAutoreleasePool.h>
#include <assert.h>


/* Exception strings */
id CoderSignatureMalformedException = @"CoderSignatureMalformedException";

#define DEFAULT_FORMAT_VERSION 0

#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })

#define DOING_ROOT_OBJECT (interconnect_stack_height != 0)

static BOOL debug_coder = NO;


@implementation Coder

+ (void) initialize
{
  if (self == [Coder class])
    behavior_class_add_class (self, [NSCoderNonCore class]);
}

+ setDebugging: (BOOL)f
{
  debug_coder = f;
  return self;
}


/* Initialization. */

/* This is the designated initializer.  But, don't call it yourself;
   override it and call [super...] in subclasses. */
- _initWithCStream: (id <CStreaming>) cs
    formatVersion: (int) version
{
  format_version = version;
  cstream = [cs retain];
  classname_2_classname = NULL;
  interconnect_stack_height = 0;
  return self;
}

- init
{
  if ([self class] == [Coder class])
    {
      [self shouldNotImplement:_cmd];
      return nil;
    }
  else
    return [super init];
}

/* We must separate the idea of "closing" a coder and "deallocating"
   a coder because of delays in deallocation due to -autorelease. */
- (void) close
{
  [[cstream stream] close];
}

- (BOOL) isClosed
{
  return [[cstream stream] isClosed];
}

- (void) dealloc
{
  /* xxx No. [self _finishDecodeRootObject]; */
  [cstream release];
  [super dealloc];
}


/* Access to instance variables. */

- cStream
{
  return cstream;
}

- (int) formatVersion
{
  return format_version;
}

- (void) resetCoder
{
  /* xxx Finish this */
  [self notImplemented:_cmd];
}

@end


/* To fool ourselves into thinking we can call all these 
   Encoding and Decoding methods. */
@interface Coder (Coding) <Encoding, Decoding>
@end



@implementation Coder (NSCoderCompatibility)


/* The core methods */

- (void) encodeValueOfObjCType: (const char*)type
   at: (const void*)address;
{
  [self encodeValueOfObjCType: type at: address withName: NULL];
}

- (void) decodeValueOfObjCType: (const char*)type
   at: (void*)address
{
  [self decodeValueOfObjCType: type at: address withName: NULL];
}

- (void) encodeDataObject: (NSData*)data
{
  [self notImplemented:_cmd];
}

- (NSData*) decodeDataObject
{
  [self notImplemented:_cmd];
  return nil;
}

- (unsigned int) versionForClassName: (NSString*)className
{
  [self notImplemented:_cmd];
  return 0;
}

/* Override some methods in NSCoderNonCore */

- (void) encodeObject: (id)anObject
{
  [self encodeObject: anObject withName: NULL];
}

- (void) encodeBycopyObject: (id)anObject
{
  [self encodeBycopyObject: anObject withName: NULL];
}

- (void) encodeConditionalObject: (id)anObject
{
  /* NeXT's implementation handles *forward* references by running
     through the entire encoding process twice!  GNU Coding can handle
     forward references with only one pass.  Therefore, however, GNU
     Coding cannot return a *forward* reference from -decodeObject, so
     here, assuming this call to -encodeConditionalObject: is mirrored
     by a -decodeObject, we don't try to encode *forward*
     references.

     Note that this means objects that use -encodeConditionalObject:
     that are encoded in the GNU style might decode a nil where
     NeXT-style encoded would not.  I don't see this a huge problem;
     at least not as bad as NeXT coding mechanism that actually causes
     crashes in situations where GNU's does fine.  Still, if we wanted
     to fix this, we might be able to build a kludgy fix based on
     detecting when this would happen, rewinding the stream to the
     "conditional" point, and encoding again.  Yuck. */

  if ([self _coderReferenceForObject: anObject])
    [self encodeObject: anObject];
  else
    [self encodeObject: nil];
}

- (void) encodeRootObject: (id)rootObject
{
  [self encodeRootObject: rootObject withName: NULL];
}

- (id) decodeObject
{
  /* This won't work for decoding GNU-style forward references because
     once the GNU decoder finds the object later in the decoding, it
     will back-patch by storing the id in &o... &o will point to some
     weird location on the stack!  This is why we make the GNU
     implementation of -encodeConditionalObject: not encode forward
     references. */
  id o;
  [self decodeObjectAt: &o withName: NULL];
  return o;
}

- (unsigned int) systemVersion
{
  return format_version;	/* xxx Is this right? */
}

@end  /* of (NSCoderCompatibility) */


@implementation Coder (NSArchiverCompatibility)


/* Initializing an archiver */

- (id) initForWritingWithMutableData: (NSMutableData*)mdata
{
  [(id)self initForWritingToStream: [MemoryStream streamWithData: mdata]];
  return self;
}

- (id) initForReadingWithData: (NSData*)data
{
  id ret = [[self class] newReadingFromStream:
		[MemoryStream streamWithData:data]];
  if ([self retainCount]
	- [[[self class] autoreleaseClass] autoreleaseCountForObject:self] == 0)
    [ret autorelease];
  else
    [self release];
  return ret;
}

/* Archiving Data */

+ (NSData*) archivedDataWithRootObject: (id)rootObject
{
  id d = [[NSMutableData alloc] init];
  id a = [[Archiver alloc] initForWritingWithMutableData:d];
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

/* Getting data from the archiver */

+ unarchiveObjectWithData: (NSData*) data
{
  return [self decodeObjectWithName: NULL
			 fromStream: [MemoryStream streamWithData:data]];
}

+ unarchiveObjectWithFile: (NSString*) path
{
  return [self decodeObjectWithName: NULL fromFile: path];
}

- (NSMutableData*) archiverData
{
  [self notImplemented:_cmd];
  return nil;
}

@end
