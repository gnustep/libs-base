/** Declaration of extension methods for base additions

   Copyright (C) 2026 Free Software Foundation, Inc.

   Written by:  Frederik Seiffert <frederik@algoriddim.com>

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

#ifndef	INCLUDED_NSProgress_GNUstepBase_h
#define	INCLUDED_NSProgress_GNUstepBase_h

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSProgress.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

/** The GSProgressDelegate protocol specifies the messages sent to the
 * delegate of a progress.  They are sent where the cancellation, pausing
 * and resuming handlers would be called, so they are portable code that
 * needs no blocks.
 */
@protocol	GSProgressDelegate <NSObject>
#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#else
@end
@interface NSObject (GSProgressDelegate)
#endif
/** Sent whenever the progress is cancelled, even if it already was, and when
 * the delegate is set on a cancelled progress.
 */
- (void) progressCancelled: (NSProgress *)progress;

/** Sent whenever the progress is paused, even if it already was, and when
 * the delegate is set on a paused progress.
 */
- (void) progressPaused: (NSProgress *)progress;

/** Sent whenever the progress is resumed, even if it was not paused.
 */
- (void) progressResumed: (NSProgress *)progress;
@end

@interface NSProgress (GNUstepBase)

/** Returns the delegate (if any) set to handle cancellation, pausing and
 * resuming of the progress.
 */
- (id<GSProgressDelegate>) delegate;

/** Sets the delegate that is sent the GSProgressDelegate messages.  The
 * progress uses a weak reference to the delegate, it does not retain it.<br />
 * Use this rather than the cancellation, pausing and resuming handlers,
 * which it replaces (do not attempt to use both).<br />
 * Like the handlers, the messages are sent asynchronously on another thread,
 * so they may arrive after later changes of the progress.
 */
- (void) setDelegate: (id<GSProgressDelegate>)delegate;

@end

#endif	/* OS_API_VERSION */

#if	defined(__cplusplus)
}
#endif

#endif	/* INCLUDED_NSProgress_GNUstepBase_h */
