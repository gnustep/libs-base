/* GSPrivate
   Copyright (C) 2001-2006 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, 
   Boston, MA 02111 USA.

   $Date$ $Revision$
*/

#ifndef __GSPrivate_h_
#define __GSPrivate_h_

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
 * Function to get the name of a string encoding as an NSString.
 */
GS_EXPORT NSString	*GSEncodingName(NSStringEncoding encoding);

/*
 * Function to determine whether data in a particular encoding can
 * generally be represented as 8-bit characters including ascii.
 */
GS_EXPORT BOOL		GSIsByteEncoding(NSStringEncoding encoding);

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

/*
 * Get one of several potentially useful flags.
 */
BOOL	GSUserDefaultsFlag(GSUserDefaultFlagType type);



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
 *	queued notifications.
 */
extern void GSNotifyASAP(void);
extern void GSNotifyIdle(void);
extern BOOL GSNotifyMore(void);

#endif /* __GSPrivate_h_ */
