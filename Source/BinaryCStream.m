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

@implementation BinaryCStream


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
  unsigned char size;

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

  /* A fairly stupid, inefficient binary encoding.  This could use 
     some improvement.  For instance, we could compress the sign
     information and the type information.
     It could probably also use some portability fixes. */
  [stream writeByte:*type];
  size = objc_sizeof_type(type);
  [stream writeByte:size];
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
#ifndef __CHAR_UNSIGNED__
      if (*(char*)d < 0)
	[stream writeByte:1];
      else
#endif
	[stream writeByte:0];
    case _C_UCHR:
      [stream writeByte:*(unsigned char*)d];
      break;

    case _C_SHT:
      if (*(short*)d < 0)
	[stream writeByte:1];
      else
	[stream writeByte:0];
    case _C_USHT:
      {
	unsigned char *buf = alloca(size);
	short s = *(short*)d;
	int count = size;
	if (s < 0) s = -s;
	for (; count--; s >>= 8)
	  buf[count] = (char) (s % 0x100);
	[stream writeBytes:buf length:size];
	break;
      }

    case _C_INT:
      if (*(int*)d < 0)
	[stream writeByte:1];
      else
	[stream writeByte:0];
    case _C_UINT:
      {
	unsigned char *buf = alloca(size);
	int s = *(int*)d;
	int count = size;
	if (s < 0) s = -s;
	for (; count--; s >>= 8)
	  buf[count] = (char) (s % 0x100);
	[stream writeBytes:buf length:size];
	break;
      }

    case _C_LNG:
      if (*(long*)d < 0)
	[stream writeByte:1];
      else
	[stream writeByte:0];
    case _C_ULNG:
      {
	unsigned char *buf = alloca(size);
	long s = *(long*)d;
	int count = size;
	if (s < 0) s = -s;
	for (; count--; s >>= 8)
	  buf[count] = (char) (s % 0x100);
	[stream writeBytes:buf length:size];
	break;
      }

    /* Two quickie kludges to make archiving of floats and doubles work */
    case _C_FLT:
      {
	char buf[64];
	char *s = buf;
	sprintf(buf, "%f", *(float*)d);
	[self encodeValueOfCType:@encode(char*)
	      at:&s withName:@"BinaryCStream float"];
	break;
      }
    case _C_DBL:
      {
	char buf[64];
	char *s = buf;
	sprintf(buf, "%f", *(double*)d);
	[self encodeValueOfCType:@encode(char*)
	      at:&s withName:@"BinaryCStream double"];
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
  unsigned char encoded_size;
  unsigned char encoded_sign = 0;

  assert(type);
  assert(*type != '@');
  assert(*type != '^');
  assert(*type != ':');

  [stream readByte:&encoded_type];
  if (encoded_type != *type 
      && !((encoded_type=='c' || encoded_type=='C') 
	   && (*type=='c' || *type=='C')))
    [self error:"Expected type \"%c\", got type \"%c\"", *type, encoded_type];
  [stream readByte:&encoded_size];
  switch (encoded_type)
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
      [stream readByte:&encoded_sign];
    case _C_UCHR:
      [stream readByte:(unsigned char*)d];
      if (encoded_sign)
	*(char*)d = *(char*)d * -1;
      break;

    case _C_SHT:
      [stream readByte:&encoded_sign];
    case _C_USHT:
      {
	unsigned char *buf = alloca(encoded_size);
	int i;
	short s = 0;
	[stream readBytes:buf length:encoded_size];
	for (i = 0; i < sizeof(short); i++)
	  {
	    s <<= 8;
	    s += buf[i];
	  }
	if (encoded_sign)
	  s = -s;
	*(short*)d = s;
	break;
      }

    case _C_INT:
      [stream readByte:&encoded_sign];
    case _C_UINT:
      {
	unsigned char *buf = alloca(encoded_size);
	int i;
	int s = 0;
	[stream readBytes:buf length:encoded_size];
	for (i = 0; i < sizeof(int); i++)
	  {
	    s <<= 8;
	    s += buf[i];
	  }
	if (encoded_sign)
	  s = -s;
	*(int*)d = s;
	break;
      }

    case _C_LNG:
      [stream readByte:&encoded_sign];
    case _C_ULNG:
      {
	unsigned char *buf = alloca(encoded_size);
	int i;
	long s = 0;
	[stream readBytes:buf length:encoded_size];
	for (i = 0; i < sizeof(long); i++)
	  {
	    s <<= 8;
	    s += buf[i];
	  }
	if (encoded_sign)
	  s = -s;
	*(long*)d = s;
	break;
      }

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

