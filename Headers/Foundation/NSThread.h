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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/ 

#ifndef __NSThread_h_GNUSTEP_BASE_INCLUDE
#define __NSThread_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSDictionary.h>
#import	<Foundation/NSDate.h>
#import	<Foundation/NSException.h>
#import	<Foundation/NSAutoreleasePool.h> // for struct autorelease_thread_vars

#if	defined(__cplusplus)
extern "C" {
#endif

@interface NSThread : NSObject
{
  id			_target;
  id			_arg;
  SEL			_selector;
@public
  BOOL			_active;
  NSHandler		*_exception_handler;
  NSMutableDictionary	*_thread_dictionary;
  struct autorelease_thread_vars _autorelease_vars;
  id			_gcontext;
}

+ (NSThread*) currentThread;
+ (void) detachNewThreadSelector: (SEL)aSelector
		        toTarget: (id)aTarget
		      withObject: (id)anArgument;
+ (void) exit;
+ (BOOL) isMultiThreaded;
+ (void) setThreadPriority: (double)pri;
+ (void) sleepUntilDate: (NSDate*)date;
+ (double) threadPriority;

- (NSMutableDictionary*) threadDictionary;

@end

#if	GS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
@interface	NSObject(NSMainThreadPerformAdditions)
- (void) performSelectorOnMainThread: (SEL)aSelector
			  withObject: (id)anObject
		       waitUntilDone: (BOOL)aFlag
			       modes: (NSArray*)anArray;
- (void) performSelectorOnMainThread: (SEL)aSelector
			  withObject: (id)anObject
		       waitUntilDone: (BOOL)aFlag;
@end
#endif

#if	GS_API_VERSION(GS_API_NONE, GS_API_NONE)
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
 * notification.  */
GS_EXPORT void GSUnregisterCurrentThread (void);
#endif

/*
 * Notification Strings.
 * NSBecomingMultiThreaded and NSThreadExiting are defined for strict
 * OpenStep compatibility, the actual notification names are the more
 * modern OPENSTEP/MacOS versions.
 */

/**
 *  Notification posted the first time a new [NSThread] is created or a
 *  separate thread from another library is registered in an application.
 *  (The initial thread that a program starts with does <em>not</em>
 *  post this notification.)  Before such a notification has been posted you
 *  can assume the application is in single-threaded mode and locks are not
 *  necessary.  Afterwards multiple threads <em>may</em> be running.
 */
GS_EXPORT NSString* const NSWillBecomeMultiThreadedNotification;
#define	NSBecomingMultiThreaded NSWillBecomeMultiThreadedNotification

/**
 *  Notification posted when an [NSThread] instance receives an exit message,
 *  or an external thread has been deregistered.
 */
GS_EXPORT NSString* const NSThreadWillExitNotification;
#define NSThreadExiting NSThreadWillExitNotification

#if	GS_API_VERSION(GS_API_NONE, GS_API_NONE)

/**
 *  Notification posted whenever a new thread is started up.  This is a
 *  GNUstep extension.
 */
GS_EXPORT NSString* const NSThreadDidStartNotification;

/*
 *	Get current thread and it's dictionary.
 */
GS_EXPORT NSThread		*GSCurrentThread(void);
GS_EXPORT NSMutableDictionary	*GSCurrentThreadDictionary(void);
#endif

#if	defined(__cplusplus)
}
#endif

#endif /* __NSThread_h_GNUSTEP_BASE_INCLUDE */
