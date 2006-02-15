/** Implementation for NSStream for GNUStep
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Derek Zhou <derekzhou@gmail.com>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2006

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   */

#include <Foundation/NSData.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>
#include <Foundation/NSError.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSHost.h>

#include "../GSStream.h"

@implementation NSStream

+ (void) getStreamsToHost: (NSHost *)host 
                     port: (int)port 
              inputStream: (NSInputStream **)inputStream 
             outputStream: (NSOutputStream **)outputStream
{
  [self notImplemented:_cmd];
}

- (void) close
{
  [self subclassResponsibility: _cmd];
}

- (void) open
{
  [self subclassResponsibility: _cmd];
}

- (void) setDelegate: (id)delegate
{
  [self subclassResponsibility: _cmd];
}

- (id) delegate
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) setProperty: (id)property forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) propertyForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  [self subclassResponsibility: _cmd];
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode;
{
  [self subclassResponsibility: _cmd];
}

- (NSError *) streamError
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSStreamStatus) streamStatus
{
  [self subclassResponsibility: _cmd];
  return 0;
}

@end

@implementation NSInputStream

+ (id) inputStreamWithData: (NSData *)data
{
  [self notImplemented:_cmd];
  return nil;
}

+ (id) inputStreamWithFileAtPath: (NSString *)path
{
  [self notImplemented:_cmd];
  return nil;
}

- (id) initWithData: (NSData *)data
{
  [self notImplemented:_cmd];
  return nil;
}

- (id) initWithFileAtPath: (NSString *)path
{
  [self notImplemented:_cmd];
  return nil;
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  [self subclassResponsibility: _cmd];
  return -1;
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (BOOL) hasBytesAvailable
{
  [self subclassResponsibility: _cmd];
  return NO;
}

@end

@implementation NSOutputStream

+ (id) outputStreamToMemory
{
  [self notImplemented:_cmd];
  return nil;
}

+ (id) outputStreamToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity
{
  [self notImplemented:_cmd];
  return nil;
}

+ (id) outputStreamToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  [self notImplemented:_cmd];
  return nil;
}

- (id) initToMemory
{
  [self notImplemented:_cmd];
  return nil;
}

- (id) initToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity
{
  [self notImplemented:_cmd];
  return nil;
}

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  [self notImplemented:_cmd];
  return nil;
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  [self subclassResponsibility: _cmd];
  return -1;  
}

- (BOOL) hasSpaceAvailable
{
  [self subclassResponsibility: _cmd];
  return NO;
}

@end

