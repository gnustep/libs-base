/* Protocol for GNU Objective-C objects that can keep a retain count.
   Copyright (C) 1993,1994 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
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

#ifndef __Retaining_h_GNUSTEP_BASE_INCLUDE
#define __Retaining_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>

@protocol Retaining

- retain;

/* Use this message when the sender did not allocate the receiving
   object, but the sender wants to keep a reference to the receiving
   object.  It increments a reference count for the object.  The
   object will not be deallocated until after a matching release
   message is sent to this object.

   IMPORTANT PROGRAMMING CONVENTION: There is no need to send this
   message to objects that the sender allocated---allocating an object
   already implies that the object will not be deallocated until the
   sender releases it.  Just as "retain" and "release" messages cancel
   each other, one "release" message is needed to cancel the original
   allocation. */


- (oneway void) release;

/* Use this message when the sender is done with the receiving object.
   If the sender had the last reference to the object, the object will
   be deallocated by sending "dealloc" to it.

   IMPORTANT PROGRAMMING CONVENTION: The sender should only send this
   to objects that it has allocated or has retain'ed. */


- (void) dealloc;

/* This method deallocates the memory for this object.  You should not
   send this message yourself; it is sent for you by the release
   method, which properly manages retain counts.  Do, however,
   override this method to deallocate any memory allocated by this
   object during initialization; the overriding method should call
   [super dealloc] at the end. */


- (unsigned) retainCount;

/* This method returns the retain count to this object.  It does
   not, however, include the decrements due to stackRelease's.  Note
   that the returned number is not quite a "reference count" in the
   traditional sense; it is less by one in that it is actually a count
   of the number of unreleased retain messages sent.  A retainCount of
   zero implies that there is still one more release necessary to
   deallocate the receiver.  For example, after an object is created,
   its retainCount is zero, but another "release" message is still
   required before the object will be deallocated. */


- autorelease;

/* Use this message when the sender is done with this object, but the
   sender doesn't want the object to be deallocated immediately
   because the function that sends this message will use this object
   as its return value.  The object will be queued to receive the
   actual "release" message later.
   
   Due to this delayed release, the function that receives the object
   as a return value will have the opportunity to retain the object
   before the "release" instigated by the "autorelease" actually
   takes place. 

   For the object to be autoreleased, you must have previously created
   a AutoreleasePool or an AutoreleaseStack.  If you don't, however,
   your program won't crash, the release corresponding to the
   autorelease will just never happen. */

@end

#endif /* __Retaining_h_GNUSTEP_BASE_INCLUDE */
