/* Concrete NSArchiver for GNUStep based on GNU Coder class
   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: April 1995
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
   */

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSGArchiver.h>
#include <base/Archiver.h>
#include <base/CStream.h>
#include <base/behavior.h>
#include <base/CoderPrivate.h>
#include <base/MemoryStream.h>
#include <Foundation/NSException.h>

#define USE_OPENSTEP_STYLE_FORWARD_REFERENCES 1

#if USE_OPENSTEP_STYLE_FORWARD_REFERENCES

@interface NSGArchiverNullCStream : CStream
@end

@implementation NSGArchiverNullCStream
- (void) encodeValueOfCType: (const char*)type 
   at: (const void*)d 
   withName: (NSString*) name
{
  return;
}
- (void) decodeValueOfCType: (const char*)type
   at: (void*)d 
   withName: (NSString* *)namePtr
{
  [self shouldNotImplement: _cmd];
}
@end

@interface NSGArchiver (Private)
- (void) _coderInternalCreateReferenceForObject: anObj;
- (void) encodeTag: (unsigned char)t;
@end

#endif /* USE_OPENSTEP_STYLE_FORWARD_REFERENCES */


@implementation NSGArchiver

+ (void) initialize
{
  if (self == [NSGArchiver class])
    class_add_behavior([NSGArchiver class], [Archiver class]);
}

#if USE_OPENSTEP_STYLE_FORWARD_REFERENCES

/* Use this if you want to define any other methods... */
//#define self ((Archiver*)self)
#define cstream (((Archiver*)self)->cstream)
#define in_progress_table (((Archiver*)self)->in_progress_table)
#define object_2_fref (((Archiver*)self)->object_2_fref)
#define object_2_xref (((Archiver*)self)->object_2_xref)
#define const_ptr_2_xref (((Archiver*)self)->const_ptr_2_xref)
#define fref_counter (((Archiver*)self)->fref_counter)

- init
{
/* initialise with autoreleased mutable data so we don't leak memory */
  return [self initForWritingWithMutableData:
	[[[NSMutableData alloc] init] autorelease]];
}

/* Unlike the GNU version, this cannot be called recursively. */
- (void) encodeRootObject: anObj
    withName: (NSString*)name
{
  id saved_cstream;

  /* Make sure that we're in a clean state. */
  NSParameterAssert (!object_2_xref);
  NSParameterAssert (!object_2_fref);

  object_2_fref = 
    NSCreateMapTable (NSNonOwnedPointerOrNullMapKeyCallBacks,
		      NSIntMapValueCallBacks, 0);

  /* First encode to a null cstream, and record all the objects that
     will be encoded.  They will get recorded in [NSGArchiver
     -_coderCreateReferenceForObject:] */
  saved_cstream = cstream;
  cstream = [[NSGArchiverNullCStream alloc] init];
  [self startEncodingInterconnectedObjects];
  [self encodeObject: anObj withName: name];
  [self finishEncodingInterconnectedObjects];
  
  [cstream release];
  cstream = saved_cstream;
  /* Reset ourselves, except for object_2_fref. */
  NSAssert(!in_progress_table, NSInternalInconsistencyException);
  NSResetMapTable (object_2_xref);
  NSResetMapTable (const_ptr_2_xref);
  NSAssert(fref_counter == 0, NSInternalInconsistencyException);

  /* Then encode everything "for real". */
  [self encodeName: @"Root Object"];
  [self encodeIndent];
  [(id)self encodeTag: CODER_OBJECT_ROOT];
  [self startEncodingInterconnectedObjects];
  [self encodeObject: anObj withName: name];
  [self finishEncodingInterconnectedObjects];
  [self encodeUnindent];
}

- (void) encodeConditionalObject: (id)anObject
{
  if ([cstream class] == [NSGArchiverNullCStream class])
    /* If we're gathering a list of all the objects that will be
       encoded (for the first half of a -encodeRootObject:), then do
       nothing. */
    return;
  else
    {
      /* Otherwise, we've already gathered a list of all the objects
         into objects_2_fref; if the object is there, encode it. */
      if (NSMapGet (object_2_fref, anObject))
	[self encodeObject: anObject];
      else
	[self encodeObject: nil];
    }
}

- (void) encodeObjectReference: anObject
{
  /* Be sure to do the OpenStep-style thing. */
  [self encodeConditionalObject: anObject];
}



/* For handling forward references. */

- (unsigned) _coderCreateReferenceForObject: anObj
{
  if ([cstream class] == [NSGArchiverNullCStream class])
    /* If we're just gathering a list of all the objects that will be
       encoded (for the first half of a -encodeRootObject:), then just
       put it in object_2_fref. */
    NSMapInsert (object_2_fref, anObj, (void*)1);

  /* Do the normal thing. */
  return (unsigned) CALL_METHOD_IN_CLASS ([Archiver class],
					  _coderCreateReferenceForObject:,
					  anObj);
}

- (unsigned) _coderCreateForwardReferenceForObject: anObject
{
  /* We should never get here. */
  [self shouldNotImplement: _cmd];
  return 0;
}

- (unsigned) _coderForwardReferenceForObject: anObject
{
  return 0;
}

- (void) _objectWillBeInProgress: anObj
{
  /* OpenStep-style coding doesn't keep an in-progress table. */
  /* Register that we have encoded it so that future encoding can 
     do backward references properly. */
  [self _coderInternalCreateReferenceForObject: anObj];
}

- (void) _objectNoLongerInProgress: anObj
{
  /* OpenStep-style coding doesn't keep an in-progress table. */
  return;
}

/* xxx This method interface may change in the future. */
- (const char *) defaultDecoderClassname
{
  return "NSGUnarchiver";
}

/* Attempting to use the archiver after this will
   mess up in a big way.  NB. If the archiver was not writing to an
   NSData object, we can't give one out, so we return nil. */
- (NSMutableData*) archiverData
{
  id	s = [cstream stream];
  if ([s isKindOfClass:[MemoryStream class]])
    {
      [s rewindStream];
      return [s mutableData];
    }
  if ([s isKindOfClass:[NSMutableData class]])
    {
      return (NSMutableData*)s;
    }
  return nil;
}

#undef self
#endif /* USE_OPENSTEP_STYLE_FORWARD_REFERENCES */

@end

@implementation NSGUnarchiver

+ (void) initialize
{
  if (self == [NSGUnarchiver class])
    class_add_behavior([NSGUnarchiver class], [Unarchiver class]);
}

#if USE_OPENSTEP_STYLE_FORWARD_REFERENCES

/* This method is called by Decoder to determine whether to add 
   an object to the xref table before it has been initialized. */
- (BOOL) _createReferenceBeforeInit
{
  return YES;
}

#endif /* USE_OPENSTEP_STYLE_FORWARD_REFERENCES */

@end

