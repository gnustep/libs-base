/* Implementation of GNU Objective-C coder object for use serializing
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
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
#include <objects/Coder.h>
#include <objects/CoderPrivate.h>
#include <objects/MemoryStream.h>
#include <objects/Coding.h>
#include <objects/Dictionary.h>
#include <objects/Stack.h>
#include <objects/Set.h>
#include <objects/NSString.h>
#include <objects/Streaming.h>
#include <objects/Stream.h>
#include <objects/CStreaming.h>
#include <objects/CStream.h>
#include <objects/TextCStream.h>
#include <objects/BinaryCStream.h>
#include <objects/StdioStream.h>
#include <Foundation/NSException.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSData.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSHashTable.h>
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
  /* Or should we provide some kind of default? */
  [self shouldNotImplement:_cmd];
  return self;
}

/* We must separate the idea of "closing" a coder and "deallocating"
   a coder because of delays in deallocation due to -autorelease. */
- (void) closeCoding
{
  [[cstream stream] closeStream];
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


/* Encoding Data */

- (void) encodeValueOfObjCType: (const char*)type
   at: (const void*)address;
{
  [self encodeValueOfObjCType: type at: address withName: NULL];
}

- (void) encodeArrayOfObjCType: (const char*)type
   count: (unsigned)count
   at: (const void*)array
{
  [self encodeArrayOfObjCType: type count: count at: array withName: NULL];
}

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
  /* Apparently, NeXT's implementation doesn't actually 
     handle *forward* references, (hence it's use of -decodeObject, 
     instead of decodeObjectAt:.)
     So here, we only encode the object for real if the object has 
     already been written. 
     This means that if you encode a web of objects with the more 
     powerful GNU Coder, and then try to decode them with NSArchiver,
     you could get corrupt data on the stack when Coder resolves its 
     forward references.  I recommend just using the GNU Coder. */
#if 1
  unsigned xref = PTR2LONG(anObject);
  if ([self _coderHasObjectReference:xref])
    [self encodeObject: anObject];
  else
    [self encodeObject: nil];
#else
  [self encodeObjectReference: anObject withName: NULL];
#endif
}

- (void) encodeDataObject: (NSData*)data
{
  [self notImplemented:_cmd];
}

- (void) encodePropertyList: (id)plist
{
  [self notImplemented:_cmd];
}

- (void) encodePoint: (NSPoint)point
{
  [self encodeValueOfObjCType:@encode(NSPoint)
	at:&point
	withName: NULL];
}

- (void) encodeRect: (NSRect)rect
{
  [self encodeValueOfObjCType:@encode(NSRect) at:&rect withName: NULL];
}

- (void) encodeRootObject: (id)rootObject
{
  [self encodeRootObject: rootObject withName: NULL];
}

- (void) encodeSize: (NSSize)size
{
  [self encodeValueOfObjCType:@encode(NSSize) at:&size withName: NULL];
}

- (void) encodeValuesOfObjCTypes: (const char*)types,...
{
  [self notImplemented:_cmd];
}


/* Decoding Data */

- (void) decodeValueOfObjCType: (const char*)type
   at: (void*)address
{
  [self decodeValueOfObjCType: type at: address withName: NULL];
}

- (void) decodeArrayOfObjCType: (const char*)type
                         count: (unsigned)count
                            at: (void*)address
{
  [self decodeArrayOfObjCType: type count: count at: address withName: NULL];
}

- (NSData*) decodeDataObject
{
  [self notImplemented:_cmd];
}

- (id) decodeObject
{
  /* xxx This won't work for decoding forward references!!! */
  id o;
  [self decodeObjectAt: &o withName: NULL];
  return o;
}

- (id) decodePropertyList
{
  [self notImplemented:_cmd];
}

- (NSPoint) decodePoint
{
  NSPoint point;
  [self decodeValueOfObjCType:@encode(NSPoint)
	at:&point
	withName: NULL];
  return point;
}

- (NSRect) decodeRect
{
  NSRect rect;
  [self decodeValueOfObjCType:@encode(NSRect)
	at:&rect
	withName: NULL];
  return rect;
}

- (NSSize) decodeSize
{
  NSSize size;
  [self decodeValueOfObjCType:@encode(NSSize)
	at:&size
	withName: NULL];
  return size;
}

- (void) decodeValuesOfObjCTypes: (const char*)types,...
{
  [self notImplemented:_cmd];
}


/* Getting a Version */

- (unsigned int) systemVersion
{
  return format_version;	/* xxx Is this right? */
}

- (unsigned int) versionForClassName: (NSString*)className
{
  [self notImplemented:_cmd];
  return 0;
}

@end  /* of (NSCoderCompatibility) */


@implementation Coder (NSArchiverCompatibility)


/* Initializing an archiver */

@interface NSData (Streaming) <Streaming>
@end

- (id) initForWritingWithMutableData: (NSMutableData*)mdata
{
  /* This relies on the fact that GNU extentions to NSMutableData 
     cause it to conform to <Streaming>. */
  [(id)self initForWritingToStream: mdata];
  return self;
}

- (id) initForReadingWithData: (NSData*)data
{
  id ret = [[self class] newReadingFromStream: data];
  [self release];
  return ret;
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

/* Getting data from the archiver */

+ unarchiveObjectWithData: (NSData*) data
{
  return [self decodeObjectWithName: NULL fromStream: data];
}

+ unarchiveObjectWithFile: (NSString*) path
{
  return [self decodeObjectWithName: NULL fromFile: path];
}

- (NSMutableData*) archiverData
{
  [self notImplemented:_cmd];
}

@end
