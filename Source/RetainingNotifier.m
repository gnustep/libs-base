/* Implementation of reference-counted invalidation notifer object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
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

/* Reference Counted object with invalidation notification 
   This object is just temporary.  Eventually, we should separate 
   reference counting functionality from notification functionality */

#include <gnustep/base/RetainingNotifier.h>
#include <gnustep/base/InvalidationListening.h>
#include <assert.h>

/* Use this for now, but GNU should switch to a GC pool
   and separate notification. */

/* I really need to check the use of locks here */

@implementation RetainingNotifier

- init
{
  retain_count = 0;
  isValid = YES;
  refGate = [[Lock alloc] init];
  notificationList = [[List alloc] init];
  return self;
}

- (void) dealloc
{
  [refGate release];
  [notificationList free];
  [super dealloc];
}

- (oneway void) release
{
  [refGate lock];
  if (retain_count--)
    {
      [refGate unlock];
      return;
    }
  [refGate unlock];
  [self dealloc];
  return;
}

- (id) retain
{
  [refGate lock];
  retain_count++;
  [refGate unlock];
  return self;
}

- (unsigned) retainCount
{
  return retain_count;
}

/* xxx Deal with this. */
- autorelease
{
  return [super autorelease];
}

- registerForInvalidationNotification:  (id <InvalidationListening>)anObject
{
  assert(refGate);
  [refGate lock];
  [notificationList addObjectIfAbsent: anObject];
  [refGate unlock];
  return self;
}
  
- unregisterForInvalidationNotification: (id <InvalidationListening>)anObject
{
  assert(refGate);
  [refGate lock];
  [notificationList removeObject: anObject];
  [refGate unlock];
  return self;
}

- (BOOL) isValid
{
  return isValid;
}

/* change name to -postInvalidation */
- invalidate
{
  if (isValid == NO)
    return nil;
  [refGate lock];
  isValid = NO;
  [notificationList makeObjectsPerform:@selector(senderIsInvalid:) with:self];
  [refGate unlock];
  return self;
}


- copy
{
  RetainingNotifier *newCopy = nil;

  if (isValid)
    {
      [refGate lock];
      newCopy = [[[self class] alloc] init];
      [newCopy->notificationList appendList:notificationList];
      newCopy->retain_count = retain_count;
      [refGate unlock];
    }
  return newCopy;
}

@end
