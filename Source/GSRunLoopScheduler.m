/** 
   Copyright (C) 2026 Free Software Foundation, Inc.

   By: Richard Frith-Macdonald <richard@brainstorm.co.uk>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/

#import "common.h"

#import "GSRunLoopScheduler.h"
#import "Foundation/NSException.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSString.h"
#import "Foundation/NSZone.h"


@implementation GSRunLoopScheduler: NSObject
- (id) copyWithZone: (NSZone*)z
{
  GSRunLoopScheduler	*r = [GSRunLoopScheduler new];

  [self schedule: r];
  return r;
}

- (void) dealloc
{
  DESTROY(_scheduled);
  DEALLOC
}

- (void) scheduleInRunLoop: (NSRunLoop*)loop forMode: (NSString*)mode
{
  NSMutableArray	*modes = [_scheduled objectForKey: loop];

  if (nil == modes)
    {
      if (nil == _scheduled)
	{
	  ASSIGN(_scheduled, [NSMapTable strongToStrongObjectsMapTable]);
	}
      modes = [NSMutableArray array];
      [_scheduled setObject: modes forKey: loop];
    }
  if (NO == [modes containsObject: mode])
    {
      [modes addObject: mode];
    }
}

- (void) unscheduleFromRunLoop: (NSRunLoop*)loop forMode: (NSString*)mode
{
  NSMutableArray	*modes = [_scheduled objectForKey: loop];

  if (modes)
    {
      [modes removeObject: mode];
      if (0 == [modes count])
	{
	  [_scheduled removeObjectForKey: loop];
	  if (0 == [_scheduled count])
	    {
	      DESTROY(_scheduled);
	    }
	}
    }
}

- (void) remove: (id)receiver
{
  GS_FOR_IN(NSRunLoop*, loop, _scheduled)
    {
      NSArray	*modes = [_scheduled objectForKey: loop];

      GS_FOR_IN(NSString*, mode, modes)
      [receiver removeFromRunLoop: loop forMode: mode];
      GS_END_FOR(modes)
    }
  GS_END_FOR(_scheduled)
}

- (void) schedule: (id)receiver
{
  GS_FOR_IN(NSRunLoop*, loop, _scheduled)
    {
      NSArray	*modes = [_scheduled objectForKey: loop];

      GS_FOR_IN(NSString*, mode, modes)
      [receiver scheduleInRunLoop: loop forMode: mode];
      GS_END_FOR(modes)
    }
  GS_END_FOR(_scheduled)
}

- (void) unschedule: (id)receiver
{
  GS_FOR_IN(NSRunLoop*, loop, _scheduled)
    {
      NSArray	*modes = [_scheduled objectForKey: loop];

      GS_FOR_IN(NSString*, mode, modes)
      [receiver unscheduleFromRunLoop: loop forMode: mode];
      GS_END_FOR(modes)
    }
  GS_END_FOR(_scheduled)
}
@end

