/* Implementation of garbage collecting classe framework

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Inspired by gc classes of  Ovidiu Predescu and Mircea Oancea

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

   AutogsdocSource: Additions/GCObject.m
   AutogsdocSource: Additions/GCArray.m
   AutogsdocSource: Additions/GCDictionary.m

*/

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>

#include <gnustep/base/GCObject.h>

/*
 * The head of a linked list of all garbage collecting objects  is a
 * special object which is never deallocated.
 */
@interface _GCObjectList : GCObject
@end
@implementation _GCObjectList
- (void) dealloc
{
}
@end


/**
 * The GCObject class is both the base class for all garbage collected
 * objects, and an infrastructure for handling garbage collection.<br />
 * It maintains a list of all garbage collectable objects and provides
 * a method to run a garbage collection pass on those objects.
 */
@implementation GCObject

static GCObject	*allObjects = nil;
static BOOL	isCollecting = NO;

+ (id) allocWithZone: (NSZone*)zone
{
  GCObject	*o = [super allocWithZone: zone];

  o->gc.next = allObjects;
  o->gc.previous = allObjects->gc.previous;
  allObjects->gc.previous->gc.next = o;
  allObjects->gc.previous = o;
  o->gc.flags.refCount = 1;

  return o;
}

/**
 * <p>This method runs a garbage collection, causing unreferenced objects to
 * be deallocated.  This is done using a simple three pass algorithm -
 * </p>
 * <deflist>
 *   <term>Pass 1</term>
 *   <desc>
 *     All the garbage collectable objects are sent a
 *     -gcDecrementRefCountOfContainedObjects message.
 *   </desc>
 *   <term>Pass 2</term>
 *   <desc>
 *      All objects having a refCount greater than 0 are sent an
 *     -gcIncrementRefCountOfContainedObjects message.
 *   </desc>
 *   <term>Pass 3</term>
 *   <desc>
 *      All the objects that still have the refCount of 0
 * 	are part of cyclic graphs and none of the objects from this graph
 * 	are held by some object outside graph. These objects receive the
 * 	-dealloc message. In this method they should send the -dealloc message
 * 	to any garbage collectable (GCObject and subclass) instances they
 *      contain.
 *   </desc>
 * </deflist>
 * <p>During garbage collection, the +gcIsCollecting method returns YES.
 * </p>
 */
+ (void) gcCollectGarbage
{
  GCObject	*object;
  GCObject	*last;

  if (isCollecting == YES)
    {
      return;	// Don't allow recursion.
    }
  isCollecting = YES;

  // Pass 1
  object = allObjects->gc.next;
  while (object != allObjects)
    {
      [object gcDecrementRefCountOfContainedObjects];
      // object->gc.flags.visited = 0;
      // object = object->gc.next;
      [object gcSetVisited: NO];
      object = [object gcNextObject];
    }

  // Pass 2
  object = allObjects->gc.next;
  while (object != allObjects)
    {
      if ([object retainCount] > 0)
	{
	  [object gcIncrementRefCountOfContainedObjects];
	}
      // object = object->gc.next;
      object = [object gcNextObject];
    }

  last = allObjects;
  object = last->gc.next;
  while (object != allObjects)
    {
      if ([object retainCount] == 0)
	{
	  GCObject	*next;

	  // next = object->gc.next;
	  // next->gc.previous = last;
	  // last->gc.next = next;
	  // object->gc.next = object;
	  // object->gc.previous = object;
	  next = [object gcNextObject];
	  [next gcSetPreviousObject: last];
	  [last gcSetNextObject: next];
	  [object gcSetNextObject: object];
	  [object gcSetPreviousObject: object];
	  [object dealloc];
	  object = next;
	}
      else
	{
	  last = object;
	  // object = object->gc.next;
	  object = [object gcNextObject];
	}
    }
  isCollecting = NO;
}

+ (void) initialize
{
  if (self == [GCObject class])
    {
      allObjects = (_GCObjectList*)
	NSAllocateObject([_GCObjectList class], 0, NSDefaultMallocZone());
      allObjects->gc.next = allObjects;
      allObjects->gc.previous = allObjects;
    }
}

/**
 * Returns a flag to indicate whether a garbage collection is in progress.
 */
+ (BOOL) gcIsCollecting
{
  return isCollecting;
}

/**
 * Called to remove anObject from the list of garbage collectable objects.
 * Subclasses should call this is their -dealloc methods.
 */
+ (void) gcObjectWillBeDeallocated: (GCObject*)anObject
{
  GCObject	*p;
  GCObject	*n;

  // p = anObject->gc.previous;
  // n = anObject->gc.next;
  // p->gc.next = n;
  // n->gc.previous = p;
  p = [anObject gcPreviousObject];
  n = [anObject gcNextObject];
  [p gcSetNextObject: n];
  [n gcSetPreviousObject: p];
}

- (id) copyWithZone: (NSZone*)zone
{
  GCObject	*o = (GCObject*)NSCopyObject(self, 0, zone);

  o->gc.next = allObjects;
  o->gc.previous = allObjects->gc.previous;
  allObjects->gc.previous->gc.next = o;
  allObjects->gc.previous = o;
  o->gc.flags.refCount = 1;
  return o;
}

/* 
 * Decrements the garbage collection reference count for the receiver.<br />
 */
- (void) gcDecrementRefCount
{
  gc.flags.refCount--;
}

/* 
 * <p>Marks the receiver as not having been visited in the current garbage
 * collection process (first pass of collection).
 * </p>
 * <p>All container subclasses should override this method to call the super
 * implementation then decrement the ref counts of their contents as well as
 * sending the -gcDecrementRefCountOfContainedObjects
 * message to each of them.
 * </p>
 */
- (void) gcDecrementRefCountOfContainedObjects
{
  gc.flags.visited = 0;
}

/* 
 * Increments the garbage collection reference count for the receiver.<br />
 */
- (void) gcIncrementRefCount
{
  gc.flags.refCount++;
}

/*
 * <p>Checks to see if the receiver has already been visited in the
 * current garbage collection process, and either marks the receiver as
 * visited (and returns YES) or returns NO to indicate that it had already
 * been visited.
 * </p>
 * <p>All container subclasses should override this method to call the super
 * implementation then, if the method returns YES, increment the reference
 * count of any contained objects and send the 
 * -gcIncrementRefCountOfContainedObjects
 * to each of the contained objects too.
 * </p>
 */
- (BOOL) gcIncrementRefCountOfContainedObjects
{
  if (gc.flags.visited == 1)
    {
      return NO;
    }
  gc.flags.visited = 1;
  return YES;
}

- (oneway void) release
{
  if (gc.flags.refCount > 0 && gc.flags.refCount-- == 1)
    {
      [GCObject gcObjectWillBeDeallocated: self];
      [self dealloc];
    }
}

- (id) retain
{
  gc.flags.refCount++;
  return self;
}

- (unsigned int) retainCount
{
  return gc.flags.refCount;
}

@end

@implementation GCObject (Extra)

- (BOOL) gcAlreadyVisited
{
  if (gc.flags.visited == 1)
    {
      return YES;
    }
  else
    {
      return NO;
    }
}

- (GCObject*) gcNextObject
{
  return gc.next;
}

- (GCObject*) gcPreviousObject
{
  return gc.previous;
}

- (GCObject*) gcSetNextObject: (GCObject*)anObject
{
  gc.next = anObject;
  return self;
}

- (GCObject*) gcSetPreviousObject: (GCObject*)anObject
{
  gc.previous = anObject;
  return self;
}

- (void) gcSetVisited: (BOOL)flag
{
  if (flag == YES)
    {
      gc.flags.visited = 1;
    }
  else
    {
      gc.flags.visited = 0;
    }
}

@end

