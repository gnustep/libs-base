/* 
   NSThread.h

   Control of executable units within a shared virtual memory space

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996
   
   This file is part of the GNUstep Objective-C Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#ifndef _GNUstep_H_NSThread
#define _GNUstep_H_NSThread

#include <Foundation/NSObject.h>
#include <objc/thread.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>

typedef enum {
    NSInteractiveThreadPriority,
    NSBackgroundThreadPriority,
    NSLowThreadPriority
} NSThreadPriority;

extern NSString *NSBecomingMultiThreaded;
extern NSString *NSThreadExiting;

@interface NSThread : NSObject
{
@private
    _objc_thread_t thread_id;
    NSMutableDictionary *thread_dictionary;
    id _thread_autorelease_pool;
}

+ (NSThread *)currentThread;
+ (void)detachNewThreadSelector:(SEL)aSelector
   toTarget:(id)aTarget
   withObject:(id)anArgument;

+ (BOOL)isMultiThreaded;
- (NSMutableDictionary *)threadDictionary;

+ (void)sleepUntilDate:(NSDate *)date;
+ (void)exit;

@end

#endif _GNUstep_H_NSThread
