/* Interface for Objective-C "collection of delegates" object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

   This file is part of the GNU Objective C Class Library.

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

#ifndef __DelegatePool_h_OBJECTS_INCLUDE
#define __DelegatePool_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/Array.h>

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
}

// CREATING AND FREEING;
+ alloc;
+ new;
- init;
- (void) dealloc;

// MANIPULATING COLLECTION OF DELEGATES;
- delegatePoolAddObject: anObject;
- delegatePoolAddObjectIfAbsent: anObject;
- delegatePoolRemoveObject: anObject;
- (BOOL) delegatePoolIncludesObject: anObject;
- delegatePoolCollection;
- (unsigned char) delegatePoolSendBehavior;
- delegatePoolSetSendBehavior: (unsigned char)b;

// FOR PASSING ALL OTHER MESSAGES TO DELEGATES;
- forward:(SEL)aSel :(arglist_t)argFrame;

@end

#endif /* __DelegatePool_h_OBJECTS_INCLUDE */
