/* Interface for Objective-C "collection of delegates" object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

   This file is part of the Gnustep Base Library.

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

/* Using this object, a delegator can have an arbitrary number of
   delegates.  Send a message to this object and the message will get
   forwarded to the delegates on the list. */

#ifndef __DelegatePool_h_GNUSTEP_BASE_INCLUDE
#define __DelegatePool_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/Array.h>

/* Available sending behaviors */
enum DelegatePoolSendBehavior {SEND_TO_ALL = 0, 
			       SEND_TO_FIRST_RESPONDER,
			       SEND_UNTIL_YES,
			       SEND_UNTIL_NO};

@interface DelegatePool
{
  struct objc_class *isa;
  @public
  unsigned char _send_behavior;
  Array *_list;
  BOOL _last_message_had_receivers;
}

// CREATING AND FREEING;
+ alloc;
+ new;
- init;
- (void) dealloc;

// MANIPULATING COLLECTION OF DELEGATES;
- (void) delegatePoolAddObject: anObject;
- (void) delegatePoolAddObjectIfAbsent: anObject;
- (void) delegatePoolRemoveObject: anObject;
- (BOOL) delegatePoolIncludesObject: anObject;
- delegatePoolCollection;
- (unsigned char) delegatePoolSendBehavior;
- (void) delegatePoolSetSendBehavior: (unsigned char)b;

// FOR PASSING ALL OTHER MESSAGES TO DELEGATES;
// RETURNS 0 IF NO OBJECTS RESPOND;
- forward:(SEL)aSel :(arglist_t)argFrame;

// FOR FINDING OUT IF ANY OBJECTS IN THE POOL RESPONDED TO THE LAST MSG;
/* This method is bad because it won't be thread-safe---it may
   go away in the future. */
- (BOOL) delegatePoolLastMessageHadReceivers;

@end

#endif /* __DelegatePool_h_GNUSTEP_BASE_INCLUDE */
