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
static unsigned			disabled = 0;

@implementation	NSGarbageCollector

+ (id) defaultCollector
{
  return collector;
}

- (void) collectIfNeeded
{
  return;
}

- (void) collectExhaustively
{
  return;
}

- (void) disable
{
  return;
}

- (void) disableCollectorForPointer: (void *)ptr
{
  return;
}

- (void) enable
{
  return;
}

- (void) enableCollectorForPointer: (void *)ptr
{
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

