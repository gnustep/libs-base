/**Interface for NSMetadataQuery for GNUStep
   Copyright (C) 2012 Free Software Foundation, Inc.

   Written by: Gregory Casamento
   Date: 2012
   
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

   AutogsdocSource: NSMetadataQuery.h
*/ 

#import <Foundation/NSMetadataQuery.h>
#import <Foundation/NSArray.h>
#import "GNUstepBase/NSObject+GNUstepBase.h"

@implementation NSMetadataQuery

/* Instance methods */
- (id)valueOfAttribute:(id)attr forResultAtIndex:(NSUInteger)index
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSArray *)groupedResults;
{
  [self subclassResponsibility: _cmd];
  return [NSArray array];
}

- (NSArray *)valueLists
{
  [self subclassResponsibility: _cmd];
  return [NSArray array];
}

- (NSUInteger)indexOfResult:(id)result
{
  [self subclassResponsibility: _cmd];
  return NSNotFound;
}

- (NSArray *)results
{
  [self subclassResponsibility: _cmd];
  return [NSArray array];
}

- (id)resultAtIndex:(NSUInteger)index
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSUInteger)resultCount
{
  [self subclassResponsibility: _cmd];
  return 0;
}

// Enable/Disable updates
- (void)enableUpdates
{
  [self subclassResponsibility: _cmd];
}

- (void)disableUpdates
{
  [self subclassResponsibility: _cmd];
}

// Status of the query...
- (BOOL)isStopped
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (BOOL)isGathering
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (BOOL)isStarted
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (void)stopQuery
{
  [self subclassResponsibility: _cmd];
}

- (BOOL)startQuery
{
  [self subclassResponsibility: _cmd];
  return NO;
}

// Search URLS
- (void)setSearchItemURLs:(NSArray *)urls
{
  [self subclassResponsibility: _cmd];
}

- (NSArray *)searchItemURLs
{
  [self subclassResponsibility: _cmd];
  return [NSArray array];
}

// Search scopes 
- (void)setSearchScopes:(NSArray *)scopes
{
  [self subclassResponsibility: _cmd];
}

- (NSArray *)searchScopes
{
  [self subclassResponsibility: _cmd];
  return [NSArray array];
}

// Notification interval
- (void)setNotificationBatchingInterval:(NSTimeInterval)interval
{
  [self subclassResponsibility: _cmd];
}

- (NSTimeInterval)notificationBatchingInterval
{
  [self subclassResponsibility: _cmd];
  return (NSTimeInterval)0;
}

// Grouping Attributes.
- (void)setGroupingAttributes:(NSArray *)attrs
{
  [self subclassResponsibility: _cmd];
}

- (NSArray *)groupingAttributes
{
  [self subclassResponsibility: _cmd];
  return [NSArray array];
}

- (void)setValueListAttributes:(NSArray *)attrs
{
  [self subclassResponsibility: _cmd];
}

- (NSArray *)valueListAttributes
{
  [self subclassResponsibility: _cmd];
  return [NSArray array];
}

// Sort descriptors
- (void)setSortDescriptors:(NSArray *)attrs
{
  [self subclassResponsibility: _cmd];
}

- (NSArray *)sortDescriptors
{
  [self subclassResponsibility: _cmd];
  return [NSArray array];
}

// Predicate
- (void)setPredicate:(NSPredicate *)predicate
{
  [self subclassResponsibility: _cmd];
}

- (NSPredicate *)predicate
{
  [self subclassResponsibility: _cmd];
  return nil;
}

// Delegate
- (void)setDelegate:(id)delegate
{
  [self subclassResponsibility: _cmd];
}

- (id)delegate
{
  [self subclassResponsibility: _cmd];
  return nil;
}

@end
