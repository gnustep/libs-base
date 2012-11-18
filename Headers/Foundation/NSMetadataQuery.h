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

#ifndef __NSMetadataQuery_h_GNUSTEP_BASE_INCLUDE
#define __NSMetadataQuery_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>
#import <Foundation/NSTimer.h>

@class NSPredicate;

@interface NSMetadataQuery : NSObject

/* Instance methods */
- (id)valueOfAttribute:(id)attr forResultAtIndex:(NSUInteger)index;
- (NSArray *)groupedResults;
- (NSArray *)valueLists;
- (NSUInteger)indexOfResult:(id)result;
- (NSArray *)results;
- (id)resultAtIndex:(NSUInteger)index;
- (NSUInteger)resultCount;

// Enable/Disable updates
- (void)enableUpdates;
- (void)disableUpdates;

// Status of the query...
- (BOOL)isStopped;
- (BOOL)isGathering;
- (BOOL)isStarted;
- (void)stopQuery;
- (BOOL)startQuery;

// Search URLS
- (void)setSearchItemURLs:(NSArray *)urls;
- (NSArray *)searchItemURLs;

// Search scopes 
- (void)setSearchScopes:(NSArray *)scopes;
- (NSArray *)searchScopes;

// Notification interval
- (void)setNotificationBatchingInterval:(NSTimeInterval)interval;
- (NSTimeInterval)notificationBatchingInterval;

// Grouping Attributes.
- (void)setGroupingAttributes:(NSArray *)attrs;
- (NSArray *)groupingAttributes;
- (void)setValueListAttributes:(NSArray *)attrs;
- (NSArray *)valueListAttributes;

// Sort descriptors
- (void)setSortDescriptors:(NSArray *)attrs;
- (id)sortDescriptors;

// Predicate
- (void)setPredicate:(NSPredicate *)predicate;
- (NSPredicate *)predicate;

// Delegate
- (void)setDelegate:(id)delegate;
- (id)delegate;

@end

#endif
