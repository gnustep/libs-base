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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#ifndef __GSPrivate_h_
#define __GSPrivate_h_

#include "GNUstepBase/GSObjCRuntime.h"

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of objects.  Use this to start the block of code using
 * the array and GS_ENDIDBUF() to end it.  The idea is to ensure that small
 * arrays are allocated on the stack (for speed), but large arrays are
 * allocated from the heap (to avoid stack overflow).
 */
#define	GS_BEGINIDBUF(P, S) { \
  id _obuf[(S) <= GS_MAX_OBJECTS_FROM_STACK ? (S) : 0]; \
  id *_base = ((S) <= GS_MAX_OBJECTS_FROM_STACK) ? _obuf \
    : (id*)NSZoneMalloc(NSDefaultMallocZone(), (S) * sizeof(id)); \
  id *(P) = _base;

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of objects.  Use GS_BEGINIDBUF() to start the block of code using
 * the array and this macro to end it.
 */
#define	GS_ENDIDBUF() \
  if (_base != _obuf) \
    NSZoneFree(NSDefaultMallocZone(), _base); \
  }

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
 * Private concrete string classes.
 * NB. All these concrete string classes MUST have the same initial ivar
 * layout so that we can swap between them as necessary.
 * The initial layout must also match that of NXConstantString (which is
 * determined by the compiler) - an initial pointer to the string data
 * followed by the string length (number of characters).
 */
@interface GSString : NSString
{
  union {
    unichar		*u;	// 16-bit unicode characters.
    unsigned char	*c;	// 8-bit characters.
  } _contents;
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
 * Enumeration for MacOS-X compatibility user defaults settings.
 * For efficiency, we save defaults information which is used by the
 * base library.
 */
typedef enum {
  GSMacOSXCompatible,			// General behavior flag.
  GSOldStyleGeometry,			// Control geometry string output.
  GSLogSyslog,				// Force logging to go to syslog.
  NSWriteOldStylePropertyLists,		// Control PList output.
  GSUserDefaultMaxFlag			// End marker.
} GSUserDefaultFlagType;

/*
 * Get the dictionary representation.
 */
NSDictionary	*GSUserDefaultsDictionaryRepresentation(void);

/*
 * Get one of several potentially useful flags.
 */
BOOL	GSUserDefaultsFlag(GSUserDefaultFlagType type);

/**
 * Get a flag from an environment variable - return def if not defined.
 */
BOOL	GSEnvironmentFlag(const char *name, BOOL def);

#endif /* __GSPrivate_h_ */

