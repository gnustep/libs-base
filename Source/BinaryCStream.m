/* Implementation of GNU Objective-C binary stream object for use serializing
   Copyright (C) 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Written: Jan 1996
   
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
#include <gnustep/base/BinaryCStream.h>
#include <gnustep/base/NSString.h>
#include <gnustep/base/StdioStream.h>
#include <gnustep/base/TextCStream.h>
#include <gnustep/base/MallocAddress.h>
#include <Foundation/NSException.h>
#include <math.h>
#include <values.h>		// This gets BITSPERBYTE on Solaris
#include <netinet/in.h>		// for byte-conversion

#define DEFAULT_FORMAT_VERSION 0

#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })

/* The number of bytes used to encode the length of a _C_CHARPTR
   string that is encoded. */
#define NUM_BYTES_STRING_LENGTH 4

/* The value by which we multiply a float or double in order to bring
   mantissa digits to the left-hand-side of the decimal point, so that
   we can extra them by assigning the float or double to an int. */
#if !defined(BITSPERBYTE) && defined(NeXT)
#include <mach/vm_param.h>
#define BITSPERBYTE BYTE_SIZE
#endif
#define FLOAT_FACTOR ((double)(1 << ((sizeof(int)*BITSPERBYTE)-2)))

@implementation BinaryCStream

+ (void) initialize
{
  if (self == [BinaryCStream class])
    /* Make sure that we don't overrun memory when reading _C_CHARPTR. */
    assert (sizeof(unsigned) >= NUM_BYTES_STRING_LENGTH);
}


/* For debugging */

static int debug_binary_coder = 0;

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

#define WRITE_SIGNED_TYPE(_PTR, _TYPE, _CONV_FUNC)			 \
      {									 \
	char buffer[1+sizeof(_TYPE)];					 \
	buffer[0] = sizeof (_TYPE);					 \
	if (*(_TYPE*)_PTR < 0)						 \
	  {								 \
	    buffer[0] |= 0x80;						 \
	    *(_TYPE*)(buffer+1) = _CONV_FUNC (- *(_TYPE*)_PTR);		 \
	  }								 \
	else								 \
	  {								 \
	    *(_TYPE*)(buffer+1) = _CONV_FUNC (*(_TYPE*)_PTR);		 \
	  }								 \
	[stream writeBytes: buffer length: 1+sizeof(_TYPE)];		 \
      }

#define READ_SIGNED_TYPE(_PTR, _TYPE, _CONV_FUNC)		\
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
	  *(unsigned _TYPE*)_PTR =				\
	    _CONV_FUNC (*(unsigned _TYPE*)buffer);		\
	  if (sign)						\
	    *(_TYPE*)_PTR = - *(_TYPE*)_PTR;			\
	}							\
      }

/* Reading and writing unsigned scalar types. */

#define WRITE_UNSIGNED_TYPE(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
	char buffer[1+sizeof(_TYPE)];				\
	buffer[0] = sizeof (_TYPE);				\
	*(_TYPE*)(buffer+1) = _CONV_FUNC (*(_TYPE*)_PTR);	\
	[stream writeBytes: buffer length: (1+sizeof(_TYPE))];	\
      }

#define READ_UNSIGNED_TYPE(_PTR, _TYPE, _CONV_FUNC)		\
      {								\
	char size;						\
	[stream readByte: &size];				\
	{							\
	  char buffer[size];					\
	  int read_size;					\
	  read_size = [stream readBytes: buffer length: size];	\
	  assert (read_size == size);				\
	  assert (size == sizeof(_TYPE));			\
	  *(_TYPE*)_PTR =					\
	    _CONV_FUNC (*(_TYPE*)buffer);			\
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
      WRITE_SIGNED_TYPE (d, short, htons);
      break;
    case _C_USHT:
      WRITE_UNSIGNED_TYPE (d, unsigned short, htons);
      break;

    case _C_INT:
      WRITE_SIGNED_TYPE (d, int, htonl);
      break;
    case _C_UINT:
      WRITE_UNSIGNED_TYPE (d, unsigned int, htonl);
      break;

    case _C_LNG:
      WRITE_SIGNED_TYPE (d, long, htonl);
      break;
    case _C_ULNG:
      WRITE_UNSIGNED_TYPE (d, unsigned long, htonl);
      break;

    /* xxx The handling of floats and doubles could be improved.
       e.g. I should account for varying sizeof(int) vs sizeof(double). */

    case _C_FLT:
      {
	volatile double value;
	int exponent, mantissa;
	short exponent_encoded;
	value = *(float*)d;
	/* Get the exponent */
	value = frexp (value, &exponent);
	exponent_encoded = exponent;
	NSParameterAssert (exponent_encoded == exponent);
	/* Get the mantissa. */
	value *= FLOAT_FACTOR;
	mantissa = value;
	assert (value - mantissa == 0);
	/* Encode the value as its two integer components. */
	WRITE_SIGNED_TYPE (&exponent_encoded, short, htons);
	WRITE_SIGNED_TYPE (&mantissa, int, htonl);
	break;
      }

    case _C_DBL:
      {
	volatile double value;
	int exponent, mantissa1, mantissa2;
	short exponent_encoded;
	value = *(double*)d;
	/* Get the exponent */
	value = frexp (value, &exponent);
	exponent_encoded = exponent;
	NSParameterAssert (exponent_encoded == exponent);
	/* Get the first part of the mantissa. */
	value *= FLOAT_FACTOR;
	mantissa1 = value;
	value -= mantissa1;
	value *= FLOAT_FACTOR;
	mantissa2 = value;
	assert (value - mantissa2 == 0);
	/* Encode the value as its three integer components. */
	WRITE_SIGNED_TYPE (&exponent_encoded, short, htons);
	WRITE_SIGNED_TYPE (&mantissa1, int, htonl);
	WRITE_SIGNED_TYPE (&mantissa2, int, htonl);
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
      [NSException raise: NSGenericException
		   format: @"Unrecognized type %s", type];
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
    [NSException raise: NSGenericException
		 format: @"Expected type \"%c\", got type \"%c\"",
		 *type, encoded_type];

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
	OBJC_MALLOC (*(char**)d, char, length+1);
	read_count = [stream readBytes: *(char**)d 
			     length: length];
	assert (read_count == length);
	(*(char**)d)[length] = '\0';
	/* Autorelease the newly malloc'ed pointer?  Grep for (*objc_free)
	   to see the places the may have to be changed
	   [MallocAddress autoreleaseMallocAddress: *(char**)d]; */
	break;
      }

    case _C_CHR:
    case _C_UCHR:
      [stream readByte: (unsigned char*)d];
      break;

    case _C_SHT:
      READ_SIGNED_TYPE (d, short, ntohs);
      break;
    case _C_USHT:
      READ_UNSIGNED_TYPE (d, unsigned short, ntohs);
      break;

    case _C_INT:
      READ_SIGNED_TYPE (d, int, ntohl);
      break;
    case _C_UINT:
      READ_UNSIGNED_TYPE (d, unsigned int, ntohl);
      break;

    case _C_LNG:
      READ_SIGNED_TYPE (d, long, ntohl);
      break;
    case _C_ULNG:
      READ_UNSIGNED_TYPE (d, unsigned long, ntohl);
      break;

    case _C_FLT:
      {
	short exponent;
	int mantissa;
	double value;
	/* Decode the exponent and mantissa. */
	READ_SIGNED_TYPE (&exponent, short, ntohs);
	READ_SIGNED_TYPE (&mantissa, int, ntohl);
	/* Assemble them into a double */
	value = mantissa / FLOAT_FACTOR;
	value = ldexp (value, exponent);
	/* Put the double into the requested memory location as a float */
	*(float*)d = value;
	break;
      }

    case _C_DBL:
      {
	short exponent;
	int mantissa1, mantissa2;
	volatile double value;
	/* Decode the exponent and the two pieces of the mantissa. */
	READ_SIGNED_TYPE (&exponent, short, ntohs);
	READ_SIGNED_TYPE (&mantissa1, int, ntohl);
	READ_SIGNED_TYPE (&mantissa2, int, ntohl);
	/* Assemble them into a double */
	value = ((mantissa2 / FLOAT_FACTOR) + mantissa1) / FLOAT_FACTOR;
	value = ldexp (value, exponent);
	/* Put the double into the requested memory location. */
	*(double*)d = value;
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
      [NSException raise: NSGenericException
		   format: @"Unrecognized Type %s", type];
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

