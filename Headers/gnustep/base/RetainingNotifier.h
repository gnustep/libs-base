/* Interface for reference-counted invalidation notifer object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: July 1994
   
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

/* Reference Counted object with invalidation notification 
   This object is just temporary.  Eventually, we should separate 
   reference counting functionality from notification functionality */

/* xxx March 1995:  Now that we have a root object that handles retaining, 
   we should create a plain Notifier class. */

#ifndef __RetainingNotifier_h
#define __RetainingNotifier_h

#include <gnustep/base/preface.h>
#include <gnustep/base/Lock.h>
#include <gnustep/base/InvalidationListening.h>
#include <gnustep/base/Retaining.h>

@interface RetainingNotifier : NSObject <Retaining>
{
  Lock *refGate;
  id *notificationList;
  BOOL isValid;
  int retain_count;
}

- init;
- (unsigned) retainCount;
- registerForInvalidationNotification:  (id <InvalidationListening>)anObject;
- unregisterForInvalidationNotification: (id <InvalidationListening>)anObject;
- (BOOL) isValid;
- invalidate;
- copy;

@end

#endif /* __RetainingNotifier_h */
