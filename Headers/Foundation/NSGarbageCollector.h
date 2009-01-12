/** Interface for NSGarbageCollector for GNUStep
   Copyright (C) 2009 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Created: Jan 2009
   
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

   AutogsdocSource: NSGarbageCollector.m

   */ 

#ifndef _NSGarbageCollector_h_GNUSTEP_BASE_INCLUDE
#define _NSGarbageCollector_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif


@interface NSGarbageCollector : NSObject 

/** Returns the garbage collector instance ... there is only one.<br />
 * Returns nil if the process is not using garbage collection.
 */
+ (id) defaultCollector;

/** Collects some memory.
 */
- (void) collectIfNeeded;

/** Collects all collectable memory.
 */
- (void) collectExhaustively;

/** Disables garbage collection until a corresponding call to -enable is made.
 */
- (void) disable;

/** Disables collection for the area of memory pointed at.
 */
- (void) disableCollectorForPointer: (void *)ptr;

/** Enables garbage collection prevously disabled by a calle to -disable
 */
- (void) enable;

/** Enables collection for the area of memory pointed at.
 */
- (void) enableCollectorForPointer: (void *)ptr;      

/** Returns yes if there is a garbage collection progress.
 */
- (BOOL) isCollecting;

/** Retunrs YES if garbage collecting is currently enabled.
 */
- (BOOL) isEnabled;

/** Returns a zone for holding non-collectable pointers.<br />
 */
- (NSZone*) zone;
@end

#if	defined(__cplusplus)
}
#endif

#endif
#endif
