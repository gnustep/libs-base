/* Implementation of GNU Objective-C text coder object for use serializing
   Copyright (C) 1994 Free Software Foundation, Inc.
   
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
#include <objects/TextCoder.h>
#include <objects/MemoryStream.h>
#include <objects/StdioStream.h>
#include <objects/objc-malloc.h>

#define CONCRETE_FORMAT_VERSION 0

static BOOL debug_textcoder = NO;

@implementation TextCoder

+ (int) coderConcreteFormatVersion
{
  return CONCRETE_FORMAT_VERSION;
}

/* Careful, this shouldn't contain newlines */
+ (const char *) coderSignature
{
  return "GNU Objective C Class Library TextCoder";
}

- doInitOnStream: (Stream *)s isDecoding: (BOOL)f
{
  [super doInitOnStream:s isDecoding:f];
  indentation = 0;
  return self;
}

#define XSTR(s) STR(s)
#define STR(s) #s

#define ENCODER_FORMAT(TYPE, CONVERSION) \
"%*s<%s> (" XSTR(TYPE) ") = %" XSTR(CONVERSION) "\n"

- (void) encodeValueOfSimpleType: (const char*)type 
   at: (const void*)d 
   withName: (const char *)name
{
  if (!name)
    name = "";
  switch (*type)
    {
    case _C_LNG:
      [stream writeFormat:"%*s<%s> (long) = %ld\n", 
	      indentation, "", name, *(long*)d];
      break;
    case _C_ULNG:
      [stream writeFormat:"%*s<%s> (unsigned long) = %lu\n", 
	      indentation, "", name, *(unsigned long*)d];
      break;
    case _C_INT:
      [stream writeFormat:"%*s<%s> (int) = %d\n", 
	      indentation, "", name, *(int*)d];
      break;
    case _C_UINT:
      [stream writeFormat:"%*s<%s> (unsigned int) = %u\n", 
	      indentation, "", name, *(unsigned int*)d];
      break;
    case _C_SHT:
      [stream writeFormat:"%*s<%s> (short) = %d\n", 
	      indentation, "", name, (int)*(short*)d];
      break;
    case _C_USHT:
      [stream writeFormat:"%*s<%s> (unsigned short) = %u\n", 
	      indentation, "", name, (unsigned)*(unsigned short*)d];
      break;
    case _C_CHR:
      [stream writeFormat:"%*s<%s> (char) = %c (0x%x)\n", 
	      indentation, "", name, *(char*)d, (unsigned)*(char*)d];
      break;
    case _C_UCHR:
      [stream writeFormat:"%*s<%s> (unsigned char) = 0x%x\n", 
	      indentation, "", name, (unsigned)*(unsigned char*)d];
      break;
    case _C_FLT:
      [stream writeFormat:"%*s<%s> (float) = %f\n",
	      indentation, "", name, *(float*)d];
      break;
    case _C_DBL:
      [stream writeFormat:"%*s<%s> (double) = %f\n",
	      indentation, "", name, *(double*)d];
      break;
    case _C_CHARPTR:
      [stream writeFormat:"%*s<%s> (char*) = \"%s\"\n", 
	      indentation, "", name, *(char**)d];
      break;
    default:
      [self error:"type %s not yet implemented", type];
    }
}

#define DECODER_FORMAT(TYPE, CONVERSION) \
" <%a[^>]> (" XSTR(TYPE) ") = %" XSTR(CONVERSION) " \n"

#define DECODE_ERROR(TYPE) [self error:"bad format decoding " XSTR(TYPE)]

#define DECODE_DEBUG(TYPE, CONVERSION) \
if (debug_textcoder) \
  [[StdioStream standardError] writeFormat:"got <%s> (%s) %" \
   XSTR(CONVERSION) "\n", \
   tmpname, \
   XSTR(TYPE), *(TYPE*)d];
   

- (void) decodeValueOfSimpleType: (const char*)type
   at: (void*)d 
   withName: (const char **)name
{
  char *tmpname;

  switch (*type)
    {
    case _C_LNG:
      if ([stream readFormat:DECODER_FORMAT(long,l), 
		  &tmpname, (long*)d] != 2)
	DECODE_ERROR(long);
      DECODE_DEBUG(long, l);
      break;
    case _C_ULNG:
      if ([stream readFormat:DECODER_FORMAT(unsigned long, lu), 
	      &tmpname, (unsigned long*)d] != 2)
	DECODE_ERROR(unsigned long);
      DECODE_DEBUG(unsigned long, lu);
      break;
    case _C_INT:
      if ([stream readFormat:DECODER_FORMAT(int, d),
	      &tmpname, (int*)d] != 2)
	DECODE_ERROR(int);
      DECODE_DEBUG(int, d);
      break;
    case _C_UINT:
      if ([stream readFormat:DECODER_FORMAT(unsigned int,u), 
	      &tmpname, (unsigned int*)d] != 2)
	DECODE_ERROR(unsigned int);
      DECODE_DEBUG(unsigned int, u);
      break;
    case _C_SHT:
      if ([stream readFormat:DECODER_FORMAT(short,hd), 
	      &tmpname, (short*)d] != 2)
	DECODE_ERROR(short);
      DECODE_DEBUG(short, d);
      break;
    case _C_USHT:
      if ([stream readFormat:DECODER_FORMAT(unsigned short,hu),
	      &tmpname, (unsigned short*)d] != 2)
	DECODE_ERROR(unsigned short);
      DECODE_DEBUG(unsigned short, u);
      break;
    case _C_CHR:
      {
	unsigned tmp;
	if ([stream readFormat:" <%a[^>]> (char) = %*c (%x) \n", 
		&tmpname, &tmp] != 2)
	  DECODE_ERROR(char);
	*(char*)d = (char)tmp;
	DECODE_DEBUG(char, c);
	break;
      }
    case _C_UCHR:
      {
	unsigned tmp;
	if ([stream readFormat:DECODER_FORMAT(unsigned char,x),
		&tmpname, &tmp] != 2)
	  DECODE_ERROR(unsigned char);
	*(unsigned char*)d = (unsigned char)tmp;
	DECODE_DEBUG(unsigned char, c);
	break;
      }
    case _C_FLT:
      if ([stream readFormat:DECODER_FORMAT(float,f),
	      &tmpname, (float*)d] != 2)
	DECODE_ERROR(float);
      DECODE_DEBUG(float, f);
      break;
    case _C_DBL:
      if ([stream readFormat:DECODER_FORMAT(double,f),
	      &tmpname, (double*)d] != 2)
	DECODE_ERROR(double);
      DECODE_DEBUG(double, f);
      break;
    case _C_CHARPTR:
      if ([stream readFormat:" <%a[^>]> (char*) = \"%a[^\"]\" \n", 
	      &tmpname, (char**)d] != 2)
	DECODE_ERROR(char*);
      DECODE_DEBUG(char*, s);
      break;
    default:
      [self error:"type %s not yet implemented", type];
    }
  if (name && *name)
    *name = tmpname;
  else
    (*objc_free)(tmpname);
}

- (void) encodeIndent
{
  [stream writeFormat:"%*s {\n", indentation, ""];
  indentation += 2;
}

- (void) encodeUnindent
{
  indentation -= 2;
  [stream writeFormat:"%*s }\n", indentation, ""];
}

- (void) decodeIndent
{
  char *line;
  char *lp;
  lp = line = [stream readLine];
  while (*lp == ' ') lp++;
  if (*lp != '{')
    [self error:"bad indent format, got \"%s\"", line];
}

- (void) decodeUnindent
{
  char *line;
  char *lp;
  lp = line = [stream readLine];
  while (*lp == ' ') lp++;
  if (*lp != '}')
    [self error:"bad unindent format, got \"%s\"", line];
}

- (void) encodeName: (const char*)n
{
  if (n)
    [stream writeFormat:"%*s<%s>\n", indentation, "", n];
  else
    [stream writeFormat:"%*s<NULL>\n", indentation, "", n];
}

/* Buffer is malloc'ed */
- (void) decodeName: (const char**)n
{
  if (n)
    {
      if ([stream readFormat:" <%a[^>]> \n", n] != 1)
	[self error:"bad format"];
      if (debug_textcoder)
	fprintf(stderr, "got name <%s>\n", *n);
    }
  else
    {
      [stream readFormat:" <%*[^>]> \n"];
    }
}

- (void) encodeWithCoder: (Coder*)anEncoder
{
  [self notImplemented:_cmd];
}

+ newWithCoder: (Coder*)aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

@end
