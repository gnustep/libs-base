/* Implementation of GNUSTEP string class
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: January 1995
   
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

/* Caveats:

   Many method unimplemented.

   Only supports C Strings.  Some implementations will need to be 
   changed when we get other string backing classes.

   Does not support all justification directives for `%@' in format strings 
   on non-GNU-libc systems.

*/

#include <gnustep/base/preface.h>
#include <gnustep/base/Coding.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <gnustep/base/String.h>
#include <gnustep/base/behavior.h>
#include <limits.h>
#include <string.h>		// for strstr()

@implementation NSString

/* For unichar strings.  (Not implemented---using cStrings) */
static Class NSString_concrete_class;
static Class NSMutableString_concrete_class;

/* For CString's */
static Class NSString_c_concrete_class;
static Class NSMutableString_c_concrete_class;

+ (void) _setConcreteClass: (Class)c
{
  NSString_concrete_class = c;
}

+ (void) _setConcreteCClass: (Class)c
{
  NSString_c_concrete_class = c;
}

+ (void) _setMutableConcreteClass: (Class)c
{
  NSMutableString_concrete_class = c;
}

+ (void) _setMutableConcreteCClass: (Class)c
{
  NSMutableString_c_concrete_class = c;
}

+ (Class) _concreteClass
{
  return NSString_concrete_class;
}

+ (Class) _concreteCClass
{
  return NSString_c_concrete_class;
}

+ (Class) _mutableConcreteClass
{
  return NSMutableString_concrete_class;
}

+ (Class) _mutableConcreteCClass
{
  return NSMutableString_c_concrete_class;
}

#if HAVE_REGISTER_PRINTF_FUNCTION
#include <stdio.h>
#include <printf.h>
#include <stdarg.h>

/* <sattler@volker.cs.Uni-Magdeburg.DE>, with libc-5.3.9 thinks this 
   flag PRINTF_ATSIGN_VA_LIST should be 0, but for me, with libc-5.0.9, 
   it crashes.  -mccallum */ 
#define PRINTF_ATSIGN_VA_LIST			\
       (defined(_LINUX_C_LIB_VERSION_MINOR)	\
	&& _LINUX_C_LIB_VERSION_MAJOR <= 5	\
	&& _LINUX_C_LIB_VERSION_MINOR < 2)

#if ! PRINTF_ATSIGN_VA_LIST
static int
arginfo_func (const struct printf_info *info,
            size_t n,
            int *argtypes) {
  *argtypes = PA_POINTER;
  return 1;
}
#endif /* !PRINTF_ATSIGN_VA_LIST */

static int
handle_printf_atsign (FILE *stream, 
		      const struct printf_info *info,
#if PRINTF_ATSIGN_VA_LIST
		      va_list *ap_pointer)
#else
                      const void **const args)
#endif
{
#if ! PRINTF_ATSIGN_VA_LIST
  const void *ptr = *args;
#endif
  id string_object;
  int len;

  /* xxx This implementation may not pay pay attention to as much 
     of printf_info as it should. */

#if PRINTF_ATSIGN_VA_LIST
  string_object = va_arg (*ap_pointer, id);
#else
  string_object = *((id*) ptr);
#endif
  len = fprintf(stream, "%*s",
		(info->left ? - info->width : info->width),
		[string_object cStringNoCopy]);
  return len;
}
#endif /* HAVE_REGISTER_PRINTF_FUNCTION */

+ (void) initialize
{
  static int done = 0;
  if (!done)
    {
      done = 1;
      class_add_behavior([NSString class], [String class]);
      NSString_concrete_class = [NSGCString class];
      NSString_c_concrete_class = [NSGCString class];
      NSMutableString_concrete_class = [NSGMutableCString class];
      NSMutableString_c_concrete_class = [NSGMutableCString class];

#if HAVE_REGISTER_PRINTF_FUNCTION
      if (register_printf_function ('@', 
				    (printf_function)handle_printf_atsign, 
#if PRINTF_ATSIGN_VA_LIST
				    0))
#else
	                           (printf_arginfo_function)arginfo_func))
#endif
	[NSException raise: NSGenericException
		     format: @"register printf handling of %%@ failed"];
#endif /* HAVE_REGISTER_PRINTF_FUNCTION */
    }
}

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _concreteClass], 0, z);
}

// Creating Temporary Strings

+ (NSString*) localizedStringWithFormat: (NSString*) format, ...
{
  [self notImplemented:_cmd];
  return self;
}

+ (NSString*) stringWithCString: (const char*) byteString
{
  return [[[self alloc] initWithCString:byteString]
	  autorelease];
}

+ (NSString*) stringWithCString: (const char*)byteString
   length: (unsigned int)length
{
  return [[[self alloc]
	   initWithCString:byteString length:length]
	  autorelease];
}

+ (NSString*) stringWithCharacters: (const unichar*)chars
   length: (unsigned int)length
{
  [self notImplemented:_cmd];
  return self;
}

+ (NSString*) stringWithFormat: (NSString*)format,...
{
  va_list ap;
  id ret;

  va_start(ap, format);
  ret = [[[self alloc] initWithFormat:format arguments:ap]
	 autorelease];
  va_end(ap);
  return ret;
}

+ (NSString*) stringWithFormat: (NSString*)format
   arguments: (va_list)argList
{
  return [[[self alloc]
	   initWithFormat:format arguments:argList]
	  autorelease];
}

// Initializing Newly Allocated Strings

- (id) init
{
  return [self initWithCString:""];
}

- (id) initWithCString: (const char*)byteString
{
  return [self initWithCString:byteString 
	       length:(byteString ? strlen(byteString) : 0)];
}

- (id) initWithCString: (const char*)byteString
   length: (unsigned int)length
{
  char *s;
  OBJC_MALLOC(s, char, length+1);
  if (byteString)
    memcpy(s, byteString, length);
  s[length] = '\0';
  return [self initWithCStringNoCopy:s length:length freeWhenDone:YES];
}

/* This is the designated initializer for CStrings. */
- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  [self subclassResponsibility:_cmd];
  return self;
}

- (id) initWithCharacters: (const unichar*)chars
   length: (unsigned int)length
{
  [self notImplemented:_cmd];
  return self;
}

/* This is the designated initializer for unichar Strings. */
- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  [self subclassResponsibility:_cmd];
  return self;
}

- (id) initWithContentsOfFile: (NSString*)path
{
  [self notImplemented:_cmd];
  return self;
}

- (id) initWithData: (NSData*)data
   encoding: (NSStringEncoding)encoding
{
  [self notImplemented:_cmd];
  return self;
}

- (id) initWithFormat: (NSString*)format,...
{
  va_list ap;
  va_start(ap, format);
  self = [self initWithFormat:format arguments:ap];
  va_end(ap);
  return self;
}

/* xxx Change this when we have non-CString classes */
- (id) initWithFormat: (NSString*)format
   arguments: (va_list)arg_list
{
#if HAVE_VSPRINTF
  const char *format_cp = [format cStringNoCopy];
  int format_len = strlen (format_cp);
  /* xxx horrible disgusting BUFFER_EXTRA arbitrary limit; fix this! */
  #define BUFFER_EXTRA 1024
  char buf[format_len + BUFFER_EXTRA];
  int printed_len = 0;

#if ! HAVE_REGISTER_PRINTF_FUNCTION
  /* If the available libc doesn't have `register_printf_function()', then
     the `%@' printf directive isn't available with printf() and friends.
     Here we make a feable attempt to handle it. */
  {
    /* We need a local copy since we change it.  (Changing and undoing
       the change doesn't work because some format strings are constant
       strings, placed in a non-writable section of the executable, and 
       writing to them will cause a segfault.) */ 
    char format_cp_copy[format_len+1];
    char *atsign_pos;
    char *format_to_go = format_cp_copy;
    strcpy (format_cp_copy, format_cp);
    /* Loop once for each `%@' in the format string. */
    while ((atsign_pos = strstr (format_to_go, "%@")))
      {
	const char *cstring;
	/* If there is a "%%@", then do the right thing: print it literally. */
	if ((*(atsign_pos-1) == '%')
	    && atsign_pos != format_cp_copy)
	  continue;
	/* Temporarily terminate the string before the `%@'. */
	*atsign_pos = '\0';
	/* Print the part before the '%@' */
	printed_len = vsprintf (buf, format_cp_copy, arg_list);
	/* Get a C-string (char*) from the String object, and print it. */
	cstring = [(id) va_arg (arg_list, id) cStringNoCopy];
	strcat (buf+printed_len, cstring);
	printed_len += strlen (cstring);
	/* Put back the `%' we removed when we terminated mid-string. */
	*atsign_pos = '%';
	/* Skip over this `%@', and look for another one. */
	format_to_go = atsign_pos + 2;
      }
    /* Print the rest of the string after the last `%@'. */
    printed_len += vsprintf (buf+printed_len, format_to_go, arg_list);
  }
#else
  /* The available libc has `register_printf_function()', so the `%@' 
     printf directive is handled by printf and friends. */
  printed_len = vsprintf (buf, format_cp, arg_list);
#endif /* !HAVE_REGISTER_PRINTF_FUNCTION */

  /* Raise an exception if we overran our buffer. */
  NSParameterAssert (printed_len < format_len + BUFFER_EXTRA - 1);
  return [self initWithCString:buf];
#else /* HAVE_VSPRINTF */
  [self notImplemented: _cmd];
  return self;
#endif
}

- (id) initWithFormat: (NSString*)format
   locale: (NSDictionary*)dictionary
{
  [self notImplemented:_cmd];
  return self;
}

- (id) initWithFormat: (NSString*)format
   locale: (NSDictionary*)dictionary
   arguments: (va_list)argList
{
  [self notImplemented:_cmd];
  return self;
}

/* xxx Change this when we have non-CString classes */
- (id) initWithString: (NSString*)string
{
  return [self initWithCString:[string _cStringContents]];
}


// Getting a String's Length

/* xxx Change this when we have non-CString classes */
- (unsigned int) length
{
  return [self cStringLength];
}


// Accessing Characters

/* xxx Change this when we have non-CString classes */
- (unichar) characterAtIndex: (unsigned int)index
{
  /* xxx raise NSException instead of assert. */
  assert(index < [self cStringLength]);
  return (unichar) [self _cStringContents][index];
}

/* Inefficient.  Should be overridden */
- (void) getCharacters: (unichar*)buffer
{
  [self getCharacters:buffer range:((NSRange){0,[self length]})];
  return;
}

/* Inefficient.  Should be overridden */
- (void) getCharacters: (unichar*)buffer
   range: (NSRange)aRange
{
  int i;
  for (i = 0; i < aRange.length; i++)
    {
      buffer[i] = [self characterAtIndex: aRange.location+i];
    }
}


// Combining Strings

- (NSString*) stringByAppendingFormat: (NSString*)format,...
{
  va_list ap;
  id ret;
  va_start(ap, format);
  ret = [self stringByAppendingString:
	      [NSString stringWithFormat:format arguments:ap]];
  va_end(ap);
  return ret;
}

/* xxx Change this when we have non-CString classes */
- (NSString*) stringByAppendingString: (NSString*)aString
{
  unsigned len = [self cStringLength];
  char *s = alloca(len + [aString cStringLength] + 1);
  s = strcpy(s, [self _cStringContents]);
  strcpy(s + len, [aString _cStringContents]);
  return [NSString stringWithCString:s];
}


// Dividing Strings into Substrings

- (NSArray*) componentsSeparatedByString: (NSString*)separator
{
  NSRange search;
  NSRange found;
  NSMutableArray *array = [NSMutableArray array];

  search = NSMakeRange (0, [self length]);
  found = [self rangeOfString: separator];
  while (found.length)
    {
      NSRange current;
      current = NSMakeRange (search.location,
			     found.location - search.location);
      [array addObject: [self substringFromRange: current]];
      search = NSMakeRange (found.location+1,
			    search.length - found.location);
      found = [self rangeOfString: separator 
		    options: 0
		    range: search];
    }

  // FIXME: Need to make mutable array into non-mutable array?
  return array;
}

- (NSString*) substringFromIndex: (unsigned int)index
{
  return [self substringFromRange:((NSRange){index, [self length]-index})];
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  unichar buffer[aRange.length];
  int count = [self length];

  if (aRange.location > count)
    [NSException raise: NSRangeException format: @"Invalid location."];
  if (aRange.length > (count - aRange.location))
    [NSException raise: NSRangeException format: @"Invalid location+length."];
  [self getCharacters: buffer range: aRange];
  return [[self class] stringWithCharacters: buffer length: aRange.length];
}

- (NSString*) substringToIndex: (unsigned int)index
{
  return [self substringFromRange:((NSRange){0,index+1})];;
}


// Finding Ranges of Characters and Substrings

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
{
  NSRange all = NSMakeRange(0, [self length]);
  return [self rangeOfCharacterFromSet:aSet
		options:0
		range:all];
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
   options: (unsigned int)mask
{
  NSRange all = NSMakeRange(0, [self length]);
  return [self rangeOfCharacterFromSet:aSet
		options:mask
		range:all];
}

/* FIXME:  how do you do a case insensitive search?  what's an anchored
   search? what's a literal search? */
- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
    options: (unsigned int)mask
    range: (NSRange)aRange
{
  int i, start, stop, step;
  NSRange range;

  /* xxx check to make sure aRange is within self; raise NSStringBoundsError */
  assert(NSMaxRange(aRange) < [self length]);

  if ((mask & NSBackwardsSearch) == NSBackwardsSearch)
    {
      start = NSMaxRange(aRange); stop = aRange.location; step = -1;
    }
  else
    {
      start = aRange.location; stop = NSMaxRange(aRange); step = 1;
    }
  range.length = 0;
  for (i = start; i < stop; i+=step)
    {
      unichar letter = [self characterAtIndex:i];
      if ([aSet characterIsMember:letter])
	{
	  range = NSMakeRange(i, 1);
	  break;
	}
    }

  return range;
}

- (NSRange) rangeOfString: (NSString*)string
{
  NSRange all = NSMakeRange(0, [self length]);
  return [self rangeOfString:string
		options:0
		range:all];
}

- (NSRange) rangeOfString: (NSString*)string
   options: (unsigned int)mask
{
  NSRange all = NSMakeRange(0, [self length]);
  return [self rangeOfString:string
		options:mask
		range:all];
}

- (NSRange) rangeOfString:(NSString *) aString
   options:(unsigned int) mask
   range:(NSRange) aRange
{
  int stepDirection;
  unsigned int myIndex, myLength, myEndIndex;
  unsigned int strLength;
  unichar strFirstCharacter;

  /* Check that the search range is reasonable */
  myLength = [self length];
  if (aRange.location > myLength)
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > (myLength - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];

  /* Ensure the string can be found */
  strLength = [aString length];
  if (strLength > aRange.length)
    return (NSRange){0, 0};

  /* Decide where to start and end the search */
  if (mask & NSBackwardsSearch)
    {
      stepDirection = -1;
      myIndex = aRange.location + aRange.length - strLength;
      myEndIndex = aRange.location;
    }
  else
    {
      stepDirection = 1;
      myIndex = aRange.location;
      myEndIndex = aRange.location + aRange.length - strLength;
    }
  /* FIXME: I am guessing that this is what NSAnchoredSearch does. */
  if (mask & NSAnchoredSearch)
    myEndIndex = myIndex;

  /* Start searching.  For efficiency there are separate loops for
     case-sensitive and case-insensitive searches. */
  strFirstCharacter = [aString characterAtIndex:0];
  if (mask & NSCaseInsensitiveSearch)
    {
      for (;;)
      {
        unsigned int i = 1;
        unichar myCharacter = [self characterAtIndex:myIndex];
        unichar strCharacter = strFirstCharacter;

        for (;;)
          {
            /* FIXME: I have no idea how to make case-insensitive
	       comparisons work over the full range of Unicode characters. */
            if ((myCharacter != strCharacter) &&
                (!isascii (myCharacter)
                 || !isalpha (myCharacter)
                 || !isascii (strCharacter)
                 || !isalpha (strCharacter)
                 || (tolower (myCharacter) != tolower (strCharacter))))
              break;
            if (i == strLength)
              return (NSRange){myIndex, strLength};
            myCharacter = [self characterAtIndex:myIndex + i];
            strCharacter = [aString characterAtIndex:i];
            i++;
          }
        if (myIndex == myEndIndex)
          break;
        myIndex += stepDirection;
      }
    }
  else
    {
      for (;;)
      {
        unsigned int i = 1;
        unichar myCharacter = [self characterAtIndex:myIndex];
        unichar strCharacter = strFirstCharacter;

        for (;;)
          {
            if (myCharacter != strCharacter)
              break;
            if (i == strLength)
              return (NSRange){myIndex, strLength};
            myCharacter = [self characterAtIndex:myIndex + i];
            strCharacter = [aString characterAtIndex:i];
            i++;
          }
        if (myIndex == myEndIndex)
          break;
        myIndex += stepDirection;
      }
    }
  return (NSRange){0, 0};
}

// Determining Composed Character Sequences

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned int)anIndex
{
  [self notImplemented:_cmd];
  return ((NSRange){0,0});
}


// Identifying and Comparing Strings

- (NSComparisonResult) caseInsensitiveCompare: (NSString*)aString
{
  return [self compare:aString options:NSCaseInsensitiveSearch 
	       range:((NSRange){0, [self length]})];
}

- (NSComparisonResult) compare: (NSString*)aString
{
  return [self compare:aString options:0];
}

- (NSComparisonResult) compare: (NSString*)aString	
   options: (unsigned int)mask
{
  return [self compare:aString options:mask 
	       range:((NSRange){0, MAX([self length], [aString length])})];
}

- (NSComparisonResult) compare: (NSString*)aString
   options: (unsigned int)mask
   range: (NSRange)aRange
{
  /* xxx ignores NSAnchoredSearch in mask.  Fix this. */
  /* xxx only handles C-string encoding */

  int i, start, end, increment;
  const char *s1 = [self _cStringContents];
  const char *s2 = [aString _cStringContents];

  if (mask & NSBackwardsSearch) 
    {
      start = aRange.location + aRange.length;
      end = aRange.location;
      increment = -1;
    }
  else
    {
      start = aRange.location;
      end = aRange.location + aRange.length;
      increment = 1;
    }

  if (mask & NSCaseInsensitiveSearch)
    {
      for (i = start; i < end; i += increment)
	{
	  int c1 = tolower(s1[i]);
	  int c2 = tolower(s2[i]);
	  if (c1 < c2) return NSOrderedAscending;
	  if (c1 > c2) return NSOrderedDescending;
	}
    }
  else
    {
      for (i = start; i < end; i += increment)
	{
	  if (s1[i] < s2[i]) return NSOrderedAscending;
	  if (s1[i] > s2[i]) return NSOrderedDescending;
	}
    }
  return NSOrderedSame;
}

- (BOOL) hasPrefix: (NSString*)aString
{
  NSRange range;
  range = [self rangeOfString:aString];
  return (range.location == 0) ? YES : NO;
}

- (BOOL) hasSuffix: (NSString*)aString
{
  NSRange range;
  range = [self rangeOfString:aString options:NSBackwardsSearch];
  return (range.location == ([self length] - [aString length])) ? YES : NO;
}

- (unsigned int) hash
{
  unsigned ret = 0;
  unsigned ctr = 0;
  unsigned char_count = 0;
  const char *s = [self _cStringContents];

  while (*s && char_count++ < NSHashStringLength)
    {
      ret ^= *s++ << ctr;
      ctr = (ctr + 1) % sizeof (void*);
    }
  return ret;
}

- (BOOL) isEqual: (id)anObject
{
  if ([anObject isKindOf:[NSString class]])
    return [self isEqualToString:anObject];
  return NO;
}

- (BOOL) isEqualToString: (NSString*)aString
{
  return ! strcmp([self _cStringContents], [aString _cStringContents]);
}


// Storing the String

- (NSString*) description
{
  const char *src = [self cString];
  char *dest;
  char *src_ptr,*dest_ptr;
  int len,quote;
  unsigned char ch;

  /* xxx Really should make this work with unichars. */

#define inrange(ch,min,max) ((ch)>=(min) && (ch)<=(max))
#define noquote(ch) (inrange(ch,'a','z') || inrange(ch,'A','Z') || inrange(ch,'0','9') || ((ch)=='_') || ((ch)=='.') || ((ch)=='$'))
#define charesc(ch) (inrange(ch,07,014) || ((ch)=='\"') || ((ch)=='\\'))
#define numesc(ch) (((ch)<=06) || inrange(ch,015,037) || ((ch)>0176))

  for (src_ptr = (char*)src, len=0,quote=0;
       (ch=*src_ptr);
       src_ptr++, len++)
    {
      if (!noquote(ch))
	{
	  quote=1;
	  if (charesc(ch))
	    len++;
	  else if (numesc(ch))
	    len+=3;
	}
    }
  if (quote)
    len+=2;

  dest = (char*) malloc (len+1);

  src_ptr = (char*) src;
  dest_ptr = dest;
  if (quote)
    *(dest_ptr++) = '\"';
  for (; (ch=*src_ptr); src_ptr++,dest_ptr++)
    {
      if (charesc(ch))
	{
	  *(dest_ptr++) = '\\';
	  switch (ch)
	    {
	    case '\a': *dest_ptr = 'a'; break;
	    case '\b': *dest_ptr = 'b'; break;
	    case '\t': *dest_ptr = 't'; break;
	    case '\n': *dest_ptr = 'n'; break;
	    case '\v': *dest_ptr = 'v'; break;
	    case '\f': *dest_ptr = 'f'; break;
	    default: *dest_ptr = ch;  /* " or \ */
	    }
	}
      else if (numesc(ch))
	{
	  *(dest_ptr++) = '\\';
	  *(dest_ptr++) = '0' + ((ch>>6)&07);
	  *(dest_ptr++) = '0' + ((ch>>3)&07);
	  *dest_ptr = '0' + (ch&07);
	}
      else
	{  /* copy literally */
	  *dest_ptr = ch;
	}
    }
  if (quote)
    *(dest_ptr++) = '\"';
  *dest_ptr = '\0';

  return [NSString stringWithCString:dest];
}

- (BOOL) writeToFile: (NSString*)filename
   atomically: (BOOL)useAuxiliaryFile
{
  [self notImplemented:_cmd];
  return NO;
}


// Getting a Shared Prefix

- (NSString*) commonPrefixWithString: (NSString*)aString
   options: (unsigned int)mask
{
  [self notImplemented:_cmd];
  return self;
}


// Changing Case

- (NSString*) capitalizedString
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) lowercaseString
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) uppercaseString
{
  [self notImplemented:_cmd];
  return self;
}


// Getting C Strings

- (const char*) cString
{
  [self subclassResponsibility:_cmd];
  return NULL;
}

- (unsigned int) cStringLength
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (void) getCString: (char*)buffer
{
  [self getCString:buffer maxLength:NSMaximumStringLength
	range:((NSRange){0, [self length]})
	remainingRange:NULL];
}

- (void) getCString: (char*)buffer
    maxLength: (unsigned int)maxLength
{
  [self getCString:buffer maxLength:maxLength 
	range:((NSRange){0, [self length]})
	remainingRange:NULL];
}

- (void) getCString: (char*)buffer
   maxLength: (unsigned int)maxLength
   range: (NSRange)aRange
   remainingRange: (NSRange*)leftoverRange
{
  int len;

  /* xxx check to make sure aRange is within self; raise NSStringBoundsError */
  assert(aRange.location + aRange.length < [self cStringLength]);
  if (maxLength < aRange.length)
    {
      len = maxLength;
      if (leftoverRange)
	{
	  leftoverRange->location = 0;
	  leftoverRange->length = 0;
	}
    }
  else
    {
      len = aRange.length;
      if (leftoverRange)
	{
	  leftoverRange->location = aRange.location + maxLength;
	  leftoverRange->length = aRange.length - maxLength;
	}
    }
  memcpy(buffer, [self _cStringContents] + aRange.location, len);
}


// Getting Numeric Values

- (double) doubleValue
{
  return atof([self _cStringContents]);
}

- (float) floatValue
{
  return (float) atof([self _cStringContents]);
}

- (int) intValue
{
  return atoi([self _cStringContents]);
}


// Working With Encodings

+ (NSStringEncoding) defaultCStringEncoding
{
  [self notImplemented:_cmd];
  return 0;
}

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)encoding
{
  [self notImplemented:_cmd];
  return NO;
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
   allowLossyConversion: (BOOL)flag
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSStringEncoding) fastestEncoding
{
  [self notImplemented:_cmd];
  return 0;
}

- (NSStringEncoding) smallestEncoding
{
  [self notImplemented:_cmd];
  return 0;
}


// Converting String Contents into a Property List

- (id)propertyList
{
  id obj;
  void *bufstate;
  bufstate = (void *)pl_scan_string([self cString]);
  obj = (id)plparse();
  pl_delete_buffer(bufstate);
  return obj;
}

- (NSDictionary*) propertyListFromStringsFileFormat
{
  [self notImplemented:_cmd];
  return nil;
}


// Manipulating File System Paths

- (unsigned int) completePathIntoString: (NSString**)outputName
   caseSensitive: (BOOL)flag
   matchesIntoArray: (NSArray**)outputArray
   filterTypes: (NSArray*)filterTypes
{
  [self notImplemented:_cmd];
  return 0;
}

/* Returns a new string containing the last path component of the receiver. The
   path component is any substring after the last '/' character. If the last
   character is a '/', then the substring before the last '/', but after the
   second-to-last '/' is returned. Returns the receiver if there are no '/'
   characters. Returns the null string if the receiver only contains a '/'
   character. */
- (NSString*) lastPathComponent
{
  NSRange range;
  NSString *substring = nil;

  range = [self rangeOfString:@"/" options:NSBackwardsSearch];
  if (range.length == 0)
      substring = self;
  else if (range.location == [self length] - 1)
    {
      if (range.location == 0)
	  substring = [NSString new];
      else
	  substring = [[self substringToIndex:range.location-1] 
				lastPathComponent];
    }
  else
      substring = [self substringFromIndex:range.location+1];

  return substring;
}

/* Returns a new string containing the path extension of the receiver. The
   path extension is a suffix on the last path component which starts with
   a '.' (for example .tiff is the pathExtension for /foo/bar.tiff). Returns
   a null string if no such extension exists. */
- (NSString*) pathExtension
{
  NSRange range;
  NSString *substring = nil;

  range = [self rangeOfString:@"." options:NSBackwardsSearch];
  if (range.length == 0 
	|| range.location 
	    < ([self rangeOfString:@"/" options:NSBackwardsSearch]).location)
      substring =  [NSString new];
  else
      substring = [self substringFromIndex:range.location+1];
  return substring;
}

- (NSString*) stringByAbbreviatingWithTildeInPath
{
  [self notImplemented:_cmd];
  return self;
}

/* Returns a new string with the path component given in aString
   appended to the receiver.  Assumes that aString is NOT prefixed by
   a '/'.  Checks the receiver to see if the last letter is a '/', if it
   is not, a '/' is appended before appending aString */
- (NSString*) stringByAppendingPathComponent: (NSString*)aString
{
  NSRange  range;
  NSString *newstring;

  range = [self rangeOfString:@"/" options:NSBackwardsSearch];
  if (range.length != 0 && range.location != [self length] - 1)
      newstring = [self stringByAppendingString:@"/"];
  else
      newstring = self;

  return [newstring stringByAppendingString:aString];
}

/* Returns a new string with the path extension given in aString
   appended to the receiver.  Assumes that aString is NOT prefixed by
   a '.'.  Checks the receiver to see if the last letter is a '.', if it
   is not, a '.' is appended before appending aString */
- (NSString*) stringByAppendingPathExtension: (NSString*)aString
{
  NSRange  range;
  NSString *newstring;

  range = [aString rangeOfString:@"." options:NSBackwardsSearch];
  if (range.length != 0 && range.location != [self length] - 1)
      newstring = [self stringByAppendingString:@"."];
  else
      newstring = self;

  return [newstring stringByAppendingString:aString];
}

/* Returns a new string with the last path component removed from the
  receiver.  See lastPathComponent for a definition of a path component */
- (NSString*) stringByDeletingLastPathComponent
{
  NSRange range;
  NSString *substring;

  range = [self rangeOfString:[self lastPathComponent] 
			options:NSBackwardsSearch];
  if (range.length != 0)
      substring = [self substringToIndex:range.location-2];
  else
      substring = self;
  return substring;
}

/* Returns a new string with the path extension removed from the receiver.
   See pathExtension for a definition of the path extension */
- (NSString*) stringByDeletingPathExtension
{
  NSRange range;
  NSString *substring;

  range = [self rangeOfString:[self pathExtension] options:NSBackwardsSearch];
  if (range.length != 0)
      substring = [self substringToIndex:range.location-2];
  else
      substring = self;
  return substring;
}

- (NSString*) stringByExpandingTildeInPath
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByResolvingSymlinksInPath
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByStandardizingPath
{
  [self notImplemented:_cmd];
  return self;
}

/* NSCopying Protocol */

- copyWithZone: (NSZone*)zone
{
  return [[[self class] allocWithZone:zone] initWithString:self];
}

- mutableCopyWithZone: (NSZone*)zone
{
  return [[[[self class] _mutableConcreteClass] allocWithZone:zone]
	  initWithString:self];
}

/* NSCoding Protocol */

- (void) encodeWithCoder: anEncoder
{
  [super encodeWithCoder:anEncoder];
}

- initWithCoder: aDecoder
{
  return [super initWithCoder:aDecoder];
}

@end

@implementation NSString (NSCStringAccess)
- (const char *) _cStringContents
{
  [self subclassResponsibility:_cmd];
  return NULL;
}
@end

/* We don't actually implement (GNU) Category, in order to avoid warning
   about "unimplemented methods"; they come from the behavior. */
@implementation NSString (GNUCollection)

- objectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, [self cStringLength]);
  return [NSNumber numberWithChar: [self _cStringContents][index]];
}

/* The rest are handled by the class_add_behavior() call in +initialize. */

@end

@implementation NSMutableString

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _mutableConcreteClass], 0, z);
}

/* xxx This method may be removed in future. */
- (void) setCString: (const char *)byteString length: (unsigned)length
{
  [self subclassResponsibility:_cmd];
}


// Initializing Newly Allocated Strings

- initWithCapacity:(unsigned)capacity
{
  [self subclassResponsibility:_cmd];
  return self;
}


// Creating Temporary Strings

+ (NSMutableString*) stringWithCapacity:(unsigned)capacity
{
  return [[[self alloc] initWithCapacity:capacity] 
	  autorelease];
}

/* Inefficient. */
+ (NSString*) stringWithCharacters: (const unichar*)characters
   length: (unsigned)length
{
  id n;
  n = [self stringWithCapacity:length];
  [n setString: [NSString stringWithCharacters:characters length:length]];
  return n;
}

+ (NSString*) stringWithCString: (const char*)byteString
{
  return [self stringWithCString:byteString length:strlen(byteString)];
}

+ (NSString*) stringWithCString: (const char*)bytes
   length:(unsigned)length
{
  id n = [[self alloc] initWithCapacity:length];
  [n setCString:bytes length:length];
  return n;
}

/* xxx Change this when we have non-CString classes */
+ (NSString*) stringWithFormat: (NSString*)format, ...
{
  va_list ap;
  va_start(ap, format);
  self = [super stringWithFormat:format arguments:ap];
  va_end(ap);
  return self;
}


// Modify A String

/* Inefficient. */
- (void) appendString: (NSString*)aString
{
  id tmp = [self stringByAppendingString:aString];
  [self setString:tmp];
}

/* Inefficient. */
- (void) appendFormat: (NSString*)format, ...
{
  va_list ap;
  id tmp;
  va_start(ap, format);
  tmp = [NSString stringWithFormat:format arguments:ap];
  va_end(ap);
  [self appendString:tmp];
}

- (void) deleteCharactersInRange: (NSRange)range
{
  [self subclassResponsibility:_cmd];
}

- (void) insertString: (NSString*)aString atIndex:(unsigned)loc
{
  [self subclassResponsibility:_cmd];
}

/* Inefficient. */
- (void) replaceCharactersInRange: (NSRange)range 
   withString: (NSString*)aString
{
  [self deleteCharactersInRange:range];
  [self insertString:aString atIndex:range.location];
}

/* xxx Change this when we have non-CString classes */
- (void) setString: (NSString*)aString
{
  const char *s = [aString _cStringContents];
  [self setCString:s length:strlen(s)];
}


@end


@implementation NXConstantString

- (void)dealloc
{
}

- (const char*) cString
{
  return _contents_chars;
}

- retain
{
  return self;
}

- (oneway void) release
{
  return;
}

- autorelease
{
  return self;
}

- copyWithZone: (NSZone*)z
{
  return self;
}

@end
