/* Implementation of GNU Objective-C text stream object for use serializing
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
#include <gnustep/base/TextCStream.h>
#include <gnustep/base/NSString.h>
#include <gnustep/base/StdioStream.h>
#include <Foundation/NSException.h>

#define DEFAULT_FORMAT_VERSION 0

static BOOL debug_textcoder = NO;

@implementation TextCStream


/* Encoding/decoding C values */

#define XSTR(s) STR(s)
#define STR(s) #s

#define ATXSTR(s) ATSTR(s)
#define ATSTR(s) @#s

#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })

#define ENCODER_FORMAT(TYPE, CONVERSION) \
@"%*s<%s> (" ATXSTR(TYPE) @") = %" ATXSTR(CONVERSION) @"\n"

- (void) encodeValueOfCType: (const char*) type 
         at: (const void*) d 
         withName: (NSString*) name;
{
  assert(type);
  assert(*type != '@');
  assert(*type != '^');
  assert(*type != ':');

  if (!name || [name length] == 0)
    name = @"Anonymous";
  switch (*type)
    {
    case _C_LNG:
      [stream writeFormat:@"%*s<%s> (long) = %ld\n", 
	      indentation, "", [name cStringNoCopy], *(long*)d];
      break;
    case _C_ULNG:
      [stream writeFormat:@"%*s<%s> (unsigned long) = %lu\n", 
	      indentation, "", [name cStringNoCopy], *(unsigned long*)d];
      break;
    case _C_INT:
      [stream writeFormat:@"%*s<%s> (int) = %d\n", 
	      indentation, "", [name cStringNoCopy], *(int*)d];
      break;
    case _C_UINT:
      [stream writeFormat:@"%*s<%s> (unsigned int) = %u\n", 
	      indentation, "", [name cStringNoCopy], *(unsigned int*)d];
      break;
    case _C_SHT:
      [stream writeFormat:@"%*s<%s> (short) = %d\n", 
	      indentation, "", [name cStringNoCopy], (int)*(short*)d];
      break;
    case _C_USHT:
      [stream writeFormat:@"%*s<%s> (unsigned short) = %u\n", 
	      indentation, "", [name cStringNoCopy],
	      (unsigned)*(unsigned short*)d];
      break;
    case _C_CHR:
      [stream writeFormat:@"%*s<%s> (char) = %c (0x%x)\n", 
	      indentation, "", [name cStringNoCopy],
	      *(char*)d, (unsigned)*(char*)d];
      break;
    case _C_UCHR:
      [stream writeFormat:@"%*s<%s> (unsigned char) = 0x%x\n", 
	      indentation, "", [name cStringNoCopy],
	      (unsigned)*(unsigned char*)d];
      break;
    case _C_FLT:
      [stream writeFormat:@"%*s<%s> (float) = %g\n",
	      indentation, "", [name cStringNoCopy], *(float*)d];
      break;
    case _C_DBL:
      [stream writeFormat:@"%*s<%s> (double) = %g\n",
	      indentation, "", [name cStringNoCopy], *(double*)d];
      break;
    case _C_CHARPTR:
      [stream writeFormat:@"%*s<%s> (char*) = \"%s\"\n", 
	      indentation, "", [name cStringNoCopy], *(char**)d];
      break;
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
    case _C_PTR:
      [NSException raise: NSGenericException
		   format: @"Cannot encode pointers"];
      break;
#if 0 /* No, don't know how far to recurse */
      [self encodeValueOfObjCType:type+1 at:*(char**)d withName:name];
      break;
#endif
    default:
      [NSException raise: NSGenericException
		   format: @"type %s not implemented", type];
    }
}

#define DECODER_FORMAT(TYPE, CONVERSION) \
@" <%a[^>]> (" ATXSTR(TYPE) @") = %" ATXSTR(CONVERSION) @" \n"

#define DECODE_ERROR(TYPE)						\
{									\
  id line = [stream readLine];						\
  [NSException raise: NSGenericException				\
	       format: @"bad format decoding " ATXSTR(TYPE) @".\n"	\
                       @"Looking at %s\n.",				\
	               [line cStringNoCopy]];				\
}
  

#define DECODE_DEBUG(TYPE, CONVERSION) \
if (debug_textcoder) \
  [[StdioStream standardError] writeFormat: \
			       @"got <%s> (%s) %" ATXSTR(CONVERSION) @"\n", \
			       tmpname, \
			       XSTR(TYPE), *(TYPE*)d];

- (void) decodeValueOfCType: (const char*) type 
         at: (void*) d 
         withName: (NSString* *) namePtr;
{
  char *tmpname;

  assert(type);
  assert(*type != '@');
  assert(*type != '^');
  assert(*type != ':');
  assert (d);

  switch (*type)
    {
    case _C_LNG:
      if ([stream readFormat: DECODER_FORMAT(long,l),
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
	if ([stream readFormat:@" <%a[^>]> (char) = %*c (%x) \n", 
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
      if ([stream readFormat:DECODER_FORMAT(double,lf),
	      &tmpname, (double*)d] != 2)
	DECODE_ERROR(double);
      DECODE_DEBUG(double, f);
      break;
    case _C_CHARPTR:
      if ([stream readFormat:@" <%a[^>]> (char*) = \"%a[^\"]\" \n", 
	      &tmpname, (char**)d] != 2)
	DECODE_ERROR(char*);
      DECODE_DEBUG(char*, s);
      break;
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
	[self decodeUnindent];
	break;
      }
    case _C_PTR:
      [NSException raise: NSGenericException
		   format: @"Cannot decode pointers"];
      break;
#if 0 /* No, don't know how far to recurse */
      OBJC_MALLOC(*(void**)d, void*, 1);
      [self decodeValueOfObjCType:type+1 at:*(char**)d withName:namePtr];
      break;
#endif
    default:
      [NSException raise: NSGenericException
		   format: @"type %s not yet implemented", type];
    }
  if (namePtr)
    *namePtr = [[[NSString alloc] initWithCStringNoCopy: tmpname
				  length: strlen (tmpname)
				  freeWhenDone: YES]
		 autorelease];
  else
    (*objc_free) (tmpname);
}


/* Encoding/decoding indentation */

- (void) encodeIndent
{
  [stream writeFormat: @"%*s {\n", indentation, ""];
  indentation += 2;
}

- (void) encodeUnindent
{
  indentation -= 2;
  [stream writeFormat: @"%*s }\n", indentation, ""];
}

- (void) decodeIndent
{
  id line;
  const char *lp;

  line = [stream readLine];
  lp = [line cStringNoCopy];
  while (*lp == ' ') lp++;
  if (*lp != '{')
    [NSException raise: NSGenericException
		 format: @"bad indent format, got \"%s\"", line];
}

- (void) decodeUnindent
{
  id line;
  const char *lp;

  line = [stream readLine];
  lp = [line cStringNoCopy];
  while (*lp == ' ') lp++;
  if (*lp != '}')
    [NSException raise: NSGenericException
		 format: @"bad unindent format, got \"%s\"", line];
}

- (void) encodeName: (NSString*) n
{
  if (n)
    [stream writeFormat:@"%*s<%s>\n", indentation, "", [n cStringNoCopy]];
  else
    [stream writeFormat:@"%*s<NULL>\n", indentation, ""];
}

- (void) decodeName: (NSString* *) name
{
  char *n;
  if (name)
    {
      if ([stream readFormat: @" <%a[^>]> \n", &n] != 1)
	[NSException raise: NSGenericException
		     format: @"bad format"];
      *name = [[[NSString alloc] initWithCStringNoCopy: n
				 length: strlen (n)
				 freeWhenDone: YES]
		autorelease];
      if (debug_textcoder)
	fprintf(stderr, "got name <%s>\n", n);
    }
  else
    {
      [stream readFormat: @" <%*[^>]> \n"];
    }
}


/* Returning default format version. */

+ (int) defaultFormatVersion
{
  return DEFAULT_FORMAT_VERSION;
}

@end
