/* Interface to debugging utilities for GNUStep and OpenStep
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1997

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

#ifndef __NSDebug_h_GNUSTEP_BASE_INCLUDE
#define __NSDebug_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <errno.h>

extern int	errno;


/*
 *	Functions for debugging object allocation/deallocation
 *
 *	Internal functions:
 *	GSDebugAllocationAdd()		is used by NSAllocateObject()
 *	GSDebugAllocationRemove()	is used by NSDeallocateObject()
 *
 *	Public functions:
 *	GSDebugAllocationActive()	
 *		Activates or deactivates object allocation debugging.
 *		Returns previous state.
 *
 *	GSDebugAllocationCount()	
 *		Returns the number of instances of the specified class
 *		which are currently allocated.
 *
 *	GSDebugAllocationList()
 *		Returns a newline separated list of the classes which
 *		have nstances allocated, and the instance counts.
 *		If 'changeFlag' is YES then the list gives the number
 *		of instances allocated/deallocated sine the function
 *		was last called.
 */

#ifndef	NDEBUG
extern	void		GSDebugAllocationAdd(Class c);
extern	void		GSDebugAllocationRemove(Class c);

extern	BOOL		GSDebugAllocationActive(BOOL active);
extern	int		GSDebugAllocationCount(Class c);
extern	const char*	GSDebugAllocationList(BOOL changeFlag);
#endif


/* Debug logging which can be enabled/disabled by defining DEBUG
   when compiling and also setting values in the mutable array
   that is set up by NSProcessInfo.
   This array is initialised by NSProcess info using the
    '--GNU-Debug=...' command line argument.  Each command-line argument
   of that form is removed from NSProcessInfos list of arguments and the
   variable part (...) is added to the array.
   For instance, to debug the NSBundle class, run your program with 
    '--GNU-Debug=NSBundle'
   You can of course supply multiple '--GNU-Debug=...' arguments to
   output debug information on more than one thing.
 */
#ifdef DEBUG
#include	<Foundation/NSDebug.h>
#include	<Foundation/NSProcessInfo.h>
#define NSDebugLLog(level, format, args...) \
  do { if ([[[NSProcessInfo processInfo] debugArray] containsObject: level]) \
    NSLog(format, ## args); } while (0)
#define NSDebugLog(format, args...) \
  do { if ([[[NSProcessInfo processInfo] debugArray] containsObject: @"dflt"]) \
    NSLog(format, ## args); } while (0)
#else
#define NSDebugLLog(level, format, args...)
#define NSDebugLog(format, args...)
#endif

#endif
