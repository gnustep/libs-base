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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
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
 *		have instances allocated, and the instance counts.
 *		If 'changeFlag' is YES then the list gives the number
 *		of instances allocated/deallocated sine the function
 *		was last called.
 *	GSDebugAllocationListAll()
 *		Returns a newline separated list of the classes which
 *		have had instances allocated at any point, and the total
 *		count of the number of instances allocated.
 */

#ifndef	NDEBUG
extern	void		GSDebugAllocationAdd(Class c);
extern	void		GSDebugAllocationRemove(Class c);

extern	BOOL		GSDebugAllocationActive(BOOL active);
extern	int		GSDebugAllocationCount(Class c);
extern	const char*	GSDebugAllocationList(BOOL changeFlag);

extern	NSString*	GSDebugFunctionMsg(const char *func, const char *file,
				int line, NSString *fmt);
extern	NSString*	GSDebugMethodMsg(id obj, SEL sel, const char *file,
				int line, NSString *fmt);
#endif


/* Debug logging which can be enabled/disabled by defining DEBUG
   when compiling and also setting values in the mutable array
   that is set up by NSProcessInfo.

   NB. The 'debug=yes' option is understood by the GNUstep make package
   to mean that DEBUG should be defined, so you don't need to go editing
   your makefiles to do it.

   NSProcess initialises a set of strings that are the names of active
   debug levels using the '--GNU-Debug=...' command line argument.
   Each command-line argument of that form is removed from NSProcessInfos
   list of arguments and the variable part (...) is added to the set.

   For instance, to debug the NSBundle class, run your program with 
    '--GNU-Debug=NSBundle'
   You can of course supply multiple '--GNU-Debug=...' arguments to
   output debug information on more than one thing.

   To embed debug logging in your code you use the NSDebugLLog() or
   NSDebugLog() macro.  NSDebugLog() is just NSDebugLLog() with the debug
   level set to 'dflt'.  So, to activate debug statements that use
   NSDebugLog(), you supply the '--GNU-Debug=dflt' argument to your program.

   You can also change the active debug levels under your programs control -
   NSProcessInfo has a [-debugSet] method that returns the mutable set that
   contains the active debug levels - your program can modify this set.

   As a convenience, there are four more logging macros you can use -
   NSDebugFLog(), NSDebugFLLog(), NSDebugMLog() and NSDebugMLLog().
   These are the same as the other macros, but are specifically for use in
   either functions or methods and prepend information about the file, line
   and either function or class/method in which the message was generated.

 */
#ifdef DEBUG
#include	<Foundation/NSObjCRuntime.h>
#include	<Foundation/NSProcessInfo.h>
#define NSDebugLLog(level, format, args...) \
  do { if (GSDebugSet(level) == YES) \
    NSLog(format, ## args); } while (0)
#define NSDebugLog(format, args...) \
  do { if (GSDebugSet(@"dflt") == YES) \
    NSLog(format, ## args); } while (0)
#define NSDebugFLLog(level, format, args...) \
  do { if (GSDebugSet(level) == YES) { \
    NSString *fmt = GSDebugFunctionMsg( \
	__PRETTY_FUNCTION__, __FILE__, __LINE__, format); \
    NSLog(fmt, ## args); }} while (0)
#define NSDebugFLog(format, args...) \
  do { if (GSDebugSet(@"dflt") == YES) { \
    NSString *fmt = GSDebugFunctionMsg( \
	__PRETTY_FUNCTION__, __FILE__, __LINE__, format); \
    NSLog(fmt, ## args); }} while (0)
#define NSDebugMLLog(level, format, args...) \
  do { if (GSDebugSet(level) == YES) { \
    NSString *fmt = GSDebugMethodMsg( \
	self, _cmd, __FILE__, __LINE__, format); \
    NSLog(fmt, ## args); }} while (0)
#define NSDebugMLog(format, args...) \
  do { if (GSDebugSet(@"dflt") == YES) { \
    NSString *fmt = GSDebugMethodMsg( \
	self, _cmd, __FILE__, __LINE__, format); \
    NSLog(fmt, ## args); }} while (0)
#else
#define NSDebugLLog(level, format, args...)
#define NSDebugLog(format, args...)
#define NSDebugFLLog(level, format, args...)
#define NSDebugFLog(format, args...)
#define NSDebugMLLog(level, format, args...)
#define NSDebugMLog(format, args...)
#endif

#endif
