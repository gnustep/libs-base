/* Implementation for Objective-C String object
   Copyright (C) 1993,1994,1995, 1996 Free Software Foundation, Inc.

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

/* Deal with strchr: */
#if STDC_HEADERS || HAVE_STRING_H
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && HAVE_MEMORY_H
#include <memory.h>
#endif /* not STDC_HEADERS and HAVE_MEMORY_H */
#define rindex strrchr
#define bcopy(s, d, n) memcpy ((d), (s), (n))
#define bcmp(s1, s2, n) memcmp ((s1), (s2), (n))
#define bzero(s, n) memset ((s), 0, (n))
#else /* not STDC_HEADERS and not HAVE_STRING_H */
#include <strings.h>
/* memory.h and strings.h conflict on some systems.  */
#endif /* not STDC_HEADERS and not HAVE_STRING_H */


@implementation String

+ (void) initialize
{
  if (self == [String class])
    {
      [self setVersion:0];	/* beta release */
      /* xxx eventually: class_add_behavior_category(NSStringStuff),
         but we'll have to be careful about these methods overriding
	 the ones inherited in NSCString from NSString!  */
    }
}

// INITIALIZING;

/* For now, this is the designated initializer for this class */
- initWithCString: (const char*)aCharPtr range: (IndexRange)aRange
{
  [self subclassResponsibility:_cmd];
  return self;
}

/* xxx This is a second "designated" initializer. */
- initWithCStringNoCopy: (const char*) aCharPtr
	   freeWhenDone: (BOOL) f
{
  [self subclassResponsibility:_cmd];
  return self;
}

/* This override in mutable string classes */
- (void) empty
{
  [self subclassResponsibility:_cmd];
}

- initWithCString: (const char*)aCharPtr length: (unsigned)aLength
{
  return [self initWithCString:aCharPtr 
	       range:((IndexRange){0,aLength})];
}

- initWithCString: (const char*)aCharPtr
{
  return [self initWithCString:aCharPtr
	       range:((IndexRange){0, strlen(aCharPtr)})];
}

#if HAVE_VSPRINTF
- initWithFormat: (id <String>)aFormatString arguments: (va_list)arg
{
  char buf[128];		/* xxx horrible, disgusting, fix this */
  vsprintf(buf, [aFormatString cString], arg);
  return [self initWithCString:buf];
}

- initWithCFormat: (const char*)formatCharPtr arguments: (va_list)arg
{
  char buf[128];		/* xxx horrible, disgusting, fix this */
  vsprintf(buf, formatCharPtr, arg);
  return [self initWithCString:buf];
}
#endif /* HAVE_VSPRINTF */

- initWithFormat: (id <String>)aFormatString, ...
{
  va_list ap;
  va_start(ap, aFormatString);
  [self initWithCFormat:[aFormatString cString] arguments:ap];
  va_end(ap);
  return self;
}

- initWithCFormat: (const char*)formatCharPtr, ...
{
  va_list ap;
  va_start(ap, formatCharPtr);
  [self initWithCFormat:formatCharPtr arguments:ap];
  va_end(ap);
  return self;
}

- init
{
  return [self initWithCString:""];
}

- initWithString: (id <String>)aString range: (IndexRange)aRange
{
  return [self initWithCString:[aString cString] range:aRange];
}

- initWithString: (id <String>)aString length: (unsigned)aLength
{
  return [self initWithCString:[aString cString]];
}

- initWithString: (id <String>)aString
{
  return [self initWithCString:[aString cString]];
}


// GETTING NEW, AUTORELEASED STRING OBJECTS, NO NEED TO RELEASE THESE;

+ stringWithString: (id <String>)aString range: (IndexRange)aRange
{
  return [[[CString alloc] initWithString:aString range:aRange]
	  autorelease];
}

+ stringWithString: (id <String>)aString
{
  return [[[CString alloc] initWithString:aString]
	  autorelease];
}

+ stringWithFormat: (id <String>)aFormatString, ...
{
  va_list ap;
  id ret;
  
  va_start(ap, aFormatString);
  ret = [[self stringWithFormat:aFormatString arguments:ap]
	 autorelease];
  va_end(ap);
  return ret;
}

+ stringWithFormat: (id <String>)aFormatString arguments: (va_list)arg
{
  return [[[CString alloc] initWithFormat:aFormatString arguments:arg]
	  autorelease];
}

+ stringWithCString: (const char*)cp range: (IndexRange)r
{
  return [[[CString alloc] initWithCString:cp range:r]
	  autorelease];
}

+ stringWithCString: (const char*)aCharPtr
{
  return [[[CString alloc] initWithCString:aCharPtr]
	  autorelease];
}

+ stringWithCStringNoCopy: (const char*)aCharPtr
	     freeWhenDone: (BOOL) f
{
  return [[[CString alloc] 
	    initWithCStringNoCopy:aCharPtr
	    freeWhenDone: f]
	  autorelease];
}

+ stringWithCStringNoCopy: (const char*)aCharPtr
{
  return [self stringWithCStringNoCopy:aCharPtr
	       freeWhenDone: YES];
}

- stringByAppendingFormat: (id <String>)aString, ...
{
  [self notImplemented:_cmd];
  return nil;
}

- stringByAppendingFormat: (id <String>)aString arguments: (va_list)arg
{
  [self notImplemented:_cmd];
  return nil;
}

- stringByPrependingFormat: (id <String>)aString, ...
{
  [self notImplemented:_cmd];
  return nil;
}

- stringByPrependingFormat: (id <String>)aString arguments: (va_list)arg
{
  [self notImplemented:_cmd];
  return nil;
}

- stringByAppendingString: (id <String>)aString
{
  [self notImplemented:_cmd];
  return nil;
}

- stringByPrependingString: (id <String>)aString
{
  [self notImplemented:_cmd];
  return nil;
}


// COPYING;

/* This is the designated copier */
- (char *) cStringCopyRange: (IndexRange)aRange;
{
  [self subclassResponsibility:_cmd];
  return "";
}

- (char *) cStringCopyLength: (unsigned)aLength
{
  // xxx need to check aLength against _count;
  return [self cStringCopyRange:((IndexRange){0,aLength})];
}

/* xxx No longer necessary because -cString does the same thing? */
- (char *) cStringCopy
{
  return [self cStringCopyRange:((IndexRange){0, [self count]})];
}

- copyWithZone: (NSZone*)z
{
  return [[[self class] allocWithZone:z] initWithString:(NSString*)self];
}

- mutableCopyWithZone: (NSZone*)z
{
  return [[MutableCString allocWithZone:z] initWithString:(NSString*)self];
}

// TESTING;

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

- (unsigned) indexOfString: (id <String>)aString
{
  const char *s = [self cString];
  return (strstr(s, [aString cString]) - s);
}

- (char) charAtIndex: (unsigned)index
{
  [self subclassResponsibility:_cmd];
  return ' ';
}

- (const char *) cString
{
  [self subclassResponsibility:_cmd];
  return NULL;
}

- (const char *) cStringNoCopy
{
  [self subclassResponsibility:_cmd];
  return NULL;
}

- (unsigned) cStringLength
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (void) getCString: (char*)buffer
{
  strcpy(buffer, [self cString]);
}

- (void) getCString: (char*)buffer range: (IndexRange)aRange
{
  memcpy(buffer, ([self cString] + aRange.location), aRange.length);
}

- (IndexRange) range
{
  return (IndexRange){0, [self count]};
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
