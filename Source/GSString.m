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

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSObjCRuntime.h>
#include <base/GSFormat.h>
#include <base/behavior.h>
#include <limits.h>

#include "GSPrivate.h"

/* memcpy(), strlen(), strcmp() are gcc builtin's */

#include <base/Unicode.h>

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
 * GSCString - concrete class for strings using 8-bit character sets.
 */
@interface GSCString : GSString
{
}
@end

/*
 * GSCInlineString - concrete subclass of GSCString, that expects the
 * characterData to appear in memory immediately after the object itsself.
 */
@interface GSCInlineString : GSCString
{
}
@end

/*
 * GSCSubString - concrete subclass of GSCString, that relies on the
 * data stored in a GSCString object.
 */
@interface GSCSubString : GSCString
{
@public
  GSCString	*_parent;
}
@end

/*
 * GSCEmptyString - concrete class for empty string
 */
@interface GSCEmptyString : GSCString
{
}
@end

/*
 * GSUnicodeString - concrete class for strings using 16-bit character sets.
 */
@interface GSUnicodeString : GSString
{
}
@end

/*
 * GSUnicodeInlineString - concrete subclass of GSUnicodeString, that
 * expects the characterData to appear in memory immediately after the
 * object itsself.
 */
@interface GSUnicodeInlineString : GSUnicodeString
{
}
@end

/*
 * GSUnicodeSubString - concrete subclass of GSUnicodeString, that
 * relies on data stored in a GSUnicodeString object.
 */
@interface GSUnicodeSubString : GSUnicodeString
{
@public
  GSUnicodeString	*_parent;
}
@end

/*
 * GSMutableString - concrete mutable string, capable of changing its storage
 * from holding 8-bit to 16-bit character set.
 */
@interface GSMutableString : NSMutableString
{
  union {
    unichar		*u;
    unsigned char	*c;
  } _contents;
  unsigned int	_count;
  struct {
    unsigned int	wide: 1;
    unsigned int	free: 1;
    unsigned int	unused: 2;
    unsigned int	hash: 28;
  } _flags;
  NSZone	*_zone;
  unsigned int	_capacity;
}
@end

/*
 * Typedef for access to internals of concrete string objects.
 */
typedef struct {
  @defs(GSMutableString)
} *ivars;

/*
 *	Include sequence handling code with instructions to generate search
 *	and compare functions for NSString objects.
 */
#define	GSEQ_STRCOMP	strCompUsNs
#define	GSEQ_STRRANGE	strRangeUsNs
#define	GSEQ_O	GSEQ_NS
#define	GSEQ_S	GSEQ_US
#include <GSeq.h>

#define	GSEQ_STRCOMP	strCompUsUs
#define	GSEQ_STRRANGE	strRangeUsUs
#define	GSEQ_O	GSEQ_US
#define	GSEQ_S	GSEQ_US
#include <GSeq.h>

#define	GSEQ_STRCOMP	strCompUsCs
#define	GSEQ_STRRANGE	strRangeUsCs
#define	GSEQ_O	GSEQ_CS
#define	GSEQ_S	GSEQ_US
#include <GSeq.h>

#define	GSEQ_STRCOMP	strCompCsNs
#define	GSEQ_STRRANGE	strRangeCsNs
#define	GSEQ_O	GSEQ_NS
#define	GSEQ_S	GSEQ_CS
#include <GSeq.h>

#define	GSEQ_STRCOMP	strCompCsUs
#define	GSEQ_STRRANGE	strRangeCsUs
#define	GSEQ_O	GSEQ_US
#define	GSEQ_S	GSEQ_CS
#include <GSeq.h>

#define	GSEQ_STRCOMP	strCompCsCs
#define	GSEQ_STRRANGE	strRangeCsCs
#define	GSEQ_O	GSEQ_CS
#define	GSEQ_S	GSEQ_CS
#include <GSeq.h>

static Class NSDataClass = 0;
static Class NSStringClass = 0;
static Class GSStringClass = 0;
static Class GSCStringClass = 0;
static Class GSCInlineStringClass = 0;
static Class GSCSubStringClass = 0;
static Class GSUnicodeStringClass = 0;
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
 * itsself with an appropriate object whose type may vary depending
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
  return;		// placeholders never get deallocated.
}

/*
 * Replace self with an inline unicode string
 */
- (id) initWithCharacters: (const unichar*)chars
		   length: (unsigned)length
{
  ivars	me;

  me = (ivars)NSAllocateObject(GSUnicodeInlineStringClass,
    length*sizeof(unichar), GSObjCZone(self));
  me->_contents.u = (unichar*)&((GSUnicodeInlineString*)me)[1];
  me->_count = length;
  me->_flags.wide = 1;
  memcpy(me->_contents.u, chars, length*sizeof(unichar));
  return (id)me;
}

/*
 * Replace self with a simple unicode string
 */
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned)length
		   freeWhenDone: (BOOL)flag
{
  ivars	me;

  me = (ivars)NSAllocateObject(GSUnicodeStringClass, 0, GSObjCZone(self));
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
 * Replace self with an inline 'C' string
 */
- (id) initWithCString: (const char*)chars
		length: (unsigned)length
{
  if (defEnc == intEnc)
    {
      ivars	me;

      me = (ivars)NSAllocateObject(GSCInlineStringClass, length,
	GSObjCZone(self));
      me->_contents.c = (unsigned char*)&((GSCInlineString*)me)[1];
      me->_count = length;
      me->_flags.wide = 0;
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
      ivars	me;

      me = (ivars)NSAllocateObject(GSCStringClass, 0, GSObjCZone(self));
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
      if (flag == YES)
	{
	  NSZoneFree(NSZoneFromPointer(chars), chars);
	}
      return self;
    }
}

/*
 * Replace self with an inline string matching the sort of information
 * given.
 */
- (id) initWithString: (NSString*)string
{
  unsigned	length;
  Class		c;
  ivars		me;

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
      && ((ivars)string)->_flags.wide == 0))
    {
      /*
       * For a GSCString subclass, and ??ConstantString, or an 8-bit
       * GSMutableString, we can copy the bytes directly into a GSCString.
       */
      me = (ivars)NSAllocateObject(GSCInlineStringClass,
	length, GSObjCZone(self));
      me->_contents.c = (unsigned char*)&((GSCInlineString*)me)[1];
      me->_count = length;
      me->_flags.wide = 0;
      memcpy(me->_contents.c, ((ivars)string)->_contents.c, length);
    }
  else if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES
    || GSObjCIsKindOf(c, GSMutableStringClass) == YES)
    {
      /*
       * For a GSUnicodeString subclass, or a 16-bit GSMutableString,
       * we can copy the bytes directly into a GSUnicodeString.
       */
      me = (ivars)NSAllocateObject(GSUnicodeInlineStringClass,
	length*sizeof(unichar), GSObjCZone(self));
      me->_contents.u = (unichar*)&((GSUnicodeInlineString*)me)[1];
      me->_count = length;
      me->_flags.wide = 1;
      memcpy(me->_contents.u, ((ivars)string)->_contents.u,
	length*sizeof(unichar));
    }
  else
    {
      /*
       * For a string with an unknown class, we can initialise by
       * having the string copy its content directly into our buffer.
       */
      me = (ivars)NSAllocateObject(GSUnicodeInlineStringClass,
	length*sizeof(unichar), GSObjCZone(self));
      me->_contents.u = (unichar*)&((GSUnicodeInlineString*)me)[1];
      me->_count = length;
      me->_flags.wide = 1;
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
 * GSCSubString and ??ConstantString inherit methods from GSCString.
 * GSUnicodeString uses the functions with the _u suffix.
 * GSUnicodeSubString inherits methods from GSUnicodeString.
 * GSMutableString uses all the functions, selecting the _c or _u versions
 * depending on whether its storage is 8-bit or 16-bit.
 * In addition, GSMutableString uses a few functions without a suffix that are
 * peculiar to its memory management (shrinking, growing, and converting).
 */

static inline char*
UTF8String_c(ivars self)
{
  unsigned char *r;

  if (self->_count == 0)
    {
      return "";
    }
  if (intEnc == NSISOLatin1StringEncoding || intEnc == NSASCIIStringEncoding)
    {
      r = (unsigned char*)_fastMallocBuffer(self->_count+1);

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
UTF8String_u(ivars self)
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
boolValue_c(ivars self)
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
boolValue_u(ivars self)
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
canBeConvertedToEncoding_c(ivars self, NSStringEncoding enc)
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
canBeConvertedToEncoding_u(ivars self, NSStringEncoding enc)
{
  BOOL	result = (*convertImp)((id)self, convertSel, enc);

  return result;
}

static inline unichar
characterAtIndex_c(ivars self, unsigned index)
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
characterAtIndex_u(ivars self,unsigned index)
{
  if (index >= self->_count)
    [NSException raise: NSRangeException format: @"Invalid index."];
  return self->_contents.u[index];
}

static inline NSComparisonResult
compare_c(ivars self, NSString *aString, unsigned mask, NSRange aRange)
{
  Class	c;

  if (aString == nil)
    [NSException raise: NSInvalidArgumentException format: @"compare with nil"];
  if (GSObjCIsInstance(aString) == NO)
    return strCompCsNs((id)self, aString, mask, aRange);

  c = GSObjCClass(aString);
  if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES
    || (c == GSMutableStringClass && ((ivars)aString)->_flags.wide == 1))
    return strCompCsUs((id)self, aString, mask, aRange);
  else if (GSObjCIsKindOf(c, GSCStringClass) == YES
    || c == NSConstantStringClass
    || (c == GSMutableStringClass && ((ivars)aString)->_flags.wide == 0))
    return strCompCsCs((id)self, aString, mask, aRange);
  else
    return strCompCsNs((id)self, aString, mask, aRange);
}

static inline NSComparisonResult
compare_u(ivars self, NSString *aString, unsigned mask, NSRange aRange)
{
  Class	c;

  if (aString == nil)
    [NSException raise: NSInvalidArgumentException format: @"compare with nil"];
  if (GSObjCIsInstance(aString) == NO)
    return strCompUsNs((id)self, aString, mask, aRange);

  c = GSObjCClass(aString);
  if (GSObjCIsKindOf(c, GSUnicodeStringClass)
    || (c == GSMutableStringClass && ((ivars)aString)->_flags.wide == 1))
    return strCompUsUs((id)self, aString, mask, aRange);
  else if (GSObjCIsKindOf(c, GSCStringClass)
    || c == NSConstantStringClass
    || (c == GSMutableStringClass && ((ivars)aString)->_flags.wide == 0))
    return strCompUsCs((id)self, aString, mask, aRange);
  else
    return strCompUsNs((id)self, aString, mask, aRange);
}

static inline char*
cString_c(ivars self)
{
  unsigned char *r;

  if (self->_count == 0)
    {
      return "";
    }
  if (defEnc == intEnc)
    {
      r = (unsigned char*)_fastMallocBuffer(self->_count+1);

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
cString_u(ivars self)
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
cStringLength_c(ivars self)
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
cStringLength_u(ivars self)
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
dataUsingEncoding_c(ivars self, NSStringEncoding encoding, BOOL flag)
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
dataUsingEncoding_u(ivars self, NSStringEncoding encoding, BOOL flag)
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

static inline double
doubleValue_c(ivars self)
{
  if (self->_count == 0)
    {
      return 0;
    }
  else
    {
      unsigned	len = self->_count < 32 ? self->_count : 31;
      unsigned char	buf[len+1];

      memcpy(buf, self->_contents.c, len);
      buf[len] = '\0';
      return atof(buf);
    }
}

static inline double
doubleValue_u(ivars self)
{
  if (self->_count == 0)
    {
      return 0;
    }
  else
    {
      unsigned int	l = self->_count < 10 ? self->_count : 9;
      unsigned char	buf[l+1];
      unsigned char	*b = buf;

      GSFromUnicode(&b, &l, self->_contents.u, l, intEnc, 0, GSUniTerminate);
      return atof(buf);
    }
}

static inline void
fillHole(ivars self, unsigned index, unsigned size)
{
  NSCAssert(size > 0, @"size <= zero");
  NSCAssert(index + size <= self->_count, @"index + size > length");

  self->_count -= size;
#ifndef STABLE_MEMCPY
  {
    int i;

    if (self->_flags.wide == 1)
      {
	for (i = index; i <= self->_count; i++)
	  {
	    self->_contents.u[i] = self->_contents.u[i+size];
	  }
      }
    else
      {
	for (i = index; i <= self->_count; i++)
	  {
	    self->_contents.c[i] = self->_contents.c[i+size];
	  }
      }
  }
#else
  if (self->_flags.wide == 1)
    {
      memcpy(self->_contents.u + index + size,
	self->_contents.u + index,
	sizeof(unichar)*(self->_count - index));
    }
  else
    {
      memcpy(self->_contents.c + index + size,
	self->_contents.c + index, (self->_count - index));
    }
#endif // STABLE_MEMCPY
  self->_flags.hash = 0;
}

static inline void
getCharacters_c(ivars self, unichar *buffer, NSRange aRange)
{
  unsigned	len = aRange.length;

  GSToUnicode(&buffer, &len, self->_contents.c + aRange.location,
    aRange.length, intEnc, 0, 0);
}

static inline void
getCharacters_u(ivars self, unichar *buffer, NSRange aRange)
{
  memcpy(buffer, self->_contents.u + aRange.location,
    aRange.length*sizeof(unichar));
}

static inline void
getCString_c(ivars self, char *buffer, unsigned int maxLength,
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
getCString_u(ivars self, char *buffer, unsigned int maxLength,
  NSRange aRange, NSRange *leftoverRange)
{
  unsigned int	len;

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

  if (GSFromUnicode((unsigned char **)&buffer, &len, self->_contents.u, len,
    defEnc, 0, GSUniTerminate | GSUniStrict) == NO)
    {
      [NSException raise: NSCharacterConversionException
		  format: @"Can't get cString from Unicode string."];
    }
  buffer[len] = '\0';
}

static inline int
intValue_c(ivars self)
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
intValue_u(ivars self)
{
  if (self->_count == 0)
    {
      return 0;
    }
  else
    {
      unsigned int	l = self->_count < 10 ? self->_count : 9;
      unsigned char	buf[l+1];
      unsigned char	*b = buf;

      GSFromUnicode(&b, &l, self->_contents.u, l, intEnc, 0, GSUniTerminate);
      return atol(buf);
    }
}

static inline BOOL
isEqual_c(ivars self, id anObject)
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
      ivars	other = (ivars)anObject;
      NSRange	r = {0, self->_count};

      if (strCompCsCs((id)self, (id)other, 0, r) == NSOrderedSame)
	return YES;
      return NO;
    }
  else if (GSObjCIsKindOf(c, GSStringClass) == YES)
    {
      ivars	other = (ivars)anObject;
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
isEqual_u(ivars self, id anObject)
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
      ivars	other = (ivars)anObject;
      NSRange	r = {0, self->_count};

      if (strCompUsCs((id)self, (id)other, 0, r) == NSOrderedSame)
	return YES;
      return NO;
    }
  else if (GSObjCIsKindOf(c, GSStringClass) == YES)
    {
      ivars	other = (ivars)anObject;
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
lossyCString_c(ivars self)
{
  char *r;

  if (self->_count == 0)
    {
      return "";
    }
  if (defEnc == intEnc)
    {
      r = (char*)_fastMallocBuffer(self->_count+1);

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
lossyCString_u(ivars self)
{
  unsigned	l = 0;
  unsigned char	*r = 0;

  GSFromUnicode(&r, &l, self->_contents.u, self->_count, defEnc,
    NSDefaultMallocZone(), GSUniTemporary|GSUniTerminate);
  return (const char*)r;
}

static inline void
makeHole(ivars self, int index, int size)
{
  unsigned	want;

  NSCAssert(size > 0, @"size < zero");
  NSCAssert(index <= self->_count, @"index > length");

  want = size + self->_count + 1;
  if (want > self->_capacity)
    {
      self->_capacity += self->_capacity/2;
      if (want > self->_capacity)
	{
	  self->_capacity = want;
	}
      if (self->_flags.free == 1)
	{
	  /*
	   * If we own the character buffer, we can simply realloc.
	   */
	  if (self->_flags.wide == 1)
	    {
	      self->_contents.u = NSZoneRealloc(self->_zone,
		self->_contents.u, self->_capacity*sizeof(unichar));
	    }
	  else
	    {
	      self->_contents.c = NSZoneRealloc(self->_zone,
		self->_contents.c, self->_capacity);
	    }
	}
      else
	{
	  /*
	   * If the initial data was not to be freed, we must allocate new
	   * buffer, copy the data, and set up the zone we are using.
	   */
	  if (self->_zone == 0)
	    {
#if	GS_WITH_GC
	      self->_zone = GSAtomicMallocZone();
#else
	      self->_zone = GSObjCZone((NSString*)self);
#endif
	    }
	  if (self->_flags.wide == 1)
	    {
	      unichar	*tmp = self->_contents.u;

	      self->_contents.u = NSZoneMalloc(self->_zone,
		self->_capacity*sizeof(unichar));
	      if (self->_count > 0)
		{
		  memcpy(self->_contents.u, tmp, self->_count*sizeof(unichar));
		}
	    }
	  else
	    {
	      unsigned char	*tmp = self->_contents.c;

	      self->_contents.c = NSZoneMalloc(self->_zone, self->_capacity);
	      if (self->_count > 0)
		{
		  memcpy(self->_contents.c, tmp, self->_count);
		}
	    }
	  self->_flags.free = 1;
	}
    }

  if (index < self->_count)
    {
#ifndef STABLE_MEMCPY
      if (self->_flags.wide == 1)
	{
	  int i;

	  for (i = self->_count; i >= index; i--)
	    {
	      self->_contents.u[i+size] = self->_contents.u[i];
	    }
	}
      else
	{
	  int i;

	  for (i = self->_count; i >= index; i--)
	    {
	      self->_contents.c[i+size] = self->_contents.c[i];
	    }
	}
#else
      if (self->_flags.wide == 1)
	{
	  memcpy(self->_contents.u + index,
	    self->_contents.u + index + size,
	    sizeof(unichar)*(self->_count - index));
	}
      else
	{
	  memcpy(self->_contents.c + index,
	    self->_contents.c + index + size,
	    (self->_count - index));
	}
#endif /* STABLE_MEMCPY */
    }

  self->_count += size;
  self->_flags.hash = 0;
}

static inline NSRange
rangeOfSequence_c(ivars self, unsigned anIndex)
{
  if (anIndex >= self->_count)
    [NSException raise: NSRangeException format:@"Invalid location."];

  return (NSRange){anIndex, 1};
}

static inline NSRange
rangeOfSequence_u(ivars self, unsigned anIndex)
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
rangeOfCharacter_c(ivars self, NSCharacterSet *aSet, unsigned mask,
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
rangeOfCharacter_u(ivars self, NSCharacterSet *aSet, unsigned mask,
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
rangeOfString_c(ivars self, NSString *aString, unsigned mask, NSRange aRange)
{
  Class	c;

  if (aString == nil)
    [NSException raise: NSInvalidArgumentException format: @"range of nil"];
  if (GSObjCIsInstance(aString) == NO)
    return strRangeCsNs((id)self, aString, mask, aRange);

  c = GSObjCClass(aString);
  if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES
    || (c == GSMutableStringClass && ((ivars)aString)->_flags.wide == 1))
    return strRangeCsUs((id)self, aString, mask, aRange);
  else if (GSObjCIsKindOf(c, GSCStringClass) == YES
    || c == NSConstantStringClass
    || (c == GSMutableStringClass && ((ivars)aString)->_flags.wide == 0))
    return strRangeCsCs((id)self, aString, mask, aRange);
  else
    return strRangeCsNs((id)self, aString, mask, aRange);
}

static inline NSRange
rangeOfString_u(ivars self, NSString *aString, unsigned mask, NSRange aRange)
{
  Class	c;

  if (aString == nil)
    [NSException raise: NSInvalidArgumentException format: @"range of nil"];
  if (GSObjCIsInstance(aString) == NO)
    return strRangeUsNs((id)self, aString, mask, aRange);

  c = GSObjCClass(aString);
  if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES
    || (c == GSMutableStringClass && ((ivars)aString)->_flags.wide == 1))
    return strRangeUsUs((id)self, aString, mask, aRange);
  else if (GSObjCIsKindOf(c, GSCStringClass) == YES
    || c == NSConstantStringClass
    || (c == GSMutableStringClass && ((ivars)aString)->_flags.wide == 0))
    return strRangeUsCs((id)self, aString, mask, aRange);
  else
    return strRangeUsNs((id)self, aString, mask, aRange);
}

static inline NSString*
substring_c(ivars self, NSRange aRange)
{
  GSCSubString	*sub;

  sub = (GSCSubString*)NSAllocateObject(GSCSubStringClass, 0,
    NSDefaultMallocZone());
  sub = [sub initWithCStringNoCopy: self->_contents.c + aRange.location
			    length: aRange.length
		      freeWhenDone: NO];
  if (sub != nil)
    {
      sub->_parent = RETAIN((id)self);
      AUTORELEASE(sub);
    }
  return sub;
}

static inline NSString*
substring_u(ivars self, NSRange aRange)
{
  GSUnicodeSubString	*sub;

  sub = (GSUnicodeSubString*)NSAllocateObject(GSUnicodeSubStringClass, 0,
    NSDefaultMallocZone());
  sub = [sub initWithCharactersNoCopy: self->_contents.u + aRange.location
			       length: aRange.length
			 freeWhenDone: NO];
  if (sub != nil)
    {
      sub->_parent = RETAIN((id)self);
      AUTORELEASE(sub);
    }
  return sub;
}

/*
 * Function to examine the given string and see if it is one of our concrete
 * string classes.  Converts the mutable string (self) from 8-bit to 16-bit
 * representation if necessary in order to contain the data in aString.
 * Returns a pointer to aStrings ivars if aString is a concrete class
 * from which contents may be copied directly without conversion.
 */
static inline ivars
transmute(ivars self, NSString *aString)
{
  ivars	other;
  BOOL	transmute;
  Class	c = GSObjCClass(aString);	// NB aString must not be nil

  other = (ivars)aString;
  transmute = YES;

  if (self->_flags.wide == 1)
    {
      /*
       * This is already a unicode string, so we don't need to transmute,
       * but we still need to know if the other string is a unicode
       * string whose ivars we can access directly.
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
	   * so we don't need to transmute, and we can use its ivars.
	   */
	  transmute = NO;
	}
      else if (intEnc == defEnc
	&& [aString canBeConvertedToEncoding: intEnc] == YES)
	{
	  /*
	   * The other string can be converted to the internal 8-bit encoding,
	   * via the cString method, so we don't need to transmute, but we
	   * can *not* use its ivars.
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
	   * use its ivars.
	   */
	  transmute = YES;
	}
      else
	{
	  /*
	   * The other string can not be converted to the internal 8-bit
	   * character string, so we need to transmute, but even then we
	   * will not be able to use the other strings ivars because that
	   * string is not a known GSString subclass.
	   */
	  other = 0;
	}
    }

  if (transmute == YES)
    {
      unichar	*tmp = 0;
      int	len = 0;

      GSToUnicode(&tmp, &len, self->_contents.c, self->_count, intEnc,
	self->_zone, 0);
      if (self->_flags.free == 1)
	{
	  NSZoneFree(self->_zone, self->_contents.c);
	}
      else
	{
	  self->_flags.free = 1;
	}
      self->_contents.u = tmp;
      self->_flags.wide = 1;
      self->_count = len;
      self->_capacity = len;
    }

  return other;
}



/*
 * The GSString class is actually only provided to provide a common ivar
 * layout for all subclasses, so that they can all share the same code.
 * We don't expect this class to ever be instantiated, but we do provide
 * a common deallocation method, and standard initialisation methods that
 * will try to convert an instance to a type we can really use if necessary.
 */ 
@implementation	GSString

+ (void) initialize
{
  setup();
}

- (void) dealloc
{
  if (_flags.free == 1 && _contents.c != 0)
    {
      NSZoneFree(NSZoneFromPointer(_contents.c), _contents.c);
      _contents.c = 0;
    }
  NSDeallocateObject(self);
}

/*
 * Try to initialise a unicode string.
 */
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		   freeWhenDone: (BOOL)flag
{
  if (isa == GSStringClass)
    {
      isa = GSUnicodeStringClass;
    }
  else if (_contents.u != 0)
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

/*
 * Try to initialise a 'C' string.
 */
- (id) initWithCStringNoCopy: (char*)chars
		      length: (unsigned int)length
	        freeWhenDone: (BOOL)flag
{
  if (isa == GSStringClass)
    {
      isa = GSCStringClass;
    }
  else if (_contents.c != 0)
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
@end



/*
 * The GSCString class is the basic implementation of a concrete
 * 8-bit string class, storing immutable data in a single buffer.
 */
@implementation GSCString
- (const char *) UTF8String
{
  return UTF8String_c((ivars)self);
}

- (BOOL) boolValue
{
  return boolValue_c((ivars)self);
}

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)enc
{
  return canBeConvertedToEncoding_c((ivars)self, enc);
}

- (unichar) characterAtIndex: (unsigned int)index
{
  return characterAtIndex_c((ivars)self, index);
}

- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  return compare_c((ivars)self, aString, mask, aRange);
}

- (id) copy
{
  if (NSShouldRetainWithZone(self, NSDefaultMallocZone()) == NO)
    {
      GSCString	*obj;

      obj = (GSCString*)NSCopyObject(self, 0, NSDefaultMallocZone());
      if (_contents.c != 0)
	{
	  unsigned char	*tmp;

	  tmp = NSZoneMalloc(NSDefaultMallocZone(), _count);
	  memcpy(tmp, _contents.c, _count);
	  obj->_contents.c = tmp;
	}
      return obj;
    }
  else 
    {
      return RETAIN(self);
    }
}

- (id) copyWithZone: (NSZone*)z
{
  if (NSShouldRetainWithZone(self, z) == NO)
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

- (const char *) cString
{
  return cString_c((ivars)self);
}

- (unsigned int) cStringLength
{
  return cStringLength_c((ivars)self);
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
	 allowLossyConversion: (BOOL)flag
{
  return dataUsingEncoding_c((ivars)self, encoding, flag);
}

- (double) doubleValue
{
  return doubleValue_c((ivars)self);
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
  return doubleValue_c((ivars)self);
}

- (void) getCharacters: (unichar*)buffer
{
  getCharacters_c((ivars)self, buffer, (NSRange){0, _count});
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  getCharacters_c((ivars)self, buffer, aRange);
}

- (void) getCString: (char*)buffer
{
  getCString_c((ivars)self, buffer, NSMaximumStringLength,
    (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
{
  getCString_c((ivars)self, buffer, maxLength, (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
	      range: (NSRange)aRange
     remainingRange: (NSRange*)leftoverRange
{
  GS_RANGE_CHECK(aRange, _count);
  getCString_c((ivars)self, buffer, maxLength, aRange, leftoverRange);
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
  return intValue_c((ivars)self);
}

- (BOOL) isEqual: (id)anObject
{
  return isEqual_c((ivars)self, anObject);
}

- (BOOL) isEqualToString: (NSString*)anObject
{
  return isEqual_c((ivars)self, anObject);
}

- (unsigned int) length
{
  return _count;
}

- (const char*) lossyCString
{
  return lossyCString_c((ivars)self);
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
  return rangeOfSequence_c((ivars)self, anIndex);
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned)mask
			      range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return rangeOfCharacter_c((ivars)self, aSet, mask, aRange);
}

- (NSRange) rangeOfString: (NSString*)aString
		  options: (unsigned)mask
		    range: (NSRange)aRange
{
  return rangeOfString_c((ivars)self, aString, mask, aRange);
}

- (NSStringEncoding) smallestEncoding
{
  return intEnc;
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return substring_c((ivars)self, aRange);
}

- (NSString*) substringWithRange: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return substring_c((ivars)self, aRange);
}

// private method for Unicode level 3 implementation
- (int) _baseLength
{
  return _count;
} 

@end



/*
 * The GSCInlineString class is a GSCString subclass that stores data
 * in memory immediately after the object.  
 */
@implementation	GSCInlineString
- (id) initWithCStringNoCopy: (char*)chars
		      length: (unsigned)length
		freeWhenDone: (BOOL)flag
{
  RELEASE(self);
  [NSException raise: NSInternalInconsistencyException
	      format: @"Illegal method used to initialise inline string"];
  return nil;
}
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
  return self;
}
- (void) dealloc
{
  NSDeallocateObject(self);
}
@end



/*
 * The GSCSubString class is a GSCString subclass that points into
 * a section of a parent constant string class.
 */
@implementation	GSCSubString
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
  RELEASE(_parent);
  NSDeallocateObject(self);
}
@end



@implementation GSUnicodeString
- (const char *) UTF8String
{
  return UTF8String_u((ivars)self);
}

- (BOOL) boolValue
{
  return boolValue_u((ivars)self);
}

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)enc
{
  return canBeConvertedToEncoding_u((ivars)self, enc);
}

- (unichar) characterAtIndex: (unsigned int)index
{
  return characterAtIndex_u((ivars)self, index);
}

- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  return compare_u((ivars)self, aString, mask, aRange);
}

- (id) copy
{
  if (NSShouldRetainWithZone(self, NSDefaultMallocZone()) == NO)
    {
      GSUnicodeString	*obj;

      obj = (GSUnicodeString*)NSCopyObject(self, 0, NSDefaultMallocZone());
      if (_contents.u != 0)
	{
	  unichar	*tmp;

	  tmp = NSZoneMalloc(NSDefaultMallocZone(), _count*sizeof(unichar));
	  memcpy(tmp, _contents.u, _count*sizeof(unichar));
	  obj->_contents.u = tmp;
	}
      return obj;
    }
  else 
    {
      return RETAIN(self);
    }
}

- (id) copyWithZone: (NSZone*)z
{
  if (NSShouldRetainWithZone(self, z) == NO)
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

- (const char *) cString
{
  return cString_u((ivars)self);
}

- (unsigned int) cStringLength
{
  return cStringLength_u((ivars)self);
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
	 allowLossyConversion: (BOOL)flag
{
  return dataUsingEncoding_u((ivars)self, encoding, flag);
}

- (double) doubleValue
{
  return doubleValue_u((ivars)self);
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
  return doubleValue_u((ivars)self);
}

- (void) getCharacters: (unichar*)buffer
{
  getCharacters_u((ivars)self, buffer, (NSRange){0, _count});
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  getCharacters_u((ivars)self, buffer, aRange);
}

- (void) getCString: (char*)buffer
{
  getCString_u((ivars)self, buffer, NSMaximumStringLength,
    (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
{
  getCString_u((ivars)self, buffer, maxLength, (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
	      range: (NSRange)aRange
     remainingRange: (NSRange*)leftoverRange
{
  GS_RANGE_CHECK(aRange, _count);

  getCString_u((ivars)self, buffer, maxLength, aRange, leftoverRange);
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
  return intValue_u((ivars)self);
}

- (BOOL) isEqual: (id)anObject
{
  return isEqual_u((ivars)self, anObject);
}

- (BOOL) isEqualToString: (NSString*)anObject
{
  return isEqual_u((ivars)self, anObject);
}

- (unsigned int) length
{
  return _count;
}

- (const char*) lossyCString
{
  return lossyCString_u((ivars)self);
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
  return rangeOfSequence_u((ivars)self, anIndex);
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned)mask
			      range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return rangeOfCharacter_u((ivars)self, aSet, mask, aRange);
}

- (NSRange) rangeOfString: (NSString*)aString
		  options: (unsigned)mask
		    range: (NSRange)aRange
{
  return rangeOfString_u((ivars)self, aString, mask, aRange);
}

- (NSStringEncoding) smallestEncoding
{
  return NSUnicodeStringEncoding;
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return substring_u((ivars)self, aRange);
}

- (NSString*) substringWithRange: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  return substring_u((ivars)self, aRange);
}

// private method for Unicode level 3 implementation
- (int) _baseLength
{
  int count = 0;
  int blen = 0;

  while (count < _count)
    if (!uni_isnonsp(_contents.u[count++]))
      blen++;
  return blen;
} 

@end



@implementation	GSUnicodeInlineString
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned)length
		   freeWhenDone: (BOOL)flag
{
  RELEASE(self);
  [NSException raise: NSInternalInconsistencyException
	      format: @"Illegal method used to initialise inline string"];
  return nil;
}
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
  return self;
}
- (void) dealloc
{
  NSDeallocateObject(self);
}
@end



/*
 * The GSUnicodeSubString class is a GSUnicodeString subclass that points
 * into a section of a parent constant string class.
 */
@implementation	GSUnicodeSubString
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
  RELEASE(_parent);
  NSDeallocateObject(self);
}
@end



/*
 * The GSMutableStrinc class shares a common initial ivar layout with
 * the GSString class, but adds a few of its own.  It uses _flags.wide
 * to determine whether it should use 8-bit or 16-bit characters and
 * is capable of changing that flag (and its underlying storage) to
 * move from an 8-bit to a 16-bit representation is that should be
 * necessary because wide characters have been placed in the string.
 */
@implementation GSMutableString

+ (void) initialize
{
  setup();
}

- (void) appendFormat: (NSString*)format, ...
{
  va_list	ap;

  va_start(ap, format);
  /*
   * If this is a unicode string, we can write the formatted data directly
   * into its buffer.
   */
  if (_flags.wide == 1)
    {
      FormatBuf_t	f;
      unichar		*fmt;
      size_t		len;

      len = [format length];
      fmt = objc_malloc((len+1)*sizeof(unichar));
      [format getCharacters: fmt];
      fmt[len] = '\0';
      f.z = _zone;
      f.buf = _contents.u;
      f.len = _count;
      f.size = _capacity;
      GSFormat(&f, fmt, ap, nil);
      _contents.u = f.buf;
      _count = f.len;
      _capacity = f.size;
      _flags.hash = 0;
      objc_free(fmt);
    }
  else
    {
      NSRange	aRange;
      NSString	*t;

      /*
       * Get the abstract class to give us the default placeholder string.
       */
      t = (NSString*)[NSStringClass allocWithZone: NSDefaultMallocZone()];
      /*
       * Now initialise with the format information ... the placeholder
       * can decide whether to create a concrete 8-bit character string
       * or unicode string.
       */
      t = [t initWithFormat: format arguments: ap];
      /*
       * Now append the created string to this one ... the appending
       * method will make this string wide if necessary.
       */
      aRange.location = _count;
      aRange.length = 0;
      [self replaceCharactersInRange: aRange withString: t];
      RELEASE(t);
    }
  va_end(ap);
}

- (BOOL) boolValue
{
  if (_flags.wide == 1)
    return boolValue_u((ivars)self);
  else
    return boolValue_c((ivars)self);
}

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)enc
{
  if (_flags.wide == 1)
    return canBeConvertedToEncoding_u((ivars)self, enc);
  else
    return canBeConvertedToEncoding_c((ivars)self, enc);
}

- (unichar) characterAtIndex: (unsigned int)index
{
  if (_flags.wide == 1)
    return characterAtIndex_u((ivars)self, index);
  else
    return characterAtIndex_c((ivars)self, index);
}

- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  if (_flags.wide == 1)
    return compare_u((ivars)self, aString, mask, aRange);
  else
    return compare_c((ivars)self, aString, mask, aRange);
}

- (id) copy
{
  id	copy;

  if (_flags.wide == 1)
    {
      copy = NSAllocateObject(GSUnicodeInlineStringClass,
	_count*sizeof(unichar), NSDefaultMallocZone());
      copy = [copy initWithCharacters: _contents.u length: _count];
    }
  else
    {
      copy = NSAllocateObject(GSCInlineStringClass,
	_count, NSDefaultMallocZone());
      copy = [copy initWithCString: _contents.c length: _count];
    }
  return copy;
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
    return cString_u((ivars)self);
  else
    return cString_c((ivars)self);
}

- (unsigned int) cStringLength
{
  if (_flags.wide == 1)
    return cStringLength_u((ivars)self);
  else
    return cStringLength_c((ivars)self);
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
	 allowLossyConversion: (BOOL)flag
{
  if (_flags.wide == 1)
    return dataUsingEncoding_u((ivars)self, encoding, flag);
  else
    return dataUsingEncoding_c((ivars)self, encoding, flag);
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
      fillHole((ivars)self, range.location, range.length);
    }
}

- (double) doubleValue
{
  if (_flags.wide == 1)
    return doubleValue_u((ivars)self);
  else
    return doubleValue_c((ivars)self);
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
    return doubleValue_u((ivars)self);
  else
    return doubleValue_c((ivars)self);
}

- (void) getCharacters: (unichar*)buffer
{
  if (_flags.wide == 1)
    getCharacters_u((ivars)self, buffer, (NSRange){0, _count});
  else
    getCharacters_c((ivars)self, buffer, (NSRange){0, _count});
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  if (_flags.wide == 1)
    {
      getCharacters_u((ivars)self, buffer, aRange);
    }
  else
    {
      getCharacters_c((ivars)self, buffer, aRange);
    }
}

- (void) getCString: (char*)buffer
{
  if (_flags.wide == 1)
    getCString_u((ivars)self, buffer, NSMaximumStringLength,
      (NSRange){0, _count}, 0);
  else
    getCString_c((ivars)self, buffer, NSMaximumStringLength,
      (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
{
  if (_flags.wide == 1)
    getCString_u((ivars)self, buffer, maxLength, (NSRange){0, _count}, 0);
  else
    getCString_c((ivars)self, buffer, maxLength, (NSRange){0, _count}, 0);
}

- (void) getCString: (char*)buffer
	  maxLength: (unsigned int)maxLength
	      range: (NSRange)aRange
     remainingRange: (NSRange*)leftoverRange
{
  GS_RANGE_CHECK(aRange, _count);
  if (_flags.wide == 1)
    {
      getCString_u((ivars)self, buffer, maxLength, aRange, leftoverRange);
    }
  else
    {
      getCString_c((ivars)self, buffer, maxLength, aRange, leftoverRange);
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

- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
	        freeWhenDone: (BOOL)flag
{
  _count = length;
  _capacity = length;
  _contents.c = byteString;
  _flags.wide = 0;
  if (flag == YES && byteString != 0)
    {
#if	GS_WITH_GC
      _zone = GSAtomicMallocZone();
#else
      _zone = NSZoneFromPointer(byteString);
#endif
      _flags.free = 1;
    }
  else
    {
      _zone = 0;
    }
  return self;
}

- (int) intValue
{
  if (_flags.wide == 1)
    return intValue_u((ivars)self);
  else
    return intValue_c((ivars)self);
}

- (BOOL) isEqual: (id)anObject
{
  if (_flags.wide == 1)
    return isEqual_u((ivars)self, anObject);
  else
    return isEqual_c((ivars)self, anObject);
}

- (BOOL) isEqualToString: (NSString*)anObject
{
  if (_flags.wide == 1)
    return isEqual_u((ivars)self, anObject);
  else
    return isEqual_c((ivars)self, anObject);
}

- (unsigned int) length
{
  return _count;
}

- (const char*) lossyCString
{
  if (_flags.wide == 1)
    return lossyCString_u((ivars)self);
  else
    return lossyCString_c((ivars)self);
}

- (id) makeImmutableCopyOnFail: (BOOL)force
{
#ifndef NDEBUG
  GSDebugAllocationRemove(isa, self);
#endif
  if (_flags.wide == 1)
    {
      isa = [GSUnicodeString class];
    }
  else
    {
      isa = [GSCString class];
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
    return rangeOfSequence_u((ivars)self, anIndex);
  else
    return rangeOfSequence_c((ivars)self, anIndex);
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned)mask
			      range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, _count);
  if (_flags.wide == 1)
    return rangeOfCharacter_u((ivars)self, aSet, mask, aRange);
  else
    return rangeOfCharacter_c((ivars)self, aSet, mask, aRange);
}

- (NSRange) rangeOfString: (NSString*)aString
		  options: (unsigned)mask
		    range: (NSRange)aRange
{
  if (_flags.wide == 1)
    return rangeOfString_u((ivars)self, aString, mask, aRange);
  else
    return rangeOfString_c((ivars)self, aString, mask, aRange);
}

- (void) replaceCharactersInRange: (NSRange)aRange
		       withString: (NSString*)aString
{
  ivars		other = 0;
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
      other = transmute((ivars)self, aString);
    }

  if (offset < 0)
    {
      fillHole((ivars)self, NSMaxRange(aRange) + offset, -offset);
    }
  else if (offset > 0)
    {
      makeHole((ivars)self, NSMaxRange(aRange), offset);
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
	  /*
	   * As we got here, intEnc == defEnc, so we can use standard
	   * CString methods to get the characters into our buffer,
	   * or may even be able to copy from another string directly.
	   */
	  if (other == 0)
	    {
	      /*
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
  int	len = (aString == nil) ? 0 : [aString length];
  ivars	other;

  if (len == 0)
    {
      _count = 0;
      return;
    }
  other = transmute((ivars)self, aString);
  if (_count < len)
    {
      makeHole((ivars)self, _count, len - _count);
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
      int count = 0;
      int blen = 0;

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

- (id) copy
{
  return [_parent copy];
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
  return [_parent getCharacters: buffer];
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  return [_parent getCharacters: buffer range: aRange];
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
  if (((ivars)_parent)->_flags.wide == 1)
    return canBeConvertedToEncoding_u((ivars)_parent, enc);
  else
    return canBeConvertedToEncoding_c((ivars)_parent, enc);
}

- (unichar) characterAtIndex: (unsigned int)index
{
  if (((ivars)_parent)->_flags.wide == 1)
    return characterAtIndex_u((ivars)_parent, index);
  else
    return characterAtIndex_c((ivars)_parent, index);
}

- (NSComparisonResult) compare: (NSString*)aString
		       options: (unsigned int)mask
			 range: (NSRange)aRange
{
  if (((ivars)_parent)->_flags.wide == 1)
    return compare_u((ivars)_parent, aString, mask, aRange);
  else
    return compare_c((ivars)_parent, aString, mask, aRange);
}

- (const char *) cString
{
  if (((ivars)_parent)->_flags.wide == 1)
    return cString_u((ivars)_parent);
  else
    return cString_c((ivars)_parent);
}

- (unsigned int) cStringLength
{
  if (((ivars)_parent)->_flags.wide == 1)
    return cStringLength_u((ivars)_parent);
  else
    return cStringLength_c((ivars)_parent);
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
	 allowLossyConversion: (BOOL)flag
{
  if (((ivars)_parent)->_flags.wide == 1)
    return dataUsingEncoding_u((ivars)_parent, encoding, flag);
  else
    return dataUsingEncoding_c((ivars)_parent, encoding, flag);
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [_parent encodeWithCoder: aCoder];
}

- (NSStringEncoding) fastestEncoding
{
  if (((ivars)_parent)->_flags.wide == 1)
    return NSUnicodeStringEncoding;
  else
    return intEnc;
}

- (void) getCharacters: (unichar*)buffer
{
  if (((ivars)_parent)->_flags.wide == 1)
    {
      getCharacters_u((ivars)_parent, buffer,
	(NSRange){0, ((ivars)_parent)->_count});
    }
  else
    {
      getCharacters_c((ivars)_parent, buffer,
	(NSRange){0, ((ivars)_parent)->_count});
    }
}

- (void) getCharacters: (unichar*)buffer range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, ((ivars)_parent)->_count);
  if (((ivars)_parent)->_flags.wide == 1)
    {
      getCharacters_u((ivars)_parent, buffer, aRange);
    }
  else
    {
      getCharacters_c((ivars)_parent, buffer, aRange);
    }
}

- (unsigned) hash
{
  if (((ivars)_parent)->_flags.hash == 0)
    {
      ((ivars)_parent)->_flags.hash = (*hashImp)((id)_parent, hashSel);
    }
  return ((ivars)_parent)->_flags.hash;
}

- (BOOL) isEqual: (id)anObject
{
  if (((ivars)_parent)->_flags.wide == 1)
    return isEqual_u((ivars)_parent, anObject);
  else
    return isEqual_c((ivars)_parent, anObject);
}

- (BOOL) isEqualToString: (NSString*)anObject
{
  if (((ivars)_parent)->_flags.wide == 1)
    return isEqual_u((ivars)_parent, anObject);
  else
    return isEqual_c((ivars)_parent, anObject);
}

- (unsigned int) length
{
  return ((ivars)_parent)->_count;
}

- (const char*) lossyCString
{
  if (((ivars)_parent)->_flags.wide == 1)
    return lossyCString_u((ivars)_parent);
  else
    return lossyCString_c((ivars)_parent);
}

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned)anIndex
{
  if (((ivars)_parent)->_flags.wide == 1)
    return rangeOfSequence_u((ivars)_parent, anIndex);
  else
    return rangeOfSequence_c((ivars)_parent, anIndex);
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
			    options: (unsigned)mask
			      range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, ((ivars)_parent)->_count);
  if (((ivars)_parent)->_flags.wide == 1)
    return rangeOfCharacter_u((ivars)_parent, aSet, mask, aRange);
  else
    return rangeOfCharacter_c((ivars)_parent, aSet, mask, aRange);
}

- (NSRange) rangeOfString: (NSString*)aString
		  options: (unsigned)mask
		    range: (NSRange)aRange
{
  if (((ivars)_parent)->_flags.wide == 1)
    return rangeOfString_u((ivars)_parent, aString, mask, aRange);
  else
    return rangeOfString_c((ivars)_parent, aString, mask, aRange);
}

- (NSStringEncoding) smallestEncoding
{
  if (((ivars)_parent)->_flags.wide == 1)
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
 * the code must make sure not to use any other GSCString ivars
 * when accesssing an NXConstantString.</p>
 */
@implementation NXConstantString

+ (void) initialize
{
  if (self == [NXConstantString class])
    {
      behavior_class_add_class(self, [GSCString class]);
      NSConstantStringClass = self;
    }
}

/*
 * Access instance variables of NXConstantString class consistently
 * with other concrete NSString subclasses.
 */
#define _self	((ivars)self)

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

- (id) copy
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
  unsigned ret = 0;

  int len = _self->_count;

  if (len > NSHashStringLength)
    len = NSHashStringLength;
  if (len)
    {
      const unsigned char	*p;
      unsigned			char_count = 0;

      p = _self->_contents.c;
      while (*p != 0 && char_count++ < NSHashStringLength)
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
      if (ret == 0)
	ret = 0x0fffffff;
      else
	ret &= 0x0fffffff;
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
    || (c == GSMutableStringClass && ((ivars)anObject)->_flags.wide == 0))
    {
      ivars	other = (ivars)anObject;

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
    || (c == GSMutableStringClass && ((ivars)anObject)->_flags.wide == 0))
    {
      ivars	other = (ivars)anObject;

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
  self = (id)NSAllocateObject(GSCStringClass, 0, NSDefaultMallocZone());
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
  self = (id)NSAllocateObject(GSUnicodeStringClass, 0, NSDefaultMallocZone());
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

