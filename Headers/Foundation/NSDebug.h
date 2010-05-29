/* Interface to debugging utilities for GNUStep and OpenStep
   Copyright (C) 1997,1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1997
   Extended by: Nicola Pero <n.pero@mi.flashnet.it>
   Date: December 2000, April 2001

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */

#ifndef __NSDebug_h_GNUSTEP_BASE_INCLUDE
#define __NSDebug_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#include <errno.h>

#if	!NO_GNUSTEP
#  if	defined(GNUSTEP_BASE_INTERNAL)
#    import	"Foundation/NSObject.h"
#    import	"GNUstepBase/NSDebug+GNUstepBase.h"
#  else
#    import	<Foundation/NSObject.h>
#    import	<GNUstepBase/NSDebug+GNUstepBase.h>
#  endif
#endif

#if	defined(__cplusplus)
extern "C" {
#endif

/*
 *	Functions for debugging object allocation/deallocation
 *
 *	Internal functions:
 *	GSDebugAllocationAdd()		is used by NSAllocateObject()
 *	GSDebugAllocationRemove()	is used by NSDeallocateObject()
 *
 *	Public functions:
 *	GSDebugAllocationActive()	
 *	GSDebugAllocationCount()	
 *      GSDebugAllocationTotal()
 *      GSDebugAllocationPeak()
 *      GSDebugAllocationClassList()
 *	GSDebugAllocationList()
 *	GSDebugAllocationListAll()
 * GSSetDebugAllocationFunctions()
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
 *  GSDebugAllocationListRecordedObjects() 
 */
#ifndef	NDEBUG

/**
 * Used internally by NSAllocateObject() ... you probably don't need this.
 */
GS_EXPORT void		GSDebugAllocationAdd(Class c, id o);

/**
 * Used internally by NSDeallocateObject() ... you probably don't need this.
 */
GS_EXPORT void		GSDebugAllocationRemove(Class c, id o);

/**
 * Activates or deactivates object allocation debugging.
 * Returns previous state.
 */
GS_EXPORT BOOL		GSDebugAllocationActive(BOOL active);

/**
 * Returns the number of instances of the specified class
 * which are currently allocated.
 */
GS_EXPORT int		GSDebugAllocationCount(Class c);

/**
 * Returns the peak number of instances of the specified class
 * which have been concurrently allocated.
 */
GS_EXPORT int		GSDebugAllocationPeak(Class c);

/**
 * Returns the total number of instances of the specified class
 * which have been allocated.
 */
GS_EXPORT int		GSDebugAllocationTotal(Class c);

/**
 * Returns a NULL terminated array listing all the classes 
 * for which statistical information has been collected.
 */
GS_EXPORT Class*        GSDebugAllocationClassList(void);

/**
 * Returns a newline separated list of the classes which
 * have instances allocated, and the instance counts.
 * If 'changeFlag' is YES then the list gives the number
 * of instances allocated/deallocated since the function
 * was last called.
 */
GS_EXPORT const char*	GSDebugAllocationList(BOOL changeFlag);

/**
 * Returns a newline separated list of the classes which
 * have had instances allocated at any point, and the total
 * count of the number of instances allocated for each class.
 */
GS_EXPORT const char*	GSDebugAllocationListAll(void);

/**
 * Starts recording all allocated objects of a certain class.<br />
 * Use with extreme care ... this could slow down your application
 * enormously.
 */
GS_EXPORT void     GSDebugAllocationActiveRecordingObjects(Class c);

/**
 * Returns an array containing all the allocated objects
 * of a certain class which have been recorded.
 * Presumably, you will immediately call [NSObject-description] on
 * them to find out the objects you are leaking.
 * Warning - the objects are put in an array, so until
 * the array is autoreleased, the objects are not released.
 */
GS_EXPORT NSArray *GSDebugAllocationListRecordedObjects(Class c);

/**
 * This function associates the supplied tag with a recorded
 * object and returns the tag which was previously associated
 * with it (if any).<br />
 * If the object was not recorded, the method returns nil<br />
 * The tag is retained while it is associated with the object.<br />
 * See also the NSDebugFRLog() and NSDebugMRLog() macros.
 */
GS_EXPORT id GSDebugAllocationTagRecordedObject(id object, id tag);

/**
 * This functions allows to set own function callbacks for debugging allocation
 * of objects. Useful if you intend to write your own object allocation code.
 */
GS_EXPORT void  GSSetDebugAllocationFunctions(
  void (*newAddObjectFunc)(Class c, id o),
  void (*newRemoveObjectFunc)(Class c, id o));

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
 * sent to the object, instead of crashing, NSZombie will use NSLog() to
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



/**
 *  Retrieve stack information.  Use caution: uses built-in gcc functions
 *  and currently only works up to 100 frames.
 */
GS_EXPORT void *NSFrameAddress(NSUInteger offset);

/**
 *  Retrieve stack information.  Use caution: uses built-in gcc functions
 *  and currently only works up to 100 frames.
 */
GS_EXPORT void *NSReturnAddress(NSUInteger offset);

/**
 *  Retrieve stack information.  Use caution: uses built-in gcc functions
 *  and currently only works up to 100 frames.
 */
GS_EXPORT NSUInteger NSCountFrames(void);

#if	defined(__cplusplus)
}
#endif

#endif
