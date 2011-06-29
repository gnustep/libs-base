/** Implementation for NSGarbageCollector for GNUStep
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

   */

#import "common.h"
#import	"Foundation/NSGarbageCollector.h"

static NSGarbageCollector	*collector = nil;

#if __OBJC_GC__
#include <objc/objc-auto.h>

id CFRetain(id obj)
{
  if (collector)
    {
      return objc_gc_retain(obj);
    }
  return [obj retain];
}

void CFRelease(id obj)
{
  if (collector)
    {
      objc_gc_release(obj);
    }
  else
    {
      [obj release];
    }
}

@implementation	NSGarbageCollector

+ (id) defaultCollector
{
  return collector;
}

+ (void) initialize
{
  if (objc_collecting_enabled())
    {
      collector = [self alloc];
      objc_startCollectorThread();
    }
}

- (void) collectIfNeeded
{
  objc_collect(OBJC_COLLECT_IF_NEEDED | OBJC_FULL_COLLECTION);
}

- (void) collectExhaustively
{
  objc_collect(OBJC_EXHAUSTIVE_COLLECTION);
}

- (void) disable
{
  objc_gc_disable();
}

- (void) disableCollectorForPointer: (void *)ptr
{
  CFRetain(ptr);
}

- (void) enable
{
  objc_gc_enable();
}

- (void) enableCollectorForPointer: (void *)ptr
{
  CFRelease(ptr);
}

- (id) init
{
  if (self != collector)
    {
      [self release];
      self = collector;
    }
  return self;
}

- (BOOL) isCollecting
{
  return NO;
}

- (BOOL) isEnabled
{
	return objc_collectingEnabled();
}

- (NSZone*) zone
{
  return NSDefaultMallocZone();
}
@end

#else

static unsigned			disabled = 0;
#if	GS_WITH_GC

#include <gc/gc.h>

#import	"Foundation/NSLock.h"
#import	"Foundation/NSHashTable.h"
static NSLock		*lock = nil;
static NSHashTable	*uncollectable = 0;
#endif

@implementation	NSGarbageCollector

+ (id) defaultCollector
{
  return collector;
}

#if	GS_WITH_GC
+ (void) initialize
{
  collector = [self alloc];
  lock = [NSLock new];
}
#endif

- (void) collectIfNeeded
{
#if	GS_WITH_GC
  GC_collect_a_little();
#endif
  return;
}

- (void) collectExhaustively
{
#if	GS_WITH_GC
  GC_gcollect();
#endif
  return;
}

- (void) disable
{
#if	GS_WITH_GC
  [lock lock];
  GC_disable();
  disabled++;
  [lock unlock];
#endif
  return;
}

- (void) disableCollectorForPointer: (void *)ptr
{
#if	GS_WITH_GC
  [lock lock];
  if (uncollectable == 0)
    {
      uncollectable = NSCreateHashTable(NSOwnedPointerHashCallBacks, 0);
    }
  NSHashInsertIfAbsent(uncollectable, ptr);
  [lock unlock];
#endif
  return;
}

- (void) enable
{
#if	GS_WITH_GC
  [lock lock];
  if (disabled)
    {
      GC_enable();
      disabled--;
    }
  [lock unlock];
#endif
  return;
}

- (void) enableCollectorForPointer: (void *)ptr
{
#if	GS_WITH_GC
  [lock lock];
  if (uncollectable != 0)
    {
      NSHashRemove(uncollectable, ptr);
    }
  [lock unlock];
#endif
  return;
}

- (id) init
{
  if (self != collector)
    {
      [self dealloc];
      self = nil;
    }
  return self;
}

- (BOOL) isCollecting
{
  return NO;
}

- (BOOL) isEnabled
{
  if (disabled)
    {
      return NO;
    }
  return YES;
}

- (NSZone*) zone
{
  return NSDefaultMallocZone();
}
@end

#endif // __OBJC_GC__
