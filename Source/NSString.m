/* Implementation of GNUSTEP string class
   Copyright (C) 1995, 1996, 1997, 1998 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: January 1995

   Unicode implementation by Stevo Crvenkovski <stevo@btinternet.com>
   Date: February 1997

   Optimisations by Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: October 1998

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

/* Initial implementation of Unicode. Version 0.0.0 : )
   Locales not yet supported.
   Limited choice of default encodings.
*/

#include <config.h>
#include <base/preface.h>
#include <base/Coding.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSPathUtilities.h>

#include <base/IndexedCollection.h>
#include <Foundation/NSData.h>
#include <Foundation/NSBundle.h>
#include <base/IndexedCollectionPrivate.h>
#include <limits.h>
#include <string.h>		// for strstr()
#include <sys/stat.h>
#include <unistd.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdio.h>

#include <base/behavior.h>

#include <base/Unicode.h>
#include <base/GetDefEncoding.h>
#include <base/NSGString.h>
#include <base/NSGCString.h>

#include <base/fast.x>


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

static Class	NSString_class;		/* For speed	*/

/*
 *	Include sequence handling code with instructions to generate search
 *	and compare functions for NSString objects.
 */
#define	GSEQ_STRCOMP	strCompNsNs
#define	GSEQ_STRRANGE	strRangeNsNs
#define	GSEQ_O	GSEQ_NS
#define	GSEQ_S	GSEQ_NS
#include <GSeq.h>

/*
 *	Include property-list parsing code configured for unicode characters.
 */
#define	GSPLUNI	1
#include "propList.h"

static unichar		pathSepChar = (unichar)'/';
static NSString		*pathSepString = @"/";

/*
 *	We can't have a 'pathSeps' variable initialized in the  +initialize
 *	method 'cos that would cause recursion.
 */
static NSCharacterSet*
pathSeps()
{
  static NSCharacterSet	*pathSeps = nil;

  if (pathSeps == nil)
    {
#if defined(__WIN32__)
      pathSeps = [NSCharacterSet characterSetWithCharactersInString: @"/\\"];
#else
      pathSeps = [NSCharacterSet characterSetWithCharactersInString: @"/"];
#endif
      [pathSeps retain];
    }
  return pathSeps;
}


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
		[[string_object description] cString]);
  return len;
}
#endif /* HAVE_REGISTER_PRINTF_FUNCTION */

+ (void) initialize
{
  if (self == [NSString class])
    {
      _DefaultStringEncoding = GetDefEncoding();
      NSString_class = self;
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
  return [super allocWithZone: z];
}

// Creating Temporary Strings

+ (NSString*) string
{
  return [[[self allocWithZone: NSDefaultMallocZone()] init] autorelease];
}

+ (NSString*) stringWithString: (NSString*)aString
{
  return [[[self allocWithZone: NSDefaultMallocZone()]
    initWithString: aString] autorelease];
}

+ (NSString*) stringWithCharacters: (const unichar*)chars
			    length: (unsigned int)length
{
  return [[[self allocWithZone: NSDefaultMallocZone()]
    initWithCharacters: chars length: length]
         autorelease];
}

+ (NSString*) stringWithCString: (const char*) byteString
{
  return [[[NSString_c_concrete_class allocWithZone: NSDefaultMallocZone()]
    initWithCString: byteString] autorelease];
}

+ (NSString*) stringWithCString: (const char*)byteString
   length: (unsigned int)length
{
  return [[[NSString_c_concrete_class allocWithZone: NSDefaultMallocZone()]
    initWithCString: byteString length: length] autorelease];
}

+ (NSString*) stringWithContentsOfFile: (NSString *)path
{
  return [[[self allocWithZone: NSDefaultMallocZone()]
    initWithContentsOfFile: path] autorelease];
}

+ (NSString*) stringWithFormat: (NSString*)format,...
{
  va_list ap;
  id ret;

  va_start(ap, format);
  if (format == nil)
    ret = nil;
  else
    ret = [[[self allocWithZone: NSDefaultMallocZone()]
      initWithFormat: format arguments: ap] autorelease];
  va_end(ap);
  return ret;
}

+ (NSString*) stringWithFormat: (NSString*)format
   arguments: (va_list)argList
{
  return [[[self allocWithZone: NSDefaultMallocZone()]
    initWithFormat: format arguments: argList] autorelease];
}


// Initializing Newly Allocated Strings

/* This is the designated initializer for Unicode Strings. */
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		       fromZone: (NSZone*)zone
{
  [self subclassResponsibility: _cmd];
  return self;
}

- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  if (flag)
    return [self initWithCharactersNoCopy: chars
				   length: length
				 fromZone: NSZoneFromPointer(chars)];
  else
    return [self initWithCharactersNoCopy: chars
				   length: length
				 fromZone: 0];
  return self;
}

- (id) initWithCharacters: (const unichar*)chars
		   length: (unsigned int)length
{
    NSZone	*z = [self zone];
    unichar	*s = NSZoneMalloc(z, sizeof(unichar)*length);

    if (chars)
	memcpy(s, chars, sizeof(unichar)*length);

    return [self initWithCharactersNoCopy: s length: length fromZone: z];
}

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		freeWhenDone: (BOOL)flag
{
  if (flag)
    return [self initWithCStringNoCopy: byteString
				length: length
			      fromZone: NSZoneFromPointer(byteString)];
  else
    return [self initWithCStringNoCopy: byteString
				length: length
			      fromZone: 0];
}

/* This is the designated initializer for CStrings. */
- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		    fromZone: (NSZone*)zone
{
  [self subclassResponsibility: _cmd];
  return self;
}

- (id) initWithCString: (const char*)byteString  length: (unsigned int)length
{
    NSZone	*z = [self zone];
    char	*s = NSZoneMalloc(z, length);

    if (byteString)
	memcpy(s, byteString, length);
    return [self initWithCStringNoCopy: s length: length fromZone: z];
}

- (id) initWithCString: (const char*)byteString
{
  return [self initWithCString: byteString 
	       length: (byteString ? strlen(byteString) : 0)];
}

- (id) initWithString: (NSString*)string
{
    NSZone	*z = [self zone];
    unsigned	length = [string length];
    unichar	*s = NSZoneMalloc(z, sizeof(unichar)*length);

    [string getCharacters: s];
    return [self initWithCharactersNoCopy: s
				   length: length
				 fromZone: z];
}

- (id) initWithFormat: (NSString*)format,...
{
  va_list ap;
  va_start(ap, format);
  self = [self initWithFormat: format arguments: ap];
  va_end(ap);
  return self;
}

/* xxx Change this when we have non-CString classes */
- (id) initWithFormat: (NSString*)format
   arguments: (va_list)arg_list
{
#if HAVE_VSPRINTF
  const char *format_cp = [format cString];
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
	cstring = [[(id) va_arg (arg_list, id) description] cString];
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
  return [self initWithCString: buf];
#else /* HAVE_VSPRINTF */
  [self notImplemented: _cmd];
  return self;
#endif
}

- (id) initWithFormat: (NSString*)format
   locale: (NSDictionary*)dictionary
{
  [self notImplemented: _cmd];
  return self;
}

- (id) initWithFormat: (NSString*)format
   locale: (NSDictionary*)dictionary
   arguments: (va_list)argList
{
  [self notImplemented: _cmd];
  return self;
}

- (id) initWithData: (NSData*)data
   encoding: (NSStringEncoding)encoding
{
  if ((encoding==[NSString defaultCStringEncoding])
    || (encoding==NSASCIIStringEncoding))
    {
      NSZone *z = fastZone(self);
      int len=[data length];
      char *s = NSZoneMalloc(z, len+1);

      [data getBytes: s];
      return [self initWithCStringNoCopy: s length: len fromZone: z];
    }
  else
    {
      NSZone *z = fastZone(self);
      int len=[data length];
      unichar *u = NSZoneMalloc(z, sizeof(unichar)*(len+1));
      int count;
      const unsigned char *b=[data bytes];

      if (encoding==NSUnicodeStringEncoding)
        {
	  if ((b[0]==0xFE)&(b[1]==0xFF))
	    for(count=2;count<(len-1);count+=2)
	      u[count/2 - 1]=256*b[count]+b[count+1];
	  else
	    for(count=2;count<(len-1);count+=2)
	      u[count/2 -1]=256*b[count+1]+b[count];
	  count = count/2 -1;
	}
      else
	count = encode_strtoustr(u,b,len,encoding);

      return [self initWithCharactersNoCopy: u length: count fromZone: z];
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
  if (test && (((test[0]==0xFF) && (test[1]==0xFE)) || ((test[1]==0xFF) && (test[0]==0xFE))))
    enc = NSUnicodeStringEncoding;
  else
    enc = [NSString defaultCStringEncoding];
  return [self initWithData: d encoding: enc];
}

- (id) init
{
 self = [super init];
 return self;
}

// Getting a String's Length

- (unsigned int) length
{
  [self subclassResponsibility: _cmd];
  return 0;
}

// Accessing Characters

- (unichar) characterAtIndex: (unsigned int)index
{
  [self subclassResponsibility: _cmd];
  return (unichar)0;
}

/* Inefficient.  Should be overridden */
- (void) getCharacters: (unichar*)buffer
{
  [self getCharacters: buffer range: ((NSRange){0,[self length]})];
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
	      [NSString stringWithFormat: format arguments: ap]];
  va_end(ap);
  return ret;
}

- (NSString*) stringByAppendingString: (NSString*)aString
{
  NSZone *z = fastZone(self);
  unsigned len = [self length];
  unsigned otherLength = [aString length];
  unichar *s = NSZoneMalloc(z, (len+otherLength)*sizeof(unichar));
  NSString *tmp;

  [self getCharacters: s];
  [aString getCharacters: s+len];
  tmp = [[[self class] allocWithZone: z] initWithCharactersNoCopy: s
		    length: len+otherLength fromZone: z];
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
  return [self substringFromRange: ((NSRange){index, [self length]-index})];
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  NSZone *z;
  unichar *buf;
  id ret;

  if (aRange.location > [self length])
    [NSException raise: NSRangeException format: @"Invalid location."];
  if (aRange.length > ([self length] - aRange.location))
    [NSException raise: NSRangeException format: @"Invalid location+length."];
  if (aRange.length == 0)
    return @"";
  z = fastZone(self);
  buf = NSZoneMalloc(z, sizeof(unichar)*aRange.length);
  [self getCharacters: buf range: aRange];
  ret = [[[self class] allocWithZone: NSDefaultMallocZone()]
    initWithCharactersNoCopy: buf length: aRange.length fromZone: z];
  return [ret autorelease];
}

- (NSString*) substringWithRange: (NSRange)aRange
{
  return [self substringFromRange: aRange];
}

- (NSString*) substringToIndex: (unsigned int)index
{
  return [self substringFromRange: ((NSRange){0,index})];;
}

// Finding Ranges of Characters and Substrings

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
{
  NSRange all = NSMakeRange(0, [self length]);
  return [self rangeOfCharacterFromSet: aSet
		options: 0
		range: all];
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned int)mask
{
  NSRange all = NSMakeRange(0, [self length]);
  return [self rangeOfCharacterFromSet: aSet
		options: mask
		range: all];
}

/* xxx FIXME */
- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned int)mask
			      range: (NSRange)aRange
{
  int i, start, stop, step;
  NSRange range;
  unichar	(*cImp)(id, SEL, unsigned);
  BOOL		(*mImp)(id, SEL, unichar);

  i = [self length];
  if (aRange.location > i)
    [NSException raise: NSRangeException format: @"Invalid location."];
  if (aRange.length > (i - aRange.location))
    [NSException raise: NSRangeException format: @"Invalid location+length."];

  if ((mask & NSBackwardsSearch) == NSBackwardsSearch)
    {
      start = NSMaxRange(aRange)-1; stop = aRange.location-1; step = -1;
    }
  else
    {
      start = aRange.location; stop = NSMaxRange(aRange); step = 1;
    }
  range.location = 0;
  range.length = 0;

  cImp = (unichar(*)(id,SEL,unsigned)) [self methodForSelector: caiSel];
  mImp = (BOOL(*)(id,SEL,unichar))
    [aSet methodForSelector: cMemberSel];

  for (i = start; i != stop; i += step)
    {
      unichar letter = (unichar)(*cImp)(self, caiSel, i);
      if ((*mImp)(aSet, cMemberSel, letter))
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
  return [self rangeOfString: string
		options: 0
		range: all];
}

- (NSRange) rangeOfString: (NSString*)string
		  options: (unsigned int)mask
{
  NSRange all = NSMakeRange(0, [self length]);
  return [self rangeOfString: string
		options: mask
		range: all];
}

- (NSRange) rangeOfString: (NSString *) aString
		  options: (unsigned int) mask
		    range: (NSRange) aRange
{
  return strRangeNsNs(self, aString, mask, aRange);
}

// Determining Composed Character Sequences

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned int)anIndex
{
  unsigned	start;
  unsigned	end;
  unsigned	length = [self length];

  if (anIndex >= length)
    [NSException raise: NSRangeException format:@"Invalid location."];
  start = anIndex;
  while (uni_isnonsp([self characterAtIndex: start]) && start > 0)
    start--;
  end=start+1;
  if (end < length)
    while ((end < length) && (uni_isnonsp([self characterAtIndex: end])) )
      end++;
  return NSMakeRange(start, end-start);
}

// Identifying and Comparing Strings

- (NSComparisonResult) compare: (NSString*)aString
{
  return [self compare: aString options: 0];
}

- (NSComparisonResult) compare: (NSString*)aString	
		       options: (unsigned int)mask
{
  return [self compare: aString options: mask 
		 range: ((NSRange){0, [self length]})];
}

// xxx Should implement full POSIX.2 collate
- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  return strCompNsNs(self, aString, mask, aRange);
}

- (BOOL) hasPrefix: (NSString*)aString
{
  NSRange range;
  range = [self rangeOfString: aString];
  return ((range.location == 0) && (range.length != 0)) ? YES : NO;
}

- (BOOL) hasSuffix: (NSString*)aString
{
  NSRange range;
  range = [self rangeOfString: aString options: NSBackwardsSearch];
  return (range.length > 0 && range.location == ([self length] - [aString length])) ? YES : NO;
}

- (BOOL) isEqual: (id)anObject
{
    if (anObject == self) {
	return YES;
    }
    if (anObject != nil) {
	Class c = fastClassOfInstance(anObject);

	if (c != nil) {
	    if (fastClassIsKindOfClass(c, NSString_class)) {
		return [self isEqualToString: anObject];
	    }
	}
    }
    return NO;
}

- (BOOL) isEqualToString: (NSString*)aString
{
  if ([self hash] != [aString hash])
    return NO;
  if (strCompNsNs(self, aString, 0, (NSRange){0, [self length]})
    == NSOrderedSame)
    return YES;
  return NO;
}

- (unsigned int) hash
{
  unsigned ret = 0;

  int len = [self length];

  if (len > NSHashStringLength)
    len = NSHashStringLength;
  if (len)
    {
      unichar		buf[len * MAXDEC + 1];
      GSeqStruct	s = { buf, len, len * MAXDEC, 0 };
      unichar		*p;
      unsigned		char_count = 0;

      [self getCharacters: buf range: NSMakeRange(0,len)];
      GSeq_normalize(&s);

      p = buf;

      while (*p && char_count++ < NSHashStringLength)
	{
	  ret = (ret << 5) + ret + *p++;
	}

      /*
       * The hash caching in our concrete string classes uses zero to denote
       * an empty cache value, so we MUST NOT return a hash of zero.
       */
      if (ret == 0)
	ret = 0xffffffff;
      return ret;
    }
  else
    return 0xfffffffe;	/* Hash for an empty string.	*/
}

// Getting a Shared Prefix

- (NSString*) commonPrefixWithString: (NSString*)aString
			     options: (unsigned int)mask
{
  if (mask & NSLiteralSearch)
    {
      int prefix_len = 0;
      unichar *u,*w;
      unichar a1[[self length]+1];
      unichar *s1 = a1;
      unichar a2[[aString length]+1];
      unichar *s2 = a2;

      u = s1;
      [self getCharacters: s1];
      s1[[self length]] = (unichar)0;
      [aString getCharacters: s2];
      s2[[aString length]] = (unichar)0;
      u = s1;
      w = s2;

      if (mask & NSCaseInsensitiveSearch)
	{
	  while (*s1 && *s2 && (uni_tolower(*s1) == uni_tolower(*s2)))
	    {
	      s1++;
	      s2++;
	      prefix_len++;
	    }
	}
      else
	{
	  while (*s1 && *s2 && (*s1 == *s2))	     
	    {
	      s1++;
	      s2++;
	      prefix_len++;
	    }
	}
      return [NSString stringWithCharacters: u length: prefix_len];
    }
  else
    {
      unichar	(*scImp)(NSString*, SEL, unsigned);
      unichar	(*ocImp)(NSString*, SEL, unsigned);
      void	(*sgImp)(NSString*, SEL, unichar*, NSRange);
      void	(*ogImp)(NSString*, SEL, unichar*, NSRange);
      NSRange	(*srImp)(NSString*, SEL, unsigned);
      NSRange	(*orImp)(NSString*, SEL, unsigned);
      BOOL	gotRangeImps = NO;
      BOOL	gotFetchImps = NO;
      NSRange	sRange;
      NSRange	oRange;
      unsigned	sLength = [self length];
      unsigned	oLength = [aString length];
      unsigned	sIndex = 0;
      unsigned	oIndex = 0;

      if (!sLength)
	return self;
      if (!oLength)
	return aString;

      scImp = (unichar (*)())[self methodForSelector: caiSel];
      ocImp = (unichar (*)())[aString methodForSelector: caiSel];

      while ((sIndex < sLength) && (oIndex < oLength))
	{
	  unichar	sc = (*scImp)(self, caiSel, sIndex);
	  unichar	oc = (*ocImp)(aString, caiSel, oIndex);

	  if (sc == oc)
	    {
	      sIndex++;
	      oIndex++;
	    }
	  else if ((mask & NSCaseInsensitiveSearch)
	    && (uni_tolower(sc) == uni_tolower(oc)))
	    {
	      sIndex++;
	      oIndex++;
	    }
	  else
	    {
	      if (gotRangeImps == NO)
		{
		  gotRangeImps = YES;
		  srImp=(NSRange (*)())[self methodForSelector: ranSel];
		  orImp=(NSRange (*)())[aString methodForSelector: ranSel];
		}
	      sRange = (*srImp)(self, ranSel, sIndex);
	      oRange = (*orImp)(aString, ranSel, oIndex);

	      if ((sRange.length < 2) || (oRange.length < 2))
		return [self substringFromRange: NSMakeRange(0, sIndex)];
	      else
		{
		  GSEQ_MAKE(sBuf, sSeq, sRange.length);
		  GSEQ_MAKE(oBuf, oSeq, oRange.length);

		  if (gotFetchImps == NO)
		    {
		      gotFetchImps = YES;
		      sgImp=(void (*)())[self methodForSelector: gcrSel];
		      ogImp=(void (*)())[aString methodForSelector: gcrSel];
		    }
		  (*sgImp)(self, gcrSel, sBuf, sRange);
		  (*ogImp)(aString, gcrSel, oBuf, oRange);

		  if (GSeq_compare(&sSeq, &oSeq) == NSOrderedSame)
		    {
		      sIndex += sRange.length;
		      oIndex += oRange.length;
		    }
		  else if (mask & NSCaseInsensitiveSearch)
		    {
		      GSeq_lowercase(&sSeq);
		      GSeq_lowercase(&oSeq);
		      if (GSeq_compare(&sSeq, &oSeq) == NSOrderedSame)
			{
			  sIndex += sRange.length;
			  oIndex += oRange.length;
			}
		      else
			return [self substringFromRange: NSMakeRange(0,sIndex)];
		    }
		  else
		    return [self substringFromRange: NSMakeRange(0,sIndex)];
		}
	    }
	}
      return [self substringFromRange: NSMakeRange(0, sIndex)];
    }
}

- (NSRange) lineRangeForRange: (NSRange)aRange
{
  unsigned int startIndex;
  unsigned int lineEndIndex;

  [self getLineStart: &startIndex
                 end: &lineEndIndex
         contentsEnd: NULL
            forRange: aRange];
  return NSMakeRange(startIndex, lineEndIndex - startIndex);
}

- (void)getLineStart: (unsigned int *)startIndex
                 end: (unsigned int *)lineEndIndex
         contentsEnd: (unsigned int *)contentsEndIndex
         forRange: (NSRange)aRange
{
  unichar thischar;
  BOOL done;
  unsigned int start, end, len;

  if (aRange.location > [self length])
    [NSException raise: NSRangeException format: @"Invalid location."];
  if (aRange.length > ([self length] - aRange.location))
    [NSException raise: NSRangeException format: @"Invalid location+length."];

  len = [self length];
  start=aRange.location;

  if (startIndex)
    if (start==0)
      *startIndex=0;
    else
    {
      start--;
      while (start>0)
      {
        BOOL done = NO;
        thischar = [self characterAtIndex: start];
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
        if (done)
          break;
      };
      if (start == 0)
      {
         thischar = [self characterAtIndex: start];
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

  if (lineEndIndex || contentsEndIndex)
  {
    end=aRange.location+aRange.length;
    while (end<len)
    {
       BOOL done = NO;
       thischar = [self characterAtIndex: end];
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
       if (done)
         break;
    };
    if (end<len)
    {
      if ([self characterAtIndex: end]==(unichar)0x000D)
        if ([self characterAtIndex: end+1]==(unichar)0x000A)
          *lineEndIndex = end+1;
        else  *lineEndIndex = end;
      else  *lineEndIndex = end;
    }
    else
    *lineEndIndex = end;
  };

  if (contentsEndIndex)
  {
    if (end<len)
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
  NSZone *z = fastZone(self);
  unichar *s;
  int count=0;
  BOOL found=YES;
  int len=[self length];

  if (whitespce == nil)
    setupWhitespce();

  s = NSZoneMalloc(z, sizeof(unichar)*(len+1));
  [self getCharacters: s];
  s[len] = (unichar)0;
  while (count<len)
  {
    if ((*whitespceImp)(whitespce, cMemberSel, s[count]))
    {
      count++;
      found=YES;
      while ((*whitespceImp)(whitespce, cMemberSel, s[count]) && (count < len))
        count++;
    };
    if (found)
    {
      s[count]=uni_toupper(s[count]);
      count++;
    }
    else
    {
      while (!(*whitespceImp)(whitespce, cMemberSel, s[count]) && (count < len))
      {
        s[count]=uni_tolower(s[count]);
        count++;
      };
    };
    found=NO;
  };
  return [[[NSString allocWithZone: NSDefaultMallocZone()]
    initWithCharactersNoCopy: s length: len fromZone: z] autorelease];
}

- (NSString*) lowercaseString
{
  NSZone *z = fastZone(self);
  unichar *s;
  int count;
  int len=[self length];
  s = NSZoneMalloc(z, sizeof(unichar)*(len+1));
  for(count=0;count<len;count++)
    s[count]=uni_tolower([self characterAtIndex: count]);
  return [[[[self class] allocWithZone: NSDefaultMallocZone()]
    initWithCharactersNoCopy: s
						  length: len
					        fromZone: z] autorelease];
}

- (NSString*) uppercaseString;
{
  NSZone *z = fastZone(self);
  unichar *s;
  int count;
  int len=[self length];
  s = NSZoneMalloc(z, sizeof(unichar)*(len+1));
  for(count=0;count<len;count++)
    s[count]=uni_toupper([self characterAtIndex: count]);
  return [[[[self class] allocWithZone: NSDefaultMallocZone()]
    initWithCharactersNoCopy: s length: len fromZone: z] autorelease];
}

// Storing the String

- (NSString*) description
{
  return self;
}


// Getting C Strings

- (const char*) cString
{
  [self subclassResponsibility: _cmd];
  return NULL;
}

- (unsigned int) cStringLength
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) getCString: (char*)buffer
{
  [self getCString: buffer maxLength: NSMaximumStringLength
	range: ((NSRange){0, [self length]})
	remainingRange: NULL];
}

- (void) getCString: (char*)buffer
    maxLength: (unsigned int)maxLength
{
  [self getCString: buffer maxLength: maxLength 
	range: ((NSRange){0, [self length]})
	remainingRange: NULL];
}

// xxx FIXME adjust range for composite sequence
- (void) getCString: (char*)buffer
   maxLength: (unsigned int)maxLength
   range: (NSRange)aRange
   remainingRange: (NSRange*)leftoverRange
{
  int len, count;

  len = [self cStringLength];
  if (aRange.location > len)
    [NSException raise: NSRangeException format: @"Invalid location."];
  if (aRange.length > (len - aRange.location))
    [NSException raise: NSRangeException format: @"Invalid location+length."];

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
  while (count<len)
  {
    buffer[count]=unitochar([self characterAtIndex: aRange.location + count]);
    count++;
   }
  buffer[len] = '\0';
}


// Getting Numeric Values

// xxx Sould we use NSScanner here ?

- (BOOL) boolValue
{
    if ([self caseInsensitiveCompare: @"YES"] == NSOrderedSame) 
	return YES;
    return [self intValue] != 0 ? YES : NO;
}

- (double) doubleValue
{
  return atof([self cString]);
}

- (float) floatValue
{
  return (float) atof([self cString]);
}

- (int) intValue
{
  return atoi([self cString]);
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

+ (NSString*)localizedNameOfStringEncoding: (NSStringEncoding)encoding
{
  id ourbundle;
  id ourname;

/*
      Should be path to localizable.strings file.
      Until we have it, just make shure that bundle
      is initialized.
*/
  ourbundle = [NSBundle bundleWithPath: @"/"];

  ourname = GetEncodingName(encoding);
  return [ourbundle
            localizedStringForKey: ourname
            value: ourname
            table: nil];
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

  if ((encoding==NSASCIIStringEncoding)
    || (encoding==NSISOLatin1StringEncoding)
    || (encoding==NSNEXTSTEPStringEncoding)
    || (encoding==NSNonLossyASCIIStringEncoding)
    || (encoding==NSSymbolStringEncoding)
    || (encoding==NSCyrillicStringEncoding))
    {
      char t;
      unsigned char *buff;

      buff = (unsigned char*)NSZoneMalloc(NSDefaultMallocZone(), len);
      if (!flag)
	{
	  for (count = 0; count < len; count++)
	    {
	      t = encode_unitochar([self characterAtIndex: count], encoding);
	      if (t)
		{
		  buff[count] = t;
		}
	      else
		{
		  NSZoneFree(NSDefaultMallocZone(), buff);
		  return nil;
		}
	    }
	}
      else /* lossy */
	{
	  for (count = 0; count < len; count++)
	    {
	      t = encode_unitochar([self characterAtIndex: count], encoding);
	      if (t)
		{
		  buff[count] = t;
		}
	      else
		{
		  /* xxx should handle decomposed characters */
		  /* OpenStep documentation is unclear on what to do
		   * if there is no simple replacement for character
		   */
		  buff[count] = '*';
		}
	    }
	}
      return [NSData dataWithBytesNoCopy: buff length: count];
    }
  else if (encoding == NSUnicodeStringEncoding)
    {
      unichar *buff;

      buff = (unichar*)NSZoneMalloc(NSDefaultMallocZone(), 2*len+2);
      buff[0]=0xFEFF;
      for (count = 0; count < len; count++)
	buff[count+1] = [self characterAtIndex: count];
      return [NSData dataWithBytesNoCopy: buff length: 2*len+2];
    }
  else /* UTF8 or EUC */
    {
      [self notImplemented: _cmd];
    }
  return nil;
}

- (NSStringEncoding) fastestEncoding
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSStringEncoding) smallestEncoding
{
  [self subclassResponsibility: _cmd];
  return 0;
}


// Manipulating File System Paths

- (unsigned int) completePathIntoString: (NSString**)outputName
			  caseSensitive: (BOOL)flag
		       matchesIntoArray: (NSArray**)outputArray
			    filterTypes: (NSArray*)filterTypes
{
  NSString * base_path = [self stringByDeletingLastPathComponent];
  NSString * last_compo = [self lastPathComponent];
  NSString * tmp_path;
  NSDirectoryEnumerator * e;
  NSMutableArray	*op;
  int match_count = 0;

  if (outputArray != 0)
    op = (NSMutableArray*)[NSMutableArray array];

  if (outputName != NULL) *outputName = nil;

  if ([base_path length] == 0) base_path = @".";

  e = [[NSFileManager defaultManager] enumeratorAtPath: base_path];
  while (tmp_path = [e nextObject], tmp_path)
    {
      /* Prefix matching */
      if (YES == flag)
	{ /* Case sensitive */
	  if (NO == [tmp_path hasPrefix: last_compo])
	    continue ;
	}
      else
	{
	  if (NO == [[tmp_path uppercaseString]
		      hasPrefix: [last_compo uppercaseString]])
	    continue;
	}

      /* Extensions filtering */
      if (filterTypes &&
	  (NO == [filterTypes containsObject: [tmp_path pathExtension]]))
	continue ;

      /* Found a completion */
      match_count++;
      if (outputArray != NULL)
	[*op addObject: tmp_path];
      
      if ((outputName != NULL) && 
	((*outputName == nil) || (([*outputName length] < [tmp_path length]))))
	*outputName = tmp_path;
    }
  if (outputArray != NULL)
    *outputArray = [[op copy] autorelease];
  return match_count;
}

/* Return a string for passing to OS calls to handle file system objects. */
- (const char*)fileSystemRepresentation
{
  return [self cString];
}

- (BOOL)getFileSystemRepresentation: (char*)buffer maxLength: (unsigned int)size
{
  const char* ptr = [self cString];
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

  range = [self rangeOfCharacterFromSet: pathSeps() options: NSBackwardsSearch];
  if (range.length == 0)
    substring = [[self copy] autorelease];
  else if (range.location == ([self length] - 1))
    {
      if (range.location == 0)
	substring = [[NSString new] autorelease];
      else
	substring = [[self substringToIndex: range.location] 
		      lastPathComponent];
    }
  else
    substring = [self substringFromIndex: range.location + 1];

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

  range = [self rangeOfString: @"." options: NSBackwardsSearch];
  if (range.length == 0) 
    substring = nil;
  else
    {
      NSRange range2 = [self rangeOfCharacterFromSet: pathSeps()
				 options: NSBackwardsSearch];
      if (range2.length > 0 && range.location < range2.location)
	substring = nil;
      else
	substring = [self substringFromIndex: range.location + 1];
    }

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

  range = [aString rangeOfCharacterFromSet: pathSeps()];
  if (range.length != 0 && range.location == 0)
      [NSException raise: NSGenericException
		     format: @"attempt to append illegal path component"];

  range = [self rangeOfCharacterFromSet: pathSeps() options: NSBackwardsSearch];
  if ((range.length == 0 || range.location != [self length] - 1) && [self length] > 0)

      newstring = [self stringByAppendingString: pathSepString];
  else
      newstring = self;

  return [newstring stringByAppendingString: aString];
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

  range = [aString rangeOfString: @"."];
  if (range.length != 0 && range.location == 0)
    [NSException raise: NSGenericException
	     format: @"attempt to append illegal path extension"];

  range = [self rangeOfString: @"." options: NSBackwardsSearch];
  if (range.length == 0 || range.location != [self length] - 1)
      newstring = [self stringByAppendingString: @"."];
  else
      newstring = self;

  return [newstring stringByAppendingString: aString];
}

/* Returns a new string with the last path component removed from the
  receiver.  See lastPathComponent for a definition of a path component */
- (NSString*) stringByDeletingLastPathComponent
{
  NSRange range;
  NSString *substring;

  range = [self rangeOfString: [self lastPathComponent] 
		      options: NSBackwardsSearch];

  if (range.length == 0)
    substring = [[self copy] autorelease];
  else if (range.location == 0)
    substring = [[NSString new] autorelease];
  else if (range.location > 1)
    substring = [self substringToIndex: range.location-1];
  else
    substring = pathSepString;
  return substring;
}

/* Returns a new string with the path extension removed from the receiver.
   See pathExtension for a definition of the path extension */
- (NSString*) stringByDeletingPathExtension
{
  NSRange range;
  NSString *substring;

  range = [self rangeOfString: [self pathExtension] options: NSBackwardsSearch];
  if (range.length != 0)
    substring = [self substringToIndex: range.location-1];
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

  first_slash_range = [self rangeOfString: pathSepString];

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

  return [NSString stringWithFormat: @"~%c%@", (char)pathSepChar,
		   [self substringFromIndex: [homedir length] + 1]];
}

- (NSString*) stringByResolvingSymlinksInPath
{
#if defined(__WIN32__)
  return self;
#else 
  NSString *first_half = self, * second_half = @"";

  const char * tmp_cpath;
  const int MAX_PATH_LEN = 1024;
  char tmp_buf[MAX_PATH_LEN];

  int syscall_result;
  struct stat tmp_stat;  

  while (1)
    {
      tmp_cpath = [first_half cString];

      syscall_result = lstat(tmp_cpath, &tmp_stat);
      if (0 != syscall_result)  return self ;
      
      if ((tmp_stat.st_mode & S_IFLNK) &&
	  ((syscall_result = readlink(tmp_cpath, tmp_buf, MAX_PATH_LEN)) != -1))
	{
	  /* 
	   * first half is a path to a symbolic link.
	   */
	  tmp_buf[syscall_result] = '\0'; // Make a C string
	  second_half 		  = [[NSString stringWithCString: tmp_buf]
				      stringByAppendingPathComponent: second_half];
	  first_half = [first_half stringByDeletingLastPathComponent];
	}
      else
	{
	  /* 
	   * second_half is an absolute path 
	   */
	  if ([second_half hasPrefix: @"/"]) 
	    return [second_half stringByResolvingSymlinksInPath];

	  /* 
	   * first half is NOT a path to a symbolic link 
	   */
	  second_half = [[first_half lastPathComponent]
			  stringByAppendingPathComponent: second_half];
	  first_half = [first_half stringByDeletingLastPathComponent];
	}

      /* BREAK CONDITION */
      if ([first_half length] == 0) break;
      else if ([first_half length] == 1
	&& [pathSeps() characterIsMember: [first_half characterAtIndex: 0]])
	{
	  second_half = [pathSepString stringByAppendingPathComponent: second_half];
	  break;
	}
    }
  return second_half;
#endif  /* (__WIN32__) */  
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
  while ((r = [s rangeOfCharacterFromSet: pathSeps()]).length
      && r.location + r.length < [s length]
      && [pathSeps() characterIsMember: [s characterAtIndex: r.location + 1]])
    [s deleteCharactersInRange: r];

  /* Condense `/./' */
  while ((r = [s rangeOfCharacterFromSet: pathSeps()]).length
      && r.location + r.length < [s length] + 1
      && [s characterAtIndex: r.location + 1] == (unichar)'.'
      && [pathSeps() characterIsMember: [s characterAtIndex: r.location + 2]])
    {
      r.length++;
      [s deleteCharactersInRange: r];
    }

  /* Condense `/../' */
  while ((r = [s rangeOfCharacterFromSet: pathSeps()]).length
      && r.location + r.length < [s length] + 2
      && [s characterAtIndex: r.location + 1] == (unichar)'.'
      && [s characterAtIndex: r.location + 2] == (unichar)'.'
      && [pathSeps() characterIsMember: [s characterAtIndex: r.location + 3]])
    {
      if (r.location > 0)
	{
	  NSRange r2 = {0, r.location};
	  r = [s rangeOfCharacterFromSet: pathSeps()
				 options: NSBackwardsSearch
				   range: r2];
	  if (r.length == 0)
	    r = r2;
	  r.length += 4;		/* Add the `/../' */
	}
      [s deleteCharactersInRange: r];
    }

  return s;
}

// private methods for Unicode level 3 implementation
- (int) _baseLength
{
  int		blen = 0;
  unsigned	len = [self length];

  if (len > 0)
    {
      int	count = 0;
      unichar	(*caiImp)() = (unichar (*)())[self methodForSelector: caiSel];

      while (count < len)
	if (!uni_isnonsp((*caiImp)(self, caiSel, count++)))
	  blen++;
    }
  return blen;
} 

+ (NSString*) pathWithComponents: (NSArray*)components
{
    NSString    *s = [components objectAtIndex: 0];
    int		i;

    for (i = 1; i < [components count]; i++) {
	s = [s stringByAppendingPathComponent: [components objectAtIndex: i]];
    }
    return s;
}

- (BOOL) isAbsolutePath
{
  if ([self length] == 0)
    return NO;

#if defined(__WIN32__)
  if ([self indexOfString: @": "] != NSNotFound)
    return YES;
#else
  if ([self characterAtIndex: 0] == (unichar)'/')
    return YES;
  if ([self characterAtIndex: 0] == (unichar)'~')
    return YES;
#endif
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
	 * fed into [+pathWithComponents: ]
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

  a = [[NSMutableArray allocWithZone: NSDefaultMallocZone()]
    initWithCapacity: [paths count]];
  for (i = 0; i < [paths count]; i++)
    {
      NSString	*s = [paths objectAtIndex: i];

      while ([s isAbsolutePath])
	{
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
  [self notImplemented: _cmd];
  return self;
}

- (NSComparisonResult) caseInsensitiveCompare: (NSString*)aString
{
  return [self compare: aString options: NSCaseInsensitiveSearch 
	       range: ((NSRange){0, [self length]})];
}

- (BOOL) writeToFile: (NSString*)filename
   atomically: (BOOL)useAuxiliaryFile
{
  id d;
  if (!(d = [self dataUsingEncoding: [NSString defaultCStringEncoding]]))
    d = [self dataUsingEncoding: NSUnicodeStringEncoding];
  return [d writeToFile: filename atomically: useAuxiliaryFile];
}

- (void) descriptionTo: (id<GNUDescriptionDestination>)output
{
  if ([self length] == 0)
    {
      [output appendString: @"\"\""];
      return;
    }

  if (quotables == nil)
    setupQuotables();

  if ([self rangeOfCharacterFromSet: quotables].length > 0)
    {
      const char	*cstring = [self cString];
      const char	*from;
      int		len = 0;

      for (from = cstring; *from; from++)
	{
	  switch (*from)
	    {
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
		if (isprint(*from) || *from == ' ')
		  {
		    len++;
		  }
		else
		  {
		    len += 4;
		  }
		break;
	    }
	}

      {
	char	buf[len+3];
	char	*ptr = buf;

	*ptr++ = '"';
	for (from = cstring; *from; from++)
	  {
	    switch (*from)
	      {
		case '\a': 	*ptr++ = '\\'; *ptr++ = 'a';  break;
		case '\b': 	*ptr++ = '\\'; *ptr++ = 'b';  break;
		case '\t': 	*ptr++ = '\\'; *ptr++ = 't';  break;
		case '\r': 	*ptr++ = '\\'; *ptr++ = 'r';  break;
		case '\n': 	*ptr++ = '\\'; *ptr++ = 'n';  break;
		case '\v': 	*ptr++ = '\\'; *ptr++ = 'v';  break;
		case '\f': 	*ptr++ = '\\'; *ptr++ = 'f';  break;
		case '\\': 	*ptr++ = '\\'; *ptr++ = '\\'; break;
		case '\'': 	*ptr++ = '\\'; *ptr++ = '\''; break;
		case '"' : 	*ptr++ = '\\'; *ptr++ = '"';  break;

		default: 
		  if (isprint(*from) || *from == ' ')
		    {
		      *ptr++ = *from;
		    }
		  else
		    {
		      sprintf(ptr, "\\%03o", *(unsigned char*)from);
		      ptr = &ptr[4];
		    }
		  break;
	      }
	  }
	*ptr++ = '"';
	*ptr = '\0';
	[output appendString: [NSString stringWithCString: buf]];
      }
    }
  else
    {
      [output appendString: self];
    }
}


/* NSCopying Protocol */

- copyWithZone: (NSZone*)zone
{
  if ([self isKindOfClass: [NSMutableString class]] ||
	NSShouldRetainWithZone(self, zone) == NO)
    return [[[[self class] _concreteClass] allocWithZone: zone]
	initWithString: self];
  else
    return [self retain];
}

- mutableCopyWithZone: (NSZone*)zone
{
  return [[[[self class] _mutableConcreteClass] allocWithZone: zone]
	  initWithString: self];
}

/* NSCoding Protocol */

- (void) encodeWithCoder: anEncoder
{
    [self subclassResponsibility: _cmd];
}

- initWithCoder: aDecoder
{
    [self subclassResponsibility: _cmd];
    return self;
}

- (Class) classForArchiver
{
  return [self class];
}

- (Class) classForCoder
{
  return [self class];
}

- (Class) classForPortCoder
{
  return [self class];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  if ([aCoder isByref] == NO)
    return self;
  return [super replacementObjectForPortCoder: aCoder];
}

- (id) propertyList
{
  unsigned	len = [self length];
  unichar	chars[len];
  id		result;
  pldata	data;

  data.ptr = chars;
  data.pos = 0;
  data.end = len;
  data.lin = 1;
  data.err = nil;

  [self getCharacters: chars];
  if (plInit == 0)
    setupPl([NSGString class]);

  result = parsePlItem(&data);

  if (result == nil && data.err != nil)
    {
      [NSException raise: NSGenericException
		  format: @"%@ at line %u", data.err, data.lin];
    }
  return result;
}

- (NSDictionary*) propertyListFromStringsFileFormat
{
  unsigned	len = [self length];
  unichar	chars[len];
  id		result;
  pldata	data;

  data.ptr = chars;
  data.pos = 0;
  data.end = len;
  data.lin = 1;
  data.err = nil;

  [self getCharacters: chars];
  if (plInit == 0)
    setupPl([NSGString class]);

  result = parseSfItem(&data);
  if (result == nil && data.err != nil)
    {
      [NSException raise: NSGenericException
		  format: @"%@ at line %u", data.err, data.lin];
    }
  return result;
}

@end


@implementation NSMutableString

+ allocWithZone: (NSZone*)z
{
  if ([self class] == [NSMutableString class])
    return NSAllocateObject([self _mutableConcreteClass], 0, z);
  return [super allocWithZone: z];
}

// Creating Temporary Strings

+ (NSMutableString*) stringWithCapacity: (unsigned)capacity
{
  return [[[self allocWithZone: NSDefaultMallocZone()]
    initWithCapacity: capacity] autorelease];
}

/* Inefficient. */
+ (NSString*) stringWithCharacters: (const unichar*)characters
   length: (unsigned)length
{
  id n;
  n =  [[self allocWithZone: NSDefaultMallocZone()]
    initWithCharacters: characters length: length];
  return [n autorelease];
}

+ (NSString*) stringWithCString: (const char*)byteString
{
  return [[[NSMutableString_c_concrete_class allocWithZone:
    NSDefaultMallocZone()] initWithCString: byteString] autorelease];
}

+ (NSString*) stringWithCString: (const char*)byteString
   length: (unsigned int)length
{
  return [[[NSMutableString_c_concrete_class allocWithZone:
    NSDefaultMallocZone()] initWithCString: byteString length: length]
    autorelease];
}

/* xxx Change this when we have non-CString classes */
+ (NSString*) stringWithFormat: (NSString*)format, ...
{
  va_list ap;
  va_start(ap, format);
  self = [super stringWithFormat: format arguments: ap];
  va_end(ap);
  return self;
}

// Initializing Newly Allocated Strings

- initWithCapacity: (unsigned)capacity
{
  [self subclassResponsibility: _cmd];
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
  tmp = [[NSString allocWithZone: NSDefaultMallocZone()]
    initWithFormat: format arguments: ap];
  va_end(ap);
  [self appendString: tmp];
  [tmp release];
}

- (void) deleteCharactersInRange: (NSRange)range
{
  [self replaceCharactersInRange: range withString: nil];
}

- (void) insertString: (NSString*)aString atIndex: (unsigned)loc
{
  NSRange range = {loc, 0};
  [self replaceCharactersInRange: range withString: aString];
}

- (void) replaceCharactersInRange: (NSRange)range 
   withString: (NSString*)aString
{
  [self subclassResponsibility: _cmd];
}

- (void) setString: (NSString*)aString
{
  NSRange range = {0, [self length]};
  [self replaceCharactersInRange: range withString: aString];
}

@end

#ifndef NO_GNUSTEP
//==============================================================================
@implementation NSString (GSTrimming)

//------------------------------------------------------------------------------
-(NSString*)stringByTrimmingLeadWhiteSpaces
{
  NSCharacterSet *nonSPSet= [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
  NSRange nonSPCharRange  = [self rangeOfCharacterFromSet: nonSPSet];
  
  if (nonSPCharRange.length>0)
	return [self substringFromIndex: nonSPCharRange.location];
  else
	return [NSString string];
};

//------------------------------------------------------------------------------
-(NSString*)stringByTrimmingTailWhiteSpaces
{
  NSCharacterSet *nonSPSet= [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
  NSRange nonSPCharRange  = [self rangeOfCharacterFromSet: nonSPSet
								  options: NSBackwardsSearch];
  if (nonSPCharRange.length>0)
	return [self substringToIndex: nonSPCharRange.location+1];
  else
	return [NSString string];
};

//------------------------------------------------------------------------------
-(NSString*)stringByTrimmingWhiteSpaces
{
  return [[self stringByTrimmingLeadWhiteSpaces]
                stringByTrimmingTailWhiteSpaces];
};;

//------------------------------------------------------------------------------
-(NSString*)stringByTrimmingLeadSpaces
{
  NSMutableString* tmp = [[self mutableCopy] autorelease];
  [tmp trimLeadSpaces];
  // Convert to immuable
  return [[tmp copy] autorelease];
};

//------------------------------------------------------------------------------
-(NSString*)stringByTrimmingTailSpaces
{
  NSMutableString* tmp= [[self mutableCopy] autorelease];
  [tmp trimTailSpaces];
  // Convert to immuable
  return [[tmp copy] autorelease];
};

//------------------------------------------------------------------------------
-(NSString*) stringByTrimmingSpaces
{
  NSMutableString* tmp=[[self mutableCopy] autorelease];
  [tmp trimLeadSpaces];
  [tmp trimTailSpaces];
  // Convert to immuable
  return [[tmp copy] autorelease];
};

@end


//==============================================================================
@implementation NSMutableString (GSTrimming)

//------------------------------------------------------------------------------
-(void)trimLeadSpaces
{
  int location = 0;
  int length = [self length];
  while (location<length && isspace([self characterAtIndex: location]))
	location++;
        
  if (location>0)
	  [self deleteCharactersInRange: NSMakeRange(0,location)];
};

//------------------------------------------------------------------------------
-(void)trimTailSpaces
{
  int length = [self length];
  int location = length-1;
        
  while (location>=0 && isspace([self characterAtIndex: location]))
	location--;
        
  if (location < length-1)
	[self deleteCharactersInRange: NSMakeRange((location == 0) ? 0 : location + 1,
											  length - ((location == 0) ? 0 : location + 1))];
}

//------------------------------------------------------------------------------
-(void)trimSpaces
{
  [self trimLeadSpaces];
  [self trimTailSpaces];
};
        
@end

//==============================================================================
@implementation NSString (GSString)

//------------------------------------------------------------------------------
-(NSString*)stringWithoutSuffix: (NSString*)_suffix
{
  NSCAssert2([self hasSuffix: _suffix],@"'%@' has not the suffix '%@'",self,_suffix);
  return [self substringToIndex: ([self length]-[_suffix length])];
};

//------------------------------------------------------------------------------
-(NSString*)stringWithoutPrefix: (NSString*)_prefix
{
  NSCAssert2([self hasPrefix: _prefix],@"'%@' has not the prefix '%@'",self,_prefix);
  return [self substringFromIndex: [_prefix length]];
};

//------------------------------------------------------------------------------
-(NSString*)stringByReplacingString: (NSString*)_replace
						 withString: (NSString*)_by
{
  NSRange range=[self rangeOfString: _replace];
  if (range.length>0)
	{
	  NSMutableString* tmp= [[self mutableCopy] autorelease];
	  [tmp replaceString: _replace
		   withString: _by];
	  // Convert to immuable
	  return [[tmp copy] autorelease];
	}
  else
	return self;
};

@end

//==============================================================================
@implementation NSMutableString (GSString)
//------------------------------------------------------------------------------
-(void)removeSuffix: (NSString*)_suffix
{
  NSCAssert2([self hasSuffix: _suffix],@"'%@' has not the suffix '%@'",self,_suffix);
  [self deleteCharactersInRange: NSMakeRange([self length]-[_suffix length],[_suffix length])];
};

//------------------------------------------------------------------------------
-(void)removePrefix: (NSString*)_prefix;
{
  NSCAssert2([self hasPrefix: _prefix],@"'%@' has not the prefix '%@'",self,_prefix);
  [self deleteCharactersInRange: NSMakeRange(0,[_prefix length])];
};

//------------------------------------------------------------------------------
-(void)replaceString: (NSString*)_replace
		  withString: (NSString*)_by
{
  NSRange range=[self rangeOfString: _replace];
  if (range.length>0)
	{
	  int byLen=[_by length];
	  do
		{
		  [self replaceCharactersInRange: range
				withString: _by];
		  range.location+=byLen;
		  range.length=[self length]-range.location;
		  range=[self rangeOfString: _replace
					  options: 0
					  range: range];
		}
	  while (range.length>0);
	};
};
@end

#endif /* NO_GNUSTEP */
