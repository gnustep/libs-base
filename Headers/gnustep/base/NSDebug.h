/* Interface to debugging utilities for GNUStep and OpenStep
   Copyright (C) 1997,1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1997
   Extended by: Nicola Pero <n.pero@mi.flashnet.it>
   Date: December 2000, April 2001

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

#ifndef __NSDebug_h_GNUSTEP_BASE_INCLUDE
#define __NSDebug_h_GNUSTEP_BASE_INCLUDE

#include <errno.h>
#include <Foundation/NSObject.h>

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
 *      GSDebugAllocationTotal()
 *		Returns the total number of instances of the specified class
 *		which have been allocated.
 *
 *      GSDebugAllocationPeak()
 *		Returns the peak number of instances of the specified class
 *		which have been concurrently allocated.
 *
 *      GSDebugAllocationClassList()
 *              Returns a NULL terminated array listing all the classes 
 *              for which statistical information has been collected.
 *
 *	GSDebugAllocationList()
 *		Returns a newline separated list of the classes which
 *		have instances allocated, and the instance counts.
 *		If 'changeFlag' is YES then the list gives the number
 *		of instances allocated/deallocated since the function
 *		was last called.
 *	GSDebugAllocationListAll()
 *		Returns a newline separated list of the classes which
 *		have had instances allocated at any point, and the total
 *		count of the number of instances allocated for each class.
 *
 * When the previous functions have allowed you to find a memory leak,
 * and you know that you are leaking objects of class XXX, but you are
 * hopeless about actually finding out where the leak is, the
 * following functions could come handy as they allow you to find
 * exactly *what* objects you are leaking (warning! these functions
 * could slow down your system appreciably - use them only temporarily
 * and only in debugging systems):
 *
 *  GSDebugAllocationActiveRecordingObjects()
 *              Starts recording all allocated objects of a certain class
 *
 *  GSDebugAllocationListRecordedObjects() 
 *              Returns an array containing all the allocated objects
 *              of a certain class which have been recorded.
 *              Presumably, you will immediately call -description on
 *              them to find out the objects you are leaking.
 *              Warning - the objects are put in an array, so until
 *              the array is autoreleased, the objects are not released.  */

#ifndef	NDEBUG
GS_EXPORT void		GSDebugAllocationAdd(Class c, id o);
GS_EXPORT void		GSDebugAllocationRemove(Class c, id o);

GS_EXPORT BOOL		GSDebugAllocationActive(BOOL active);
GS_EXPORT int		GSDebugAllocationCount(Class c);
GS_EXPORT int		GSDebugAllocationPeak(Class c);
GS_EXPORT int		GSDebugAllocationTotal(Class c);
GS_EXPORT Class*        GSDebugAllocationClassList();
GS_EXPORT const char*	GSDebugAllocationList(BOOL changeFlag);
GS_EXPORT const char*	GSDebugAllocationListAll();

GS_EXPORT void     GSDebugAllocationActiveRecordingObjects(Class c);
GS_EXPORT NSArray *GSDebugAllocationListRecordedObjects(Class c);

GS_EXPORT NSString*	GSDebugFunctionMsg(const char *func, const char *file,
				int line, NSString *fmt);
GS_EXPORT NSString*	GSDebugMethodMsg(id obj, SEL sel, const char *file,
				int line, NSString *fmt);
#endif

/**
 * Enable/disable zombies.
 * <p>When an object is deallocated, its isa pointer is normally modified
 * to the hexadecimal value 0xdeadface, so that any attempt to send a
 * message to the deallocated object will cause a crash, and examination
 * of the object within the debugger will show the 0xdeadface value ...
 * making it obvious why the program crashed.
 * </p>
 * <p>Turning on zombies changes this behavior so that the isa pointer
 * is modified to be that of the NSZombie class.  When messages are
 * sent to the object, intead of crashing, NSZombie will use NSLog() to
 * produce an error message.  By default the memory used by the object
 * will not really be freed, so error messages will continue to
 * be generated whenever a message is sent to the object, and the object
 * instance variables will remain available for examination by the debugger.
 * </p>
 * The default value of this boolean is NO, but this can be controlled
 * by the NSZombieEnabled environment variable.
 */
GS_EXPORT BOOL NSZombieEnabled;

/**
 * Enable/disable object deallocation.
 * <p>If zombies are enabled, objects are by default <em>not</em>
 * deallocated, and memory leaks.  The NSDeallocateZombies variable
 * lets you say that the the memory used by zombies should be freed.
 * </p>
 * <p>Doing this makes the behavior of zombies similar to that when zombies
 * are not enabled ... the memory occupied by the zombie may be re-used for
 * other purposes, at which time the isa pointer may be overwritten and the
 * zombie behavior will cease.
 * </p>
 * The default value of this boolean is NO, but this can be controlled
 * by the NSDeallocateZombies environment variable.
 */
GS_EXPORT BOOL NSDeallocateZombies;



/* Debug logging which can be enabled/disabled by defining GSDIAGNOSE
   when compiling and also setting values in the mutable array
   that is set up by NSProcessInfo. GSDIAGNOSE is defined autmatically unless
   diagnose=no is specified in the make arguments.

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
#ifdef GSDIAGNOSE
#include	<Foundation/NSObjCRuntime.h>
#include	<Foundation/NSProcessInfo.h>

#define NSDebugLLog(level, format, args...) \
  do { if (GSDebugSet(level) == YES) \
    NSLog(format , ## args); } while (0)
#define NSDebugLog(format, args...) \
  do { if (GSDebugSet(@"dflt") == YES) \
    NSLog(format , ## args); } while (0)
#define NSDebugFLLog(level, format, args...) \
  do { if (GSDebugSet(level) == YES) { \
    NSString *fmt = GSDebugFunctionMsg( \
	__PRETTY_FUNCTION__, __FILE__, __LINE__, format); \
    NSLog(fmt , ## args); }} while (0)
#define NSDebugFLog(format, args...) \
  do { if (GSDebugSet(@"dflt") == YES) { \
    NSString *fmt = GSDebugFunctionMsg( \
	__PRETTY_FUNCTION__, __FILE__, __LINE__, format); \
    NSLog(fmt , ## args); }} while (0)
#define NSDebugMLLog(level, format, args...) \
  do { if (GSDebugSet(level) == YES) { \
    NSString *fmt = GSDebugMethodMsg( \
	self, _cmd, __FILE__, __LINE__, format); \
    NSLog(fmt , ## args); }} while (0)
#define NSDebugMLog(format, args...) \
  do { if (GSDebugSet(@"dflt") == YES) { \
    NSString *fmt = GSDebugMethodMsg( \
	self, _cmd, __FILE__, __LINE__, format); \
    NSLog(fmt , ## args); }} while (0)
#else
#define NSDebugLLog(level, format, args...)
#define NSDebugLog(format, args...)
#define NSDebugFLLog(level, format, args...)
#define NSDebugFLog(format, args...)
#define NSDebugMLLog(level, format, args...)
#define NSDebugMLog(format, args...)
#endif



/* Warning messages which can be enabled/disabled by defining GSWARN
   when compiling.

   These logging macros are intended to be used when the software detects
   something that it not necessarily fatal or illegal, but looks like it
   might be a programming error.  eg. attempting to remove 'nil' from an
   NSArray, which the Spec/documentation does not prohibit, but which a
   well written progam should not be attempting (since an NSArray object
   cannot contain a 'nil').

   NB. The 'warn=yes' option is understood by the GNUstep make package
   to mean that GSWARN should be defined, and the 'warn=no' means that
    GSWARN should be undefined.  Default is to define it.

   To embed debug logging in your code you use the NSWarnLog() macro.

   As a convenience, there are two more logging macros you can use -
   NSWarnLog(), and NSWarnMLog().
   These are specifically for use in either functions or methods and
   prepend information about the file, line and either function or
   class/method in which the message was generated.

 */
#ifdef GSWARN
#include	<Foundation/NSObjCRuntime.h>

#define NSWarnLog(format, args...) \
  do { \
    NSLog(format , ## args); } while (0)
#define NSWarnFLog(format, args...) \
  do { \
    NSString *fmt = GSDebugFunctionMsg( \
	__PRETTY_FUNCTION__, __FILE__, __LINE__, format); \
    NSLog(fmt , ## args); } while (0)
#define NSWarnMLog(format, args...) \
  do { \
    NSString *fmt = GSDebugMethodMsg( \
	self, _cmd, __FILE__, __LINE__, format); \
    NSLog(fmt , ## args); } while (0)
#else
#define NSWarnLog(format, args...)
#define NSWarnFLog(format, args...)
#define NSWarnMLog(format, args...)
#endif

/* Getting stack information. Use caution with this. It uses builtin
   gcc functions and currently only works up to 100 frames 
*/
GS_EXPORT void *NSFrameAddress(int offset);
GS_EXPORT void *NSReturnAddress(int offset);
GS_EXPORT unsigned NSCountFrames(void);

#endif
