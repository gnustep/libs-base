/* Implementation of GNU Objective-C class for streaming C types and indentatn
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

#include <gnustep/base/prefix.h>
#include <gnustep/base/CStream.h>
#include <gnustep/base/NSString.h>
#include <gnustep/base/StdioStream.h>
#include <gnustep/base/CoderPrivate.h> /* for SIGNATURE_FORMAT_STRING */
#include <Foundation/NSException.h>
#include <assert.h>

id CStreamSignatureMalformedException = @"CStreamSignatureMalformedException";
id CStreamSignatureMismatchException  = @"CStreamSignatureMismatchException";

@implementation CStream


/* Encoding/decoding C values */

- (void) encodeValueOfCType: (const char*) type 
         at: (const void*) d 
         withName: (id <String>) name;
{
  [self subclassResponsibility:_cmd];
}

- (void) decodeValueOfCType: (const char*) type 
         at: (void*) d 
         withName: (id <String> *) namePtr;
{
  [self subclassResponsibility:_cmd];
}


/* Signature methods. */

- (void) writeSignature
{
  /* Careful: the string should not contain newlines. */
  [stream writeFormat: SIGNATURE_FORMAT_STRING,
	  STRINGIFY(OBJECTS_PACKAGE_NAME),
	  OBJECTS_MAJOR_VERSION,
	  OBJECTS_MINOR_VERSION,
	  OBJECTS_SUBMINOR_VERSION,
	  object_get_class_name(self),
	  format_version];
}

+ (void) readSignatureFromStream: s
		    getClassname: (char *) name
                   formatVersion: (int*) version
{
  int got;
  char package_name[64];
  int major_version;
  int minor_version;
  int subminor_version;

  got = [s readFormat: SIGNATURE_FORMAT_STRING,
	   &(package_name[0]), 
	   &major_version,
	   &minor_version,
	   &subminor_version,
	   name, 
	   version];
  if (got != 6)
    [NSException raise:CStreamSignatureMalformedException
      format: @"CStream found a malformed signature"];
}


/* Initialization methods */

/* This is the hidden designated initializer.  Do not call it yourself. */
- _initWithStream: (id <Streaming>) s
    formatVersion: (int)version
{
  [super init];
  [s retain];
  stream = s;
  format_version = version;
  indentation = 0;
  return self;
}

- initForReadingFromStream: (id <Streaming>) s
	     withFormatVersion: (int)version
{
  [self _initWithStream: s
	formatVersion: version];
  if ([stream streamPosition] != 0)
    {
      char name[128];		/* max class name length. */
      int version;
      [[self class] readSignatureFromStream: stream
		    getClassname: name
		    formatVersion: &version];
      if (!strcmp(name, object_get_class_name(self))
	  || version != format_version)
	{
	  [NSException raise: CStreamSignatureMismatchException
		       format: @"CStream found a mismatched signature"];
	}
    }
  return self;
}

+ cStreamReadingFromStream: (id <Streaming>) s
{
  char name[128];		/* Maximum class name length. */
  int version;
  id new_cstream;

  [self readSignatureFromStream: s
	getClassname: name
	formatVersion: &version];
  new_cstream = [[objc_lookup_class(name) alloc] 
		  _initWithStream: s
		  formatVersion: version];
  return [new_cstream autorelease];
}

+ cStreamReadingFromFile: (id <String>) filename
{
  return [self cStreamReadingFromStream:
		 [StdioStream streamWithFilename: filename fmode: "r"]];
}

/* This is a designated initializer for writing. */
- initForWritingToStream: (id <Streaming>) s
       withFormatVersion: (int)version
{
  [self _initWithStream: s
	formatVersion: version];
  [self writeSignature];
  return self;
}

- initForWritingToStream: (id <Streaming>) s
{
  return [self initForWritingToStream: s
	       withFormatVersion: [[self class] defaultFormatVersion]];
}

- initForWritingToFile: (id <String>) file
{
  return [self initForWritingToStream: 
		 [StdioStream streamWithFilename: file fmode: "w"]];
}

+ cStreamWritingToStream: (id <Streaming>) s
{
  return [[[self alloc] initForWritingToStream: s]
	   autorelease];
}

+ cStreamWritingToFile: (id <String>) filename;
{
  return [[[self alloc] initForWritingToFile: filename]
	   autorelease];
}


/* Encoding/decoding indentation */

- (void) encodeWithName: (id <String>) name
	 valuesOfCTypes: (const char *) types, ...
{
  va_list ap;

  [self encodeName: name];
  va_start (ap, types);
  while (*types)
    {
      [self encodeValueOfCType: types
	    at: va_arg(ap, void*)
	    withName: NULL];
      types = objc_skip_typespec (types);
    }
  va_end (ap);
}

- (void) decodeWithName: (id <String> *)name
	 valuesOfCTypes: (const char *)types, ...
{
  va_list ap;

  [self decodeName: name];
  va_start (ap, types);
  while (*types)
    {
      [self decodeValueOfCType: types
	    at: va_arg (ap, void*)
	    withName: NULL];
      types = objc_skip_typespec (types);
    }
  va_end (ap);
}

- (void) encodeIndent
{
  /* Do nothing */
}

- (void) encodeUnindent
{
  /* Do nothing */
}

- (void) decodeIndent
{
  /* Do nothing */
}

- (void) decodeUnindent
{
  /* Do nothing */
}

- (void) encodeName: (id <String>) n
{
  /* Do nothing */
}

- (void) decodeName: (id <String> *) name
{
  /* Do nothing */
}


/* Access to the underlying stream. */

- (id <Streaming>) stream
{
  return stream;
}


/* Deallocation. */

- (void) dealloc
{
  [stream release];
  [super dealloc];
}


/* Returning default format version. */

+ (int) defaultFormatVersion
{
  [self subclassResponsibility:_cmd];
  return 0;
}

@end
