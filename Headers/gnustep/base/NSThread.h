/* Control of executable units within a shared virtual memory space
   Copyright (C) 1996 Free Software Foundation, Inc.

   Original Author:  Scott Christley <scottc@net-community.com>
   Rewritten by: Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: 1996
   
   This file is part of the GNUstep Objective-C Library.

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

#ifndef __NSThread_h_GNUSTEP_BASE_INCLUDE
#define __NSThread_h_GNUSTEP_BASE_INCLUDE

#ifdef NeXT_RUNTIMME
#include <base/thr-mach.h>
#endif
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h> // for struct autorelease_thread_vars

typedef enum
{
  NSInteractiveThreadPriority,
  NSBackgroundThreadPriority,
  NSLowThreadPriority
} NSThreadPriority;

@interface NSThread : NSObject
{
  id			_target;
  id			_arg;
  SEL			_selector;
  BOOL			_active;
@public
  NSHandler		*_exception_handler;
  NSMutableDictionary	*_thread_dictionary;
  struct autorelease_thread_vars _autorelease_vars;
  id			_gcontext;
}

+ (NSThread*) currentThread;
+ (void) detachNewThreadSelector: (SEL)aSelector
		        toTarget: (id)aTarget
		      withObject: (id)anArgument;

+ (BOOL) isMultiThreaded;
- (NSMutableDictionary*) threadDictionary;

+ (void) sleepUntilDate: (NSDate*)date;
+ (void) exit;

@end

#ifndef NO_GNUSTEP
/*
 * Don't use the following functions unless you really know what you are 
 * doing ! 
 * The following functions are low-levelish and special. 
 * They are meant to make it possible to run GNUstep code in threads 
 * created in completely different environment, eg inside a JVM.
 *
 * If you use them, make sure you initialize the NSThread class inside
 * (what you consider to be your) main thread, before registering any
 * other thread.  To initialize NSThread, simply call GSCurrentThread
 * ().  The main thread will not need to be registered.  
 */

/*
 * Register an external thread (created using your OS thread interface
 * directly) to GNUstep.  This means that it creates a NSThread object
 * corresponding to the current thread, and sets things up so that you
 * can run GNUstep code inside the thread.  If the thread was not
 * known to GNUstep, this function registers it, and returns YES.  If
 * the thread was already known to GNUstep, this function does nothing
 * and returns NO.  */
GS_EXPORT BOOL GSRegisterCurrentThread (void);
/*
 * Unregister the current thread from GNUstep.  You must only
 * unregister threads which have been register using
 * registerCurrentThread ().  This method is basically the same as
 * `+exit', but does not exit the thread - just destroys all objects
 * associated with the thread.  Warning: using any GNUstep code after
 * this method call is not safe.  Posts an NSThreadWillExit
 * notification. x*/
GS_EXPORT void GSUnregisterCurrentThread (void);
#endif

/*
 * Notification Strings.
 * NSBecomingMultiThreaded and NSThreadExiting are defined for strict
 * OpenStep compatibility, the actual notification names are the more
 * modern OPENSTEP/MacOS versions.
 */
GS_EXPORT NSString	*NSWillBecomeMultiThreadedNotification;
#define	NSBecomingMultiThreaded NSWillBecomeMultiThreadedNotification

GS_EXPORT NSString	*NSThreadWillExitNotification;
#define NSThreadExiting NSThreadWillExitNotification

#ifndef	NO_GNUSTEP

GS_EXPORT NSString	*NSThreadDidStartNotification;

/*
 *	Get current thread and it's dictionary.
 */
GS_EXPORT NSThread		*GSCurrentThread();
GS_EXPORT NSMutableDictionary	*GSCurrentThreadDictionary();
#endif

#endif /* __NSThread_h_GNUSTEP_BASE_INCLUDE */
