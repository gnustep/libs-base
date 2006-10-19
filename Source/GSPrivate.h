/* GSPrivate
   Copyright (C) 2001,2002 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02111 USA.
*/ 

#ifndef _GSPrivate_h_
#define _GSPrivate_h_

@class	NSNotification;

#if (__GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 3))
#define GS_ATTRIB_PRIVATE __attribute__ ((visibility("internal")))
#else
#define GS_ATTRIB_PRIVATE
#endif

/* Absolute Gregorian date for NSDate reference date Jan 01 2001
 *
 *  N = 1;                 // day of month
 *  N = N + 0;             // days in prior months for year
 *  N = N +                // days this year
 *    + 365 * (year - 1)   // days in previous years ignoring leap days
 *    + (year - 1)/4       // Julian leap days before this year...
 *    - (year - 1)/100     // ...minus prior century years...
 *    + (year - 1)/400     // ...plus prior years divisible by 400
 */
#define GREGORIAN_REFERENCE 730486


#include "GNUstepBase/GSObjCRuntime.h"
#include "Foundation/NSString.h"

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of items.  Use this to start the block of code using
 * the array and GS_ENDITEMBUF() to end it.  The idea is to ensure that small
 * arrays are allocated on the stack (for speed), but large arrays are
 * allocated from the heap (to avoid stack overflow).
 */
#define	GS_BEGINITEMBUF(P, S, T) { \
  T _ibuf[(S) <= GS_MAX_OBJECTS_FROM_STACK ? (S) : 0]; \
  T *_base = ((S) <= GS_MAX_OBJECTS_FROM_STACK) ? _ibuf \
    : (T*)NSZoneMalloc(NSDefaultMallocZone(), (S) * sizeof(T)); \
  T *(P) = _base;

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of items.  Use GS_BEGINITEMBUF() to start the block of code using
 * the array and this macro to end it.
 */
#define	GS_ENDITEMBUF() \
  if (_base != _ibuf) \
    NSZoneFree(NSDefaultMallocZone(), _base); \
  }

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of objects.  Use this to start the block of code using
 * the array and GS_ENDIDBUF() to end it.  The idea is to ensure that small
 * arrays are allocated on the stack (for speed), but large arrays are
 * allocated from the heap (to avoid stack overflow).
 */
#define	GS_BEGINIDBUF(P, S) GS_BEGINITEMBUF(P, S, id)

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of objects.  Use GS_BEGINIDBUF() to start the block of code using
 * the array and this macro to end it.
 */
#define	GS_ENDIDBUF() GS_ENDITEMBUF()

/**
 * Macro to consistently replace public accessable
 * constant strings with dynamically allocated versions.
 * This method assumes an initialized NSStringClass symbol
 * which contains the Class object of NSString.  <br>
 * Most public accessible strings are used in collection classes
 * like NSDictionary, and therefore tend to receive -isEqual:
 * messages (and therefore -hash) rather often.  Statically
 * allocated strings must calculate their hash values while
 * dynamically allocated strings can store them.  This optimization
 * is by far more effective than using NSString * const.
 * The drawback is that the memory management cannot enforce these values
 * to remain unaltered as it would for variables declared NSString * const.
 * Yet the optimization of the stored hash value is currently deemed
 * more important.
 */
#define GS_REPLACE_CONSTANT_STRING(ID) \
  ID = [[NSStringClass alloc] initWithCString: [ID cString]]
/* Using cString here is OK here
   because NXConstantString returns a pointer
   to it's internal pointer.  */

/*
 * Type to hold either UTF-16 (unichar) or 8-bit encodings,
 * while satisfying alignment constraints.
 */
typedef union {
  unichar *u;       // 16-bit unicode characters.
  unsigned char *c; // 8-bit characters.
} GSCharPtr;

/*
 * Private concrete string classes.
 * NB. All these concrete string classes MUST have the same initial ivar
 * layout so that we can swap between them as necessary.
 * The initial layout must also match that of NXConstantString (which is
 * determined by the compiler) - an initial pointer to the string data
 * followed by the string length (number of characters).
 */
@interface GSString : NSString
{
  GSCharPtr _contents;
  unsigned int	_count;
  struct {
    unsigned int	wide: 1;	// 16-bit characters in string?
    unsigned int	free: 1;	// Set if the instance owns the
					// _contents buffer
    unsigned int	unused: 2;
    unsigned int	hash: 28;
  } _flags;
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
} GSStr_t;
typedef	GSStr_t	*GSStr;

/*
 * Function to append to GSStr
 */
extern void GSStrAppendUnichars(GSStr s, const unichar *u, unsigned l);
/*
 * Make the content of this string into unicode if it is not in
 * the external defaults C string encoding.
 */
void GSStrExternalize(GSStr s);


/*
 * Enumeration for MacOS-X compatibility user defaults settings.
 * For efficiency, we save defaults information which is used by the
 * base library.
 */
typedef enum {
  GSMacOSXCompatible,			// General behavior flag.
  GSOldStyleGeometry,			// Control geometry string output.
  GSLogSyslog,				// Force logging to go to syslog.
  GSLogThread,				// Include thread ID in log message.
  NSWriteOldStylePropertyLists,		// Control PList output.
  GSUserDefaultMaxFlag			// End marker.
} GSUserDefaultFlagType;



/**
 * This class exists simply as a mechanism for encapsulating arrays
 * encoded using [NSKeyedArchiver-encodeArrayOfObjCType:count:at:]
 */
@interface	_NSKeyedCoderOldStyleArray : NSObject <NSCoding>
{
  char		_t[2];
  unsigned	_c;
  unsigned	_s;
  const void	*_a;
  NSData	*_d;	// Only valid after initWithCoder:
}
- (const void*) bytes;
- (unsigned) count;
- (void) encodeWithCoder: (NSCoder*)aCoder;
- (id) initWithCoder: (NSCoder*)aCoder;
- (id) initWithObjCType: (const char*)t count: (int)c at: (const void*)a;
- (unsigned) size;
- (const char*) type;
@end

/*
 *	Functions used by the NSRunLoop and friends for processing
 *	queued notifications and task completion events.
 */
BOOL GSPrivateCheckTasks(void) GS_ATTRIB_PRIVATE;
void GSPrivateNotifyASAP(void) GS_ATTRIB_PRIVATE;
void GSPrivateNotifyIdle(void) GS_ATTRIB_PRIVATE;
BOOL GSPrivateNotifyMore(void) GS_ATTRIB_PRIVATE;

/* This class exists to encapsulate various otherwise unrelated functions
 * so that we expose a single global symbol (the class) whose name marks it
 * very clearly as for private/internal use only.  Avoiding the exposure
 * (and hence possible accidental use) of symbols for each function ... 
 * The formal implementation of the class is a near empty implementation
 * (in Additions/GSPrivate.m), with most methods being provided by other
 * categories in the files wishing to expose some functionality for use
 * by other parts of the base library.
 */
@interface GSPrivate : NSObject
{
}

/* Return the text describing the last system error to have occurred.
 */
- (NSString*) error;
- (NSString*) error: (long)number;
@end

extern GSPrivate	*_GSPrivate;

@interface GSPrivate (ProcessInfo)
/* Used by NSException uncaught exception handler - must not call any
 * methods/functions which might cause a recursive exception.
 */
- (const char*) argZero;

/* get a flag from an environment variable - return def if not defined.
 */
- (BOOL) environmentFlag: (const char *)name defaultValue: (BOOL)def;
@end

@interface GSPrivate (Unicode)
/* get the available string encodings (nul terminated array)
 */
- (NSStringEncoding*) availableEncodings;

/* get the default C-string encoding.
 */
- (NSStringEncoding) defaultCStringEncoding;

/* get the name of a string encoding as an NSString.
 */
- (NSString*) encodingName: (NSStringEncoding)encoding;

/* determine whether data in a particular encoding can
 * generally be represented as 8-bit characters including ascii.
 */
- (BOOL) isByteEncoding: (NSStringEncoding)encoding;

/* determine whether encoding is currently supported.
 */
- (BOOL) isEncodingSupported: (NSStringEncoding)encoding;

@end

@interface GSPrivate (UserDefaults)
/*
 * Get one of several potentially useful flags.
 */
- (BOOL) userDefaultsFlag: (GSUserDefaultFlagType)type;
@end

/* Get default locale quickly (usually from cache).
 * External apps would cache the locale themselves.
 */
NSDictionary *
GSPrivateDefaultLocale() GS_ATTRIB_PRIVATE;

#endif /* _GSPrivate_h_ */

