/* Definition of class NSProgress
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   Written by: 	Gregory Casamento <greg.casamento@gmail.com>
   Date: 	July 2019
   
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

#define	GS_NSProgress_IVARS	 \
  NSProgressKind _kind;  \
  NSProgressFileOperationKind _fileOperationKind; \
  NSURL *_fileUrl; \
  BOOL _isFinished; \
  BOOL _old; \
  NSNumber *_estimatedTimeRemaining; \
  NSNumber *_fileCompletedCount; \
  NSNumber *_fileTotalCount; \
  NSNumber *_throughput; \
  int64_t _totalUnitCount; \
  int64_t _completedUnitCount; \
  NSMutableDictionary *_userInfo; \
  BOOL _cancelled; \
  BOOL _paused; \
  BOOL _cancellable; \
  BOOL _pausable; \
  BOOL _indeterminate; \
  BOOL _finished; \
  double _fractionCompleted; \
  NSProgress *_parent;

#define	EXPOSE_NSProgress_IVARS

#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import	<Foundation/NSProgress.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSString.h>

#define	GSInternal NSProgressInternal
#include "GSInternal.h"
GS_PRIVATE_INTERNAL(NSProgress)

@implementation NSProgress

// Creating progress objects...
- (instancetype)initWithParent: (NSProgress *)parent 
                      userInfo: (NSDictionary *)userInfo
{
  return nil;
}

+ (NSProgress *)discreteProgressWithTotalUnitCount:(int64_t)unitCount
{
  return nil;
}

+ (NSProgress *)progressWithTotalUnitCount:(int64_t)unitCount
{
  return nil;
}

+ (NSProgress *)progressWithTotalUnitCount:(int64_t)unitCount 
                                    parent:(NSProgress *)parent 
                          pendingUnitCount:(int64_t)portionOfParentTotalUnitCount
{
  return nil;
}


// Current progress
+ (NSProgress *)currentProgress
{
  return nil;
}

- (void)becomeCurrentWithPendingUnitCount:(int64_t)unitCount
{
}

- (void)addChild:(NSProgress *)child withPendingUnitCount: (int64_t)inUnitCount
{
}

- (void)resignCurrent
{
}

// Reporting progress
- (int64_t) totalUnitCount
{
  return internal->_totalUnitCount;
}

- (void) setTotalUnitCount: (int64_t)count
{
  internal->_totalUnitCount = count;
}

- (int64_t) completedUnitCount
{
  return internal->_completedUnitCount;
}

- (void) setCompletedUnitCount: (int64_t)count
{
  internal->_completedUnitCount = count;
}

- (NSString *) localizedDescription
{
  return nil;
}

- (NSString *) localizedAddtionalDescription
{
  return nil;
}

// Observing progress
- (double) fractionCompleted
{
  return internal->_fractionCompleted;
}

// Controlling progress
- (BOOL) isCancellable
{
  return internal->_cancellable;
}

- (BOOL) isCancelled
{
  return internal->_cancelled;
}

- (void) cancel
{
}

- (void) setCancellationHandler: (GSProgressCancellationHandler) handler
{
}

- (BOOL) isPausable
{
  return internal->_pausable;
}

- (BOOL) isPaused
{
  return internal->_paused;
}

- (void) pause
{
}

- (void) setPausingHandler: (GSProgressPausingHandler) handler
{
}

- (void) resume
{
}

- (void) setResumingHandler: (GSProgressResumingHandler) handler
{
}

// Progress Information
- (BOOL) isIndeterminate
{
  return internal->_indeterminate;
}

- (void) setIndeterminate: (BOOL)flag
{
  internal->_indeterminate = flag;
}

- (NSProgressKind) kind
{
  return internal->_kind;
}

- (void) setKind: (NSProgressKind)k
{
}

- (void)setUserInfoObject: (id)obj
                   forKey: (NSProgressUserInfoKey)key
{
                
}


// Instance property accessors...
- (void) setFileOperationKind: (NSProgressFileOperationKind)k;
{
  ASSIGN(internal->_fileOperationKind, k);
}

- (NSProgressFileOperationKind) fileOperationKind
{
  return internal->_fileOperationKind;
}

- (void) setFileUrl: (NSURL *)u
{
  ASSIGN(internal->_fileUrl, u);
}

- (NSURL *)fileUrl
{
  return internal->_fileUrl;
}

- (BOOL) isFinished
{
  return internal->_finished;
}

- (BOOL) isOld
{
  return internal->_old;
}

- (void) setEstimatedTimeRemaining: (NSNumber *)n
{
  ASSIGN(internal->_estimatedTimeRemaining, n);
}

- (NSNumber *) estimatedTimeRemaining
{
  return internal->_estimatedTimeRemaining;
}

- (void) setFileCompletedCount: (NSNumber *)n
{
}

- (NSNumber *) fileCompletedCount
{
  return nil;
}

- (void) setFileTotalCount: (NSNumber *)n
{
}

- (NSNumber *) fileTotalCount
{
  return nil;
}

- (void) setThroughput: (NSNumber *)n
{
}

- (NSNumber *) throughtput
{
  return nil;
}

// Instance methods
- (void) publish
{
}

- (void) unpublish
{
}

- (void)performAsCurrentWithPendingUnitCount: (int64_t)unitCount 
                                  usingBlock: (GSProgressPendingUnitCountBlock)work
{
}

// Type methods
+ (id)addSubscriberForFileURL: (NSURL *)url 
        withPublishingHandler: (NSProgressPublishingHandler)publishingHandler
{
  return nil;
}

+ (void)removeSubscriber: (id)subscriber
{
}
  
@end


