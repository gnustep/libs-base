/** Declaration of extension methods for base additions

   Copyright (C) 2026 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/

#ifndef	INCLUDED_NSHost_GNUstepBase_h
#define	INCLUDED_NSHost_GNUstepBase_h

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSHost.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

@class	NSArray;
@class	NSString;
@class	NSThread;

@interface NSHost (GNUstepBase)
/** Performs an asynchronous lookup of the host name (using an operation queue)
 * and sends the response to the target object as a message with the specified
 * selector (the single argument of the message is the result of the host
 * lookup).<br />
 * The result is sent to the target in the specified thread and using the
 * supplied run loop modes.<br />
 * If the thread argument is nil, the result is delivered to the thread in
 * which this method is called.<br />
 * If the modes argument is empty, NSDefaultRunLoopMode is used to deliver
 * the result.<br />
 * The target object is NOT retained.
 */
+ (void) lookupName: (NSString*)name
             thread: (NSThread*)thread
             target: (id)anObject
           selector: (SEL)aSelector
              modes: (NSArray*)modes;
@end

#endif	/* OS_API_VERSION */

#if	defined(__cplusplus)
}
#endif

#endif	/* INCLUDED_NSHost_GNUstepBase_h */

