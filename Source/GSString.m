/** Implementation for GNUStep of NSString concrete subclasses
   Copyright (C) 1997,1998,2000 Free Software Foundation, Inc.
   
   Base on code written by Stevo Crvenkovski <stevo@btinternet.com>
   Date: February 1997
   
   Based on NSGCString and NSString
   Written by:  Andrew Kachites McCallum
   <mccallum@gnu.ai.mit.edu>
   Date: March 1995

   Optimised by  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: October 1998

   Redesign/rewrite by  Richard Frith-Macdonald <rfm@gnu.org>
   Date: September 2000

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSString.h"
#include "Foundation/NSCoder.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSData.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSCharacterSet.h"
#include "Foundation/NSRange.h"
#include "Foundation/NSException.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSObjCRuntime.h"
#include "GNUstepBase/GSObjCRuntime.h"
#include "GSFormat.h"
#include <limits.h>

#include "GSPrivate.h"

/* memcpy(), strlen(), strcmp() are gcc builtin's */

#include "GNUstepBase/Unicode.h"

#ifdef NeXT_RUNTIME
/* Used by the Darwin/NeXT ObjC Runtime
   until Apple Radar 2870817 is fixed. */
struct objc_class _NSConstantStringClassReference;
#endif


/*
 * GSPlaceholderString - placeholder class for objects awaiting intialisation.
 */
@interface GSPlaceholderString : NSString
{
}
@end


/*
GSString is the root class of our hierarchy of string classes. All our
classes except GSPlaceholderString inherit from it. GSString provides
the common part of the ivar layout. It also has safe implementations
of all the memory management methods subclasses should override.

Concrete subclasses of GSString are identified by two properties:
how the string is encoded (its structure; 8-bit data or 16-bit unicode
data), and how the memory for the contents is handled (its memory
management).

Two direct subclasses of GSString provide the code for the two structures.
The memory management part of the concrete subclasses is abstracted to
a single flag for the structure classes: free. This is set only if the
_contents buffer is guaranteed to remain valid at least until the instance
has been deallocated.

(It really should be named 'ownsContents' or something similar, but it's
'free' in GSMutableString, and the structures need to be interchangeable.)

Many optimizations, such as retaining instead of copying, and using pointers
to another strings _contents buffer, are valid only if this flag is set.

GSCString, an abstract class that stores the string as 8-bit data in the
internal encoding.
*/
@interface GSCString : GSString
{
}
@end

/*
And GSUnicodeString, an abstract class that stores the string as 16-bit
unicode characters.
*/
@interface GSUnicodeString : GSString
{
}
@end


/*
For each memory management scheme, there is a pair of concrete subclasses
of the two abstract structure classes. Each subclass has a single -init...
method which can be used to initialize that specific subclass.

GS*BufferString, concrete subclasses that store the data in an external
(wrt. the instance itself) buffer. The buffer may or may not be owned
by the instance; the 'free' flag indicates which. If it is set,
we need to free the buffer when we are deallocated.
*/
@interface GSCBufferString : GSCString
{
}
- (id) initWithCStringNoCopy: (char*)chars
		      length: (unsigned int)length
	        freeWhenDone: (BOOL)flag;
@end

@interface GSUnicodeBufferString : GSUnicodeString
{
}
- (id) initWithCharactersNoCopy: (unichar *)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag;
@end


/*
GS*InlineString, concrete subclasses that store the data immediately after
the instance iself.
*/
@interface GSCInlineString : GSCString
{
}
- (id) initWithCString: (const char*)chars length: (unsigned)length;
@end

@interface GSUnicodeInlineString : GSUnicodeString
{
}
- (id) initWithCharacters: (const unichar*)chars length: (unsigned)length;
@end


/*
GS*SubString, concrete subclasses that use the data in another string
instance.
*/
@interface GSCSubString : GSCString
{
@public
  GSCString	*_parent;
}
- (id) initWithCString: (char *)chars length: (unsigned)length
	    fromParent: (GSCString *)parent;
@end

@interface GSUnicodeSubString : GSUnicodeString
{
@public
  GSUnicodeString	*_parent;
}
- (id) initWithCharacters: (unichar *)chars length: (unsigned)length
	       fromParent: (GSUnicodeString *)parent;
@end


/*
 *	Include sequence handling code with instructions to generate search
 *	and compare functions for NSString objects.
 */
#define	GSEQ_STRCOMP	strCompUsNs
#define	GSEQ_STRRANGE	strRangeUsNs
#define	GSEQ_O	GSEQ_NS
#define	GSEQ_S	GSEQ_US
#include "GSeq.h"

#define	GSEQ_STRCOMP	strCompUsUs
#define	GSEQ_STRRANGE	strRangeUsUs
#define	GSEQ_O	GSEQ_US
#define	GSEQ_S	GSEQ_US
#include "GSeq.h"

#define	GSEQ_STRCOMP	strCompUsCs
#define	GSEQ_STRRANGE	strRangeUsCs
#define	GSEQ_O	GSEQ_CS
#define	GSEQ_S	GSEQ_US
#include "GSeq.h"

#define	GSEQ_STRCOMP	strCompCsNs
#define	GSEQ_STRRANGE	strRangeCsNs
#define	GSEQ_O	GSEQ_NS
#define	GSEQ_S	GSEQ_CS
#include "GSeq.h"

#define	GSEQ_STRCOMP	strCompCsUs
#define	GSEQ_STRRANGE	strRangeCsUs
#define	GSEQ_O	GSEQ_US
#define	GSEQ_S	GSEQ_CS
#include "GSeq.h"

#define	GSEQ_STRCOMP	strCompCsCs
#define	GSEQ_STRRANGE	strRangeCsCs
#define	GSEQ_O	GSEQ_CS
#define	GSEQ_S	GSEQ_CS
#include "GSeq.h"

static Class NSDataClass = 0;
static Class NSStringClass = 0;
static Class GSStringClass = 0;
static Class GSCStringClass = 0;
static Class GSCBufferStringClass = 0;
static Class GSCInlineStringClass = 0;
static Class GSCSubStringClass = 0;
static Class GSUnicodeStringClass = 0;
static Class GSUnicodeBufferStringClass = 0;
static Class GSUnicodeSubStringClass = 0;
static Class GSUnicodeInlineStringClass = 0;
static Class GSMutableStringClass = 0;
static Class NSConstantStringClass = 0;

static SEL	cMemberSel;
static SEL	convertSel;
static BOOL	(*convertImp)(id, SEL, NSStringEncoding);
static SEL	equalSel;
static BOOL	(*equalImp)(id, SEL, id);
static SEL	hashSel;
static unsigned (*hashImp)(id, SEL);

static NSStringEncoding defEnc = 0;
static NSStringEncoding intEnc = NSISOLatin1StringEncoding;

/*
 * The setup() function is called when any concrete string class is
 * initialized, and caches classes and some method implementations.
 */
static void
setup(void)
{
  static BOOL	beenHere = NO;

  if (beenHere == NO)
    {
      extern NSStringEncoding	GetDefEncoding(void);

      beenHere = YES;

      /*
       * Cache pointers to classes to work round misfeature in
       * GNU compiler/runtime system where class lookup is very slow.
       */
      NSDataClass = [NSData class];
      NSStringClass = [NSString class];
      GSStringClass = [GSString class];
      GSCStringClass = [GSCString class];
      GSUnicodeStringClass = [GSUnicodeString class];
      GSCBufferStringClass = [GSCBufferString class];
      GSUnicodeBufferStringClass = [GSUnicodeBufferString class];
      GSCInlineStringClass = [GSCInlineString class];
      GSUnicodeInlineStringClass = [GSUnicodeInlineString class];
      GSCSubStringClass = [GSCSubString class];
      GSUnicodeSubStringClass = [GSUnicodeSubString class];
      GSMutableStringClass = [GSMutableString class];
      NSConstantStringClass = [NXConstantString class];

      /*
       * Cache some selectors and method implementations for
       * cases where we want to use the implementation
       * provided in the abstract rolot cllass of the cluster.
       */
      cMemberSel = @selector(characterIsMember:);
      convertSel = @selector(canBeConvertedToEncoding:);
      convertImp = (BOOL (*)(id, SEL, NSStringEncoding))
	[NSStringClass instanceMethodForSelector: convertSel];
      equalSel = @selector(isEqualToString:);
      equalImp = (BOOL (*)(id, SEL, id))
	[NSStringClass instanceMethodForSelector: equalSel];
      hashSel = @selector(hash);
      hashImp = (unsigned (*)(id, SEL))
	[NSStringClass instanceMethodForSelector: hashSel];

      caiSel = @selector(characterAtIndex:);
      gcrSel = @selector(getCharacters:range:);
      ranSel = @selector(rangeOfComposedCharacterSequenceAtIndex:);

      /*
       * Cache the default string encoding, and set the internal encoding
       * used by 8-bit character strings to match if possible.
       */
      defEnc = GetDefEncoding();
      if (GSIsByteEncoding(defEnc) == YES)
	{
	  intEnc = defEnc;
	}
    }
}

/*
 * The GSPlaceholderString class is used by the abstract cluster root
 * class to provide temporary objects that will be replaced as soon
 * as the objects are initialised.  This object tries to replace
 * itself with an appropriate object whose type may vary depending
 * on the initialisation method used.
 */
@implementation GSPlaceholderString
+ (void) initialize
{
  setup();
}

- (id) autorelease
{
  NSWarnLog(@"-autorelease sent to uninitialised string");
  return self;		// placeholders never get released.
}

- (unichar) characterAtIndex: (unsigned)index
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"attempt to use uninitialised string"];
  return 0;
}

- (void) dealloc
{
  return;		// Placeholders never get deallocated.
}

/*
 * Replace self with an inline unicode string.
 */
- (id) initWithCharacters: (const unichar*)chars
		   length: (unsigned)length
{
  GSStr	me;

  me = (GSStr)NSAllocateObject(GSUnicodeInlineStringClass,
    length*sizeof(unichar), GSObjCZone(self));
  me->_contents.u = (unichar*)&((GSUnicodeInlineString*)me)[1];
  me->_count = length;
  me->_flags.wide = 1;
  me->_flags.free = 1;
  memcpy(me->_contents.u, chars, length*sizeof(unichar));
  return (id)me;
}

/*
 * Replace self with a simple unicode string.
 */
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned)length
		   freeWhenDone: (BOOL)flag
{
  GSStr	me;

  me = (GSStr)NSAllocateObject(GSUnicodeBufferStringClass, 0, GSObjCZone(self));
  me->_contents.u = chars;
  me->_count = length;
  me->_flags.wide = 1;
  if (flag == YES)
    {
      me->_flags.free = 1;
    }
  return (id)me;
}

/*
 * Replace self with an inline 'C' string.
 */
- (id) initWithCString: (const char*)chars
		length: (unsigned)length
{
  if (defEnc == intEnc)
    {
      GSStr	me;

      me = (GSStr)NSAllocateObject(GSCInlineStringClass, length,
	GSObjCZone(self));
      me->_contents.c = (unsigned char*)&((GSCInlineString*)me)[1];
      me->_count = length;
      me->_flags.wide = 0;
      me->_flags.free = 1;
      memcpy(me->_contents.c, chars, length);
      return (id)me;
    }
  else
    {
      unichar	*u = 0;
      unsigned	l = 0;

      if (GSToUnicode(&u, &l, chars, length, defEnc, GSObjCZone(self), 0) == NO)
	{
	  return nil;
	}
      return [self initWithCharactersNoCopy: u length: l freeWhenDone: YES];
    }
}

/*
 * Replace self with a simple 'C' string
 */
- (id) initWithCStringNoCopy: (char*)chars
		      length: (unsigned)length
		freeWhenDone: (BOOL)flag
{
  if (defEnc == intEnc)
    {
      GSStr	me;

      me = (GSStr)NSAllocateObject(GSCBufferStringClass, 0, GSObjCZone(self));
      me->_contents.c = (unsigned char*)chars;
      me->_count = length;
      me->_flags.wide = 0;
      if (flag == YES)
	{
	  me->_flags.free = 1;
	}
      return (id)me;
    }
  else
    {
      unichar	*u = 0;
      unsigned	l = 0;

      if (GSToUnicode(&u, &l, chars, length, defEnc, GSObjCZone(self), 0) == NO)
	{
	  self = nil;
	}
      else
	{
	  self = [self initWithCharactersNoCopy: u length: l freeWhenDone: YES];
	}
      if (flag == YES && chars != 0)
	{
	  NSZoneFree(NSZoneFromPointer(chars), chars);
	}
      return self;
    }
}

- (id) initWithFormat: (NSString*)format
               locale: (NSDictionary*)locale
	    arguments: (va_list)argList
{
  unsigned char	buf[2048];
  GSStr_t	f;
  unichar	fbuf[1024];
  unichar	*fmt = fbuf;
  size_t	len;
  GSStr		me;


  /*
   * First we provide an array of unichar characters containing the
   * format string.  For performance reasons we try to use an on-stack
   * buffer if the format string is small enough ... it almost always
   * will be.
   */
  len = [format length];
  if (len >= 1024)
    {
      fmt = objc_malloc((len+1)*sizeof(unichar));
    }
  [format getCharacters: fmt];
  fmt[len] = '\0';

  /*
   * Now set up 'f' as a GSMutableString object whose initial buffer is
   * allocated on the stack.  The GSFormat function can write into it.
   */
  f.isa = GSMutableStringClass;
  f._zone = NSDefaultMallocZone();
  f._contents.c = buf;
  f._capacity = sizeof(buf);
  f._count = 0;
  f._flags.wide = 0;
  f._flags.free = 0;
  GSFormat(&f, fmt, argList, locale);
  if (fmt != fbuf)
    {
      objc_free(fmt);
    }

  /*
   * Don't use noCopy because f._contents.u may be memory on the stack,
   * and even if it wasn't f._capacity may be greater than f._count so
   * we could be wasting quite a bit of space.  Better to accept a
   * performance hit due to copying data (and allocating/deallocating
   * the temporary buffer) for large strings.  For most strings, the
   * on-stack memory will have been used, so we will get better performance.
   */
  if (f._flags.wide == 1)
    {
      me = (GSStr)NSAllocateObject(GSUnicodeInlineStringClass,
	f._count*sizeof(unichar), GSObjCZone(self));
      me->_contents.u = (unichar*)&((GSUnicodeInlineString*)me)[1];
      me->_count = f._count;
      me->_flags.wide = 1;
      me->_flags.free = 1;
      memcpy(me->_contents.u, f._contents.u, f._count*sizeof(unichar));
    }
  else
    {
      me = (GSStr)NSAllocateObject(GSCInlineStringClass, f._count,
	GSObjCZone(self));
      me->_contents.c = (unsigned char*)&((GSCInlineString*)me)[1];
      me->_count = f._count;
      me->_flags.wide = 0;
      me->_flags.free = 1;
      memcpy(me->_contents.c, f._contents.c, f._count);
    }

  /*
   * If the string had to grow beyond the initial buffer size, we must
   * release any allocated memory.
   */
  if (f._flags.free == 1)
    {
      NSZoneFree(f._zone, f._contents.c);
    }
  return (id)me;
}

/*
 * Replace self with an inline string matching the sort of information
 * given.
 */
- (id) initWithString: (NSString*)string
{
  unsigned	length;
  Class		c;
  GSStr		me;

  if (string == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"-initWithString: given nil string"];
  c = GSObjCClass(string);
  if (GSObjCIsKindOf(c, NSStringClass) == NO)
    [NSException raise: NSInvalidArgumentException
		format: @"-initWithString: given non-string object"];

  length = [string length];
  if (GSObjCIsKindOf(c, GSCStringClass) == YES || c == NSConstantStringClass
    || (GSObjCIsKindOf(c, GSMutableStringClass) == YES
      && ((GSStr)string)->_flags.wide == 0))
    {
      /*
       * For a GSCString subclass, and ??ConstantString, or an 8-bit
       * GSMutableString, we can copy the bytes directly into a GSCString.
       */
      me = (GSStr)NSAllocateObject(GSCInlineStringClass,
	length, GSObjCZone(self));
      me->_contents.c = (unsigned char*)&((GSCInlineString*)me)[1];
      me->_count = length;
      me->_flags.wide = 0;
      me->_flags.free = 1;
      memcpy(me->_contents.c, ((GSStr)string)->_contents.c, length);
    }
  else if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES
    || GSObjCIsKindOf(c, GSMutableStringClass) == YES)
    {
      /*
       * For a GSUnicodeString subclass, or a 16-bit GSMutableString,
       * we can copy the bytes directly into a GSUnicodeString.
       */
      me = (GSStr)NSAllocateObject(GSUnicodeInlineStringClass,
	length*sizeof(unichar), GSObjCZone(self));
      me->_contents.u = (unichar*)&((GSUnicodeInlineString*)me)[1];
      me->_count = length;
      me->_flags.wide = 1;
      me->_flags.free = 1;
      memcpy(me->_contents.u, ((GSStr)string)->_contents.u,
	length*sizeof(unichar));
    }
  else
    {
      /*
       * For a string with an unknown class, we can initialise by
       * having the string copy its content directly into our buffer.
       */
      me = (GSStr)NSAllocateObject(GSUnicodeInlineStringClass,
	length*sizeof(unichar), GSObjCZone(self));
      me->_contents.u = (unichar*)&((GSUnicodeInlineString*)me)[1];
      me->_count = length;
      me->_flags.wide = 1;
      me->_flags.free = 1;
      [string getCharacters: me->_contents.u];
    }
  return (id)me;
}

- (unsigned) length
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"attempt to use uninitialised string"];
  return 0;
}

- (void) release
{
  return;		// placeholders never get released.
}

- (id) retain
{
  return self;		// placeholders never get retained.
}
@end



/*
 * The following inline functions are used by the concrete string classes
 * to implement their core functionality.
 * GSCString uses the functions with the _c suffix.
 * GSCSubString, GSCInlineString, GSCBufferString, and ??ConstantString
 * inherit methods from GSCString.
 * GSUnicodeString uses the functions with the _u suffix.
 * GSUnicodeSubString, GSUnicodeInlineString, and GSUnicodeBufferString
 * inherit methods from GSUnicodeString.
 * GSMutableString uses all the functions, selecting the _c or _u versions
 * depending on whether its storage is 8-bit or 16-bit.
 * In addition, GSMutableString uses a few functions without a suffix that are
 * peculiar to its memory management (shrinking, growing, and converting).
 */

static inline char*
UTF8String_c(GSStr self)
{
  unsigned char *r;

  if (self->_count == 0)
    {
      return "";
    }
  if (intEnc == NSASCIIStringEncoding)
    {
      unsigned	i = self->_count;

      r = (unsigned char*)GSAutoreleasedBuffer(self->_count+1);
      while (i-- > 0)
	{
	  r[i] = self->_contents.c[i] & 0x7f;
	}
      r[self->_count] = '\0';
    }
  else
    {
      unichar	*u = 0;
      unsigned	l = 0;
      unsigned	s = 0;

      /*
       * We must convert from internal format to unicode and then to
       * UTF8 string encoding.
       */
      if (GSToUnicode(&u, &l, self->_contents.c, self->_count, intEnc,
	NSDefaultMallocZone(), 0) == NO)
	{
	  [NSException raise: NSCharacterConversionException
		      format: @"Can't convert to Unicode string."];
	}
      if (GSFromUnicode((unsigned char**)&r, &s, u, l, NSUTF8StringEncoding,
	NSDefaultMallocZone(), GSUniTerminate|GSUniTemporary|GSUniStrict) == NO)
	{
	  NSZoneFree(NSDefaultMallocZone(), u);
	  [NSException raise: NSCharacterConversionException
		      format: @"Can't convert from Unicode to UTF8."];
	}
      NSZoneFree(NSDefaultMallocZone(), u);
    }
  
  return r;
}

static inline char*
UTF8String_u(GSStr self)
{
  unsigned	c = self->_count;

  if (c == 0)
    {
      return "";
    }
  else
    {
      unsigned int	l = 0;
      unsigned char	*r = 0;

      if (GSFromUnicode(&r, &l, self->_contents.u, c, NSUTF8StringEncoding,
	NSDefaultMallocZone(), GSUniTerminate|GSUniTemporary|GSUniStrict) == NO)
	{
	  [NSException raise: NSCharacterConversionException
		      format: @"Can't get UTF8 from Unicode string."];
	}
      return r;
    }
}

static inline BOOL
boolValue_c(GSStr self)
{
  if (self->_count == 0)
    {
      return NO;
    }
  else
    {
      unsigned	len = self->_count < 10 ? self->_count : 9;

      if (len == 3
	&& (self->_contents.c[0] == 'Y' || self->_contents.c[0] == 'y')
	&& (self->_contents.c[1] == 'E' || self->_contents.c[1] == 'e')
	&& (self->_contents.c[2] == 'S' || self->_contents.c[2] == 's'))
	{
	  return YES;
	}
      else if (len == 4
	&& (self->_contents.c[0] == 'T' || self->_contents.c[0] == 't')
	&& (self->_contents.c[1] == 'R' || self->_contents.c[1] == 'r')
	&& (self->_contents.c[2] == 'U' || self->_contents.c[2] == 'u')
	&& (self->_contents.c[3] == 'E' || self->_contents.c[3] == 'e'))
	{
	  return YES;
	}
      else
	{
	  unsigned char	buf[len+1];

	  memcpy(buf, self->_contents.c, len);
	  buf[len] = '\0';
	  return atoi(buf);
	}
    }
}

static inline BOOL
boolValue_u(GSStr self)
{
  if (self->_count == 0)
    {
      return NO;
    }
  else
    {
      unsigned int	l = self->_count < 10 ? self->_count : 9;
      unsigned char	buf[l+1];
      unsigned char	*b = buf;

      GSFromUnicode(&b, &l, self->_contents.u, l, intEnc, 0, GSUniTerminate);
      if (l == 3
	&& (buf[0] == 'Y' || buf[0] == 'y')
	&& (buf[1] == 'E' || buf[1] == 'e')
	&& (buf[2] == 'S' || buf[2] == 's'))
	{
	  return YES;
	}
      else if (l == 4
	&& (buf[0] == 'T' || buf[0] == 't')
	&& (buf[1] == 'R' || buf[1] == 'r')
	&& (buf[2] == 'U' || buf[2] == 'u')
	&& (buf[3] == 'E' || buf[3] == 'e'))
	{
	  return YES;
	}
      else
	{
	  return atoi(buf);
	}
    }
}

static inline BOOL
canBeConvertedToEncoding_c(GSStr self, NSStringEncoding enc)
{
  if (enc == intEnc)
    {
      return YES;
    }
  else
    {
      BOOL	result = (*convertImp)((id)self, convertSel, enc);

      return result;
    }
}

static inline BOOL
canBeConvertedToEncoding_u(GSStr self, NSStringEncoding enc)
{
  BOOL	result = YES;

  if (enc == NSISOLatin1StringEncoding)
    {
      unsigned	i;

      /*
       * If all the unicode characters are in the 0 to 255 range
       * they are all latin1.
       */
      for (i = 0; i < self->_count; i++)
	{
	  if (self->_contents.u[i] > 255)
	    {
	      result = NO;
	      break;
	    }
	}
    }
  else if (enc == NSASCIIStringEncoding)
    {
      unsigned	i;

      /*
       * If all the unicode characters are in the 0 to 127 range
       * they are all ascii.
       */
      for (i = 0; i < self->_count; i++)
	{
	  if (self->_contents.u[i] > 127)
	    {
	      result = NO;
	      break;
	    }
	}
    }
  else
    {
      result = (*convertImp)((id)self, convertSel, enc);
    }
  return result;
}

static inline unichar
characterAtIndex_c(GSStr self, unsigned index)
{
  unichar	c;

  if (index >= self->_count)
    [NSException raise: NSRangeException format: @"Invalid index."];
  c = self->_contents.c[index];
  if (c > 127)
    {
      c = encode_chartouni(c, intEnc);
    }
  return c;
}

static inline unichar
characterAtIndex_u(GSStr self,unsigned index)
{
  if (index >= self->_count)
    [NSException raise: NSRangeException format: @"Invalid index."];
  return self->_contents.u[index];
}

static inline NSComparisonResult
compare_c(GSStr self, NSString *aString, unsigned mask, NSRange aRange)
{
  Class	c;

  if (aString == nil)
    [NSException raise: NSInvalidArgumentException format: @"compare with nil"];
  if (GSObjCIsInstance(aString) == NO)
    return strCompCsNs((id)self, aString, mask, aRange);

  c = GSObjCClass(aString);
  if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES
    || (c == GSMutableStringClass && ((GSStr)aString)->_flags.wide == 1))
    return strCompCsUs((id)self, aString, mask, aRange);
  else if (GSObjCIsKindOf(c, GSCStringClass) == YES
    || c == NSConstantStringClass
    || (c == GSMutableStringClass && ((GSStr)aString)->_flags.wide == 0))
    return strCompCsCs((id)self, aString, mask, aRange);
  else
    return strCompCsNs((id)self, aString, mask, aRange);
}

static inline NSComparisonResult
compare_u(GSStr self, NSString *aString, unsigned mask, NSRange aRange)
{
  Class	c;

  if (aString == nil)
    [NSException raise: NSInvalidArgumentException format: @"compare with nil"];
  if (GSObjCIsInstance(aString) == NO)
    return strCompUsNs((id)self, aString, mask, aRange);

  c = GSObjCClass(aString);
  if (GSObjCIsKindOf(c, GSUnicodeStringClass)
    || (c == GSMutableStringClass && ((GSStr)aString)->_flags.wide == 1))
    return strCompUsUs((id)self, aString, mask, aRange);
  else if (GSObjCIsKindOf(c, GSCStringClass)
    || c == NSConstantStringClass
    || (c == GSMutableStringClass && ((GSStr)aString)->_flags.wide == 0))
    return strCompUsCs((id)self, aString, mask, aRange);
  else
    return strCompUsNs((id)self, aString, mask, aRange);
}

static inline char*
cString_c(GSStr self)
{
  unsigned char *r;

  if (self->_count == 0)
    {
      return "";
    }
  if (defEnc == intEnc)
    {
      r = (unsigned char*)GSAutoreleasedBuffer(self->_count+1);

      if (self->_count > 0)
	{
	  memcpy(r, self->_contents.c, self->_count);
	}
      r[self->_count] = '\0';
    }
  else
    {
      unichar	*u = 0;
      unsigned	l = 0;
      unsigned	s = 0;

      /*
       * The external C string encoding is not compatible with the internal
       * 8-bit character strings ... we must convert from internal format to
       * unicode and then to the external C string encoding.
       */
      if (GSToUnicode(&u, &l, self->_contents.c, self->_count, intEnc,
	NSDefaultMallocZone(), 0) == NO)
	{
	  [NSException raise: NSCharacterConversionException
		      format: @"Can't convert to/from Unicode string."];
	}
      if (GSFromUnicode((unsigned char**)&r, &s, u, l, defEnc,
	NSDefaultMallocZone(), GSUniTerminate|GSUniTemporary|GSUniStrict) == NO)
	{
	  NSZoneFree(NSDefaultMallocZone(), u);
	  [NSException raise: NSCharacterConversionException
		      format: @"Can't convert to/from Unicode string."];
	}
      NSZoneFree(NSDefaultMallocZone(), u);
    }

  return r;
}

static inline char*
cString_u(GSStr self)
{
  unsigned	c = self->_count;

  if (c == 0)
    {
      return "";
    }
  else
    {
      unsigned int	l = 0;
      unsigned char	*r = 0;

      if (GSFromUnicode(&r, &l, self->_contents.u, c, defEnc,
	NSDefaultMallocZone(), GSUniTerminate|GSUniTemporary|GSUniStrict) == NO)
	{
	  [NSException raise: NSCharacterConversionException
		      format: @"Can't get cString from Unicode string."];
	}
      return r;
    }
}

static inline unsigned int
cStringLength_c(GSStr self)
{
  if (defEnc == intEnc)
    {
      return self->_count;
    }
  else
    {
      /*
       * The external C string encoding is not compatible with the internal
       * 8-bit character strings ... we must convert from internal format to
       * unicode and then to the external C string encoding.
       */
      if (self->_count == 0)
	{
	  return 0;
	}
      else
	{
	  unichar	*u = 0;
	  unsigned	l = 0;
	  unsigned	s = 0;

	  if (GSToUnicode(&u, &l, self->_contents.c, self->_count, intEnc,
	    NSDefaultMallocZone(), 0) == NO)
	    {
	      [NSException raise: NSCharacterConversionException
			  format: @"Can't convert to/from Unicode string."];
	    }
	  if (GSFromUnicode(0, &s, u, l, defEnc, 0, GSUniStrict) == NO)
	    {
	      NSZoneFree(NSDefaultMallocZone(), u);
	      [NSException raise: NSCharacterConversionException
			  format: @"Can't get cStringLength from string."];
	    }
	  NSZoneFree(NSDefaultMallocZone(), u);
	  return s;
	}
    }
}

static inline unsigned int
cStringLength_u(GSStr self)
{
  unsigned	c = self->_count;

  if (c == 0)
    {
      return 0;
    }
  else
    {
      unsigned	l = 0;

      if (GSFromUnicode(0, &l, self->_contents.u, c, defEnc, 0, GSUniStrict)
	== NO)
	{
	  [NSException raise: NSCharacterConversionException
		      format: @"Can't get cStringLength from Unicode string."];
	}
      return l;
    }
}

static inline NSData*
dataUsingEncoding_c(GSStr self, NSStringEncoding encoding, BOOL flag)
{
  unsigned	len = self->_count;

  if (len == 0)
    {
      return [NSDataClass data];
    }

  if ((encoding == intEnc)
    || ((intEnc == NSASCIIStringEncoding) 
    && ((encoding == NSISOLatin1StringEncoding)
    || (encoding == NSISOLatin2StringEncoding)
    || (encoding == NSNEXTSTEPStringEncoding)
    || (encoding == NSNonLossyASCIIStringEncoding))))
    {
      unsigned char *buff;

      buff = (unsigned char*)NSZoneMalloc(NSDefaultMallocZone(), len);
      memcpy(buff, self->_contents.c, len);
      return [NSDataClass dataWithBytesNoCopy: buff length: len];
    }
  else if (encoding == NSUnicodeStringEncoding)
    {
      unsigned int	l = 0;
      unichar		*r = 0;
      unsigned int	options = GSUniBOM;

      if (flag == NO)
	{
	  options |= GSUniStrict;
	}

      if (GSToUnicode(&r, &l, self->_contents.c, self->_count, intEnc,
	NSDefaultMallocZone(), options) == NO)
	{
	  return nil;
	}
      return [NSDataClass dataWithBytesNoCopy: r length: l * sizeof(unichar)];
    }
  else
    {
      unichar		*u = 0;
      unsigned		l = 0;
      unsigned char	*r = 0;
      unsigned		s = 0;

      if (GSToUnicode(&u, &l, self->_contents.c, self->_count, intEnc,
	NSDefaultMallocZone(), 0) == NO)
	{
	  [NSException raise: NSCharacterConversionException
		      format: @"Can't convert to Unicode string."];
	}
      if (GSFromUnicode(&r, &s, u, l, encoding, NSDefaultMallocZone(),
	(flag == NO) ? GSUniStrict : 0) == NO)
	{
	  NSZoneFree(NSDefaultMallocZone(), u);
	  return nil;
	}
      NSZoneFree(NSDefaultMallocZone(), u);
      return [NSDataClass dataWithBytesNoCopy: r length: s];
    }
}

static inline NSData*
dataUsingEncoding_u(GSStr self, NSStringEncoding encoding, BOOL flag)
{
  unsigned	len = self->_count;

  if (len == 0)
    {
      return [NSDataClass data];
    }

  if (encoding == NSUnicodeStringEncoding)
    {
      unichar *buff;

      buff = (unichar*)NSZoneMalloc(NSDefaultMallocZone(),
	sizeof(unichar)*(len+1));
      buff[0] = 0xFEFF;
      memcpy(buff+1, self->_contents.u, sizeof(unichar)*len);
      return [NSData dataWithBytesNoCopy: buff
				  length: sizeof(unichar)*(len+1)];
    }
  else
    {
      unsigned char	*r = 0;
      unsigned int	l = 0;

      if (GSFromUnicode(&r, &l, self->_contents.u, self->_count, encoding,
	NSDefaultMallocZone(), (flag == NO) ? GSUniStrict : 0) == NO)
	{
	  return nil;
	}
      return [NSDataClass dataWithBytesNoCopy: r length: l];
    }
}

extern BOOL GSScanDouble(unichar*, unsigned, double*);

static inline double
doubleValue_c(GSStr self)
{
  if (self->_count == 0)
    {
      return 0.0;
    }
  else
    {
      unsigned	l = self->_count < 32 ? self->_count : 32;
      unichar	buf[l];
      unichar	*b = buf;
      double	d = 0.0;

      GSToUnicode(&b, &l, self->_contents.c, l, intEnc, 0, 0);
      GSScanDouble(b, l, &d);
      return d;
    }
}

static inline double
doubleValue_u(GSStr self)
{
  if (self->_count == 0)
    {
      return 0.0;
    }
  else
    {
      double	d = 0.0;

      GSScanDouble(self->_contents.u, self->_count, &d);
      return d;
    }
}

static inline void
fillHole(GSStr self, unsigned index, unsigned size)
{
  NSCAssert(size > 0, @"size <= zero");
  NSCAssert(index + size <= self->_count, @"index + size > length");

  self->_count -= size;
  if (self->_flags.wide == 1)
    {
      memmove(self->_contents.u + index,
	self->_contents.u + index + size,
	sizeof(unichar)*(self->_count - index));
    }
  else
    {
      memmove(self->_contents.c + index,
	self->_contents.c + index + size, (self->_count - index));
    }
  self->_flags.hash = 0;
}

static inline void
getCharacters_c(GSStr self, unichar *buffer, NSRange aRange)
{
  unsigned	len = aRange.length;

  if (!len)
    return;

  if (!GSToUnicode(&buffer, &len, self->_contents.c + aRange.location,
		   aRange.length, intEnc, 0, 0))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Can't convert to Unicode."];
    }
}

static inline void
getCharacters_u(GSStr self, unichar *buffer, NSRange aRange)
{
  memcpy(buffer, self->_contents.u + aRange.location,
    aRange.length*sizeof(unichar));
}

static inline void
getCString_c(GSStr self, char *buffer, unsigned int maxLength,
  NSRange aRange, NSRange *leftoverRange)
{
  int len;

  if (maxLength > self->_count)
    {
      maxLength = self->_count;
    }
  if (maxLength < aRange.length)
    {
      len = maxLength;
      if (leftoverRange != 0)
	{
	  leftoverRange->location = aRange.location + maxLength;
	  leftoverRange->length = aRange.length - maxLength;
	}
    }
  else
    {
      len = aRange.length;
      if (leftoverRange != 0)
	{
	  leftoverRange->location = 0;
	  leftoverRange->length = 0;
	}
    }

  memcpy(buffer, &self->_contents.c[aRange.location], len);
  buffer[len] = '\0';
}

static inline void
getCString_u(GSStr self, char *buffer, unsigned int maxLength,
  NSRange aRange, NSRange *leftoverRange)
{
  /* The primitive we have for converting from unicode, GSFromUnicode,
  can't deal with our leftoverRange case, so we need to use a bit of
  complexity instead. */
  unsigned int len;

  /* TODO: this is an extremely ugly hack to work around buggy iconvs
  that return -1/E2BIG for buffers larger than 0x40000acf */
  if (maxLength > 0x40000000)
    maxLength = 0x40000000;

  /* First, try converting the whole thing. */
  len = maxLength;
  if (GSFromUnicode((unsigned char **)&buffer, &len,
		    self->_contents.u + aRange.location, aRange.length,
		    defEnc, 0, GSUniTerminate | GSUniStrict) == YES)
    {
      if (leftoverRange)
	leftoverRange->location = leftoverRange->length = 0;
      return;
    }

  /* The conversion failed. Either the buffer is too small for the whole
  range, or there are characters in it we can't convert. Check for
  unconvertable characters first. */
  len = 0;
  if (GSFromUnicode(NULL, &len,
		    self->_contents.u + aRange.location, aRange.length,
		    defEnc, 0, GSUniTerminate | GSUniStrict) == NO)
    {
      [NSException raise: NSCharacterConversionException
		  format: @"Can't get cString from Unicode string."];
      return;
    }

  /* The string can be converted, but not all of it. Do a binary search
  to find the longest subrange that fits in the buffer. */
  {
    unsigned int lo, hi, mid;

    lo = 0;
    hi = aRange.length;
    while (lo < hi)
      {
	mid = (lo + hi + 1) / 2; /* round up to get edge case right */
	len = maxLength;
	if (GSFromUnicode((unsigned char **)&buffer, &len,
			  self->_contents.u + aRange.location, mid,
			  defEnc, 0, GSUniTerminate | GSUniStrict) == YES)
	  {
	    lo = mid;
	  }
	else
	  {
	    hi = mid - 1;
	  }
      }

    /* lo==hi characters fit. Do the real conversion. */
    len = maxLength;
    if (lo == 0)
      {
        buffer[0] = 0;
      }
    else if (GSFromUnicode((unsigned char **)&buffer, &len,
			   self->_contents.u + aRange.location, lo,
			   defEnc, 0, GSUniTerminate | GSUniStrict) == NO)
      {
        NSCAssert(NO, @"binary search gave inconsistent results");
      }

    if (leftoverRange)
      {
	leftoverRange->location = aRange.location + lo;
	leftoverRange->length = NSMaxRange(aRange) - leftoverRange->location;
      }
  }
}

static inline int
intValue_c(GSStr self)
{
  if (self->_count == 0)
    {
      return 0;
    }
  else
    {
      unsigned	len = self->_count < 32 ? self->_count : 31;
      char	buf[len+1];

      memcpy(buf, self->_contents.c, len);
      buf[len] = '\0';
      return atol(buf);
    }
}

static inline int
intValue_u(GSStr self)
{
  if (self->_count == 0)
    {
      return 0;
    }
  else
    {
      unsigned int	l = self->_count < 32 ? self->_count : 31;
      unsigned char	buf[l+1];
      unsigned char	*b = buf;

      GSFromUnicode(&b, &l, self->_contents.u, l, intEnc, 0, GSUniTerminate);
      return atol(buf);
    }
}

static inline BOOL
isEqual_c(GSStr self, id anObject)
{
  Class	c;

  if (anObject == (id)self)
    {
      return YES;
    }
  if (anObject == nil)
    {
      return NO;
    }
  if (GSObjCIsInstance(anObject) == NO)
    {
      return NO;
    }
  c = GSObjCClass(anObject);
  if (c == NSConstantStringClass)
    {
      GSStr	other = (GSStr)anObject;
      NSRange	r = {0, self->_count};

      if (strCompCsCs((id)self, (id)other, 0, r) == NSOrderedSame)
	return YES;
      return NO;
    }
  else if (GSObjCIsKindOf(c, GSStringClass) == YES || c == GSMutableStringClass)
    {
      GSStr	other = (GSStr)anObject;
      NSRange	r = {0, self->_count};

      /*
       * First see if the hash is the same - if not, we can't be equal.
       */
      if (self->_flags.hash == 0)
        self->_flags.hash = (*hashImp)((id)self, hashSel);
      if (other->_flags.hash == 0)
        other->_flags.hash = (*hashImp)((id)other, hashSel);
      if (self->_flags.hash != other->_flags.hash)
	return NO;

      /*
       * Do a compare depending on the type of the other string.
       */
      if (other->_flags.wide == 1)
	{
	  if (strCompCsUs((id)self, (id)other, 0, r) == NSOrderedSame)
	    return YES;
	}
      else
	{
	  if (strCompCsCs((id)self, (id)other, 0, r) == NSOrderedSame)
	    return YES;
	}
      return NO;
    }
  else if (GSObjCIsKindOf(c, NSStringClass))
    {
      return (*equalImp)((id)self, equalSel, anObject);
    }
  else
    {
      return NO;
    }
}

static inline BOOL
isEqual_u(GSStr self, id anObject)
{
  Class	c;

  if (anObject == (id)self)
    {
      return YES;
    }
  if (anObject == nil)
    {
      return NO;
    }
  if (GSObjCIsInstance(anObject) == NO)
    {
      return NO;
    }
  c = GSObjCClass(anObject);
  if (c == NSConstantStringClass)
    {
      GSStr	other = (GSStr)anObject;
      NSRange	r = {0, self->_count};

      if (strCompUsCs((id)self, (id)other, 0, r) == NSOrderedSame)
	return YES;
      return NO;
    }
  else if (GSObjCIsKindOf(c, GSStringClass) == YES || c == GSMutableStringClass)
    {
      GSStr	other = (GSStr)anObject;
      NSRange	r = {0, self->_count};

      /*
       * First see if the hash is the same - if not, we can't be equal.
       */
      if (self->_flags.hash == 0)
        self->_flags.hash = (*hashImp)((id)self, hashSel);
      if (other->_flags.hash == 0)
        other->_flags.hash = (*hashImp)((id)other, hashSel);
      if (self->_flags.hash != other->_flags.hash)
	return NO;

      /*
       * Do a compare depending on the type of the other string.
       */
      if (other->_flags.wide == 1)
	{
	  if (strCompUsUs((id)self, (id)other, 0, r) == NSOrderedSame)
	    return YES;
	}
      else
	{
	  if (strCompUsCs((id)self, (id)other, 0, r) == NSOrderedSame)
	    return YES;
	}
      return NO;
    }
  else if (GSObjCIsKindOf(c, NSStringClass))
    {
      return (*equalImp)((id)self, equalSel, anObject);
    }
  else
    {
      return NO;
    }
}

static inline const char*
lossyCString_c(GSStr self)
{
  char *r;

  if (self->_count == 0)
    {
      return "";
    }
  if (defEnc == intEnc)
    {
      r = (char*)GSAutoreleasedBuffer(self->_count+1);

      if (self->_count > 0)
	{
	  memcpy(r, self->_contents.c, self->_count);
	}
      r[self->_count] = '\0';
    }
  else
    {
      unichar	*u = 0;
      unsigned	l = 0;
      unsigned	s = 0;

      /*
       * The external C string encoding is not compatible with the internal
       * 8-bit character strings ... we must convert from internal format to
       * unicode and then to the external C string encoding.
       */
      if (GSToUnicode(&u, &l, self->_contents.c, self->_count, intEnc,
	NSDefaultMallocZone(), 0) == NO)
	{
	  [NSException raise: NSCharacterConversionException
		      format: @"Can't convert to/from Unicode string."];
	}
      if (GSFromUnicode((unsigned char**)&r, &s, u, l, defEnc,
	NSDefaultMallocZone(), GSUniTerminate|GSUniTemporary) == NO)
	{
	  NSZoneFree(NSDefaultMallocZone(), u);
	  [NSException raise: NSCharacterConversionException
		      format: @"Can't convert to/from Unicode string."];
	}
      NSZoneFree(NSDefaultMallocZone(), u);
    }
  
  return r;
}

static inline const char*
lossyCString_u(GSStr self)
{
  unsigned	l = 0;
  unsigned char	*r = 0;

  GSFromUnicode(&r, &l, self->_contents.u, self->_count, defEnc,
    NSDefaultMallocZone(), GSUniTemporary|GSUniTerminate);
  return (const char*)r;
}

static void GSStrMakeSpace(GSStr s, unsigned size)
{
  unsigned	want;

  want = size + s->_count + 1;
  s->_capacity += s->_capacity/2;
  if (want > s->_capacity)
    {
      s->_capacity = want;
    }
  if (s->_flags.free == 1)
    {
      /*
       * If we own the character buffer, we can simply realloc.
       */
      if (s->_flags.wide == 1)
	{
	  s->_contents.u = NSZoneRealloc(s->_zone,
	    s->_contents.u, s->_capacity*sizeof(unichar));
	}
      else
	{
	  s->_contents.c = NSZoneRealloc(s->_zone,
	    s->_contents.c, s->_capacity);
	}
    }
  else
    {
      /*
       * If the initial data was not to be freed, we must allocate new
       * buffer, copy the data, and set up the zone we are using.
       */
      if (s->_zone == 0)
	{
#if	GS_WITH_GC
	  s->_zone = GSAtomicMallocZone();
#else
	  if (s->isa == 0)
	    {
	      s->_zone = NSDefaultMallocZone();
	    }
	  else
	    {
	      s->_zone = GSObjCZone((NSString*)s);
	    }
#endif
	}
      if (s->_flags.wide == 1)
	{
	  unichar	*tmp = s->_contents.u;

	  s->_contents.u = NSZoneMalloc(s->_zone,
	    s->_capacity*sizeof(unichar));
	  if (s->_count > 0)
	    {
	      memcpy(s->_contents.u, tmp, s->_count*sizeof(unichar));
	    }
	}
      else
	{
	  unsigned char	*tmp = s->_contents.c;

	  s->_contents.c = NSZoneMalloc(s->_zone, s->_capacity);
	  if (s->_count > 0)
	    {
	      memcpy(s->_contents.c, tmp, s->_count);
	    }
	}
      s->_flags.free = 1;
    }
}

static void GSStrWiden(GSStr s)
{
  unichar	*tmp = 0;
  int		len = 0;

  NSCAssert(s->_flags.wide == 0, @"string is not wide");

  /*
   * As a special case, where we are ascii or latin1 and the buffer size
   * is big enough, we can widen to unicode without having to allocate
   * more memory or call a character conversion function.
   */
  if (s->_count <= s->_capacity / 2)
    {
      if (intEnc == NSISOLatin1StringEncoding
	|| intEnc == NSASCIIStringEncoding)
	{
	  len = s->_count;
	  while (len-- > 0)
	    {
	      s->_contents.u[len] = s->_contents.c[len];
	    }
	  s->_capacity /= 2;
	  s->_flags.wide = 1;
	  return;
	}
    }

  if (!s->_zone)
    {
#if GS_WITH_GC
      s->_zone = GSAtomicMallocZone();
#else
      if (s->isa == 0)
	{
	  s->_zone = NSDefaultMallocZone();
	}
      else
	{
	  s->_zone = GSObjCZone((NSString*)s);
	}
#endif
    }

  if (!GSToUnicode(&tmp, &len, s->_contents.c, s->_count, intEnc, s->_zone, 0))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"widen of string failed"];
    }
  if (s->_flags.free == 1)
    {
      NSZoneFree(s->_zone, s->_contents.c);
    }
  else
    {
      s->_flags.free = 1;
    }
  s->_contents.u = tmp;
  s->_flags.wide = 1;
  s->_count = len;
  s->_capacity = len;
}

static inline void
makeHole(GSStr self, unsigned int index, unsigned int size)
{
  NSCAssert(size > 0, @"size < zero");
  NSCAssert(index <= self->_count, @"index > length");

  if (self->_count + size + 1 >= self->_capacity)
    {
      GSStrMakeSpace((GSStr)self, size);
    }

  if (index < self->_count)
    {
      if (self->_flags.wide == 1)
	{
	  memmove(self->_contents.u + index + size,
	    self->_contents.u + index,
	    sizeof(unichar)*(self->_count - index));
	}
      else
	{
	  memmove(self->_contents.c + index + size,
	    self->_contents.c + index,
	    (self->_count - index));
	}
    }

  self->_count += size;
  self->_flags.hash = 0;
}

static inline NSRange
rangeOfSequence_c(GSStr self, unsigned anIndex)
{
  if (anIndex >= self->_count)
    [NSException raise: NSRangeException format:@"Invalid location."];

  return (NSRange){anIndex, 1};
}

static inline NSRange
rangeOfSequence_u(GSStr self, unsigned anIndex)
{
  unsigned	start;
  unsigned	end;

  if (anIndex >= self->_count)
    [NSException raise: NSRangeException format:@"Invalid location."];

  start = anIndex;
  while (uni_isnonsp(self->_contents.u[start]) && start > 0)
    start--;
  end = start + 1;
  if (end < self->_count)
    while ((end < self->_count) && (uni_isnonsp(self->_contents.u[end])) )
      end++;
  return (NSRange){start, end-start};
}

static inline NSRange
rangeOfCharacter_c(GSStr self, NSCharacterSet *aSet, unsigned mask,
  NSRange aRange)
{
  int		i;
  int		start;
  int		stop;
  int		step;
  NSRange	range;
  BOOL		(*mImp)(id, SEL, unichar);

  if (aSet == nil)
    [NSException raise: NSInvalidArgumentException format: @"range of nil"];
  i = self->_count;

  if ((mask & NSBackwardsSearch) == NSBackwardsSearch)
    {
      start = NSMaxRange(aRange)-1; stop = aRange.location-1; step = -1;
    }
  else
    {
      start = aRange.location; stop = NSMaxRange(aRange); step = 1;
    }
  range.location = NSNotFound;
  range.length = 0;

  mImp = (BOOL(*)(id,SEL,unichar))
    [aSet methodForSelector: cMemberSel];

  for (i = start; i != stop; i += step)
    {
      unichar letter = self->_contents.c[i];

      if (letter > 127)
	{
	  letter = encode_chartouni(letter, intEnc);
	}
      if ((*mImp)(aSet, cMemberSel, letter))
	{
	  range = NSMakeRange(i, 1);
	  break;
	}
    }

  return range;
}

static inline NSRange
rangeOfCharacter_u(GSStr self, NSCharacterSet *aSet, unsigned mask,
  NSRange aRange)
{
  int		i;
  int		start;
  int		stop;
  int		step;
  NSRange	range;
  BOOL		(*mImp)(id, SEL, unichar);

  if (aSet == nil)
    [NSException raise: NSInvalidArgumentException format: @"range of nil"];
  i = self->_count;

  if ((mask & NSBackwardsSearch) == NSBackwardsSearch)
    {
      start = NSMaxRange(aRange)-1; stop = aRange.location-1; step = -1;
    }
  else
    {
      start = aRange.location; stop = NSMaxRange(aRange); step = 1;
    }
  range.location = NSNotFound;
  range.length = 0;

  mImp = (BOOL(*)(id,SEL,unichar))
    [aSet methodForSelector: cMemberSel];

  for (i = start; i != stop; i += step)
    {
      unichar letter = self->_contents.u[i];

      if ((*mImp)(aSet, cMemberSel, letter))
	{
	  range = NSMakeRange(i, 1);
	  break;
	}
    }

  return range;
}

static inline NSRange
rangeOfString_c(GSStr self, NSString *aString, unsigned mask, NSRange aRange)
{
  Class	c;

  if (aString == nil)
    [NSException raise: NSInvalidArgumentException format: @"range of nil"];
  if (GSObjCIsInstance(aString) == NO)
    return strRangeCsNs((id)self, aString, mask, aRange);

  c = GSObjCClass(aString);
  if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES
    || (c == GSMutableStringClass && ((GSStr)aString)->_flags.wide == 1))
    return strRangeCsUs((id)self, aString, mask, aRange);
  else if (GSObjCIsKindOf(c, GSCStringClass) == YES
    || c == NSConstantStringClass
    || (c == GSMutableStringClass && ((GSStr)aString)->_flags.wide == 0))
    return strRangeCsCs((id)self, aString, mask, aRange);
  else
    return strRangeCsNs((id)self, aString, mask, aRange);
}

static inline NSRange
rangeOfString_u(GSStr self, NSString *aString, unsigned mask, NSRange aRange)
{
  Class	c;

  if (aString == nil)
    [NSException raise: NSInvalidArgumentException format: @"range of nil"];
  if (GSObjCIsInstance(aString) == NO)
    return strRangeUsNs((id)self, aString, mask, aRange);

  c = GSObjCClass(aString);
  if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES
    || (c == GSMutableStringClass && ((GSStr)aString)->_flags.wide == 1))
    return strRangeUsUs((id)self, aString, mask, aRange);
  else if (GSObjCIsKindOf(c, GSCStringClass) == YES
    || c == NSConstantStringClass
    || (c == GSMutableStringClass && ((GSStr)aString)->_flags.wide == 0))
    return strRangeUsCs((id)self, aString, mask, aRange);
  else
    return strRangeUsNs((id)self, aString, mask, aRange);
}

static inline NSString*
substring_c(GSStr self, NSRange aRange)
{
  id	sub;

  if (self->_flags.free == 1)
    {
      sub = NSAllocateObject(GSCSubStringClass, 0, NSDefaultMallocZone());
      sub = [sub initWithCString: self->_contents.c + aRange.location
			  length: aRange.length
		      fromParent: (GSCString *)self];
    }
  else
    {
      sub = NSAllocateObject(GSCInlineStringClass,
	aRange.length, NSDefaultMallocZone());
      sub = [sub initWithCString: self->_contents.c + aRange.location
			  length: aRange.length];
    }
  AUTORELEASE(sub);
  return sub;
}

static inline NSString*
substring_u(GSStr self, NSRange aRange)
{
  id	sub;

  if (self->_flags.free == 1)
    {
      sub = NSAllocateObject(GSUnicodeSubStringClass, 0, NSDefaultMallocZone());
      sub = [sub initWithCharacters: self->_contents.u + aRange.location
			     length: aRange.length
			 fromParent: (GSUnicodeString *)self];
    }
  else
    {
      sub = NSAllocateObject(GSUnicodeInlineStringClass,
	aRange.length*sizeof(unichar),
	NSDefaultMallocZone());
      sub = [sub initWithCharacters: self->_contents.u + aRange.location
			     length: aRange.length];
    }
  AUTORELEASE(sub);
  return sub;
}

/*
 * Function to examine the given string and see if it is one of our concrete
 * string classes.  Converts the mutable string (self) from 8-bit to 16-bit
 * representation if necessary in order to contain the data in aString.
 * Returns a pointer to aStrings GSStr if aString is a concrete class
 * from which contents may be copied directly without conversion.
 */
static inline GSStr
transmute(GSStr self, NSString *aString)
{
  GSStr	other = (GSStr)aString;
  BOOL	transmute = YES;
  Class	c = GSObjCClass(aString);	// NB aString must not be nil

  if (self->_flags.wide == 1)
    {
      /*
       * This is already a unicode string, so we don't need to transmute,
       * but we still need to know if the other string is a unicode
       * string whose GSStr we can access directly.
       */
      transmute = NO;
      if (GSObjCIsKindOf(c, GSUnicodeStringClass) == NO
	&& (c != GSMutableStringClass || other->_flags.wide != 1))
	{
	  other = 0;
	}
    }
  else
    {
      /*
       * This is a string held in the internal 8-bit encoding.
       */
      if (GSObjCIsKindOf(c, GSCStringClass) || c == NSConstantStringClass
	|| (c == GSMutableStringClass && other->_flags.wide == 0))
	{
	  /*
	   * The other string is also held in the internal 8-bit encoding,
	   * so we don't need to transmute, and we can use its GSStr.
	   */
	  transmute = NO;
	}
      else if (intEnc == defEnc
	&& [aString canBeConvertedToEncoding: intEnc] == YES)
	{
	  /*
	   * The other string can be converted to the internal 8-bit encoding,
	   * via the cString method, so we don't need to transmute, but we
	   * can *not* use its GSStr.
	   * NB. If 'intEnc != defEnc' the cString method of the other string
	   * will not return data in the internal encoding.
	   */
	  transmute = NO;
	  other = 0;
	}
      else if ((c == GSMutableStringClass && other->_flags.wide == 1)
	|| GSObjCIsKindOf(c, GSUnicodeStringClass) == YES)
	{
	  /*
	   * The other string can not be converted to the internal 8-bit
	   * encoding, so we need to transmute, and will then be able to
	   * use its GSStr.
	   */
	  transmute = YES;
	}
      else
	{
	  /*
	   * The other string can not be converted to the internal 8-bit
	   * character string, so we need to transmute, but even then we
	   * will not be able to use the other strings GSStr because that
	   * string is not a known GSString subclass.
	   */
	  other = 0;
	}
    }

  if (transmute == YES)
    {
      GSStrWiden((GSStr)self);
    }

  return other;
}



/*
 * The GSString class is actually only provided to provide a common ivar
 * layout for all subclasses, so that they can all share the same code.
 * This class should never be instantiated, and with the exception of
 * -copyWithZone:, none of its memory management related methods
 * (initializers and -dealloc) should ever be called. We guard against
 * this happening.
 */ 
@implementation GSString

+ (void) initialize
{
  setup();
}

- (void) dealloc
{
  [self subclassResponsibility: _cmd];
}

/*
 * Try to initialise a unicode string.
 */
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/*
 * Try to initialise a 'C' string.
 * Only ever called if defEnc==intEnc
 */
- (id) initWithCStringNoCopy: (char*)chars
		      length: (unsigned int)length
	        freeWhenDone: (BOOL)flag
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) copyWithZone: (NSZone*)z
{
  [self subclassResponsibility: _cmd];
  return nil;
}

@end



@implementation GSCString
- (const char *) UTF8String
{
  return UTF8String_c((GSStr)self);
}

- (BOOL) boolValue
{
  return boolValue_c((GSStr)self);
}

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)enc
{
  return canBeConvertedToEncoding_c((GSStr)self, enc);
}

- (unichar) characterAtIndex: (unsigned int)index
{
  return characterAtIndex_c((GSStr)self, index);
}

- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  return compare_c((GSStr)self, aString, mask, aRange);
}

- (const char *) cString
{
  return cString_c((GSStr)self);
}

- (unsigned int) cStringLength
{
  return cStringLength_c((GSStr)self);
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
	 allowLossyConversion: (BOOL)flag
{
  return dataUsingEncoding_c((GSStr)self, encoding, flag);
}

- (double) doubleValue
{
  return doubleValue_c((GSStr)self);
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &_count];
  if (_count > 0)
    {
      [aCoder encodeValueOfObjCType: @encode(NSStringEncoding) at: &intEnc];
      [aCoder encodeArrayOfObjCType: @encode(unsigned char)
			      count: _count
				 at: _contents.c];
    }
}

- (NSStringEncoding) fastestEncoding
{
  return intEnc;
}

- (float) floatValue
{
  return doubleValue_c((GSStr)self);
}

- (void) getCharacters: (unichar*)buffer
{
  getCharacters_c((GSStr)self, buffer, (NSRange){0, _count});
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  getCharacters_c((GSStr)self, buffer, aRange);
}

- (void) getCString: (char*)buffer
{
  getCString_c((GSStr)self, buffer, NSMaximumStringLength,
    (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
{
  getCString_c((GSStr)self, buffer, maxLength, (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
	      range: (NSRange)aRange
     remainingRange: (NSRange*)leftoverRange
{
  GS_RANGE_CHECK(aRange, _count);
  getCString_c((GSStr)self, buffer, maxLength, aRange, leftoverRange);
}

- (unsigned) hash
{
  if (self->_flags.hash == 0)
    {
      self->_flags.hash = (*hashImp)((id)self, hashSel);
    }
  return self->_flags.hash;
}

- (int) intValue
{
  return intValue_c((GSStr)self);
}

- (BOOL) isEqual: (id)anObject
{
  return isEqual_c((GSStr)self, anObject);
}

- (BOOL) isEqualToString: (NSString*)anObject
{
  return isEqual_c((GSStr)self, anObject);
}

- (unsigned int) length
{
  return _count;
}

- (const char*) lossyCString
{
  return lossyCString_c((GSStr)self);
}

- (id) mutableCopy
{
  GSMutableString	*obj;

  obj = (GSMutableString*)NSAllocateObject(GSMutableStringClass, 0,
    NSDefaultMallocZone());
  obj = [obj initWithCString: _contents.c length: _count];
  return obj;
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  GSMutableString	*obj;

  obj = (GSMutableString*)NSAllocateObject(GSMutableStringClass, 0, z);
  obj = [obj initWithCString: _contents.c length: _count];
  return obj;
}

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned)anIndex
{
  return rangeOfSequence_c((GSStr)self, anIndex);
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned)mask
			      range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return rangeOfCharacter_c((GSStr)self, aSet, mask, aRange);
}

- (NSRange) rangeOfString: (NSString*)aString
		  options: (unsigned)mask
		    range: (NSRange)aRange
{
  return rangeOfString_c((GSStr)self, aString, mask, aRange);
}

- (NSStringEncoding) smallestEncoding
{
  return intEnc;
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return substring_c((GSStr)self, aRange);
}

- (NSString*) substringWithRange: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return substring_c((GSStr)self, aRange);
}

// private method for Unicode level 3 implementation
- (int) _baseLength
{
  return _count;
} 

/*
Default copy implementation. Retain if we own the buffer and the zones
agree, create a new GSCInlineString otherwise.
*/
- (id) copyWithZone: (NSZone*)z
{
  if (!_flags.free || NSShouldRetainWithZone(self, z) == NO)
    {
      NSString	*obj;

      obj = (NSString*)NSAllocateObject(GSCInlineStringClass, _count, z);
      obj = [obj initWithCString: _contents.c length: _count];
      return obj;
    }
  else
    {
      return RETAIN(self);
    }
}

@end



@implementation GSCBufferString
- (id) initWithCStringNoCopy: (char*)chars
		      length: (unsigned int)length
	        freeWhenDone: (BOOL)flag
{
  if (_contents.c != 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"re-initialisation of string"];
    }
  _count = length;
  _contents.c = chars;
  _flags.wide = 0;
  if (flag == YES)
    {
      _flags.free = 1;
    }
  return self;
}

- (void) dealloc
{
  if (_flags.free && _contents.c != 0)
    {
      NSZoneFree(NSZoneFromPointer(_contents.c), _contents.c);
      _contents.c = 0;
    }
  NSDeallocateObject(self);
}
@end



@implementation	GSCInlineString
- (id) initWithCString: (const char*)chars length: (unsigned)length
{
  if (_contents.c != 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"re-initialisation of string"];
    }
  _count = length;
  _contents.c = (unsigned char*)&self[1];
  if (_count > 0)
    memcpy(_contents.c, chars, length);
  _flags.wide = 0;
  _flags.free = 1;
  return self;
}

- (void) dealloc
{
  NSDeallocateObject(self);
}
@end



@implementation	GSCSubString
- (id) initWithCString: (char *)chars length: (unsigned)length
	    fromParent: (GSCString *)parent
{
  if (_contents.c != 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"re-initialisation of string"];
    }
  _count = length;
  _contents.c = (unsigned char *)chars;
  _flags.wide = 0;
  _flags.free = 1;
  ASSIGN(_parent, parent);
  return self;
}

/*
 * Assume that a copy should be a new string, never just a retained substring.
 */
- (id) copyWithZone: (NSZone*)z
{
  NSString	*obj;

  obj = (NSString*)NSAllocateObject(GSCInlineStringClass, _count, z);
  obj = [obj initWithCString: _contents.c length: _count];
  return obj;
}

- (void) dealloc
{
  DESTROY(_parent);
  NSDeallocateObject(self);
}
@end



@implementation GSUnicodeString
- (const char *) UTF8String
{
  return UTF8String_u((GSStr)self);
}

- (BOOL) boolValue
{
  return boolValue_u((GSStr)self);
}

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)enc
{
  return canBeConvertedToEncoding_u((GSStr)self, enc);
}

- (unichar) characterAtIndex: (unsigned int)index
{
  return characterAtIndex_u((GSStr)self, index);
}

- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  return compare_u((GSStr)self, aString, mask, aRange);
}

- (const char *) cString
{
  return cString_u((GSStr)self);
}

- (unsigned int) cStringLength
{
  return cStringLength_u((GSStr)self);
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
	 allowLossyConversion: (BOOL)flag
{
  return dataUsingEncoding_u((GSStr)self, encoding, flag);
}

- (double) doubleValue
{
  return doubleValue_u((GSStr)self);
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &_count];
  if (_count > 0)
    {
      NSStringEncoding	enc = NSUnicodeStringEncoding;

      [aCoder encodeValueOfObjCType: @encode(NSStringEncoding) at: &enc];
      [aCoder encodeArrayOfObjCType: @encode(unichar)
			      count: _count
				 at: _contents.u];
    }
}

- (NSStringEncoding) fastestEncoding
{
  return NSUnicodeStringEncoding;
}

- (float) floatValue
{
  return doubleValue_u((GSStr)self);
}

- (void) getCharacters: (unichar*)buffer
{
  getCharacters_u((GSStr)self, buffer, (NSRange){0, _count});
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  getCharacters_u((GSStr)self, buffer, aRange);
}

- (void) getCString: (char*)buffer
{
  getCString_u((GSStr)self, buffer, NSMaximumStringLength,
    (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
{
  getCString_u((GSStr)self, buffer, maxLength, (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
	      range: (NSRange)aRange
     remainingRange: (NSRange*)leftoverRange
{
  GS_RANGE_CHECK(aRange, _count);

  getCString_u((GSStr)self, buffer, maxLength, aRange, leftoverRange);
}

- (unsigned) hash
{
  if (self->_flags.hash == 0)
    {
      self->_flags.hash = (*hashImp)((id)self, hashSel);
    }
  return self->_flags.hash;
}

- (int) intValue
{
  return intValue_u((GSStr)self);
}

- (BOOL) isEqual: (id)anObject
{
  return isEqual_u((GSStr)self, anObject);
}

- (BOOL) isEqualToString: (NSString*)anObject
{
  return isEqual_u((GSStr)self, anObject);
}

- (unsigned int) length
{
  return _count;
}

- (const char*) lossyCString
{
  return lossyCString_u((GSStr)self);
}

- (id) mutableCopy
{
  GSMutableString	*obj;

  obj = (GSMutableString*)NSAllocateObject(GSMutableStringClass, 0,
    NSDefaultMallocZone());
  obj = [obj initWithCharacters: _contents.u length: _count];
  return obj;
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  GSMutableString	*obj;

  obj = (GSMutableString*)NSAllocateObject(GSMutableStringClass, 0, z);
  obj = [obj initWithCharacters: _contents.u length: _count];
  return obj;
}

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned)anIndex
{
  return rangeOfSequence_u((GSStr)self, anIndex);
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned)mask
			      range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return rangeOfCharacter_u((GSStr)self, aSet, mask, aRange);
}

- (NSRange) rangeOfString: (NSString*)aString
		  options: (unsigned)mask
		    range: (NSRange)aRange
{
  return rangeOfString_u((GSStr)self, aString, mask, aRange);
}

- (NSStringEncoding) smallestEncoding
{
  return NSUnicodeStringEncoding;
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return substring_u((GSStr)self, aRange);
}

- (NSString*) substringWithRange: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return substring_u((GSStr)self, aRange);
}

// private method for Unicode level 3 implementation
- (int) _baseLength
{
  unsigned int count = 0;
  unsigned int blen = 0;

  while (count < _count)
    if (!uni_isnonsp(_contents.u[count++]))
      blen++;
  return blen;
} 

/*
Default -copy implementation. Retain if we own the buffer and the zones
agree, create a new GSUnicodeInlineString otherwise.
*/
- (id) copyWithZone: (NSZone*)z
{
  if (!_flags.free || NSShouldRetainWithZone(self, z) == NO)
    {
      NSString	*obj;

      obj = (NSString*)NSAllocateObject(GSUnicodeInlineStringClass,
	_count*sizeof(unichar), z);
      obj = [obj initWithCharacters: _contents.u length: _count];
      return obj;
    }
  else 
    {
      return RETAIN(self);
    }
}

@end



@implementation	GSUnicodeBufferString
- (id) initWithCharactersNoCopy: (unichar *)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
  if (_contents.u != 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"re-initialisation of string"];
    }
  _count = length;
  _contents.u = chars;
  _flags.wide = 1;
  if (flag == YES)
    {
      _flags.free = 1;
    }
  return self;
}

- (void) dealloc
{
  if (_flags.free && _contents.u != 0)
    {
      NSZoneFree(NSZoneFromPointer(_contents.u), _contents.u);
      _contents.u = 0;
    }
  NSDeallocateObject(self);
}
@end



@implementation	GSUnicodeInlineString
- (id) initWithCharacters: (const unichar*)chars length: (unsigned)length
{
  if (_contents.u != 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"re-initialisation of string"];
    }
  _count = length;
  _contents.u = (unichar*)&((GSUnicodeInlineString*)self)[1];
  if (_count > 0)
    memcpy(_contents.u, chars, length*sizeof(unichar));
  _flags.wide = 1;
  _flags.free = 1;
  return self;
}

- (void) dealloc
{
  NSDeallocateObject(self);
}
@end



@implementation	GSUnicodeSubString
- (id) initWithCharacters: (unichar *)chars length: (unsigned)length
	       fromParent: (GSUnicodeString *)parent
{
  if (_contents.u != 0)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"re-initialisation of string"];
    }
  _count = length;
  _contents.u = chars;
  _flags.wide = 1;
  _flags.free = 1;
  ASSIGN(_parent, parent);
  return self;
}

/*
 * Assume that a copy should be a new string, never just a retained substring.
 */
- (id) copyWithZone: (NSZone*)z
{
  NSString	*obj;

  obj = (NSString*)NSAllocateObject(GSUnicodeInlineStringClass,
    _count*sizeof(unichar), z);
  obj = [obj initWithCharacters: _contents.u length: _count];
  return obj;
}

- (void) dealloc
{
  DESTROY(_parent);
  NSDeallocateObject(self);
}
@end



/*
 * The GSMutableString class shares a common initial ivar layout with
 * the GSString class, but adds a few of its own.  It uses _flags.wide
 * to determine whether it should use 8-bit or 16-bit characters and
 * is capable of changing that flag (and its underlying storage) to
 * move from an 8-bit to a 16-bit representation is that should be
 * necessary because wide characters have been placed in the string.
 * If defEnc!=intEnc, GSMutableString objects will always have
 * _flags.wide set, since ite cannot have been initialised as a C String.
 */
@implementation GSMutableString

+ (void) initialize
{
  setup();
}

- (void) appendFormat: (NSString*)format, ...
{
  va_list	ap;
  unichar	buf[1024];
  unichar	*fmt = buf;
  size_t	len;

  va_start(ap, format);

  /*
   * Make sure we have the format string in a nul terminated array of
   * unichars for passing to GSFormat.  Use on-stack memory for performance
   * unless the size of the format string is really big (a rare occurrance).
   */
  len = [format length];
  if (len >= 1024)
    {
      fmt = objc_malloc((len+1)*sizeof(unichar));
    }
  [format getCharacters: fmt];
  fmt[len] = '\0';

  /*
   * If no zone is set, make sure we have one so any memory mangement
   * (buffer growth) is done with the correct zone.
   */
  if (_zone == 0)
    {
#if	GS_WITH_GC
      _zone = GSAtomicMallocZone();
#else
      _zone = GSObjCZone(self);
#endif
    }
  GSFormat((GSStr)self, fmt, ap, nil);
  _flags.hash = 0;	// Invalidate the hash for this string.
  if (fmt != buf)
    {
      objc_free(fmt);
    }
  va_end(ap);
}

- (BOOL) boolValue
{
  if (_flags.wide == 1)
    return boolValue_u((GSStr)self);
  else
    return boolValue_c((GSStr)self);
}

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)enc
{
  if (_flags.wide == 1)
    return canBeConvertedToEncoding_u((GSStr)self, enc);
  else
    return canBeConvertedToEncoding_c((GSStr)self, enc);
}

- (unichar) characterAtIndex: (unsigned int)index
{
  if (_flags.wide == 1)
    return characterAtIndex_u((GSStr)self, index);
  else
    return characterAtIndex_c((GSStr)self, index);
}

- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  if (_flags.wide == 1)
    return compare_u((GSStr)self, aString, mask, aRange);
  else
    return compare_c((GSStr)self, aString, mask, aRange);
}

- (id) copyWithZone: (NSZone*)z
{
  id	copy;

  if (_flags.wide == 1)
    {
      copy = (NSString*)NSAllocateObject(GSUnicodeInlineStringClass,
	_count*sizeof(unichar), z);
      copy = [copy initWithCharacters: _contents.u length: _count];
    }
  else
    {
      copy = (NSString*)NSAllocateObject(GSCInlineStringClass, _count, z);
      copy = [copy initWithCString: _contents.c length: _count];
    }
  return copy;
}

- (const char *) cString
{
  if (_flags.wide == 1)
    return cString_u((GSStr)self);
  else
    return cString_c((GSStr)self);
}

- (unsigned int) cStringLength
{
  if (_flags.wide == 1)
    return cStringLength_u((GSStr)self);
  else
    return cStringLength_c((GSStr)self);
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
	 allowLossyConversion: (BOOL)flag
{
  if (_flags.wide == 1)
    return dataUsingEncoding_u((GSStr)self, encoding, flag);
  else
    return dataUsingEncoding_c((GSStr)self, encoding, flag);
}

- (void) dealloc
{
  if (_flags.free == 1 && _zone != 0 && _contents.c != 0)
    {
      NSZoneFree(self->_zone, self->_contents.c);
      self->_contents.c = 0;
      self->_zone = 0;
    }
  NSDeallocateObject(self);
}

- (void) deleteCharactersInRange: (NSRange)range
{
  GS_RANGE_CHECK(range, _count);
  if (range.length > 0)
    {
      fillHole((GSStr)self, range.location, range.length);
    }
}

- (double) doubleValue
{
  if (_flags.wide == 1)
    return doubleValue_u((GSStr)self);
  else
    return doubleValue_c((GSStr)self);
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &_count];
  if (_count > 0)
    {
      if (_flags.wide == 1)
	{
	  NSStringEncoding	enc = NSUnicodeStringEncoding;

	  [aCoder encodeValueOfObjCType: @encode(NSStringEncoding) at: &enc];
	  [aCoder encodeArrayOfObjCType: @encode(unichar)
				  count: _count
				     at: _contents.u];
	}
      else
	{
	  [aCoder encodeValueOfObjCType: @encode(NSStringEncoding) at: &intEnc];
	  [aCoder encodeArrayOfObjCType: @encode(unsigned char)
				  count: _count
				     at: _contents.c];
	}
    }
}

- (NSStringEncoding) fastestEncoding
{
  if (_flags.wide == 1)
    return NSUnicodeStringEncoding;
  else
    return intEnc;
}

- (float) floatValue
{
  if (_flags.wide == 1)
    return doubleValue_u((GSStr)self);
  else
    return doubleValue_c((GSStr)self);
}

- (void) getCharacters: (unichar*)buffer
{
  if (_flags.wide == 1)
    getCharacters_u((GSStr)self, buffer, (NSRange){0, _count});
  else
    getCharacters_c((GSStr)self, buffer, (NSRange){0, _count});
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  if (_flags.wide == 1)
    {
      getCharacters_u((GSStr)self, buffer, aRange);
    }
  else
    {
      getCharacters_c((GSStr)self, buffer, aRange);
    }
}

- (void) getCString: (char*)buffer
{
  if (_flags.wide == 1)
    getCString_u((GSStr)self, buffer, NSMaximumStringLength,
      (NSRange){0, _count}, 0);
  else
    getCString_c((GSStr)self, buffer, NSMaximumStringLength,
      (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
{
  if (_flags.wide == 1)
    getCString_u((GSStr)self, buffer, maxLength, (NSRange){0, _count}, 0);
  else
    getCString_c((GSStr)self, buffer, maxLength, (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
	      range: (NSRange)aRange
     remainingRange: (NSRange*)leftoverRange
{
  GS_RANGE_CHECK(aRange, _count);
  if (_flags.wide == 1)
    {
      getCString_u((GSStr)self, buffer, maxLength, aRange, leftoverRange);
    }
  else
    {
      getCString_c((GSStr)self, buffer, maxLength, aRange, leftoverRange);
    }
}

- (unsigned) hash
{
  if (self->_flags.hash == 0)
    {
      self->_flags.hash = (*hashImp)((id)self, hashSel);
    }
  return self->_flags.hash;
}

- (id) init
{
  return [self initWithCapacity: 0];
}

- (id) initWithCapacity: (unsigned)capacity
{
  if (capacity < 2)
    {
      capacity = 2;
    }
  _count = 0;
  _capacity = capacity;
#if	GS_WITH_GC
  _zone = GSAtomicMallocZone();
#else
  _zone = GSObjCZone(self);
#endif
  _contents.c = NSZoneMalloc(_zone, capacity + 1);
  _flags.wide = 0;
  _flags.free = 1;
  return self;
}

- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
  _count = length;
  _capacity = length;
  _contents.u = chars;
  _flags.wide = 1;
  if (flag == YES && chars != 0)
    {
#if	GS_WITH_GC
      _zone = GSAtomicMallocZone();
#else
      _zone = NSZoneFromPointer(chars);
#endif
      _flags.free = 1;
    }
  else
    {
      _zone = 0;
    }
  return self;
}

- (id) initWithCStringNoCopy: (char*)chars
		      length: (unsigned int)length
	        freeWhenDone: (BOOL)flag
{
  if (defEnc != intEnc)
    {
      unichar	*u = 0;
      unsigned	l = 0;

      if (GSToUnicode(&u, &l, chars, length, defEnc, GSObjCZone(self), 0) == NO)
	{
	  DESTROY(self);
	}
      else
	{
	  self = [self initWithCharactersNoCopy: u length: l freeWhenDone: YES];
	}
      if (flag == YES && chars != 0)
	{
	  NSZoneFree(NSZoneFromPointer(chars), chars);
	}
      return self;
    }

  if (flag == YES && chars != 0)
    {
#if	GS_WITH_GC
      _zone = GSAtomicMallocZone();
#else
      _zone = NSZoneFromPointer(chars);
#endif
      _flags.free = 1;
    }
  else
    {
      _zone = 0;
    }
  _count = length;
  _capacity = length;
  _contents.c = chars;
  _flags.wide = 0;

  return self;
}

- (id) initWithFormat: (NSString*)format
               locale: (NSDictionary*)locale
	    arguments: (va_list)argList
{
  unichar	fbuf[1024];
  unichar	*fmt = fbuf;
  size_t	len;

  /*
   * First we provide an array of unichar characters containing the
   * format string.  For performance reasons we try to use an on-stack
   * buffer if the format string is small enough ... it almost always
   * will be.
   */
  len = [format length];
  if (len >= 1024)
    {
      fmt = objc_malloc((len+1)*sizeof(unichar));
    }
  [format getCharacters: fmt];
  fmt[len] = '\0';

  GSFormat((GSStr)self, fmt, argList, locale);
  if (fmt != fbuf)
    {
      objc_free(fmt);
    }
  return self;
}

- (int) intValue
{
  if (_flags.wide == 1)
    return intValue_u((GSStr)self);
  else
    return intValue_c((GSStr)self);
}

- (BOOL) isEqual: (id)anObject
{
  if (_flags.wide == 1)
    return isEqual_u((GSStr)self, anObject);
  else
    return isEqual_c((GSStr)self, anObject);
}

- (BOOL) isEqualToString: (NSString*)anObject
{
  if (_flags.wide == 1)
    return isEqual_u((GSStr)self, anObject);
  else
    return isEqual_c((GSStr)self, anObject);
}

- (unsigned int) length
{
  return _count;
}

- (const char*) lossyCString
{
  if (_flags.wide == 1)
    return lossyCString_u((GSStr)self);
  else
    return lossyCString_c((GSStr)self);
}

- (id) makeImmutableCopyOnFail: (BOOL)force
{
#ifndef NDEBUG
  GSDebugAllocationRemove(isa, self);
#endif
  if (_flags.wide == 1)
    {
      isa = [GSUnicodeBufferString class];
    }
  else
    {
      isa = [GSCBufferString class];
    }
#ifndef NDEBUG
  GSDebugAllocationAdd(isa, self);
#endif
  return self;
}

- (id) mutableCopy
{
  GSMutableString	*obj;

  obj = (GSMutableString*)NSAllocateObject(GSMutableStringClass, 0,
    NSDefaultMallocZone());

  if (_flags.wide == 1)
    obj = [obj initWithCharacters: _contents.u length: _count];
  else
    obj = [obj initWithCString: _contents.c length: _count];
  return obj;
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  GSMutableString	*obj;

  obj = (GSMutableString*)NSAllocateObject(GSMutableStringClass, 0, z);

  if (_flags.wide == 1)
    obj = [obj initWithCharacters: _contents.u length: _count];
  else
    obj = [obj initWithCString: _contents.c length: _count];
  return obj;
}

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned)anIndex
{
  if (_flags.wide == 1)
    return rangeOfSequence_u((GSStr)self, anIndex);
  else
    return rangeOfSequence_c((GSStr)self, anIndex);
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned)mask
			      range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  if (_flags.wide == 1)
    return rangeOfCharacter_u((GSStr)self, aSet, mask, aRange);
  else
    return rangeOfCharacter_c((GSStr)self, aSet, mask, aRange);
}

- (NSRange) rangeOfString: (NSString*)aString
		  options: (unsigned)mask
		    range: (NSRange)aRange
{
  if (_flags.wide == 1)
    return rangeOfString_u((GSStr)self, aString, mask, aRange);
  else
    return rangeOfString_c((GSStr)self, aString, mask, aRange);
}

- (void) replaceCharactersInRange: (NSRange)aRange
		       withString: (NSString*)aString
{
  GSStr		other = 0;
  int		offset;
  unsigned	length = 0;

  GS_RANGE_CHECK(aRange, _count);
  if (aString != nil)
    {
      if (GSObjCIsInstance(aString) == NO)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"replace characters with non-string"];
	}
      else
	{
	  length = (aString == nil) ? 0 : [aString length];
	}
    }
  offset = length - aRange.length;

  /*
   * We must change into a unicode string (if necessary) *before*
   * adjusting length and capacity, so that the transmute doesn't
   * mess up due to any hole in the string etc.
   */
  if (length > 0)
    {
      other = transmute((GSStr)self, aString);
    }

  if (offset < 0)
    {
      fillHole((GSStr)self, NSMaxRange(aRange) + offset, -offset);
    }
  else if (offset > 0)
    {
      makeHole((GSStr)self, NSMaxRange(aRange), (unsigned int)offset);
    }

  if (length > 0)
    {
      if (_flags.wide == 1)
	{
	  if (other == 0)
	    {
	      /*
	       * Not a cString class - use standard method to get characters.
	       */
	      [aString getCharacters: &_contents.u[aRange.location]];
	    }
	  else
	    {
	      memcpy(&_contents.u[aRange.location], other->_contents.u,
		length * sizeof(unichar));
	    }
	}
      else
	{
	  if (other == 0)
	    {
	      /*
	       * As we got here, intEnc == defEnc, so we can use standard
	       * CString methods to get the characters into our buffer,
	       * or may even be able to copy from another string directly.
	       *
	       * Since getCString appends a '\0' terminator, we must handle 
	       * that problem in copying data into our buffer.  Either by
	       * saving and restoring the character which would be
	       * overwritten by the nul, or by getting a character less,
	       * and fetching the last character separately.
	       */
	      if (aRange.location + length  < _count)
		{
		  unsigned char	tmp = _contents.c[aRange.location + length];

		  [aString getCString: &_contents.c[aRange.location]
			    maxLength: length];
		  _contents.c[aRange.location + length] = tmp;
		}
	      else
		{ 
		  unsigned int	l = length - 1;
		  unsigned int  size = 1;
		  unichar	u;
		  unsigned char *dst = &_contents.c[aRange.location + l];

		  if (l > 0)
		    {
		      [aString getCString: &_contents.c[aRange.location]
				maxLength: l];
		    }
		  u = [aString characterAtIndex: l];
		  GSFromUnicode(&dst, &size, &u, 1, intEnc, 0, 0);
		}
	    }
	  else
	    {
	      /*
	       * Simply copy cString data from other string into self.
	       */
	      memcpy(&_contents.c[aRange.location], other->_contents.c, length);
	    }
	}
      _flags.hash = 0;
    }
}

- (void) setString: (NSString*)aString
{
  unsigned int	len = (aString == nil) ? 0 : [aString length];
  GSStr	other;

  if (len == 0)
    {
      _count = 0;
      return;
    }
  other = transmute((GSStr)self, aString);
  if (_count < len)
    {
      makeHole((GSStr)self, _count, (unsigned int)(len - _count));
    }
  else
    {
      _count = len;
      _flags.hash = 0;
    }

  if (_flags.wide == 1)
    {
      if (other == 0)
	{
	  [aString getCharacters: _contents.u];
	}
      else
	{
	  memcpy(_contents.u, other->_contents.u, len * sizeof(unichar));
	}
    }
  else
    {
      if (other == 0)
	{
	  unsigned	l;

	  /*
	   * transmute() will leave us non-wide and return other == 0,
	   * only if intEnc == defEnc, so we get use the cstring methods
	   * to copy directly to our buffer.
	   *
	   * Since getCString appends a '\0' terminator, we must ask for
	   * one character less than we actually want, then get the last
	   * character separately.
	   */
	  l = len - 1;
	  if (l > 0)
	    {
	      [aString getCString: _contents.c maxLength: l];
	    }
	  _contents.c[l]
	    = encode_unitochar([aString characterAtIndex: l], intEnc);
	}
      else
	{
	  memcpy(_contents.c, other->_contents.c, len);
	}
    }
}

- (NSStringEncoding) smallestEncoding
{
  if (_flags.wide == 1)
    {
      return NSUnicodeStringEncoding;
    }
  else
    return intEnc;
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  NSString	*sub;

  GS_RANGE_CHECK(aRange, _count);

  if (_flags.wide == 1)
    {
      sub = (NSString*)NSAllocateObject(GSUnicodeInlineStringClass,
	_count*sizeof(unichar), NSDefaultMallocZone());
      sub = [sub initWithCharacters: self->_contents.u + aRange.location
			     length: aRange.length];
    }
  else
    {
      sub = (NSString*)NSAllocateObject(GSCInlineStringClass,
	_count, NSDefaultMallocZone());
      sub = [sub initWithCString: self->_contents.c + aRange.location
			  length: aRange.length];
    }
  AUTORELEASE(sub);
  return sub;
}

- (NSString*) substringWithRange: (NSRange)aRange
{
  NSString	*sub;

  GS_RANGE_CHECK(aRange, _count);

  if (_flags.wide == 1)
    {
      sub = (NSString*)NSAllocateObject(GSUnicodeInlineStringClass,
					(aRange.length)*sizeof(unichar),
					NSDefaultMallocZone());
      sub = [sub initWithCharacters: self->_contents.u + aRange.location
			     length: aRange.length];
    }
  else
    {
      sub = (NSString*)NSAllocateObject(GSCInlineStringClass,
					aRange.length, 
					NSDefaultMallocZone());
      sub = [sub initWithCString: self->_contents.c + aRange.location
			  length: aRange.length];
    }
  AUTORELEASE(sub);
  return sub;
}

// private method for Unicode level 3 implementation
- (int) _baseLength
{
  if (_flags.wide == 1)
    {
      unsigned int count = 0;
      unsigned int blen = 0;

      while (count < _count)
	if (!uni_isnonsp(_contents.u[count++]))
	  blen++;
      return blen;
    }
  else
    return _count;
} 

@end



@interface	NSImmutableString: NSString
{
  id	_parent;
}
- (id) initWithString: (NSString*)parent;
@end

@interface	GSImmutableString: NSImmutableString
@end

@implementation NSImmutableString

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)enc
{
  return [_parent canBeConvertedToEncoding: enc];
}

- (unichar) characterAtIndex: (unsigned int)index
{
  return [_parent characterAtIndex: index];
}

- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  return [_parent compare: aString options: mask range: aRange];
}

- (const char *) cString
{
  return [_parent cString];
}

- (unsigned int) cStringLength
{
  return [_parent cStringLength];
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
	 allowLossyConversion: (BOOL)flag
{
  return [_parent dataUsingEncoding: encoding allowLossyConversion: flag];
}

- (void) dealloc
{
  RELEASE(_parent);
  [super dealloc];
}

- (id) copyWithZone: (NSZone*)z
{
  return [_parent copyWithZone: z];
}

- (id) mutableCopy
{
  return [_parent mutableCopy];
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  return [_parent mutableCopyWithZone: z];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [_parent encodeWithCoder: aCoder];
}

- (NSStringEncoding) fastestEncoding
{
  return [_parent fastestEncoding];
}

- (void) getCharacters: (unichar*)buffer
{
  [_parent getCharacters: buffer];
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  [_parent getCharacters: buffer range: aRange];
}

- (void) getCString: (char*)buffer
{
  [_parent getCString: buffer];
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
{
  [_parent getCString: buffer maxLength: maxLength];
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
	      range: (NSRange)aRange
     remainingRange: (NSRange*)leftoverRange
{
  [_parent getCString: buffer
	    maxLength: maxLength
		range: aRange
       remainingRange: leftoverRange];
}

- (unsigned) hash
{
  return [_parent hash];
}

- (id) initWithString: (NSString*)parent
{
  _parent = RETAIN(parent);
  return self;
}

- (BOOL) isEqual: (id)anObject
{
  return [_parent isEqual: anObject];
}

- (BOOL) isEqualToString: (NSString*)anObject
{
  return [_parent isEqualToString: anObject];
}

- (unsigned int) length
{
  return [_parent length];
}

- (const char*) lossyCString
{
  return [_parent lossyCString];
}

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned)anIndex
{
  return [_parent rangeOfComposedCharacterSequenceAtIndex: anIndex];
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned)mask
			      range: (NSRange)aRange
{
  return [_parent rangeOfCharacterFromSet: aSet options: mask range: aRange];
}

- (NSRange) rangeOfString: (NSString*)aString
		  options: (unsigned)mask
		    range: (NSRange)aRange
{
  return [_parent rangeOfString: aString options: mask range: aRange];
}

- (NSStringEncoding) smallestEncoding
{
  return [_parent smallestEncoding];
}

@end


@implementation GSImmutableString

+ (void) initialize
{
  setup();
}

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)enc
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return canBeConvertedToEncoding_u((GSStr)_parent, enc);
  else
    return canBeConvertedToEncoding_c((GSStr)_parent, enc);
}

- (unichar) characterAtIndex: (unsigned int)index
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return characterAtIndex_u((GSStr)_parent, index);
  else
    return characterAtIndex_c((GSStr)_parent, index);
}

- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return compare_u((GSStr)_parent, aString, mask, aRange);
  else
    return compare_c((GSStr)_parent, aString, mask, aRange);
}

- (const char *) cString
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return cString_u((GSStr)_parent);
  else
    return cString_c((GSStr)_parent);
}

- (unsigned int) cStringLength
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return cStringLength_u((GSStr)_parent);
  else
    return cStringLength_c((GSStr)_parent);
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
	 allowLossyConversion: (BOOL)flag
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return dataUsingEncoding_u((GSStr)_parent, encoding, flag);
  else
    return dataUsingEncoding_c((GSStr)_parent, encoding, flag);
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [_parent encodeWithCoder: aCoder];
}

- (NSStringEncoding) fastestEncoding
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return NSUnicodeStringEncoding;
  else
    return intEnc;
}

- (void) getCharacters: (unichar*)buffer
{
  if (((GSStr)_parent)->_flags.wide == 1)
    {
      getCharacters_u((GSStr)_parent, buffer,
	(NSRange){0, ((GSStr)_parent)->_count});
    }
  else
    {
      getCharacters_c((GSStr)_parent, buffer,
	(NSRange){0, ((GSStr)_parent)->_count});
    }
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, ((GSStr)_parent)->_count);
  if (((GSStr)_parent)->_flags.wide == 1)
    {
      getCharacters_u((GSStr)_parent, buffer, aRange);
    }
  else
    {
      getCharacters_c((GSStr)_parent, buffer, aRange);
    }
}

- (unsigned) hash
{
  if (((GSStr)_parent)->_flags.hash == 0)
    {
      ((GSStr)_parent)->_flags.hash = (*hashImp)((id)_parent, hashSel);
    }
  return ((GSStr)_parent)->_flags.hash;
}

- (BOOL) isEqual: (id)anObject
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return isEqual_u((GSStr)_parent, anObject);
  else
    return isEqual_c((GSStr)_parent, anObject);
}

- (BOOL) isEqualToString: (NSString*)anObject
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return isEqual_u((GSStr)_parent, anObject);
  else
    return isEqual_c((GSStr)_parent, anObject);
}

- (unsigned int) length
{
  return ((GSStr)_parent)->_count;
}

- (const char*) lossyCString
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return lossyCString_u((GSStr)_parent);
  else
    return lossyCString_c((GSStr)_parent);
}

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned)anIndex
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return rangeOfSequence_u((GSStr)_parent, anIndex);
  else
    return rangeOfSequence_c((GSStr)_parent, anIndex);
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned)mask
			      range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, ((GSStr)_parent)->_count);
  if (((GSStr)_parent)->_flags.wide == 1)
    return rangeOfCharacter_u((GSStr)_parent, aSet, mask, aRange);
  else
    return rangeOfCharacter_c((GSStr)_parent, aSet, mask, aRange);
}

- (NSRange) rangeOfString: (NSString*)aString
		  options: (unsigned)mask
		    range: (NSRange)aRange
{
  if (((GSStr)_parent)->_flags.wide == 1)
    return rangeOfString_u((GSStr)_parent, aString, mask, aRange);
  else
    return rangeOfString_c((GSStr)_parent, aString, mask, aRange);
}

- (NSStringEncoding) smallestEncoding
{
  if (((GSStr)_parent)->_flags.wide == 1)
    {
      return NSUnicodeStringEncoding;
    }
  else
    return intEnc;
}

@end



/**
 * <p>The NXConstantString class is used by the compiler for constant
 * strings, as such its ivar layout is determined by the compiler
 * and consists of a pointer (_contents.c) and a character count
 * (_count).  So, while this class inherits GSCString behavior,
 * the code must make sure not to use any other GSCString GSStr
 * when accesssing an NXConstantString.</p>
 */
@implementation NXConstantString

+ (void) initialize
{
  if (self == [NXConstantString class])
    {
      GSObjCAddClassBehavior(self, [GSCString class]);
      NSConstantStringClass = self;
    }
}

/*
 * Access instance variables of NXConstantString class consistently
 * with other concrete NSString subclasses.
 */
#define _self	((GSStr)self)

- (id) initWithCharacters: (unichar*)byteString
		   length: (unsigned int)length
	     freeWhenDone: (BOOL)flag
{
  [NSException raise: NSGenericException
	      format: @"Attempt to init a constant string"];
  return nil;
}

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		freeWhenDone: (BOOL)flag
{
  [NSException raise: NSGenericException
	      format: @"Attempt to init a constant string"];
  return nil;
}

- (void) dealloc
{
}

- (const char*) cString
{
  return _self->_contents.c;
}

- (id) retain
{
  return self;
}

- (oneway void) release
{
  return;
}

- (id) autorelease
{
  return self;
}

- (id) copyWithZone: (NSZone*)z
{
  return self;
}

- (NSZone*) zone
{
  return NSDefaultMallocZone();
}

- (NSStringEncoding) fastestEncoding
{
  return NSASCIIStringEncoding;
}

- (NSStringEncoding) smallestEncoding
{
  return NSASCIIStringEncoding;
}


/*
 * Return a 28-bit hash value for the string contents - this
 * MUST match the algorithm used by the NSString base class.
 */
- (unsigned) hash
{
  unsigned	ret = 0;
  unsigned	len = _self->_count;

  if (len > 0)
    {
      const unsigned char	*p;
      unsigned			char_count = 0;

      p = _self->_contents.c;
      while (char_count++ < len)
	{
	  unichar	c = *p++;

	  if (c > 127)
	    {
	      c = encode_chartouni(c, intEnc);
	    }
	  ret = (ret << 5) + ret + c;
	}

      /*
       * The hash caching in our concrete string classes uses zero to denote
       * an empty cache value, so we MUST NOT return a hash of zero.
       */
      ret &= 0x0fffffff;
      if (ret == 0)
	{
	  ret = 0x0fffffff;
	}
    }
  else
    {
      ret = 0x0ffffffe;	/* Hash for an empty string.	*/
    }
  return ret;
}

- (BOOL) isEqual: (id)anObject
{
  Class	c;

  if (anObject == self)
    {
      return YES;
    }
  if (anObject == nil)
    {
      return NO;
    }
  if (GSObjCIsInstance(anObject) == NO)
    {
      return NO;
    }
  c = GSObjCClass(anObject);

  if (GSObjCIsKindOf(c, GSCStringClass) == YES
    || c == NSConstantStringClass
    || (c == GSMutableStringClass && ((GSStr)anObject)->_flags.wide == 0))
    {
      GSStr	other = (GSStr)anObject;

      if (_self->_count != other->_count)
	return NO;
      if (memcmp(_self->_contents.c, other->_contents.c, _self->_count) != 0)
	return NO;
      return YES;
    }
  else if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES
    || c == GSMutableStringClass)
    {
      if (strCompCsUs(self, anObject, 0, (NSRange){0,_self->_count})
	== NSOrderedSame)
	{
	  return YES;
	}
      return NO;
    }
  else if (GSObjCIsKindOf(c, NSStringClass))
    {
      return (*equalImp)(self, equalSel, anObject);
    }
  else
    {
      return NO;
    }
}

- (BOOL) isEqualToString: (NSString*)anObject
{
  Class	c;

  if (anObject == self)
    {
      return YES;
    }
  if (anObject == nil)
    {
      return NO;
    }
  if (GSObjCIsInstance(anObject) == NO)
    {
      return NO;
    }
  c = GSObjCClass(anObject);

  if (GSObjCIsKindOf(c, GSCStringClass) == YES
    || c == NSConstantStringClass
    || (c == GSMutableStringClass && ((GSStr)anObject)->_flags.wide == 0))
    {
      GSStr	other = (GSStr)anObject;

      if (_self->_count != other->_count)
	return NO;
      if (memcmp(_self->_contents.c, other->_contents.c, _self->_count) != 0)
	return NO;
      return YES;
    }
  else if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES
    || c == GSMutableStringClass)
    {
      if (strCompCsUs(self, anObject, 0, (NSRange){0,_self->_count})
	== NSOrderedSame)
	{
	  return YES;
	}
      return NO;
    }
  else if (GSObjCIsKindOf(c, NSStringClass))
    {
      return (*equalImp)(self, equalSel, anObject);
    }
  else
    {
      return NO;
    }
}

@end


/*
 * Some classes for backward compatibility with archives.
 */
@interface	NSGCString : NSString
@end
@implementation	NSGCString
- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	count;

  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  RELEASE(self);
  self = (id)NSAllocateObject(GSCBufferStringClass, 0, NSDefaultMallocZone());
  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &count];
  if (count > 0)
    {
      unsigned char	*chars;

      chars = NSZoneMalloc(NSDefaultMallocZone(), count+1);
      [aCoder decodeArrayOfObjCType: @encode(unsigned char)
			      count: count
				 at: chars];
      self = [self initWithCStringNoCopy: chars
				  length: count
			    freeWhenDone: YES];
    }
  else
    {
      self = [self initWithCStringNoCopy: 0 length: 0 freeWhenDone: NO];
    }
  return self;
}
@end

@interface	NSGMutableCString : NSMutableString
@end
@implementation	NSGMutableCString
- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	count;

  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  RELEASE(self);
  self = (id)NSAllocateObject(GSMutableStringClass, 0, NSDefaultMallocZone());
  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &count];
  if (count > 0)
    {
      unsigned char	*chars;

      chars = NSZoneMalloc(NSDefaultMallocZone(), count+1);
      [aCoder decodeArrayOfObjCType: @encode(unsigned char)
			      count: count
				 at: chars];
      self = [self initWithCStringNoCopy: chars
				  length: count
			    freeWhenDone: YES];
    }
  else
    {
      self = [self initWithCStringNoCopy: 0 length: 0 freeWhenDone: NO];
    }
  return self;
}
@end

@interface	NSGString : NSString
@end
@implementation	NSGString
- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	count;

  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  RELEASE(self);
  self = (id)NSAllocateObject(GSUnicodeBufferStringClass, 0, NSDefaultMallocZone());
  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &count];
  if (count > 0)
    {
      unichar	*chars;

      chars = NSZoneMalloc(NSDefaultMallocZone(), count*sizeof(unichar));
      [aCoder decodeArrayOfObjCType: @encode(unichar)
			      count: count
				 at: chars];
      self = [self initWithCharactersNoCopy: chars
				     length: count
			       freeWhenDone: YES];
    }
  else
    {
      self = [self initWithCharactersNoCopy: 0 length: 0 freeWhenDone: NO];
    }
  return self;
}
@end

@interface	NSGMutableString : NSMutableString
@end
@implementation	NSGMutableString
- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	count;

  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  RELEASE(self);
  self = (id)NSAllocateObject(GSMutableStringClass, 0, NSDefaultMallocZone());
  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &count];
  if (count > 0)
    {
      unichar	*chars;

      chars = NSZoneMalloc(NSDefaultMallocZone(), count*sizeof(unichar));
      [aCoder decodeArrayOfObjCType: @encode(unichar)
			      count: count
				 at: chars];
      self = [self initWithCharactersNoCopy: chars
				     length: count
			       freeWhenDone: YES];
    }
  else
    {
      self = [self initWithCharactersNoCopy: 0 length: 0 freeWhenDone: NO];
    }
  return self;
}
@end


/**
 * Append characters to a string.
 */
void GSStrAppendUnichars(GSStr s, const unichar *u, unsigned l)
{
  /*
   * Make the string wide if necessary.
   */
  if (s->_flags.wide == 0)
    {
      BOOL	widen = NO;

      if (intEnc == NSISOLatin1StringEncoding)
	{
	  unsigned	i;

	  for (i = 0; i < l; i++)
	    {
	      if (u[i] > 255)
		{
		  widen = YES;
		  break;
		}
	    }
	}
      else
	{
	  unsigned	i;

	  for (i = 0; i < l; i++)
	    {
	      if (u[i] > 127)
		{
		  widen = YES;
		  break;
		}
	    }
	}
      if (widen == YES)
	{
	  GSStrWiden(s);
	}
    }

  /*
   * Make room for the characters we are appending.
   */
  if (s->_count + l + 1 >= s->_capacity)
    {
      GSStrMakeSpace(s, l);
    }

  /*
   * Copy the characters into place.
   */
  if (s->_flags.wide == 1)
    {
      unsigned 	i;

      for (i = 0; i < l; i++)
	{
	  s->_contents.u[s->_count++] = u[i];
	}
    }
  else
    {
      unsigned 	i;

      for (i = 0; i < l; i++)
	{
	  s->_contents.c[s->_count++] = u[i];
	}
    }
}

void GSStrAppendUnichar(GSStr s, unichar u)
{
  /*
   * Make the string wide if necessary.
   */
  if (s->_flags.wide == 0)
    {
      if (u > 255 || (u > 127 && intEnc != NSISOLatin1StringEncoding))
	{
	  GSStrWiden(s);
	}
    }

  /*
   * Make room for the characters we are appending.
   */
  if (s->_count + 2 >= s->_capacity)
    {
      GSStrMakeSpace(s, 1);
    }

  /*
   * Copy the characters into place.
   */
  if (s->_flags.wide == 1)
    {
      s->_contents.u[s->_count++] = u;
    }
  else
    {
      s->_contents.c[s->_count++] = u;
    }
}

/*
 * Make the content of this string into unicode if it is not in
 * the external defaults C string encoding.
 */
void GSStrExternalize(GSStr s)
{
  if (s->_flags.wide == 0 && intEnc != defEnc)
    {
      GSStrWiden(s);
    }
}

