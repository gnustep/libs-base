/* Implementation for Objective-C String object
   Copyright (C) 1993,1994,1995 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#include <objects/String.h>
#include <objects/IndexedCollectionPrivate.h>
/* memcpy(), strlen(), strcmp() are gcc builtin's */
#include <stdarg.h>
#include <assert.h>

@implementation String

/* Fill this with "notImplemented:" Do the same for Mutable and
   Constant String. */

+ initialize
{
  if (self == [String class])
    [self setVersion:0];	/* beta release */
  return self;
}

// INITIALIZING;

/* For now, this is the designated initializer for this class */
- initFromCString: (const char*)aCharPtr range: (IndexRange)aRange
{
  [self notImplemented:_cmd];
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  [self notImplemented:_cmd];
  return self;
}

/* This override in mutable string classes */
- empty
{
  [self shouldNotImplement:_cmd];
  return self;
}

/* Override the designated initializer of superclass */
- initWithType: (const char *)contentEncoding
{
  if (strcmp(contentEncoding, @encode(char)))
    [self error:"invalid args to String initializer"];
  [self init];
  return self;
}

- initFromCString: (const char*)aCharPtr length: (unsigned)aLength
{
  return [self initFromCString:aCharPtr 
	       range:((IndexRange){0,aLength})];
}

- initFromCString: (const char*)aCharPtr
{
  return [self initFromCString:aCharPtr
	       range:((IndexRange){0, strlen(aCharPtr)})];
}

#if HAVE_VSPRINTF
- initFromFormat: (String*)aFormatString arguments: (va_list)arg
{
  char buf[128];		/* xxx horrible, disgusting, fix this */
  vsprintf(buf, [aFormatString cString], arg);
  return [self initFromCString:buf];
}

- initFromCFormat: (const char*)formatCharPtr arguments: (va_list)arg
{
  char buf[128];		/* xxx horrible, disgusting, fix this */
  vsprintf(buf, formatCharPtr, arg);
  return [self initFromCString:buf];
}
#endif /* HAVE_VSPRINTF */

- initFromFormat: (String*)aFormatString, ...
{
  va_list ap;
  va_start(ap, aFormatString);
  [self initFromCFormat:[aFormatString cString] arguments:ap];
  va_end(ap);
  return self;
}

- initFromCFormat: (const char*)formatCharPtr, ...
{
  va_list ap;
  va_start(ap, formatCharPtr);
  [self initFromCFormat:formatCharPtr arguments:ap];
  va_end(ap);
  return self;
}

- init
{
  return [self initFromCString:""];
}

- initFromString: (String*)aString range: (IndexRange)aRange
{
  return [self initFromCString:[aString cString] range:aRange];
}

- initFromString: (String*)aString length: (unsigned)aLength
{
  return [self initFromCString:[aString cString]];
}

- initFromString: (String*)aString
{
  return [self initFromCString:[aString cString]];
}


// GETTING NEW, AUTORELEASED STRING OBJECTS, NO NEED TO RELEASE THESE;

+ (String*) stringWithString: (String*)aString range: (IndexRange)aRange
{
  return [[[CString alloc] initWithString:aString range:aRange]
	  autorelease];
}

+ (String*) stringWithString: (String*)aString length: (unsigned)aLength
{
  return [[[CString alloc] initWithString:aString length:aLength]
	  autorelease];
}

+ (String*) stringWithString: (String*)aString
{
  return [[[CString alloc] initWithString:aString]
	  autorelease];
}

+ (String*) stringWithFormat: (String*)aFormatString, ...
{
  va_list ap;
  id ret;
  
  va_start(ap, aFormatString);
  ret = [[self stringWithFormat:aFormatString arguments:ap]
	 autorelease];
  va_end(ap);
  return ret;
}

+ (String*) stringWithFormat: (String*)aFormatString arguments: (va_list)arg
{
  return [[[CString alloc] initWithFormat:aFormatString arguments:arg]
	  autorelease];
}

+ (String*) stringWithCString: (const char*)cp range: (IndexRange)r
   noCopy: (BOOL)f
{
  [self notImplemented:_cmd];
  return nil;
}

+ (String*) stringWithCString: (const char*)aCharPtr range: (IndexRange)aRange
{
  [self notImplemented:_cmd];
  return nil;
}

+ (String*) stringWithCString: (const char*)aCharPtr length: (unsigned)aLength
{
  [self notImplemented:_cmd];
  return nil;
}

+ (String*) stringWithCString: (const char*)aCharPtr
{
  [self notImplemented:_cmd];
  return nil;
}


- (String*) stringByAppendingFormat: (String*)aString, ...
{
  [self notImplemented:_cmd];
  return nil;
}

- (String*) stringByAppendingFormat: (String*)aString arguments: (va_list)arg
{
  [self notImplemented:_cmd];
  return nil;
}

- (String*) stringByPrependingFormat: (String*)aString, ...
{
  [self notImplemented:_cmd];
  return nil;
}

- (String*) stringByPrependingFormat: (String*)aString arguments: (va_list)arg
{
  [self notImplemented:_cmd];
  return nil;
}

- (String*) stringByAppendingString: (String*)aString
{
  [self notImplemented:_cmd];
  return nil;
}

- (String*) stringByPrependingString: (String*)aString
{
  [self notImplemented:_cmd];
  return nil;
}


// COPYING;

/* This is the designated copier */
- (char *) cStringCopyRange: (IndexRange)aRange;
{
  [self notImplemented:_cmd];
  return "";
}

- (char *) cStringCopyLength: (unsigned)aLength
{
  // xxx need to check aLength against _count;
  return [self cStringCopyRange:((IndexRange){0,aLength})];
}

- (char *) cStringCopy
{
  return [self cStringCopyRange:((IndexRange){0, [self count]})];
}

- copy
{
  return [[[self class] alloc] initWithCString:[self cString]];
}

// TESTING;

- (const char *) contentsDescription
{
  return @encode(char);
}

- (int(*)(elt,elt)) comparisonFunction
{
  return elt_compare_chars;
}

- (unsigned) hash
{
  return elt_hash_string([self cString]);
}

- (int) compare: anObject
{
  if ([anObject isKindOfClass:[String class]])
    return strcmp([self cString], [anObject cString]);
  return [super compare:anObject];
}

- (BOOL) isEqual: anObject 
{
    if (self == anObject) 
      return YES;
    if (! [anObject isKindOf:[String class]]
	|| [self count] != [anObject count]
	|| [anObject hash] != [self hash] ) 
      return NO;
    return ! [self compare:anObject];
}    

- (unsigned) count
{
  /* Should be overridden for efficiency. */
  return strlen([self cString]);
}

- (unsigned) length
{
  return [self count];
}

- (IndexRange) stringRange
{
  IndexRange r = {0, [self count]};
  return r;
}

/* xxx These next three need error checking to handle the case in which 
   we're looking for never appears */

- (unsigned) indexOfChar: (char)aChar
{
  const char *s = [self cString];
  return (strchr(s, aChar) - s);
}

- (unsigned) indexOfLastChar: (char)aChar
{
  const char *s = [self cString];
  return (strrchr(s, aChar) - s);
}

- (unsigned) indexOfString: (String*)aString
{
  const char *s = [self cString];
  return (strstr(s, [aString cString]) - s);
}

- (char) charAtIndex: (unsigned)index
{
  [self notImplemented:_cmd];
  return ' ';
}



// GETTING VALUES;

- (int) intValue
{
  return atoi([self cString]);
}

- (float) floatValue
{
  return (float) atof([self cString]);
}

- (double) doubleValue
{
  return atof([self cString]);
}

- (const char *) cStringValue
{
  return [self cString];
}

- (String *) stringValue
{
  return self;
}

// FOR FILE AND PATH NAMES;

- (IndexRange) fileRange
{
  IndexRange r;
  [self notImplemented:_cmd];
  return r;
}

- (IndexRange) pathRange
{
  IndexRange r;
  [self notImplemented:_cmd];
  return r;
}

- (IndexRange) extensionRange
{
  IndexRange r;
  [self notImplemented:_cmd];
  return r;
}

- (IndexRange) fileWithOutExtentionRange
{
  IndexRange r;
  [self notImplemented:_cmd];
  return r;
}

- (BOOL) isAbsolute
{
  [self notImplemented:_cmd];
  return NO;
}

- (BOOL) isRelative
{
  [self notImplemented:_cmd];
  return NO;
}


@end
