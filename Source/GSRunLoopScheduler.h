#ifndef __GSRunLoopScheduler_h_GNUSTEP_BASE_INCLUDE
#define __GSRunLoopScheduler_h_GNUSTEP_BASE_INCLUDE
/** 
   Copyright (C) 2026 Free Software Foundation, Inc.

   By: Richard Frith-Macdonald <richard@brainstorm.co.uk>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/

#import "common.h"
#import "Foundation/NSObject.h"
#import "Foundation/NSURLConnection.h"

@class NSMapTable;
@class NSRunLoop;
@class NSString;

/** Utility to manage scheduling
 */
@interface GSRunLoopScheduler: NSObject
{
  NSMapTable	*_scheduled;
}

/** Record loop/mode combination in this instance.
 */
- (void) scheduleInRunLoop: (NSRunLoop*)loop forMode: (NSString*)mode;

/** Remove recorded loop/mode combination from this instance.
 */
- (void) unscheduleFromRunLoop: (NSRunLoop*)loop forMode: (NSString*)mode;

/** Remove the receiver from all the recorded loop/mode combinations.
 */
- (void) remove: (id)receiver;

/** Schedule the receiver in all the recorded loop/mode combinations.
 */
- (void) schedule: (id)receiver;

/** Unschedule the receiver from all the recorded loop/mode combinations.
 */
- (void) unschedule: (id)receiver;
@end

@interface NSURLConnection (NSURLProtocolClient)
/* Internal method for NSURLProtocol to determine what loops/modes to run in.
 */
- (GSRunLoopScheduler*) _scheduled;
@end

#endif /* __GSRunLoopScheduler_h_GNUSTEP_BASE_INCLUDE */
