/* Implementation of GNUSTEP string class
   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: January 1995

   Unicode implementation by Stevo Crvenkovski <stevo@btinternet.com>
   Date: February 1997

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

   Some implementations will need to be changed.
   Does not support all justification directives for `%@' in format strings 
   on non-GNU-libc systems.
*/

/* Initial implementation of Unicode. Version 0.0.0 :)
   Locales not yet supported.
   Limited choice of default encodings.
*/

#include <config.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/Coding.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSUserDefaults.h>
#include <gnustep/base/IndexedCollection.h>
#include <Foundation/NSData.h>
#include <Foundation/NSBundle.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <limits.h>
#include <string.h>		// for strstr()
#include <sys/stat.h>
#include <unistd.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdio.h>

#include <gnustep/base/MallocAddress.h>
#include <gnustep/base/behavior.h>

#include <gnustep/base/NSGSequence.h>
#include <gnustep/base/Unicode.h>
#include <gnustep/base/GetDefEncoding.h>

// Uncomment when implemented
    static NSStringEncoding _availableEncodings[] = {
 NSASCIIStringEncoding,
        NSNEXTSTEPStringEncoding,
//        NSJapaneseEUCStringEncoding,
//        NSUTF8StringEncoding,
        NSISOLatin1StringEncoding,
//        NSSymbolStringEncoding,
//        NSNonLossyASCIIStringEncoding,
//        NSShiftJISStringEncoding,
//        NSISOLatin2StringEncoding,
        NSUnicodeStringEncoding,
//        NSWindowsCP1251StringEncoding,
//        NSWindowsCP1252StringEncoding,
//        NSWindowsCP1253StringEncoding,
//        NSWindowsCP1254StringEncoding,
//        NSWindowsCP1250StringEncoding,
//        NSISO2022JPStringEncoding,
// GNUstep additions
        NSCyrillicStringEncoding,
 0
    };


#if defined(__WIN32__) || defined(_WIN32)

#define PATH_COMPONENT @"\\"
#define PATH_COMPONENT_LEN 1
#define PATH_COMPONENT2 @"/"
#define PATH_COMPONENT_LEN2 1

#else

#define PATH_COMPONENT @"/"
#define PATH_COMPONENT_LEN 1

#endif /* Path components */

@implementation NSString

/* For unichar strings. */
static Class NSString_concrete_class;
static Class NSMutableString_concrete_class;

/* For CString's */
static Class NSString_c_concrete_class;
static Class NSMutableString_c_concrete_class;

static NSStringEncoding _DefaultStringEncoding;


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
   it crashes.  -mccallum

   Apparently GNU libc 2.xx needs this to be 0 also, along with Linux
   libc versions 5.2.xx and higher (including libc6, which is just GNU
   libc). -chung */
#define PRINTF_ATSIGN_VA_LIST			\
       (defined(_LINUX_C_LIB_VERSION_MINOR)	\
	&& _LINUX_C_LIB_VERSION_MAJOR <= 5	\
	&& _LINUX_C_LIB_VERSION_MINOR < 2)

#if ! PRINTF_ATSIGN_VA_LIST
static int
arginfo_func (const struct printf_info *info, size_t n, int *argtypes)
{
  *argtypes = PA_POINTER;
  return 1;
}
#endif /* !PRINTF_ATSIGN_VA_LIST */

static int
handle_printf_atsign (FILE *stream, 
		      const struct printf_info *info,
#if PRINTF_ATSIGN_VA_LIST
		      va_list *ap_pointer)
#elif defined(_LINUX_C_LIB_VERSION_MAJOR)       \
     && _LINUX_C_LIB_VERSION_MAJOR < 6
                      const void **const args)
#else /* GNU libc needs the following. */
                      const void *const *args)
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
		[[string_object description] cStringNoCopy]);
  return len;
}
#endif /* HAVE_REGISTER_PRINTF_FUNCTION */

+ (void) initialize
{
  if (self == [NSString class])
    {
      _DefaultStringEncoding = GetDefEncoding();
      NSString_concrete_class = [NSGString class];
      NSString_c_concrete_class = [NSGCString class];
      NSMutableString_concrete_class = [NSGMutableString class];
      NSMutableString_c_concrete_class = [NSGMutableCString class];

#if HAVE_REGISTER_PRINTF_FUNCTION
      if (register_printf_function ('@', 
				    handle_printf_atsign, 
#if PRINTF_ATSIGN_VA_LIST
				    0))
#else
	                            arginfo_func))
#endif
	[NSException raise: NSGenericException
		     format: @"register printf handling of %%@ failed"];
#endif /* HAVE_REGISTER_PRINTF_FUNCTION */
    }
}

+ allocWithZone: (NSZone*)z
{
  if ([self class] == [NSString class])
    return NSAllocateObject ([self _concreteClass], 0, z);
  return [super allocWithZone:z];
}

// Creating Temporary Strings

+ (NSString*) string
{
  return [[[self alloc] init] autorelease];
}

+ (NSString*) stringWithString: (NSString*)aString
{
   return [[[self alloc] initWithString: aString] autorelease];
}

+ (NSString*) stringWithCharacters: (const unichar*)chars
   length: (unsigned int)length
{
   return [[[self alloc]
          initWithCharacters:chars length:length]
         autorelease];
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

+ (NSString*) stringWithContentsOfFile:(NSString *)path
{
  return [[[self alloc]
	      initWithContentsOfFile: path] autorelease];
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

/* This is the designated initializer for Unicode Strings. */
- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  [self subclassResponsibility:_cmd];
  return self;
}

- (id) initWithCharacters: (const unichar*)chars
   length: (unsigned int)length
{
  unichar *s;
  OBJC_MALLOC(s, unichar, length+1);
  if (chars)
    memcpy(s, chars,2*length);
  s[length] = (unichar)0;
  return [self initWithCharactersNoCopy:s length:length freeWhenDone:YES];
}

/* This is the designated initializer for CStrings. */
- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  [self subclassResponsibility:_cmd];
  return self;
}

- (id) initWithCString: (const char*)byteString  length: (unsigned int)length
{
  char *s;
  OBJC_MALLOC(s, char, length+1);
  if (byteString)
    memcpy(s, byteString, length);
  s[length] = '\0';
  return [self initWithCStringNoCopy:s length:length freeWhenDone:YES];
}

- (id) initWithCString: (const char*)byteString
{
  return [self initWithCString:byteString 
	       length:(byteString ? strlen(byteString) : 0)];
}

- (id) initWithString: (NSString*)string
{
  unichar *s;
  unsigned length = [string length];
  OBJC_MALLOC(s, unichar, length+1);
  [string getCharacters:s];
  s[length] = (unichar)0;
  return [self initWithCharactersNoCopy: s
				 length: length
			   freeWhenDone: YES];
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
  #define BUFFER_EXTRA 1024*500
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
    char *atsign_pos;	     /* points to a location inside format_cp_copy */
    char *format_to_go = format_cp_copy;
    strcpy (format_cp_copy, format_cp);
    /* Loop once for each `%@' in the format string. */
    while ((atsign_pos = strstr (format_to_go, "%@")))
      {
	const char *cstring;
	char *formatter_pos; // Position for formatter.

	/* If there is a "%%@", then do the right thing: print it literally. */
	if ((*(atsign_pos-1) == '%')
	    && atsign_pos != format_cp_copy)
	  continue;
	/* Temporarily terminate the string before the `%@'. */
	*atsign_pos = '\0';
	/* Print the part before the '%@' */
	printed_len += VSPRINTF_LENGTH (vsprintf (buf+printed_len,
						  format_to_go, arg_list));
	/* Skip arguments used in last vsprintf(). */
	while ((formatter_pos = strchr(format_to_go, '%')))
	  {
	    char *spec_pos; // Position of conversion specifier.

	    if (*(formatter_pos+1) == '%')
	      {
		format_to_go = formatter_pos+2;
		continue;
	      }
	    /* Specifiers from K&R C 2nd ed. */
	    spec_pos = strpbrk(formatter_pos+1, "dioxXucsfeEgGpn\0");
	    switch (*spec_pos)
	      {
	      case 'd': case 'i': case 'o':
	      case 'x': case 'X': case 'u': case 'c':
		va_arg(arg_list, int);
		break;
	      case 's':
		if (*(spec_pos - 1) == '*')
		  va_arg(arg_list, int*);
		va_arg(arg_list, char*);
		break;
	      case 'f': case 'e': case 'E': case 'g': case 'G':
		va_arg(arg_list, double);
		break;
	      case 'p':
		va_arg(arg_list, void*);
		break;
	      case 'n':
		va_arg(arg_list, int*);
		break;
	      case '\0':
		/* Make sure loop exits on next iteration. */
		spec_pos--;
		break;
	      }
	    format_to_go = spec_pos+1;
	  }
	/* Get a C-string (char*) from the String object, and print it. */
	cstring = [[(id) va_arg (arg_list, id) description] cStringNoCopy];
	if (!cstring)
	  cstring = "<null string>";
	strcat (buf+printed_len, cstring);
	printed_len += strlen (cstring);
	/* Skip over this `%@', and look for another one. */
	format_to_go = atsign_pos + 2;
      }
    /* Print the rest of the string after the last `%@'. */
    printed_len += VSPRINTF_LENGTH (vsprintf (buf+printed_len,
					      format_to_go, arg_list));
  }
#else
  /* The available libc has `register_printf_function()', so the `%@' 
     printf directive is handled by printf and friends. */
  printed_len = VSPRINTF_LENGTH (vsprintf (buf, format_cp, arg_list));
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

- (id) initWithData: (NSData*)data
   encoding: (NSStringEncoding)encoding
{
  if((encoding==[NSString defaultCStringEncoding])
  || (encoding==NSASCIIStringEncoding))
  {
    char *s;

    int len=[data length];
    OBJC_MALLOC(s, char, len+1);
    [data getBytes:s];
    s[len]=0;
      return [self initWithCStringNoCopy:s length:len freeWhenDone:YES];
    }
  else
  {
    unichar *u;
    int count;

    int len=[data length];
    const unsigned char *b=[data bytes];
    OBJC_MALLOC(u, unichar, len+1);

    if(encoding==NSUnicodeStringEncoding)
    {
      if((b[0]==0xFE)&(b[1]==0xFF))
        for(count=2;count<(len-1);count+=2)
          u[count/2 - 1]=256*b[count]+b[count+1];
      else
        for(count=2;count<(len-1);count+=2)
          u[count/2 -1]=256*b[count+1]+b[count];
      count = count/2 -1;
    }
    else
      count = encode_strtoustr(u,b,len,encoding);

    u[count]=(unichar)0;
     return [self initWithCharactersNoCopy:u length:count freeWhenDone:YES];
  }
  return self;
}

- (id) initWithContentsOfFile: (NSString*)path
{
  unsigned char *buff;
  NSStringEncoding enc;
  id d = [NSData dataWithContentsOfFile: path];
  const unsigned char *test=[d bytes];
  unsigned int len = [d length];

  if (d == nil) return nil;
  if(test && (((test[0]==0xFF) && (test[1]==0xFE)) || ((test[1]==0xFF) && (test[0]==0xFE))))
    enc = NSUnicodeStringEncoding;
  else
    enc = [NSString defaultCStringEncoding];
  return [self initWithData:d encoding:enc];
}

- (id) init
{
 self = [super init];
 return self;
}

// Getting a String's Length

- (unsigned int) length
{
  [self subclassResponsibility:_cmd];
  return 0;
}

// Accessing Characters

- (unichar) characterAtIndex: (unsigned int)index
{
  [self subclassResponsibility:_cmd];
  return (unichar)0;
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

- (NSString*) stringByAppendingString: (NSString*)aString
{
  unsigned len = [self length];
  unsigned otherLength = [aString length];
  unichar *s;
  NSString *tmp;
  OBJC_MALLOC(s, unichar, len+otherLength+1);
  [self getCharacters:s];
  [aString getCharacters:s+len];
  s[len + otherLength]=(unichar) 0;
  tmp = [[[self class] alloc] initWithCharactersNoCopy: s
						length: len+otherLength
					  freeWhenDone: YES];
  return [tmp autorelease];
}

// Dividing Strings into Substrings

- (NSArray*) componentsSeparatedByString: (NSString*)separator
{
  NSRange search, complete;
  NSRange found;
  NSMutableArray *array = [NSMutableArray array];

  search = NSMakeRange (0, [self length]);
  complete = search;
  found = [self rangeOfString: separator];
  while (found.length)
    {
      NSRange current;

      current = NSMakeRange (search.location,
			     found.location - search.location);
      [array addObject: [self substringFromRange: current]];

      search = NSMakeRange (found.location + found.length,
			    complete.length - found.location - found.length);
      found = [self rangeOfString: separator 
		    options: 0
		    range: search];
    }
  // Add the last search string range
  [array addObject: [self substringFromRange: search]];

  // FIXME: Need to make mutable array into non-mutable array?
  return array;
}

- (NSString*) substringFromIndex: (unsigned int)index
{
  return [self substringFromRange:((NSRange){index, [self length]-index})];
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  unichar *buf;
  id ret;

  if (aRange.location > [self length])
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > ([self length] - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];
  if (aRange.length == 0)
    return @"";
  OBJC_MALLOC(buf, unichar, aRange.length+1);
  [self getCharacters:buf range:aRange];
  ret = [[[self class] alloc] initWithCharactersNoCopy: buf
						length: aRange.length
					  freeWhenDone: YES];
  return [ret autorelease];
}

- (NSString*) substringWithRange: (NSRange)aRange
{
  return [self substringFromRange: aRange];
}

- (NSString*) substringToIndex: (unsigned int)index
{
  return [self substringFromRange:((NSRange){0,index})];;
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

/* xxx FIXME */
- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
    options: (unsigned int)mask
    range: (NSRange)aRange
{
  int i, start, stop, step;
  NSRange range;

  /* xxx check to make sure aRange is within self; raise NSStringBoundsError */
  assert(NSMaxRange(aRange) <= [self length]);

  if ((mask & NSBackwardsSearch) == NSBackwardsSearch)
    {
      start = NSMaxRange(aRange)-1; stop = aRange.location-1; step = -1;
    }
  else
    {
      start = aRange.location; stop = NSMaxRange(aRange); step = 1;
    }
  range.length = 0;
  for (i = start; i != stop; i+=step)
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

- (NSRange) _searchForwardCaseInsensitiveLiteral:(NSString *) aString
   options:(unsigned int) mask
   range:(NSRange) aRange
{
  unsigned int myIndex, myEndIndex;
  unsigned int strLength;
  unichar strFirstCharacter;

  strLength = [aString length];

  myIndex = aRange.location;
  myEndIndex = aRange.location + aRange.length - strLength;

  if (mask & NSAnchoredSearch)
    myEndIndex = myIndex;

  strFirstCharacter = [aString characterAtIndex:0];

  for (;;)
    {
      unsigned int i = 1;
      unichar myCharacter = [self characterAtIndex:myIndex];
      unichar strCharacter = strFirstCharacter;

      for (;;)
	{
	  if ((myCharacter != strCharacter) &&
	      ((uni_tolower (myCharacter) != uni_tolower (strCharacter))))
	    break;
	  if (i == strLength)
	    return (NSRange){myIndex, strLength};
	  myCharacter = [self characterAtIndex:myIndex + i];
	  strCharacter = [aString characterAtIndex:i];
	  i++;
	}
      if (myIndex == myEndIndex)
	break;
      myIndex ++;
    }
  return (NSRange){0, 0};
}

- (NSRange) _searchBackwardCaseInsensitiveLiteral:(NSString *) aString
   options:(unsigned int) mask
   range:(NSRange) aRange
{
  unsigned int myIndex, myEndIndex;
  unsigned int strLength;
  unichar strFirstCharacter;

  strLength = [aString length];

  myIndex = aRange.location + aRange.length - strLength;
  myEndIndex = aRange.location;


  if (mask & NSAnchoredSearch)
    myEndIndex = myIndex;

  strFirstCharacter = [aString characterAtIndex:0];

      for (;;)
      {
        unsigned int i = 1;
        unichar myCharacter = [self characterAtIndex:myIndex];
        unichar strCharacter = strFirstCharacter;

        for (;;)
          {
            if ((myCharacter != strCharacter) &&
                ((uni_tolower (myCharacter) != uni_tolower (strCharacter))))
              break;
            if (i == strLength)
              return (NSRange){myIndex, strLength};
            myCharacter = [self characterAtIndex:myIndex + i];
            strCharacter = [aString characterAtIndex:i];
            i++;
          }
        if (myIndex == myEndIndex)
          break;
        myIndex --;
      }
  return (NSRange){0, 0};
}

- (NSRange) _searchForwardLiteral:(NSString *) aString
   options:(unsigned int) mask
   range:(NSRange) aRange
{
  unsigned int myIndex, myEndIndex;
  unsigned int strLength;
  unichar strFirstCharacter;

  strLength = [aString length];

  myIndex = aRange.location;
  myEndIndex = aRange.location + aRange.length - strLength;

  if (mask & NSAnchoredSearch)
    myEndIndex = myIndex;

  strFirstCharacter = [aString characterAtIndex:0];

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
        myIndex ++;
      }
  return (NSRange){0, 0};
}

- (NSRange) _searchBackwardLiteral:(NSString *) aString
   options:(unsigned int) mask
   range:(NSRange) aRange
{
  unsigned int myIndex, myEndIndex;
  unsigned int strLength;
  unichar strFirstCharacter;

  strLength = [aString length];

  myIndex = aRange.location + aRange.length - strLength;
  myEndIndex = aRange.location;


  if (mask & NSAnchoredSearch)
    myEndIndex = myIndex;

  strFirstCharacter = [aString characterAtIndex:0];

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
        myIndex --;
      }
  return (NSRange){0, 0};
}


- (NSRange) _searchForwardCaseInsensitive:(NSString *) aString
   options:(unsigned int) mask
   range:(NSRange) aRange
{
  unsigned int myIndex, myEndIndex;
  unsigned int strLength, strBaseLength;
  id strFirstCharacterSeq;

  strLength = [aString length];
  strBaseLength = [aString _baseLength];

  myIndex = aRange.location;
  myEndIndex = aRange.location + aRange.length - strBaseLength;

  if (mask & NSAnchoredSearch)
    myEndIndex = myIndex;

  strFirstCharacterSeq = [NSGSequence sequenceWithString: aString
    range: [aString rangeOfComposedCharacterSequenceAtIndex: 0]];

      for (;;)
      {
        NSRange myRange;
        NSRange mainRange;
        NSRange strRange;
        unsigned int myCount = 1;
        unsigned int strCount = 1;
        id myCharacter = [NSGSequence sequenceWithString: self
    range: [self rangeOfComposedCharacterSequenceAtIndex: myIndex]];
        id strCharacter = strFirstCharacterSeq;
        for (;;)
          {
            if (![[myCharacter normalize] isEqual: [strCharacter normalize]] 
            && ![[[myCharacter lowercase] normalize] isEqual: [[strCharacter lowercase] normalize]])

              break;
            if (strCount >= strLength)
              return (NSRange){myIndex, myCount};
            myRange = [self rangeOfComposedCharacterSequenceAtIndex: myIndex + myCount];
            myCharacter = [NSGSequence sequenceWithString: self range: myRange];
            strRange = [aString rangeOfComposedCharacterSequenceAtIndex: strCount];
            strCharacter = [NSGSequence sequenceWithString: aString range: strRange];
            myCount += myRange.length;
            strCount += strRange.length;
          }  /* for */
        if (myIndex >= myEndIndex)
          break;
            mainRange = [self rangeOfComposedCharacterSequenceAtIndex: myIndex];
          myIndex += mainRange.length;
      } /* for */
  return (NSRange){0, 0};
}

- (NSRange) _searchBackwardCaseInsensitive:(NSString *) aString
   options:(unsigned int) mask
   range:(NSRange) aRange
{
  unsigned int myIndex, myEndIndex;
  unsigned int strLength, strBaseLength;
  id strFirstCharacterSeq;

  strLength = [aString length];
  strBaseLength = [aString _baseLength];

  myIndex = aRange.location + aRange.length - strBaseLength;
  myEndIndex = aRange.location;

  if (mask & NSAnchoredSearch)
    myEndIndex = myIndex;

  strFirstCharacterSeq = [NSGSequence sequenceWithString: aString
    range: [aString rangeOfComposedCharacterSequenceAtIndex: 0]];

      for (;;)
      {
        NSRange myRange;
        NSRange strRange;
        unsigned int myCount = 1;
        unsigned int strCount = 1;
        id myCharacter = [NSGSequence sequenceWithString: self
    range: [self rangeOfComposedCharacterSequenceAtIndex: myIndex]];
        id strCharacter = strFirstCharacterSeq;
        for (;;)
          {
            if (![[myCharacter normalize] isEqual: [strCharacter normalize]] 
            && ![[[myCharacter lowercase] normalize] isEqual: [[strCharacter lowercase] normalize]])

              break;
            if (strCount >= strLength)
              return (NSRange){myIndex, myCount};
            myCharacter = [NSGSequence sequenceWithString: self range: [self rangeOfComposedCharacterSequenceAtIndex: myIndex + myCount]];
            myRange = [self rangeOfComposedCharacterSequenceAtIndex: myIndex + myCount];
            strCharacter = [NSGSequence sequenceWithString: aString range: [aString rangeOfComposedCharacterSequenceAtIndex: strCount]];
            strRange = [aString rangeOfComposedCharacterSequenceAtIndex: strCount];
            myCount += myRange.length;
            strCount += strRange.length;
          }  /* for */
        if (myIndex <= myEndIndex)
          break;
          myIndex--;
          while(uni_isnonsp([self characterAtIndex: myIndex])&&(myIndex>0))
            myIndex--;
      } /* for */
  return (NSRange){0, 0};
}


- (NSRange) _searchForward:(NSString *) aString
   options:(unsigned int) mask
   range:(NSRange) aRange
{
  unsigned int myIndex, myEndIndex;
  unsigned int strLength, strBaseLength;
  id strFirstCharacterSeq;

  strLength = [aString length];
  strBaseLength = [aString _baseLength];

  myIndex = aRange.location;
  myEndIndex = aRange.location + aRange.length - strBaseLength;

  if (mask & NSAnchoredSearch)
    myEndIndex = myIndex;

  strFirstCharacterSeq = [NSGSequence sequenceWithString: aString
    range: [aString rangeOfComposedCharacterSequenceAtIndex: 0]];

      for (;;)
      {
        NSRange myRange;
        NSRange strRange;
        NSRange mainRange;
        unsigned int myCount = 1;
        unsigned int strCount = 1;
        id myCharacter = [NSGSequence sequenceWithString: self
    range: [self rangeOfComposedCharacterSequenceAtIndex: myIndex]];
        id strCharacter = strFirstCharacterSeq;
        for (;;)
          {
            if (![[myCharacter normalize] isEqual: [strCharacter normalize]])
              break;
            if (strCount >= strLength)
              return (NSRange){myIndex, myCount};
            myRange = [self rangeOfComposedCharacterSequenceAtIndex: myIndex + myCount];
            myCharacter = [NSGSequence sequenceWithString: self range: myRange];
            strRange = [aString rangeOfComposedCharacterSequenceAtIndex: strCount];
            strCharacter = [NSGSequence sequenceWithString: aString range: strRange];
            myCount += myRange.length;
            strCount += strRange.length;
          }  /* for */
        if (myIndex >= myEndIndex)
          break;
            mainRange = [self rangeOfComposedCharacterSequenceAtIndex: myIndex];
          myIndex += mainRange.length;
      } /* for */
 return (NSRange){0, 0};
}


- (NSRange) _searchBackward:(NSString *) aString
   options:(unsigned int) mask
   range:(NSRange) aRange
{
  unsigned int myIndex, myEndIndex;
  unsigned int strLength, strBaseLength;
  id strFirstCharacterSeq;

  strLength = [aString length];
  strBaseLength = [aString _baseLength];

  myIndex = aRange.location + aRange.length - strBaseLength;
  myEndIndex = aRange.location;

  if (mask & NSAnchoredSearch)
    myEndIndex = myIndex;

  strFirstCharacterSeq = [NSGSequence sequenceWithString: aString
    range: [aString rangeOfComposedCharacterSequenceAtIndex: 0]];

      for (;;)
      {
        NSRange myRange;
        NSRange strRange;
        unsigned int myCount = 1;
        unsigned int strCount = 1;
        id myCharacter = [NSGSequence sequenceWithString: self
    range: [self rangeOfComposedCharacterSequenceAtIndex: myIndex]];
        id strCharacter = strFirstCharacterSeq;
        for (;;)
          {
            if (![[myCharacter normalize] isEqual: [strCharacter normalize]])
           
              break;
            if (strCount >= strLength)
              return (NSRange){myIndex, myCount};
            myCharacter = [NSGSequence sequenceWithString: self range: [self rangeOfComposedCharacterSequenceAtIndex: myIndex + myCount]];
            myRange = [self rangeOfComposedCharacterSequenceAtIndex: myIndex + myCount];
            strCharacter = [NSGSequence sequenceWithString: aString range: [aString rangeOfComposedCharacterSequenceAtIndex: strCount]];
            strRange = [aString rangeOfComposedCharacterSequenceAtIndex: strCount];
            myCount += myRange.length;
            strCount += strRange.length;
          }  /* for */
        if (myIndex <= myEndIndex)
          break;
          myIndex--;
          while(uni_isnonsp([self characterAtIndex: myIndex])&&(myIndex>0))
            myIndex--;
      } /* for */
 return (NSRange){0, 0};
}

- (NSRange) rangeOfString:(NSString *) aString
   options:(unsigned int) mask
   range:(NSRange) aRange
{

 #define FCLS  3
 #define BCLS  7
 #define FLS  2
 #define BLS 6
 #define FCS  1
 #define BCS  5
 #define FS  0
 #define BS  4
 #define FCLAS  11
 #define BCLAS  15
 #define FLAS  10
 #define BLAS 14
 #define FCAS  9
 #define BCAS  13
 #define FAS  8
 #define BAS  12

  unsigned int myLength, strLength;
  
  /* Check that the search range is reasonable */
  myLength = [self length];
  if (aRange.location > myLength)
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > (myLength - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];


  /* Ensure the string can be found */
  strLength = [aString length];
  if (strLength > aRange.length || strLength == 0)
    return (NSRange){0, 0};

 switch (mask)
 {
  case FCLS :
  case FCLAS :
     return [self _searchForwardCaseInsensitiveLiteral: aString
               options: mask
               range: aRange];
           break;

  case BCLS :
  case BCLAS :
     return [self _searchBackwardCaseInsensitiveLiteral: aString
               options: mask
               range: aRange];
           break;

  case FLS :
  case FLAS :
    return [self _searchForwardLiteral: aString
               options: mask 
               range: aRange];
           break;

  case BLS :
  case BLAS :
    return [self _searchBackwardLiteral: aString
               options: mask
               range: aRange];
           break;

  case FCS :
  case FCAS :
    return [self _searchForwardCaseInsensitive: aString
               options: mask
               range: aRange];
               break;

  case BCS :
  case BCAS :
    return [self _searchBackwardCaseInsensitive: aString
               options: mask
               range: aRange];
               break;

  case BS :
  case BAS :
    return [self _searchBackward: aString
               options: mask
               range: aRange];
               break;

  case FS :
  case FAS :
  default :
    return [self _searchForward: aString
           options: mask
           range: aRange];
           break;
 }
 return (NSRange){0, 0};
}

// Determining Composed Character Sequences

 - (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned int)anIndex
{
  unsigned int start, end;

  start=anIndex;
  while(uni_isnonsp([self characterAtIndex: start]))
    start++;
  end=start+1;
  if(end < [self length])
    while((end < [self length]) && (uni_isnonsp([self characterAtIndex: end])) )
      end++;
  return NSMakeRange(start, end-start);
}

// Converting String Contents into a Property List

//  xxx C strings only ???
- (id)propertyList
{
  id obj;
  void *bufstate;
  bufstate = (void *)pl_scan_string([self cStringNoCopy]);
  obj = (id)plparse();
  pl_delete_buffer(bufstate);
  return obj;
}

//  xxx C strings only ???
- (NSDictionary*) propertyListFromStringsFileFormat
{
   id dict = [[[NSMutableDictionary alloc] init] autorelease];
   void *bufstate;

   bufstate = (void *)sf_scan_string([self cStringNoCopy]);
   sfSetDict(dict);
   sfparse(dict);
   sf_delete_buffer(bufstate);
   return dict;
}

// Identifying and Comparing Strings

- (NSComparisonResult) compare: (NSString*)aString
{
  return [self compare:aString options:0];
}

- (NSComparisonResult) compare: (NSString*)aString	
   options: (unsigned int)mask
{
  return [self compare:aString options:mask 
	       range:((NSRange){0, [self length]})];
}

// xxx Should implement full POSIX.2 collate
- (NSComparisonResult) compare: (NSString*)aString
   options: (unsigned int)mask
   range: (NSRange)aRange
{
  if (aRange.location > [self length])
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > ([self length] - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];

  if((([self length] - aRange.location == 0) && (![aString length])))
    return NSOrderedSame;
  if(![self length])
    return NSOrderedAscending;
  if(![aString length])
    return NSOrderedDescending;

if (mask & NSLiteralSearch)
{
  int i;
  int s1len = aRange.length;
  int s2len = [aString length];
  int end;
  unichar s1[s1len+1];
  unichar s2[s2len+1];

  [self getCharacters:s1 range: aRange];
  s1[s1len] = (unichar)0;
  [aString getCharacters:s2];
  s2[s2len] = (unichar)0;
  end = s1len+1;
  if (s2len < s1len)
    end = s2len+1;

  if (mask & NSCaseInsensitiveSearch)
    {
      for (i = 0; i < end; i++)
	{
	  int c1 = uni_tolower(s1[i]);
	  int c2 = uni_tolower(s2[i]);
	  if (c1 < c2) return NSOrderedAscending;
	  if (c1 > c2) return NSOrderedDescending;
	}
    }
  else
    {
      for (i = 0; i < end; i++)
	{
	  if (s1[i] < s2[i]) return NSOrderedAscending;
	  if (s1[i] > s2[i]) return NSOrderedDescending;
	}
    }
  if (s1len > s2len)
    return NSOrderedDescending;
  else if (s1len < s2len)
    return NSOrderedAscending;
  else
    return NSOrderedSame;
}  /* if NSLiteralSearch */
else
{
  int start, end, myCount, strCount;
  NSRange myRange, strRange;
  id mySeq, strSeq;
  NSComparisonResult result;

  start = aRange.location;
  end = aRange.location + aRange.length;
  myCount = start;
  strCount = start;
  while(myCount < end)
  {
    if(strCount>=[aString length])
      return NSOrderedDescending;
    if(myCount>=[self length])
      return NSOrderedAscending;
    myRange = [self rangeOfComposedCharacterSequenceAtIndex:  myCount];
    myCount += myRange.length;
    strRange = [aString rangeOfComposedCharacterSequenceAtIndex:  strCount];
    strCount += strRange.length;
    mySeq = [NSGSequence sequenceWithString: self range: myRange];
    strSeq = [NSGSequence sequenceWithString: aString range: strRange];
    if (mask & NSCaseInsensitiveSearch)
      result = [[mySeq lowercase] compare: [strSeq lowercase]];
    else
      result = [mySeq compare: strSeq];
    if(result != NSOrderedSame)
      return result;
    } /* while */
  if(strCount<[aString length])
    return NSOrderedAscending;
  return NSOrderedSame;
 }  /* else */
}

- (BOOL) hasPrefix: (NSString*)aString
{
  NSRange range;
  range = [self rangeOfString:aString];
  return ((range.location == 0) && (range.length != 0)) ? YES : NO;
}

- (BOOL) hasSuffix: (NSString*)aString
{
  NSRange range;
  range = [self rangeOfString:aString options:NSBackwardsSearch];
  return (range.length > 0 && range.location == ([self length] - [aString length])) ? YES : NO;
}

- (BOOL) isEqual: (id)anObject
{
  if (anObject == self)
    return YES;
  if ([anObject isKindOf:[NSString class]])
    return [self isEqualToString:anObject];
  return NO;
}

- (BOOL) isEqualToString: (NSString*)aString
{
  id mySeq, strSeq;
  NSRange myRange, strRange;
  unsigned int myLength;
  unsigned int strLength;
  unsigned int myIndex = 0;
  unsigned int strIndex = 0;

  if ([self hash] != [aString hash])
    return NO;
  myLength = [self length];
  strLength = [aString length];
  if((!myLength) && (!strLength))
    return YES;
  if(!myLength)
    return NO;
  if(!strLength)
    return NO;

  while((myIndex < myLength) && (strIndex < strLength))
    if([self characterAtIndex: myIndex] ==
       [aString characterAtIndex: strIndex])
    {
      myIndex++;
      strIndex++;
    }
    else
    {
      myRange = [self rangeOfComposedCharacterSequenceAtIndex: myIndex];
      strRange = [aString rangeOfComposedCharacterSequenceAtIndex: strIndex];
      if((myRange.length < 2) || (strRange.length < 2))
        return NO;
      else
      {
        mySeq = [NSGSequence sequenceWithString: self range: myRange];
        strSeq = [NSGSequence sequenceWithString: aString range: strRange];
        if([mySeq isEqual: strSeq])
        {
          myIndex += myRange.length;
          strIndex += strRange.length;
        }
        else
          return NO;
      }
    }
  if((myIndex  == myLength) && (strIndex  == strLength))
    return YES;
  else
    return NO;
}

- (unsigned int) hash
{
  #define MAXDEC 18

  unsigned ret = 0;
  unsigned ctr = 0;
  unsigned char_count = 0;
  unichar *source,*p;

  unichar *target;
  unichar *spoint;
  unichar *tpoint;
  unichar *dpoint;
  BOOL notdone;

  unichar  *first,*second,tmp;
  int count,len2;

  int len = [self length];

  if (len)
  {
    if(len > NSHashStringLength)
      len = NSHashStringLength;
    source = alloca(sizeof(unichar)*(len*MAXDEC+1));
    [self getCharacters: source range:NSMakeRange(0,len)];
    source[len]=(unichar)0;

// decompose
    target = alloca(sizeof(unichar)*(len*MAXDEC+1));
    spoint = source;
    tpoint = target;
    do
    {
      notdone=NO;
      do
      {
        if(!(dpoint=uni_is_decomp(*spoint)))
          *tpoint++ = *spoint;
        else
        {
          while(*dpoint)
            *tpoint++=*dpoint++;
          notdone=YES;
        }
      } while(*spoint++);
      *tpoint=(unichar)0;
      memcpy(source, target,2*(len*MAXDEC+1));
      tpoint = target;
      spoint = source;
    } while(notdone);

// order

  len2 = uslen(source);
  if(len2>1)
  do
  {
    notdone=NO;
    first=source;
    second=first+1;
    for(count=1;count<len2;count++)
    {
      if(uni_cop(*second))
      {
         if(uni_cop(*first)>uni_cop(*second))
         {
            tmp= *first;
            *first= *second;
            *second=tmp;
            notdone=YES;
         }
         if(uni_cop(*first)==uni_cop(*second))
           if(*first>*second)
           {
              tmp= *first;
              *first= *second;
              *second=tmp;
              notdone=YES;
           }
      }
      first++;
      second++;
    }
  } while(notdone);

  p = source;
  while (*p && char_count++ < NSHashStringLength)
    {
      ret ^= *p++ << ctr;
      ctr = (ctr + 1) % sizeof (void*);
    }
  return ret;
  }
  else
  return 0;
}

// Getting a Shared Prefix

- (NSString*) commonPrefixWithString: (NSString*)aString
   options: (unsigned int)mask
{
 if(mask & NSLiteralSearch)
 {
  int prefix_len = 0;
  unichar *u,*w;
  unichar a1[[self length]+1];
  unichar *s1 = a1;
  unichar a2[[aString length]+1];
  unichar *s2 = a2;
  u=s1;
  [self getCharacters:s1];
  s1[[self length]] = (unichar)0;
  [aString getCharacters:s2];
  s2[[aString length]] = (unichar)0;
  u=s1;
  w=s2;
 if(mask & NSCaseInsensitiveSearch)
  while (*s1 && *s2 
	 && (uni_tolower(*s1) == uni_tolower(*s2)))
    {
      s1++;
      s2++;
      prefix_len++;
    }
 else
  while (*s1 && *s2 
	 && (*s1 == *s2))	     
    {
      s1++;
      s2++;
      prefix_len++;
    }
    return [NSString stringWithCharacters: u length: prefix_len];
 }
 else
 {
  id mySeq, strSeq;
  NSRange myRange, strRange;
  unsigned int myLength = [self length];
  unsigned int strLength = [aString length];
  unsigned int myIndex = 0;
  unsigned int strIndex = 0;
  if(!myLength)
    return self;
  if(!strLength)
    return aString;
 if(mask & NSCaseInsensitiveSearch)
 {
  while((myIndex < myLength) && (strIndex < strLength))
    if(uni_tolower([self characterAtIndex: myIndex]) ==
       uni_tolower([aString characterAtIndex: strIndex]))
    {
      myIndex++;
      strIndex++;
    }
    else
    {
      myRange = [self rangeOfComposedCharacterSequenceAtIndex: myIndex];
      strRange = [aString rangeOfComposedCharacterSequenceAtIndex: strIndex];
      if((myRange.length < 2) || (strRange.length < 2))
        return [self substringFromRange: NSMakeRange(0, myIndex)];
      else
      {
        mySeq = [NSGSequence sequenceWithString: self range: myRange];
        strSeq = [NSGSequence sequenceWithString: aString range: strRange];
        if([[mySeq lowercase] isEqual: [strSeq lowercase]])
        {
          myIndex += myRange.length;
          strIndex += strRange.length;
        }
        else
         return [self substringFromRange: NSMakeRange(0, myIndex)];
      }
    }
  return [self substringFromRange: NSMakeRange(0, myIndex)];
 }
 else
 {
  while((myIndex < myLength) && (strIndex < strLength))
    if([self characterAtIndex: myIndex] ==
       [aString characterAtIndex: strIndex])
    {
      myIndex++;
      strIndex++;
    }
    else
    {
      myRange = [self rangeOfComposedCharacterSequenceAtIndex: myIndex];
      strRange = [aString rangeOfComposedCharacterSequenceAtIndex: strIndex];
      if((myRange.length < 2) || (strRange.length < 2))
        return [self substringFromRange: NSMakeRange(0, myIndex)];
      else
      {
        mySeq = [NSGSequence sequenceWithString: self range: myRange];
        strSeq = [NSGSequence sequenceWithString: aString range: strRange];
        if([mySeq isEqual: strSeq])
        {
          myIndex += myRange.length;
          strIndex += strRange.length;
        }
        else
         return [self substringFromRange: NSMakeRange(0, myIndex)];
      }
    }
  return [self substringFromRange: NSMakeRange(0, myIndex)];
 }
 }
}

- (NSRange)lineRangeForRange:(NSRange)aRange
{
  unsigned int startIndex;
  unsigned int lineEndIndex;

  [self getLineStart: &startIndex
                 end: &lineEndIndex
         contentsEnd: NULL
            forRange:aRange];
  return NSMakeRange(startIndex, lineEndIndex - startIndex);
}

- (void)getLineStart:(unsigned int *)startIndex
                 end:(unsigned int *)lineEndIndex
         contentsEnd:(unsigned int *)contentsEndIndex
         forRange:(NSRange)aRange
{
  unichar thischar;
  BOOL done;
  unsigned int start, end, len;

  if (aRange.location > [self length])
    [NSException raise: NSRangeException format:@"Invalid location."];
  if (aRange.length > ([self length] - aRange.location))
    [NSException raise: NSRangeException format:@"Invalid location+length."];

  len = [self length];
  start=aRange.location;

  if(startIndex)
    if(start==0)
      *startIndex=0;
    else
    {
      start--;
      while(start>0)
      {
        BOOL done = NO;
        thischar = [self characterAtIndex:start];
        switch(thischar)
        {
          case (unichar)0x000A:
          case (unichar)0x000D:
          case (unichar)0x2028:
          case (unichar)0x2029:
            done = YES;
            break;
          default:
            start--;
            break;
        };
        if(done)
          break;
      };
      if(start == 0)
      {
         thischar = [self characterAtIndex:start];
         switch(thischar)
         {
           case (unichar)0x000A:
           case (unichar)0x000D:
           case (unichar)0x2028:
           case (unichar)0x2029:
             start++;
             break;
           default:
             break;
         };
      }
      else
      start++;
      *startIndex=start;
    };

  if(lineEndIndex || contentsEndIndex)
  {
    end=aRange.location+aRange.length;
    while(end<len)
    {
       BOOL done = NO;
       thischar = [self characterAtIndex:end];
       switch(thischar)
       {
         case (unichar)0x000A:
         case (unichar)0x000D:
         case (unichar)0x2028:
         case (unichar)0x2029:
           done = YES;
           break;
         default:
           break;
       };
       end++;
       if(done)
         break;
    };
    if(end<len)
    {
      if([self characterAtIndex:end]==(unichar)0x000D)
        if([self characterAtIndex:end+1]==(unichar)0x000A)
          *lineEndIndex = end+1;
        else  *lineEndIndex = end;
      else  *lineEndIndex = end;
    }
    else
    *lineEndIndex = end;
  };

  if(contentsEndIndex)
  {
    if(end<len)
    {
      *contentsEndIndex= end-1;
    }
    else

/* xxx OPENSTEP documentation does not say what to do if last
   line is not terminated. Assume this */
     *contentsEndIndex= end;
    };
}

// Changing Case

// xxx There is more than this in word capitalization in Unicode,
// but this will work in most cases
- (NSString*) capitalizedString
{
  unichar *s;
  int count=0;
  BOOL found=YES;
  int len=[self length];
  id white = [NSCharacterSet whitespaceAndNewlineCharacterSet];

  OBJC_MALLOC(s, unichar,len +1);
  [self getCharacters:s];
  s[len] = (unichar)0;
  while(count<len)
  {
    if([white characterIsMember:s[count]])
    {
      count++;
      found=YES;
      while([white characterIsMember:s[count]]&(count<len))
        count++;
    };
    if(found)
    {
      s[count]=uni_toupper(s[count]);
      count++;
    }
    else
    {
      while(![white characterIsMember:s[count]]&(count<len))
      {
        s[count]=uni_tolower(s[count]);
        count++;
      };
    };
    found=NO;
  };
  s[count] = (unichar)0;
  return [[[NSString alloc] initWithCharactersNoCopy:s length:len freeWhenDone:YES] autorelease];
}

- (NSString*) lowercaseString
{
  unichar *s;
  int count;
  int len=[self length];
  OBJC_MALLOC(s, unichar,len +1);
  for(count=0;count<len;count++)
    s[count]=uni_tolower([self characterAtIndex:count]);
  s[len] = (unichar)0;
  return [[[[self class] alloc] initWithCharactersNoCopy: s
						  length: len
					    freeWhenDone: YES] autorelease];
}

- (NSString*) uppercaseString;
{
  unichar *s;
  int count;
  int len=[self length];
  OBJC_MALLOC(s, unichar,len +1);
  for(count=0;count<len;count++)
    s[count]=uni_toupper([self characterAtIndex:count]);
  s[len] = (unichar)0;
  return [[[[self class] alloc] initWithCharactersNoCopy: s
						  length: len
					    freeWhenDone: YES] autorelease];
}

// Storing the String

- (NSString*) description
{
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

// xxx FIXME adjust range for composite sequence
- (void) getCString: (char*)buffer
   maxLength: (unsigned int)maxLength
   range: (NSRange)aRange
   remainingRange: (NSRange*)leftoverRange
{
  int len, count;

  /* xxx check to make sure aRange is within self; raise NSStringBoundsError */
  assert(NSMaxRange(aRange) <= [self cStringLength]);
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
  count=0;
  while(count<len)
  {
    buffer[count]=unitochar([self characterAtIndex: aRange.location + count]);
    count++;
   }
  buffer[len] = '\0';
}


// Getting Numeric Values

// xxx Sould we use NSScanner here ?

- (double) doubleValue
{
  return atof([self cStringNoCopy]);
}

- (float) floatValue
{
  return (float) atof([self cStringNoCopy]);
}

- (int) intValue
{
  return atoi([self cStringNoCopy]);
}

// Working With Encodings

+ (NSStringEncoding) defaultCStringEncoding
{
  return _DefaultStringEncoding;
}

+ (NSStringEncoding*)availableStringEncodings
{
  return _availableEncodings;
}

+ (NSString*)localizedNameOfStringEncoding:(NSStringEncoding)encoding
{
  id ourbundle;
  id ourname;

/*
      Should be path to localizable.strings file.
      Until we have it, just make shure that bundle
      is initialized.
*/
  ourbundle = [NSBundle bundleWithPath:@"/"];

  ourname = GetEncodingName(encoding);
  return [ourbundle
            localizedStringForKey:ourname
            value:ourname
            table:nil];
}

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)encoding
{
  id d = [self  dataUsingEncoding: encoding allowLossyConversion: NO];
  return d ? YES : NO;
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
{
  return [self dataUsingEncoding: encoding allowLossyConversion: NO];
}

// xxx incomplete
- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
   allowLossyConversion: (BOOL)flag
{
  int count=0;
  int len = [self length];

  if((encoding==NSASCIIStringEncoding)
  || (encoding==NSISOLatin1StringEncoding)
  || (encoding==NSNEXTSTEPStringEncoding)
  || (encoding==NSNonLossyASCIIStringEncoding)
  || (encoding==NSSymbolStringEncoding)
  || (encoding==NSCyrillicStringEncoding))
  {
    unsigned char *buff;
    char t;
    OBJC_MALLOC(buff, char, len+1);
    if(!flag)
      for(count=0; count<len; count++)
        if((t = encode_unitochar([self characterAtIndex: count], encoding)))
          buff[count] = t;
        else
          return nil;
    else /* lossy */
      for(count=0; count<len; count++)
        if((t = encode_unitochar([self characterAtIndex: count], encoding)))
          buff[count] = t;
        else
        {
          t=[[NSGSequence sequenceWithString: self
          range:
          [self rangeOfComposedCharacterSequenceAtIndex: count]]
           baseCharacter];
          if((t = encode_unitochar([self characterAtIndex: count], encoding)))
            buff[count] = t;
          else
  /* xxx should handle decomposed characters */
 /* OpenStep documentation is unclear on what to do if there is no
    simple replacement for character */
            buff[count] = '*';
        };
     buff[count]=0;
     return [NSData dataWithBytes: (char *)buff length: count];
    }
    else
      if(encoding==NSUnicodeStringEncoding)
      {
        unichar *buff;
        OBJC_MALLOC(buff, unichar, len+2);
        buff[0]=0xFEFF;
        for(count=0; count<len; count++)
          buff[count+1]=[self characterAtIndex: count];
        buff[count+1]= (unichar)0;
  return [NSData dataWithBytes: (char *)buff length: 2*(count+1)];
      }
      else /* UTF8 or EUC */
        [self notImplemented:_cmd];
  return nil;
}

- (NSStringEncoding) fastestEncoding
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (NSStringEncoding) smallestEncoding
{
  [self subclassResponsibility:_cmd];
  return 0;
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

/* Return a string for passing to OS calls to handle file system objects. */
- (const char*)fileSystemRepresentation
{
  return [self cString];
}

- (BOOL)getFileSystemRepresentation: (char*)buffer maxLength: (unsigned int)size
{
  const char* ptr = [self cStringNoCopy];
  if (strlen(ptr) > size)
    return NO;
  strcpy(buffer, ptr);
  return YES;
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

  range = [self rangeOfString: PATH_COMPONENT options:NSBackwardsSearch];
  if (range.length == 0)
    substring = [[self copy] autorelease];
  else if (range.location == ([self length] - PATH_COMPONENT_LEN))
    {
      if (range.location == 0)
	substring = [[NSString new] autorelease];
      else
	substring = [[self substringToIndex:range.location] 
		      lastPathComponent];
    }
  else
    substring = [self substringFromIndex:range.location + PATH_COMPONENT_LEN];

#ifdef PATH_COMPONENT2
  if (substring == self)
    {
      NSRange range2 = [self rangeOfString: PATH_COMPONENT2
			     options:NSBackwardsSearch];
      if (range2.length == 0)
	substring = [[self copy] autorelease];
      else if (range2.location == ([self length] - PATH_COMPONENT_LEN2))
	{
	  if (range2.location == 0)
	    substring = [[NSString new] autorelease];
	  else
	    substring = [[self substringToIndex:range2.location] 
			  lastPathComponent];
	}
      else
	substring = [self substringFromIndex:
			    range2.location + PATH_COMPONENT_LEN2];
    }
#endif /* PATH_COMPONENT2 */

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
      || range.location < ([self rangeOfString: PATH_COMPONENT
				 options:NSBackwardsSearch]).location)
    substring = nil;
  else
    substring = [self substringFromIndex:range.location + PATH_COMPONENT_LEN];

#ifdef PATH_COMPONENT2
  if (!substring)
    {
      if (range.length == 0 
	  || range.location < ([self rangeOfString: PATH_COMPONENT2
				     options:NSBackwardsSearch]).location)
	substring = nil;
      else
	substring = [self substringFromIndex:
			    range.location + PATH_COMPONENT_LEN2];
    }
#endif

  if (!substring)
    substring = [[NSString new] autorelease];
  return substring;
}

/* Returns a new string with the path component given in aString
   appended to the receiver.  Raises an exception if aString starts with
   a '/'.  Checks the receiver to see if the last letter is a '/', if it
   is not, a '/' is appended before appending aString */
- (NSString*) stringByAppendingPathComponent: (NSString*)aString
{
  NSRange  range;
  NSString *newstring;

  if ([aString length] == 0)
      return [[self copy] autorelease];

  range = [aString rangeOfString:@"/"];
  if (range.length != 0 && range.location == 0)
      [NSException raise: NSGenericException
		     format: @"attempt to append illegal path component"];

  range = [self rangeOfString:@"/" options:NSBackwardsSearch];
  if ((range.length == 0 || range.location != [self length] - 1) && [self length] > 0)

      newstring = [self stringByAppendingString:@"/"];
  else
      newstring = self;

  return [newstring stringByAppendingString:aString];
}

/* Returns a new string with the path extension given in aString
   appended to the receiver.  Raises an exception if aString starts with
   a '.'.  Checks the receiver to see if the last letter is a '.', if it
   is not, a '.' is appended before appending aString */
- (NSString*) stringByAppendingPathExtension: (NSString*)aString
{
  NSRange  range;
  NSString *newstring;

  if ([aString length] == 0)
    return [[self copy] autorelease];

  range = [aString rangeOfString:@"."];
  if (range.length != 0 && range.location == 0)
    [NSException raise: NSGenericException
	     format: @"attempt to append illegal path extension"];

  range = [self rangeOfString:@"." options:NSBackwardsSearch];
  if (range.length == 0 || range.location != [self length] - 1)
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

  if (range.length == 0)
    substring = [[self copy] autorelease];
  else if (range.location == 0)
    substring = [[NSString new] autorelease];
  else if (range.location > 1)
      substring = [self substringToIndex:range.location-1];
  else
      substring = PATH_COMPONENT;
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
      substring = [self substringToIndex:range.location-1];
  else
      substring = [[self copy] autorelease];
  return substring;
}

- (NSString*) stringByExpandingTildeInPath
{
  unichar *s;
  NSString *homedir;
  NSRange first_slash_range;
  
  if ([self length] == 0)
    return [[self copy] autorelease];
  if ([self characterAtIndex: 0] != 0x007E)
    return [[self copy] autorelease];

  first_slash_range = [self rangeOfString: @"/"];

  if (first_slash_range.location != 1)
    {
      /* It is of the form `~username/blah/...' */
      int uname_len;
      NSString *uname;

      if (first_slash_range.length != 0)
	uname_len = first_slash_range.length - 1;
      else
	/* It is actually of the form `~username' */
	uname_len = [self length] - 1;
      uname = [self substringFromRange: ((NSRange){1, uname_len})];
      homedir = NSHomeDirectoryForUser (uname);
    }
  else
    {
      /* It is of the form `~/blah/...' */
      homedir = NSHomeDirectory ();
    }
  
  return [NSString stringWithFormat: @"%@%@", 
		   homedir, 
		   [self substringFromIndex: first_slash_range.location]];
}

- (NSString*) stringByAbbreviatingWithTildeInPath
{
  NSString *homedir = NSHomeDirectory ();

  if (![self hasPrefix: homedir])
    return [[self copy] autorelease];

  return [NSString stringWithFormat: @"~/%@",
		   [self substringFromIndex: [homedir length] + 1]];
}

- (NSString*) stringByResolvingSymlinksInPath
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByStandardizingPath
{
  NSMutableString *s;
  NSRange r;

  /* Expand `~' in the path */
  s = [[self stringByExpandingTildeInPath] mutableCopy];

  /* Remove `/private' */
  if ([s hasPrefix: @"/private"])
    [s deleteCharactersInRange: ((NSRange){0,7})];

  /* Condense `//' */
  while ((r = [s rangeOfString: @"//"]).length)
    [s deleteCharactersInRange: r];

  /* Condense `/./' */
  while ((r = [s rangeOfString: @"/./"]).length)
    {
      r.length--;
      [s deleteCharactersInRange: r];
    }

  /* Condense `/../' */
  while ((r = [s rangeOfString: @"/../"]).length)
    {
      NSRange r2 = {0, r.length-1};
      r = [s rangeOfString: @"/" 
	     options: NSBackwardsSearch
	     range: r2];
      r.length += 4;		/* Add the `/../' */
      [s deleteCharactersInRange: r];
    }

  /* xxx Should we not return a mutable string? */
  return s;
}

// private methods for Unicode level 3 implementation
- (int) _baseLength
{
  int count=0;
  int blen=0;
  while(count < [self length])
    if(!uni_isnonsp([self characterAtIndex: count++]))
      blen++;
  return blen;
} 


- (NSString*) _normalizedString
{
  #define MAXDEC 18

  unichar *u, *upoint;
  NSRange r;
  id seq,ret;
  int len = [self length];
  int count = 0;
  OBJC_MALLOC(u, unichar, len*MAXDEC+1);
  upoint = u;

  while(count < len)
  {
    r = [self rangeOfComposedCharacterSequenceAtIndex: count];
    seq=[NSGSequence sequenceWithString: self range: r];
    [[seq normalize] getCharacters: upoint];
    upoint += [seq length];
    count += r.length;
  }
  *upoint = (unichar)0;

  ret = [[[[self class] alloc] initWithCharactersNoCopy: u
						 length: uslen(u)
					   freeWhenDone: YES] autorelease];
  return ret;
}

// #ifndef STRICT_OPENSTEP
+ (NSString*) pathWithComponents: (NSArray*)components
{
    NSString	*s = [self string];
    int		i;

    for (i = 0; i < [components count]; i++) {
	s = [s stringByAppendingPathComponent: [components objectAtIndex: i]];
    }
    return s;
}

- (BOOL) isAbsolutePath
{
    if ([self length] > 0 && [self characterAtIndex: 0] == (unichar)'/') {
	return YES;
    }
    return NO;
}

- (NSArray*) pathComponents
{
    NSMutableArray	*a;
    NSArray		*r;

    a = [[self componentsSeparatedByString: @"/"] mutableCopy];
    if ([a count] > 0) {
	int	i;

	/* If the path began with a '/' then the first path component must
	 * be a '/' rather than an empty string so that our output could be
	 * fed into [+pathWithComponents:]
         */
	if ([[a objectAtIndex: 0] length] == 0) {
	    [a replaceObjectAtIndex: 0 withObject: @"/"];
	}
	/* Any empty path components (except a trailing one) must be removed. */
	for (i = [a count] - 2; i > 0; i--) {
	    if ([[a objectAtIndex: i] length] == 0) {
		[a removeObjectAtIndex: i];
	    }
	}
    }
    r = [a copy];
    [a release];
    return [r autorelease];
}

- (NSArray*) stringsByAppendingPaths: (NSArray*)paths
{
    NSMutableArray	*a;
    NSArray		*r;
    int			i;

    a = [[NSMutableArray alloc] initWithCapacity: [paths count]];
    for (i = 0; i < [paths count]; i++) {
	NSString	*s = [paths objectAtIndex: i];

	while ([s isAbsolutePath]) {
	    s = [s substringFromIndex: 1];
	}
	s = [self stringByAppendingPathComponent: s];
	[a addObject: s];
    }
    r = [a copy];
    [a release];
    return [r autorelease];
}

+ (NSString*) localizedStringWithFormat: (NSString*) format, ...
{
  [self notImplemented:_cmd];
  return self;
}

- (NSComparisonResult) caseInsensitiveCompare: (NSString*)aString
{
  return [self compare:aString options:NSCaseInsensitiveSearch 
	       range:((NSRange){0, [self length]})];
}

- (BOOL) writeToFile: (NSString*)filename
   atomically: (BOOL)useAuxiliaryFile
{
  id d;
  if(!(d = [self dataUsingEncoding:[NSString defaultCStringEncoding]]))
    d = [self dataUsingEncoding: NSUnicodeStringEncoding];
  return [d writeToFile: filename atomically: useAuxiliaryFile];
}
// #endif

// #ifndef NO_GNUSTEP
// This method should be removed
- (const char *) cStringNoCopy
{
  [self subclassResponsibility: _cmd];
  return NULL;
}

- (NSString*) descriptionForPropertyList
{
    static NSCharacterSet	*quotables = nil;

    if (quotables == nil) {
	quotables = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
	[quotables retain];
    }

    if ([self length] == 0 ||
	[self rangeOfCharacterFromSet: quotables].length > 0) {
	const char	*cstring = [self cStringNoCopy];
	const char	*from;
	int		len = 0;

	for (from = cstring; *from; from++) {
	    switch (*from) {
		case '\a':
		case '\b':
		case '\t':
		case '\r':
		case '\n':
		case '\v':
		case '\f':
		case '\\':
		case '\'' :
		case '"' :
		    len += 2;
		    break;

		default:
		    if (isprint(*from) || *from == ' ') {
			len++;
		    }
		    else {
			len += 4;
		    }
		    break;
	    }
	}

	if (len == 0) {
	    return @"\"\"";
	}
	else {
	    char	buf[len+3];
	    char	*ptr = buf;
	    NSString	*result;

	    *ptr++ = '"';
	    for (from = cstring; *from; from++) {
		switch (*from) {
		    case '\a':	*ptr++ = '\\'; *ptr++ = 'a';  break;
		    case '\b':	*ptr++ = '\\'; *ptr++ = 'b';  break;
		    case '\t':	*ptr++ = '\\'; *ptr++ = 't';  break;
		    case '\r':	*ptr++ = '\\'; *ptr++ = 'r';  break;
		    case '\n':	*ptr++ = '\\'; *ptr++ = 'n';  break;
		    case '\v':	*ptr++ = '\\'; *ptr++ = 'v';  break;
		    case '\f':	*ptr++ = '\\'; *ptr++ = 'f';  break;
		    case '\\':	*ptr++ = '\\'; *ptr++ = '\\'; break;
		    case '\'':	*ptr++ = '\\'; *ptr++ = '\''; break;
		    case '"' :	*ptr++ = '\\'; *ptr++ = '"';  break;

		    default:
			if (isprint(*from) || *from == ' ') {
			    *ptr++ = *from;
			}
			else {
			    sprintf(ptr, "\\%03o", *(unsigned char*)from);
			    ptr = &ptr[4];
			}
			break;
		}
	    }
	    *ptr++ = '"';
	    *ptr = '\0';
	    result = [NSString stringWithCString: buf];
	    return result;
	}
    }
    return self;
}
// #endif /* NO_GNUSTEP */


/* NSCopying Protocol */

- copyWithZone: (NSZone*)zone
{
  if ([self isKindOfClass: [NSMutableString class]] ||
	NSShouldRetainWithZone(self, zone) == NO)
    return [[[[self class] _concreteClass] allocWithZone:zone]
	initWithString:self];
  else
    return [self retain];
}

/* xxx Temporarily put this NSObject-like implementation here, so
   we don't get String's Collection implementation. 
   When we separate Core from NonCore methods, this problem will
   go away. */
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


@implementation NSMutableString

+ allocWithZone: (NSZone*)z
{
  if ([self class] == [NSMutableString class])
    return NSAllocateObject([self _mutableConcreteClass], 0, z);
  return [super allocWithZone:z];
}

/* xxx This method may be removed in future. */
- (void) setCString: (const char *)byteString length: (unsigned)length
{
  [self subclassResponsibility:_cmd];
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
  n =  [[self alloc] initWithCharacters: characters length: length];
  return [n autorelease];
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

// Initializing Newly Allocated Strings

- initWithCapacity:(unsigned)capacity
{
  [self subclassResponsibility:_cmd];
  return self;
}

// Modify A String

- (void) appendString: (NSString*)aString
{
  NSRange aRange;

  aRange.location = [self length];
  aRange.length = 0;
  [self replaceCharactersInRange: aRange withString: aString];
}

/* Inefficient. */
- (void) appendFormat: (NSString*)format, ...
{
  va_list ap;
  id tmp;
  va_start(ap, format);
  tmp = [[NSString alloc] initWithFormat:format arguments:ap];
  va_end(ap);
  [self appendString:tmp];
  [tmp release];
}

- (void) deleteCharactersInRange: (NSRange)range
{
  [self replaceCharactersInRange:range withString:nil];
}

- (void) insertString: (NSString*)aString atIndex:(unsigned)loc
{
  NSRange range = {loc, 0};
  [self replaceCharactersInRange:range withString:aString];
}

- (void) replaceCharactersInRange: (NSRange)range 
   withString: (NSString*)aString
{
  [self subclassResponsibility:_cmd];
}

- (void) setString: (NSString*)aString
{
  NSRange range = {0, [self length]};
  [self replaceCharactersInRange:range withString:aString];
}

@end

@implementation NXConstantString

/*
 *	NXConstantString overrides [-dealloc] so that it is never deallocated.
 *	If we pass an NXConstantString to another process it will never get
 *	deallocated in the other process - causing a memory leak.  So we tell
 *	the DO system to use the super class instead.
 */
- (Class)classForPortCoder
{
  return [self superclass];
}

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

- (NSStringEncoding) fastestEncoding
{
  return NSASCIIStringEncoding;
}

- (NSStringEncoding) smallestEncoding
{
  return NSASCIIStringEncoding;
}

- (unichar) characterAtIndex: (unsigned int)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return (unichar)_contents_chars[index];
}

@end
