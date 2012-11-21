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

   AutogsdocSource: NSMetadata.m
*/ 

#import <Foundation/NSMetadata.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import "GNUstepBase/NSObject+GNUstepBase.h"

// Metadata item constants...
NSString * const NSMetadataItemFSNameKey = @"NSMetadataItemFSNameKey";
NSString * const NSMetadataItemDisplayNameKey = @"NSMetadataItemDisplayNameKey";
NSString * const NSMetadataItemURLKey = @"NSMetadataItemURLKey";
NSString * const NSMetadataItemPathKey = @"NSMetadataItemPathKey";
NSString * const NSMetadataItemFSSizeKey = @"NSMetadataItemFSSizeKey";
NSString * const NSMetadataItemFSCreationDateKey = @"NSMetadataItemFSCreationDateKey";
NSString * const NSMetadataItemFSContentChangeDateKey = @"NSMetadataItemFSContentChangeDateKey";

@implementation NSMetadataItem
- (NSArray *)attributes
{
  return [attributes allKeys];
}

- (id)valueForAttribute: (NSString *)key
{
  return [attributes objectForKey: key];
}

- (NSDictionary *)valuesForAttributes: (NSArray *)keys
{
  NSMutableDictionary *results = [NSMutableDictionary dictionary];
  NSEnumerator *en = [keys objectEnumerator];
  id key = nil;

  while((key = [en nextObject]) != nil)
    {
      id value = [self valueForAttribute: key];
      [results setObject: value forKey: key];
    }

  return results;
}

@end

// Metdata Query Constants...
NSString * const NSMetadataQueryUserHomeScope = @"NSMetadataQueryUserHomeScope";
NSString * const NSMetadataQueryLocalComputerScope = @"NSMetadataQueryLocalComputerScope";
NSString * const NSMetadataQueryNetworkScope = @"NSMetadataQueryNetworkScope";
NSString * const NSMetadataQueryUbiquitousDocumentsScope = @"NSMetadataQueryUbiquitousDocumentsScope";
NSString * const NSMetadataQueryUbiquitousDataScope = @"NSMetadataQueryUbiquitousDataScope";

NSString * const NSMetadataQueryDidFinishGatheringNotification = @"NSMetadataQueryDidFinishGatheringNotification";
NSString * const NSMetadataQueryDidStartGatheringNotification = @"NSMetadataQueryDidStartGatheringNotification";
NSString * const NSMetadataQueryDidUpdateNotification = @"NSMetadataQueryDidUpdateNotification";
NSString * const NSMetadataQueryGatheringProgressNotification = @"NSMetadataQueryGatheringProgressNotification";

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
