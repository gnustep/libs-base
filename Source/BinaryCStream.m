/* Implementation of GNU Objective-C binary stream object for use serializing
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

#include <objects/stdobjects.h>
#include <objects/BinaryCStream.h>
#include <objects/NSString.h>
#include <objects/StdioStream.h>
#include <objects/TextCStream.h>

#define DEFAULT_FORMAT_VERSION 0

#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })

#define NUM_BYTES_STRING_LENGTH 4

@implementation BinaryCStream

+ (void) initialize
{
  if (self == [BinaryCStream class])
    /* Make sure that we don't overrun memory when reading _C_CHARPTR. */
    assert (sizeof(unsigned) >= NUM_BYTES_STRING_LENGTH);
}


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


/* Encoding/decoding C values */

- (void) encodeValueOfCType: (const char*)type 
   at: (const void*)d 
   withName: (id <String>) name
{
  /* Make sure we're not being asked to encode an "ObjC" type. */
  assert(type);
  assert(*type != '@');
  assert(*type != '^');
  assert(*type != ':');

  if (debug_binary_coder)
    {
      [[[self class] debugStderrCoder] 
       encodeValueOfCType: type
       at: d
       withName: name];
    }

  [stream writeByte: *type];

#define WRITE_SIGNED_TYPE(_TYPE, CONV_FUNC)				 \
      {									 \
	char buffer[1+sizeof(_TYPE)];					 \
	buffer[0] = sizeof (_TYPE);					 \
	if (*(_TYPE*)d < 0)						 \
	  {								 \
	    buffer[0] |= 0x80;						 \
	    *(_TYPE*)(buffer+1) = CONV_FUNC (- *(_TYPE*)d);		 \
	  }								 \
	else								 \
	  {								 \
	    *(_TYPE*)(buffer+1) = CONV_FUNC (*(_TYPE*)d);		 \
	  }								 \
	[stream writeBytes: buffer length: 1+sizeof(_TYPE)];		 \
      }

#define READ_SIGNED_TYPE(_TYPE, CONV_FUNC)			\
      {								\
	char sign, size;					\
	[stream readByte: &size];				\
	sign = size & 0x80;					\
	size &= ~0x80;						\
	{							\
	  char buffer[size];					\
	  int read_size;					\
	  read_size = [stream readBytes: buffer length: size];	\
	  assert (read_size == size);				\
	  assert (size == sizeof(_TYPE));		  	\
	  *(unsigned _TYPE*)d =					\
	    CONV_FUNC (*(unsigned _TYPE*)buffer);		\
	  if (sign)						\
	    *(_TYPE*)d = - *(_TYPE*)d;				\
	}							\
      }

/* Reading and writing unsigned scalar types. */

#define WRITE_UNSIGNED_TYPE(_TYPE, CONV_FUNC)			\
      {								\
	char buffer[1+sizeof(_TYPE)];				\
	buffer[0] = sizeof (_TYPE);				\
	*(_TYPE*)(buffer+1) = CONV_FUNC (*(_TYPE*)d);		\
	[stream writeBytes: buffer length: (1+sizeof(_TYPE))];	\
      }

#define READ_UNSIGNED_TYPE(_TYPE, CONV_FUNC)			\
      {								\
	char size;						\
	[stream readByte: &size];				\
	{							\
	  char buffer[size];					\
	  int read_size;					\
	  read_size = [stream readBytes: buffer length: size];	\
	  assert (read_size == size);				\
	  assert (size == sizeof(_TYPE));			\
	  *(_TYPE*)d =						\
	    CONV_FUNC (*(_TYPE*)buffer);			\
	}							\
      }

  switch (*type)
    {
    case _C_CHARPTR:
      {
	unsigned length = strlen (*(char**)d);
	unsigned nlength;
	nlength = htonl (length);
	[stream writeBytes: &nlength
		length: NUM_BYTES_STRING_LENGTH];
	[stream writeBytes: *(char**)d
		length: length];
	break;
      }

    case _C_CHR:
    case _C_UCHR:
      [stream writeByte: *(unsigned char*)d];
      break;

/* Reading and writing signed scalar types. */

    case _C_SHT:
      WRITE_SIGNED_TYPE (short, htons);
      break;
    case _C_USHT:
      WRITE_UNSIGNED_TYPE (unsigned short, htons);
      break;

    case _C_INT:
      WRITE_SIGNED_TYPE (int, htonl);
      break;
    case _C_UINT:
      WRITE_UNSIGNED_TYPE (unsigned int, htonl);
      break;

    case _C_LNG:
      WRITE_SIGNED_TYPE (long, htonl);
      break;
    case _C_ULNG:
      WRITE_UNSIGNED_TYPE (unsigned long, htonl);
      break;

    /* Two quickie kludges to make archiving of floats and doubles work */
    case _C_FLT:
      {
	char buf[64];
	char *s = buf;
	sprintf(buf, "%f", *(float*)d);
	[self encodeValueOfCType: @encode(char*)
	      at: &s
	      withName: @"BinaryCStream float"];
	break;
      }
    case _C_DBL:
      {
	char buf[64];
	char *s = buf;
	sprintf(buf, "%f", *(double*)d);
	[self encodeValueOfCType: @encode(char*)
	      at: &s
	      withName: @"BinaryCStream double"];
	break;
      }
    case _C_ARY_B:
      {
	int len = atoi (type+1);	/* xxx why +1 ? */
	int offset;

	while (isdigit(*++type));
	offset = objc_sizeof_type(type);
	[self encodeName:name];
	[self encodeIndent];
	while (len-- > 0)
	  {
	    /* Change this so we don't re-write type info every time. */
	    /* xxx We should be able to encode arrays "ObjC" types also! */
	    [self encodeValueOfCType:type 
		  at:d 
		  withName:@"array component"];
	    ((char*)d) += offset;
	  }
	[self encodeUnindent];
	break; 
      }
    case _C_STRUCT_B:
      {
	int acc_size = 0;
	int align;

	while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	[self encodeName:name];
	[self encodeIndent];
	while (*type != _C_STRUCT_E)
	  {
	    align = objc_alignof_type (type); /* pad to alignment */
	    acc_size = ROUND (acc_size, align);
	    /* xxx We should be able to encode structs "ObjC" types also! */
	    [self encodeValueOfCType:type 
		  at:((char*)d)+acc_size 
		  withName:@"structure component"];
	    acc_size += objc_sizeof_type (type); /* add component size */
	    type = objc_skip_typespec (type); /* skip component */
	  }
	[self encodeUnindent];
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
  char encoded_type;

  assert(type);
  assert(*type != '@');
  assert(*type != '^');
  assert(*type != ':');

  [stream readByte: &encoded_type];
  if (encoded_type != *type 
      && !((encoded_type=='c' || encoded_type=='C') 
	   && (*type=='c' || *type=='C')))
    [self error:"Expected type \"%c\", got type \"%c\"", *type, encoded_type];

  switch (encoded_type)
    {
    case _C_CHARPTR:
      {
	unsigned length;
	unsigned read_count;
	read_count = [stream readBytes: &length
			     length: NUM_BYTES_STRING_LENGTH];
	assert (read_count == NUM_BYTES_STRING_LENGTH);
	length = ntohl (length);
	/* xxx Maybe I should make this alloca() instead of malloc(). */
	OBJC_MALLOC (*(char**)d, char, length+1);
	read_count = [stream readBytes: *(char**)d 
			     length: length];
	assert (read_count == length);
	(*(char**)d)[length] = '\0';
	break;
      }

    case _C_CHR:
    case _C_UCHR:
      [stream readByte: (unsigned char*)d];
      break;

    case _C_SHT:
      READ_SIGNED_TYPE (short, ntohs);
      break;
    case _C_USHT:
      READ_UNSIGNED_TYPE (unsigned short, ntohs);
      break;

    case _C_INT:
      READ_SIGNED_TYPE (int, ntohl);
      break;
    case _C_UINT:
      READ_UNSIGNED_TYPE (unsigned int, ntohl);
      break;

    case _C_LNG:
      READ_SIGNED_TYPE (long, ntohl);
      break;
    case _C_ULNG:
      READ_UNSIGNED_TYPE (unsigned long, ntohl);
      break;

  /* Two quickie kludges to make archiving of floats and doubles work */
    case _C_FLT:
      {
	char *buf;
	[self decodeValueOfCType:@encode(char*) at:&buf withName:NULL];
	if (sscanf(buf, "%f", (float*)d) != 1)
	  [self error:"expected float, got %s", buf];
	(*objc_free)(buf);
	break;
      }
    case _C_DBL:
      {
	char *buf;
	[self decodeValueOfCType:@encode(char*) at:&buf withName:NULL];
	if (sscanf(buf, "%lf", (double*)d) != 1)
	  [self error:"expected double, got %s", buf];
	(*objc_free)(buf);
	break;
      }
    case _C_ARY_B:
      {
	/* xxx Do we need to allocate space, just like _C_CHARPTR ? */
	int len = atoi(type+1);
	int offset;
	[self decodeName:namePtr];
	[self decodeIndent];
	while (isdigit(*++type));
	offset = objc_sizeof_type(type);
	while (len-- > 0)
	  {
	    [self decodeValueOfCType:type 
		  at:d 
		  withName:namePtr];
	    ((char*)d) += offset;
	  }
	[self decodeUnindent];
	break; 
      }
    case _C_STRUCT_B:
      {
	/* xxx Do we need to allocate space just like char* ?  No. */
	int acc_size = 0;
	int align;
	const char *save_type = type;

	while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	[self decodeName:namePtr];
	[self decodeIndent];		/* xxx insert [self decodeName:] */
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
	[self decodeUnindent];
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


/* Encoding and decoding names. */

- (void) encodeName: (id <String>) name
{
  if (debug_binary_coder)
    [[[self class] debugStderrCoder]
     encodeName:name];
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

