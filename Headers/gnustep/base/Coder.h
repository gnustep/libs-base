/* Interface for GNU Objective-C coder object for use serializing
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

#ifndef __Coder_h_GNUSTEP_BASE_INCLUDE
#define __Coder_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <base/Coding.h>
#include <base/Streaming.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSMapTable.h>

@class CStream;


/* The root abstract class for archiving */

@interface Coder : NSObject
{
  @public
  int format_version;
  CStream *cstream;
  NSMapTable *classname_2_classname; /* for changing class names on r/w */
  int interconnect_stack_height;     /* number of nested root objects */
}

+ setDebugging: (BOOL)f;

@end


/* An abstract class for writing an archive */

@interface Encoder : Coder
{
  @public
  /* xxx in_progress_table should actually be an NSHashTable,
     but we are working around a bug right now. */
  NSMapTable *in_progress_table;    /* objects begun writing, but !finished */
  NSMapTable *object_2_xref;        /* objects already written */
  NSMapTable *object_2_fref;        /* table of forward references */
  NSMapTable *const_ptr_2_xref;     /* const pointers already written */
  unsigned fref_counter;            /* Keep track of unused fref numbers */
}

- initForWritingToFile: (NSString*) filename;
- initForWritingToFile: (NSString*) filename
      withCStreamClass: (Class) cStreamClass;
- initForWritingToFile: (NSString*) filename
     withFormatVersion: (int) version
          cStreamClass: (Class)scc
  cStreamFormatVersion: (int) cStreamFormatVersion;

- initForWritingToStream: (id <Streaming>) s;
- initForWritingToStream: (id <Streaming>) s
	withCStreamClass: (Class) cStreamClass;
- initForWritingToStream: (id <Streaming>) s
       withFormatVersion: (int) version
            cStreamClass: (Class) cStreamClass
    cStreamFormatVersion: (int) cStreamFormatVersion;

+ (BOOL) encodeRootObject: anObject 
  	         withName: (NSString*) name
                   toFile: (NSString*) filename;
+ (BOOL) encodeRootObject: anObject 
  	         withName: (NSString*) name
		 toStream: (id <Streaming>)stream;

/* Defaults */
+ (void) setDefaultStreamClass: sc;
+ defaultStreamClass;
+ (void) setDefaultCStreamClass: sc;
+ defaultCStreamClass;
+ (void) setDefaultFormatVersion: (int)fv;
+ (int) defaultFormatVersion;

@end

@interface Encoder (Encoding) <Encoding>
@end



/* An abstract class for reading an archive. */

@interface Decoder : Coder
{
  NSZone *zone;			  /* zone in which to create objects */
  id xref_2_object;               /* objects already read */
  id xref_2_object_root;          /* objs read since last -startDecodoingI.. */
  NSMapTable *xref_2_const_ptr;   /* const pointers already written */
  NSMapTable *fref_2_object;      /* table of forward references */
  NSMapTable *address_2_fref;     /* table of forward references */
}

/* These are class methods (and not instance methods) because the
   header of the file or stream determines which subclass of Decoder
   is created. */

+ newReadingFromFile: (NSString*) filename;
+ newReadingFromStream: (id <Streaming>)stream;

+ decodeObjectWithName: (NSString* *) name
	      fromFile: (NSString*) filename;
+ decodeObjectWithName: (NSString* *) name
	    fromStream: (id <Streaming>)stream;

@end

@interface Decoder (Decoding) <Decoding>
@end


/* Extensions to NSObject for encoding and decoding. */

@interface NSObject (OptionalNewWithCoder)
+ newWithCoder: (Coder*)aDecoder;
@end

@interface NSObject (CoderAdditions) 
/* <SelfCoding> not needed because of NSCoding */
/* These methods here temporarily until ObjC runtime category bug fixed */
- classForConnectedCoder:aRmc;
+ (void) encodeObject: anObject withConnectedCoder: aRmc;
@end

extern id CoderSignatureMalformedException;

#endif /* __Coder_h_GNUSTEP_BASE_INCLUDE */
