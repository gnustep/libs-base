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
    unsigned int	free: 1;	// Should free memory?
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

