/* Interface to release stack for delayed disposal
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __AutoreleaseStack_m_GNUSTEP_BASE_INCLUDE
#define __AutoreleaseStack_m_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/ObjectRetaining.h>

@interface AutoreleaseStack : Object
{
}

+ (void) autoreleaseObject: anObj;
- (void) autoreleaseObject: anObj;

- init;

@end

void objc_release_stack_objects();

/* 
   Use of this autorelease class gives -autorelease the following semantics:

   - autorelease;

   Use this message when the sender is done with this object, but the
   sender doesn't want the object to be deallocated immediately
   because the function that sends this message will use this object
   as its return value.  The object will be queued to receive the
   actual "release" message only after the caller's caller returns.
   (Well, not "queued", "stacked" actually.)
   
   Due to this delayed release, the function that receives the object
   as a return value will have the opportunity to retain the object
   before the "release" instigated by the "autorelease" actually
   takes place.

   IMPORTANT PROGRAMMING CONVENTION: Since a autoreleased object may
   be freed in the caller's caller's frame, a function must be careful
   when returning an object that has been been autoreleased to it
   (i.e. returning the object to the autorelease caller's caller's
   caller).  Since you cannot always know which objects returned to
   the current function have been autoreleased by their returners,
   you must use the following rule to insure safety for these
   situations:

      When returning an object that has been allocated, copied or
      retained by the returner, return the object as usual.  If
      returning an object that has been received in this function by
      another function, always retain and autorelease the object
      before returning it.  (Unless, of course, the returner still
      needs to keep a reference to the object, in which case the final
      autorelease should be omitted.)
      
   The autorelease mechanism works as follows: The implementation of
   the "autorelease" method pushes the receiver and the caller's
   caller's frame address onto an internally maintained stack.  But,
   before pushing the reciever, the implementation checks the entries
   already on the stack, popping elements off the stack until the
   recorded frame address is less than the caller's caller's frame
   address.  Each object popped off the stack is sent a "release"
   message.  The stack capacity grows automatically if necessary.

   This mechanism ensures that not too many autoreleased objects can
   be stacked before we check to see what objects can be released
   (i.e. no objects).  It also ensures that objects which have been
   autoreleased are released as soon as we autorelease any other
   object in a lower stack frame.

   The only way to build up an unnecessarily large collection of
   autoreleased objects is by calling functions that autorelease an
   object, and by repeatedly calling those functions from functions
   with equal or increasingly higher frame addresses.

   Any time that you suspect that you may be creating an unnecessarily
   large number of autoreleased objects in a function, (e.g. the
   function contains a loop that creates many autoreleased objects
   that the function doesn't need), you can always release all the
   releasable autoreleased objects for this frame by calling
   objc_release_stack_objects().  Be warned that calling this function
   will release all objects that have been autoreleased to this
   function; if you still need to use some of them, you will have to
   retain them beforehand, and release or autorelease them
   afterwards.  

   If desired, you can also use objc_release_stack_objects() at the
   top of an event loop, a guaranteed "catch-all" coding practise
   similar to the creation and destruction of AutoreleasePool objects
   in the event loop.

   As an alternative to calling objc_release_stack_objects() you can
   also use the same scheme for forcing autorelease's as used for
   AutoreleasePool's: s = [[AutoreleaseStack alloc] init], ... code
   that autoreleases a bunch of objects to the same stack level ...,
   [s release].  It has the same effect.

*/


#endif /* __AutoreleaseStack_m_GNUSTEP_BASE_INCLUDE */
