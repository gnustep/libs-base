/* NSCountedSet - CountedSet object 
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: Sep 1995
   
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

#include <config.h>
#include <base/behavior.h>
#include <base/fast.x>
#include <Foundation/NSSet.h>
#include <Foundation/NSGSet.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSObjCRuntime.h>

@class	NSSetNonCore;
@class	NSMutableSetNonCore;

/*
 *	Class variables for uniquing objects;
 */
static NSRecursiveLock	*uniqueLock = nil;
static NSCountedSet	*uniqueSet = nil;
static IMP		uniqueImp = 0;
static IMP		lockImp = 0;
static IMP		unlockImp = 0;
static BOOL		uniquing = NO;

@interface	NSCountedSet (GSThreading)
+ (void) _becomeThreaded: (id)notification;
@end

@implementation NSCountedSet 

static Class NSCountedSet_abstract_class;
static Class NSCountedSet_concrete_class;

+ (void) initialize
{
  if (self == [NSCountedSet class])
    {
      NSCountedSet_abstract_class = self;
      NSCountedSet_concrete_class = [NSGCountedSet class];
      behavior_class_add_class(self, [NSMutableSetNonCore class]);
      behavior_class_add_class(self, [NSSetNonCore class]);
      if ([NSThread isMultiThreaded])
	{
	  [self _becomeThreaded: nil];
	}
      else
	{
	  [[NSNotificationCenter defaultCenter]
	    addObserver: self
	       selector: @selector(_becomeThreaded:)
		   name: NSWillBecomeMultiThreadedNotification
		 object: nil];
	}
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSCountedSet_abstract_class)
    {
      return NSAllocateObject(NSCountedSet_concrete_class, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

- (unsigned int) countForObject: (id)anObject
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (id) copyWithZone: (NSZone*)z
{
  return [[[self class] allocWithZone: z] initWithSet: self copyItems: YES];
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  return [[[self class] allocWithZone: z] initWithSet: self copyItems: NO];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	count;
  Class		c = GSObjCClassOfObject(self);

  if (c == NSCountedSet_abstract_class)
    {
      RELEASE(self);
      self = [NSCountedSet_concrete_class allocWithZone: NSDefaultMallocZone()];
      return [self initWithCoder: aCoder];
    }
  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &count];
  {
    id		objs[count];
    unsigned	refs[count];
    unsigned	i;
    IMP		addImp = [self methodForSelector: @selector(addObject:)];

    for (i = 0; i < count; i++)
      {
	[aCoder decodeValueOfObjCType: @encode(id) at: &objs[i]];
	[aCoder decodeValueOfObjCType: @encode(unsigned) at: &refs[i]];
      }
    self = [self initWithObjects: objs count: count];
    for (i = 0; i < count; i++)
      {
	unsigned	j = refs[i];

	while (j-- > 1)
	  {
	    (*addImp)(self, @selector(addObject:), objs[i]);
	  }
      }
  }
  return self;
}

- (Class) classForCoder
{
  return NSCountedSet_abstract_class;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  unsigned	count = [self count];
  NSEnumerator	*e = [self objectEnumerator];
  id		o;

  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
  while ((o = [e nextObject]) != nil)
    {
      [aCoder encodeValueOfObjCType: @encode(id) at: &o];
      count = [self countForObject: o];
      [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
    }
}

- (id) initWithSet: (NSSet*)other copyItems: (BOOL)flag
{
  unsigned	c = [other count];
  id		os[c], o, e = [other objectEnumerator];
  unsigned	i = 0;
  NSZone	*z = [self zone];
  IMP		next = [e methodForSelector: @selector(nextObject)];

  while ((o = (*next)(e, @selector(nextObject))) != nil)
    {
      if (flag)
	os[i] = [o copyWithZone: z];
      else
	os[i] = o;
      i++;
    }
  self = [self initWithObjects: os count: c];
  if ([other isKindOfClass: NSCountedSet_abstract_class])
    {
      unsigned	j;
      IMP	addImp = [self methodForSelector: @selector(addObject:)];

      for (j = 0; j < i; j++)
	{
          unsigned	extra = [(NSCountedSet*)other countForObject: os[j]];

	  while (extra-- > 1)
	    (*addImp)(self, @selector(addObject:), os[j]);
	}
    }
#if	!GS_WITH_GC
  if (flag)
    while (i--)
      [os[i] release];
#endif
  return self;
}

- (void) purge: (int)level
{
  if (level > 0)
    {
      NSEnumerator	*enumerator = [self objectEnumerator];

      if (enumerator != nil)
	{
	  id		obj;
	  id		(*nImp)(NSEnumerator*, SEL);
	  unsigned	(*cImp)(NSCountedSet*, SEL, id);
	  void		(*rImp)(NSCountedSet*, SEL, id);

	  nImp = (id (*)(NSEnumerator*, SEL))
	    [enumerator methodForSelector: @selector(nextObject)];
	  cImp = (unsigned (*)(NSCountedSet*, SEL, id))
	    [self methodForSelector: @selector(countForObject:)];
	  rImp = (void (*)(NSCountedSet*, SEL, id))
	    [self methodForSelector: @selector(removeObject:)];
	  while ((obj = (*nImp)(enumerator, @selector(nextObject))) != nil)
	    {
	      unsigned	c = (*cImp)(self, @selector(countForObject:), obj);

	      if (c <= level)
		{
		  while (c-- > 0)
		    {
		      (*rImp)(self, @selector(removeObject:), obj);
		    }
		}
	    }
	}
    }
}

- (id) unique: (id)anObject
{
  id	o = [self member: anObject];

  [self addObject: anObject];
  if (o == nil)
    {
      o = anObject;
    }
#if	!GS_WITH_GC
  if (o != anObject)
    {
      [anObject release];
      [o retain];
    }
#endif
  return o;
}
@end

@implementation	NSCountedSet (GSThreading)
/*
 * If we are multi-threaded, we must guard access to the uniquing set.
 */
+ (void) _becomeThreaded: (id)notification
{
  uniqueLock = [NSLock new];
  lockImp = [uniqueLock methodForSelector: @selector(lock)];
  unlockImp = [uniqueLock methodForSelector: @selector(unlock)];
}
@end


void
GSUPurge(unsigned level)
{
  if (uniqueLock != nil)
    {
      (*lockImp)(uniqueLock, @selector(lock));
    }
  [uniqueSet purge: level];
  if (uniqueLock != nil)
    {
      (*unlockImp)(uniqueLock, @selector(unlock));
    }
}

id
GSUSet(id obj, unsigned level)
{
  id		found;
  unsigned	i;

  if (uniqueLock != nil)
    {
      (*lockImp)(uniqueLock, @selector(lock));
    }
  found = [uniqueSet member: obj];
  if (found == nil)
    {
      found = obj;
      for (i = 0; i < level; i++)
	{
	  [uniqueSet addObject: obj];
	}
    }
  else
    {
      i = [uniqueSet countForObject: found];
      if (i < level)
	{
	  while (i < level)
	    {
	      [uniqueSet addObject: found];
	      i++;
	    }
	}
      else if (i > level)
	{
	  while (i > level)
	    {
	      [uniqueSet removeObject: found];
	      i--;
	    }
	}
    }
  if (uniqueLock != nil)
    {
      (*unlockImp)(uniqueLock, @selector(unlock));
    }
  return found;
}

id
GSUnique(id obj)
{
  if (uniquing == YES)
    {
      if (uniqueLock != nil)
	{
	  (*lockImp)(uniqueLock, @selector(lock));
	}
      obj = (*uniqueImp)(uniqueSet, @selector(unique:), obj);
      if (uniqueLock != nil)
	{
	  (*unlockImp)(uniqueLock, @selector(unlock));
	}
    }
  return obj;
}

void
GSUniquing(BOOL flag)
{
  if (uniqueSet == nil)
    {
      uniqueSet = [NSCountedSet new];
      uniqueImp = [uniqueSet methodForSelector: @selector(unique:)];
    }
  uniquing = flag;
}

