/* GSUserDefaults
   Copyright (C) 2001 Free Software Foundation, Inc.

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

#ifndef __GSUserDefaults_h_
#define __GSUserDefaults_h_

#include <Foundation/NSUserDefaults.h>

/*
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
NSDictionary	*GSUserDefaultsDictionaryRepresentation();

/*
 * Get one of several potentially useful flags.
 */
BOOL		GSUserDefaultsFlag(GSUserDefaultFlagType type);

#endif /* __GSUserDefaults_h_ */
