/* Implementation of GNU Objective-C raw-binary stream for archiving
   Copyright (C) 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Written: Jan 1996
   
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

/* Use this CStream subclass when you are encoding/decoding on the 
   same architecture, and you care about time and space.
   WARNING: This encoding is *not* machine-independent. */

#include <gnustep/base/prefix.h>
#include <gnustep/base/RawCStream.h>
#include <gnustep/base/NSString.h>
#include <gnustep/base/StdioStream.h>
#include <gnustep/base/TextCStream.h>

#define DEFAULT_FORMAT_VERSION 0

#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })

@implementation RawCStream


/* For debugging */

static BOOL debug_binary_coder;

+ setDebugging: (BOOL)f
{
  debug_binary_coder = f;
  return self;
}

+ debugStderrCoder
{
  static id c = nil;

  if (!c)
    c = [[TextCStream alloc] 
	  initForWritingToStream: [StdioStream standardError]];
  return c;
}

- (void) encodeName: (id <String>) name
{
  if (debug_binary_coder)
    [[[self class] debugStderrCoder]
     encodeName:name];
}



/* Encoding/decoding C values */

- (void) encodeValueOfCType: (const char*)type 
   at: (const void*)d 
   withName: (id <String>) name
{
  if (debug_binary_coder)
    {
      [[[self class] debugStderrCoder] 
       encodeValueOfCType:type
       at:d
       withName:name];
    }
  assert(type);
  assert(*type != '@');
  assert(*type != '^');
  assert(*type != ':');

  switch (*type)
    {
    case _C_CHARPTR:
      {
	int length = strlen(*(char**)d);
	[self encodeValueOfCType:@encode(int)
	      at:&length withName:@"BinaryCStream char* length"];
	[stream writeBytes:*(char**)d length:length];
	break;
      }

    case _C_CHR:
    case _C_UCHR:
      [stream writeByte:*(unsigned char*)d];
      break;

    case _C_SHT:
    case _C_USHT:
      [stream writeBytes:d length:sizeof(short)];
      break;

    case _C_INT:
    case _C_UINT:
      [stream writeBytes:d length:sizeof(int)];
      break;

    case _C_LNG:
    case _C_ULNG:
      [stream writeBytes:d length:sizeof(long)];
      break;

    case _C_FLT:
      [stream writeBytes:d length:sizeof(float)];
      break;

    case _C_DBL:
      [stream writeBytes:d length:sizeof(double)];
      break;

    case _C_ARY_B:
      {
	int len = atoi (type+1);	/* xxx why +1 ? */
	int offset;

	while (isdigit(*++type));
	offset = objc_sizeof_type(type);
	while (len-- > 0)
	  {
	    /* Change this so we don't re-write type info every time. */
	    [self encodeValueOfCType: type 
		  at: d 
		  withName: NULL];
	    ((char*)d) += offset;
	  }
	break; 
      }
    case _C_STRUCT_B:
      {
	int acc_size = 0;
	int align;

	while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	while (*type != _C_STRUCT_E)
	  {
	    align = objc_alignof_type (type); /* pad to alignment */
	    acc_size = ROUND (acc_size, align);
	    [self encodeValueOfCType: type 
		  at: ((char*)d)+acc_size 
		  withName: NULL];
	    acc_size += objc_sizeof_type (type); /* add component size */
	    type = objc_skip_typespec (type); /* skip component */
	  }
	break;
      }
    default:
      [self error:"Unrecognized Type %s", type];
    }
}

- (void) decodeValueOfCType: (const char*)type
   at: (void*)d 
   withName: (id <String> *)namePtr
{
  assert(type);
  assert(*type != '@');
  assert(*type != '^');
  assert(*type != ':');

  switch (*type)
    {
    case _C_CHARPTR:
      {
	int length;
	[self decodeValueOfCType:@encode(int)
	      at:&length withName:NULL];
	OBJC_MALLOC(*(char**)d, char, length+1);
	[stream readBytes:*(char**)d length:length];
	(*(char**)d)[length] = '\0';
	break;
      }

    case _C_CHR:
    case _C_UCHR:
      [stream readByte:d];
      break;

    case _C_SHT:
    case _C_USHT:
      [stream readBytes:d length:sizeof(short)];
      break;

    case _C_INT:
    case _C_UINT:
      [stream readBytes:d length:sizeof(int)];
      break;

    case _C_LNG:
    case _C_ULNG:
      [stream readBytes:d length:sizeof(long)];
      break;

    case _C_FLT:
      [stream readBytes:d length:sizeof(float)];
      break;

    case _C_DBL:
      [stream readBytes:d length:sizeof(double)];
      break;

    case _C_ARY_B:
      {
	/* xxx Do we need to allocate space, just like _C_CHARPTR ? */
	int len = atoi(type+1);
	int offset;
	while (isdigit(*++type));
	offset = objc_sizeof_type(type);
	while (len-- > 0)
	  {
	    [self decodeValueOfCType:type 
		  at:d 
		  withName:namePtr];
	    ((char*)d) += offset;
	  }
	break; 
      }
    case _C_STRUCT_B:
      {
	/* xxx Do we need to allocate space just like char* ?  No. */
	int acc_size = 0;
	int align;
	const char *save_type = type;

	while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	while (*type != _C_STRUCT_E)
	  {
	    align = objc_alignof_type (type); /* pad to alignment */
	    acc_size = ROUND (acc_size, align);
	    [self decodeValueOfCType:type 
		  at:((char*)d)+acc_size 
		  withName:namePtr];
	    acc_size += objc_sizeof_type (type); /* add component size */
	    type = objc_skip_typespec (type); /* skip component */
	  }
	type = save_type;
	break;
      }
    default:
      [self error:"Unrecognized Type %s", type];
    }

  if (debug_binary_coder)
    {
      [[[self class] debugStderrCoder] 
       encodeValueOfCType:type
       at:d
       withName:@"decoding unnamed"];
    }
}


/* Returning default format version. */

+ (int) defaultFormatVersion
{
  return DEFAULT_FORMAT_VERSION;
}

- (void) decodeName: (id <String> *)n
{
#if 1
  if (n)
    *n = nil;
#else
  if (n)
    *n = [[[NSString alloc] init] autorelease];
#endif
}

@end

