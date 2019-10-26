/* Implementation of class NSBackgroundActivityScheduler
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Fri Oct 25 00:52:54 EDT 2019

   This file is part of the GNUstep Library.
   
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

#include <Foundation/NSBackgroundActivityScheduler.h>

@implementation NSBackgroundActivityScheduler

- (instancetype) initWithIdentifier: (NSString *)identifier
{
  self = [super init];
  if(self != nil)
    {
      _identifier = identifier;
      _qualityOfService = NSQualityOfServiceDefault;
      _repeats = NO;
      _interval = 0;
      _tolerance = 0;
      _shouldDefer = NO;
    }
  return self;
}

- (NSString *) identifier
{
  return _identifier;
}

- (void) setIdentifier: (NSString *)identifier
{
  ASSIGNCOPY(_identifier, identifier);
}

- (NSQualityOfService) qualityOfService
{
  return _qualityOfService;
}

- (void) setQualityOfService: (NSQualityOfService)qualityOfService
{
  _qualityOfService = qualityOfService;
}

- (BOOL) repeats
{
  return _repeats;
}

- (void) setRepeats: (BOOL)flag
{
  _repeats = flag;
}

- (NSTimeInterval) interval
{
  return _interval;
}

- (void) setInterval: (NSTimeInterval)interval
{
  _interval = interval;
}

- (NSTimeInterval) tolerance
{
  return _tolerance;
}

- (void) setTolerance: (NSTimeInterval)tolerance
{
  _tolerance = tolerance;
}

- (BOOL) shouldDefer
{
  return _shouldDefer;
}

- (void) setShouldDefer: (BOOL)flag
{
  _shouldDefer = flag;
}

- (void) scheduleWithBlock: (GSScheduledBlock)block
{
}

- (void) invalidate
{
}

@end

