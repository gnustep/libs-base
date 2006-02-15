/** Implementation for GSStream for GNUStep
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
#include <unistd.h>
#include <errno.h>

#include <Foundation/NSData.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>
#include <Foundation/NSError.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSHost.h>

#include "GSStream.h"

NSString * const NSStreamDataWrittenToMemoryStreamKey
  = @"NSStreamDataWrittenToMemoryStreamKey";
NSString * const NSStreamFileCurrentOffsetKey
  = @"NSStreamFileCurrentOffsetKey";

NSString * const NSStreamSocketSecurityLevelKey
  = @"NSStreamSocketSecurityLevelKey";
NSString * const NSStreamSocketSecurityLevelNone
  = @"NSStreamSocketSecurityLevelNone";
NSString * const NSStreamSocketSecurityLevelSSLv2
  = @"NSStreamSocketSecurityLevelSSLv2";
NSString * const NSStreamSocketSecurityLevelSSLv3
  = @"NSStreamSocketSecurityLevelSSLv3";
NSString * const NSStreamSocketSecurityLevelTLSv1
  = @"NSStreamSocketSecurityLevelTLSv1";
NSString * const NSStreamSocketSecurityLevelNegotiatedSSL
  = @"NSStreamSocketSecurityLevelNegotiatedSSL";
NSString * const NSStreamSocketSSLErrorDomain
  = @"NSStreamSocketSSLErrorDomain";
NSString * const NSStreamSOCKSErrorDomain
  = @"NSStreamSOCKSErrorDomain";
NSString * const NSStreamSOCKSProxyConfigurationKey
  = @"NSStreamSOCKSProxyConfigurationKey";
NSString * const NSStreamSOCKSProxyHostKey
  = @"NSStreamSOCKSProxyHostKey";
NSString * const NSStreamSOCKSProxyPasswordKey
  = @"NSStreamSOCKSProxyPasswordKey";
NSString * const NSStreamSOCKSProxyPortKey
  = @"NSStreamSOCKSProxyPortKey";
NSString * const NSStreamSOCKSProxyUserKey
  = @"NSStreamSOCKSProxyUserKey";
NSString * const NSStreamSOCKSProxyVersion4
  = @"NSStreamSOCKSProxyVersion4";
NSString * const NSStreamSOCKSProxyVersion5
  = @"NSStreamSOCKSProxyVersion5";
NSString * const NSStreamSOCKSProxyVersionKey
  = @"NSStreamSOCKSProxyVersionKey";


@implementation GSStream

- (void) close
{
  NSAssert(_currentStatus != NSStreamStatusNotOpen
    && _currentStatus != NSStreamStatusClosed, 
    @"Attempt to close a stream not yet opened.");
  [self _setStatus: NSStreamStatusClosed];
}

- (void) dealloc
{
  DESTROY(_runloop);
  DESTROY(_modes);
  DESTROY(_properties);
  DESTROY(_lastError);
  [super dealloc];
}

- (id) delegate
{
  return _delegate;
}

- (void) open
{
  NSAssert(_currentStatus == NSStreamStatusNotOpen
    || _currentStatus == NSStreamStatusOpening, 
    @"Attempt to open a stream already opened.");  
  [self _setStatus: NSStreamStatusOpen];
}

- (void) setDelegate: (id)delegate
{
  if (delegate)
    {
      _delegate = delegate;
    }
  else
    {
      _delegate = self;
    }
  _delegateValid
    = [_delegate respondsToSelector: @selector(stream:handleEvent:)];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _delegate = self;
      _properties = nil;
      _lastError = nil;
      _modes = [NSMutableArray new];
      _currentStatus = NSStreamStatusNotOpen;
    }
  return self;
}

- (BOOL) setProperty: (id)property forKey: (NSString *)key
{
  if (_properties == nil)
    {
      _properties = [NSMutableDictionary new];
    }
  [_properties setObject: property forKey: key];
  return YES;
}

- (id) propertyForKey: (NSString *)key
{
  return [_properties objectForKey: key];
}

- (NSError *) streamError
{
  if (_currentStatus == NSStreamStatusError)
    {
      return _lastError;
    }
  return nil;
}

- (NSStreamStatus) streamStatus
{
  return _currentStatus;
}

@end


@implementation	GSStream (Private)

- (BOOL) _isOpened
{
  return !(_currentStatus == NSStreamStatusNotOpen
    || _currentStatus == NSStreamStatusOpening
    || _currentStatus == NSStreamStatusClosed);
}

- (void) _recordError
{
  // make an error
  NSError *theError = [NSError errorWithDomain: NSPOSIXErrorDomain
					  code: errno
				      userInfo: nil];
  perror("");
  ASSIGN(_lastError, theError);
  _currentStatus = NSStreamStatusError;
}

- (void) _sendEvent: (NSStreamEvent)event
{
  if (_delegateValid)
    {
      [(id <GSStreamListener>)_delegate stream: self handleEvent: event];
    }
}

- (void) _setStatus: (NSStreamStatus)newStatus
{
  // last error before closing is preserved
  if (_currentStatus != NSStreamStatusError
    || newStatus != NSStreamStatusClosed)
    {
      _currentStatus = newStatus;
    }
}

@end

@implementation	GSInputStream
+ (void) initialize
{
  if (self == [GSInputStream class])
    {
      GSObjCAddClassBehavior(self, [GSStream class]);
    }
}
@end

@implementation	GSOutputStream
+ (void) initialize
{
  if (self == [GSOutputStream class])
    {
      GSObjCAddClassBehavior(self, [GSStream class]);
    }
}
@end


@implementation GSMemoryInputStream

/**
 * the designated initializer
 */ 
- (id) initWithData: (NSData *)data
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_data, data);
      _pointer = 0;
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    [self close];
  RELEASE(_data);
  [super dealloc];
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  unsigned long dataSize = [_data length];
  unsigned long copySize;

  NSAssert(dataSize >= _pointer, @"Buffer overflow!");
  if (len + _pointer > dataSize)
    {
      copySize = dataSize - _pointer;
    }
  else
    {
      copySize = len;
    }
  if (copySize) 
    {
      memcpy(buffer, [_data bytes] + _pointer, copySize);
      _pointer = _pointer + copySize;
    }
  else
    {
      [self _setStatus: NSStreamStatusAtEnd];
    }
  return copySize;
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len
{
  unsigned long dataSize = [_data length];

  NSAssert(dataSize >= _pointer, @"Buffer overflow!");
  *buffer = (uint8_t*)[_data bytes] + _pointer;
  *len = dataSize - _pointer;
  return YES;
}

- (BOOL) hasBytesAvailable
{
  unsigned long dataSize = [_data length];

  return (dataSize > _pointer);
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(!_runloop || _runloop == aRunLoop, 
           @"Attempt to schedule in more than one runloop.");
  ASSIGN(_runloop, aRunLoop);
  if (![_modes containsObject: mode])
    [_modes addObject: mode];
  if ([self _isOpened])
    [_runloop performSelector:@selector(dispatch:) target: self
              argument: nil order: 0 modes: _modes];
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(_runloop == aRunLoop, 
           @"Attempt to remove unscheduled runloop");
  if ([_modes containsObject: mode])
    {
      [_modes removeObject: mode];
      if ([self _isOpened])
        [_runloop cancelPerformSelector:@selector(dispatch:) 
                  target: self argument: nil];
      if ([_modes count] == 0)
        DESTROY(_runloop);
    }
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    return [NSNumber numberWithLong: _pointer];
  return [super propertyForKey: key];
}

- (void) open
{
  [super open];
  if (_runloop)
    [_runloop performSelector: @selector(dispatch:)
		       target: self
		     argument: nil
			order: 0
			modes: _modes];
}

- (void) close
{
  if (_runloop)
    [_runloop cancelPerformSelectorsWithTarget: self];
  [super close];
}

- (void) dispatch
{
  BOOL av = [self hasBytesAvailable];
  NSStreamEvent myEvent = av ? NSStreamEventHasBytesAvailable : 
    NSStreamEventEndEncountered;
  NSStreamStatus myStatus = av ? NSStreamStatusReading :
    NSStreamStatusAtEnd;
  
  [self _setStatus: myStatus];
  [self _sendEvent: myEvent];
 // dispatch again iff still opened, and last event is not eos
  if (av && [self _isOpened])
    {
      [_runloop performSelector: @selector(dispatch:)
			 target: self
		       argument: nil
			  order: 0
			  modes: _modes];
    }
}

@end


@implementation GSMemoryOutputStream

- (id) initToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity
{
  if ((self = [super init]) != nil)
    {
      if (!buffer)
	{
	  _data = [NSMutableData new];
	  _fixedSize = NO;
	}
      else
	{
	  _data = [[NSMutableData alloc] initWithBytesNoCopy: buffer 
					 length: capacity freeWhenDone: NO];
	  _fixedSize = YES;
	}
      _pointer = 0;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_data);
  [super dealloc];
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  if (_fixedSize)
    {
      unsigned long dataLen = [_data length];
      uint8_t *origin = (uint8_t *)[_data mutableBytes];

      if (_pointer+len>dataLen)
        len = dataLen - _pointer;
      memcpy(origin+_pointer, buffer, len);
      _pointer = _pointer + len;
    }
  else
    [_data appendBytes: buffer length: len];
  return len;
}

- (BOOL) hasSpaceAvailable
{
  if (_fixedSize)
    return  [_data length]>_pointer;
  else
    return YES;
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(!_runloop || _runloop == aRunLoop, 
    @"Attempt to schedule in more than one runloop.");
  ASSIGN(_runloop, aRunLoop);
  if (![_modes containsObject: mode])
    [_modes addObject: mode];
  if ([self _isOpened])
    [_runloop performSelector: @selector(dispatch:)
		       target: self
		     argument: nil
			order: 0
			modes: _modes];
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(_runloop == aRunLoop, 
    @"Attempt to remove unscheduled runloop");
  if ([_modes containsObject: mode])
    {
      [_modes removeObject: mode];
      if ([self _isOpened])
        [_runloop cancelPerformSelector: @selector(dispatch:) 
				 target: self
			       argument: nil];
      if ([_modes count] == 0)
        DESTROY(_runloop);
    }
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      if (_fixedSize)
        return [NSNumber numberWithLong: _pointer];
      else
        return [NSNumber numberWithLong:[_data length]];
    }
  else if ([key isEqualToString: NSStreamDataWrittenToMemoryStreamKey])
    return _data;
  return [super propertyForKey: key];
}

- (void) open
{
  [super open];
  if (_runloop)
    {
      [_runloop performSelector: @selector(dispatch:)
			 target: self
		       argument: nil
			  order: 0
			  modes: _modes];
    }
}

- (void) close
{
  if (_runloop)
    [_runloop cancelPerformSelectorsWithTarget: self];
  [super close];
}

- (void) dispatch
{
  BOOL av = [self hasSpaceAvailable];
  NSStreamEvent myEvent = av ? NSStreamEventHasSpaceAvailable : 
    NSStreamEventEndEncountered;

  [self _sendEvent: myEvent];
  // dispatch again iff still opened, and last event is not eos
  if (av && [self _isOpened])
    [_runloop performSelector: @selector(dispatch:)
		       target: self
		     argument: nil
			order: 0
			modes: _modes];
}

@end







