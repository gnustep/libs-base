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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#ifndef __NSThread_h_GNUSTEP_BASE_INCLUDE
#define __NSThread_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <objc/thr.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>

typedef enum
{
  NSInteractiveThreadPriority,
  NSBackgroundThreadPriority,
  NSLowThreadPriority
} NSThreadPriority;

@interface NSThread : NSObject
{
@private
   _objc_thread_t _thread_id;
   NSMutableDictionary *_thread_dictionary;
   id _thread_autorelease_pool;
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

/* Notification Strings. */
extern NSString *NSBecomingMultiThreaded;
extern NSString *NSThreadExiting;

#endif /* __NSThread_h_GNUSTEP_BASE_INCLUDE */
