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


/*
 * Determine the type of event to use when adding a stream to the run loop.
 * By default add as an 'ET_TRIGGER' so that the stream will be notified
 * every time the loop runs (the event id/reference must be the address of
 * the stream itsself to ensure that event/type is unique).
 *
 * Streams which actually expect to wait for I/O events must be added with
 * the appropriate information for the loop to signal them.
 */
static RunLoopEventType typeForStream(NSStream *aStream)
{
#if	defined(__MINGW32__)
  if ([aStream _loopID] == (void*)aStream)
    {
      return ET_TRIGGER;
    }
  else
    {
      return ET_HANDLE;
    }
#else
  if ([aStream _loopID] == (void*)aStream)
    {
      return ET_TRIGGER;
    }
  else if ([aStream isKindOfClass: [NSOutputStream class]] == NO
    && [aStream  streamStatus] != NSStreamStatusOpening)
    {
      return ET_RDESC;
    }
  else
    {
      return ET_WDESC;	
    }
#endif
}

@implementation	NSRunLoop (NSStream)
- (void) addStream: (NSStream*)aStream mode: (NSString*)mode
{
  [self addEvent: [aStream _loopID]
	    type: typeForStream(aStream)
	 watcher: (id<RunLoopEvents>)aStream
	 forMode: mode];
}

- (void) removeStream: (NSStream*)aStream mode: (NSString*)mode
{
  [self removeEvent: [aStream _loopID]
	       type: typeForStream(aStream)
	    forMode: mode
		all: NO];
}
@end

@implementation GSStream

- (void) close
{
  NSAssert(_currentStatus != NSStreamStatusNotOpen
    && _currentStatus != NSStreamStatusClosed, 
    @"Attempt to close a stream not yet opened.");
  if (_runloop)
    {
      unsigned	i = [_modes count];

      while (i-- > 0)
	{
	  [_runloop removeStream: self mode: [_modes objectAtIndex: i]];
	}
    }
  [self _setStatus: NSStreamStatusClosed];
  /* We don't want to send any events the the delegate after the
   * stream has been closed.
   */
  _delegateValid = NO;
}

- (void) dealloc
{
  if (_currentStatus != NSStreamStatusNotOpen
    && _currentStatus != NSStreamStatusClosed)
    {
      [self close];
    }
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

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _delegate = self;
      _properties = nil;
      _lastError = nil;
      _modes = [NSMutableArray new];
      _currentStatus = NSStreamStatusNotOpen;
      _loopID = (void*)self;
    }
  return self;
}

- (void) open
{
  NSAssert(_currentStatus == NSStreamStatusNotOpen
    || _currentStatus == NSStreamStatusOpening, 
    @"Attempt to open a stream already opened.");  
  [self _setStatus: NSStreamStatusOpen];
  if (_runloop)
    {
      unsigned	i = [_modes count];

      while (i-- > 0)
	{
	  [_runloop addStream: self mode: [_modes objectAtIndex: i]];
	}
    }
  [self _sendEvent: NSStreamEventOpenCompleted];
}

- (id) propertyForKey: (NSString *)key
{
  return [_properties objectForKey: key];
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  [self _dispatch];
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  if (_runloop == aRunLoop)
    {
      if ([_modes containsObject: mode])
	{
	  if ([self _isOpened])
	    {
	      [_runloop removeStream: self mode: mode];
	    }
	  [_modes removeObject: mode];
	  if ([_modes count] == 0)
	    {
	      DESTROY(_runloop);
	    }
	}
    }
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(!_runloop || _runloop == aRunLoop, 
    @"Attempt to schedule in more than one runloop.");
  ASSIGN(_runloop, aRunLoop);
  if ([_modes containsObject: mode] == NO)
    {
      mode = [mode copy];
      [_modes addObject: mode];
      RELEASE(mode);
      if ([self _isOpened])
	{
	  [_runloop addStream: self mode: mode];
	}
    }
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
  if ([self streamStatus] != NSStreamStatusClosed
    && [self streamStatus] != NSStreamStatusError)
    {
      /* We don't want to send any events the the delegate after the
       * stream has been closed.
       */
      _delegateValid
        = [_delegate respondsToSelector: @selector(stream:handleEvent:)];
    }
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

- (NSError *) streamError
{
  return _lastError;
}

- (NSStreamStatus) streamStatus
{
  return _currentStatus;
}

@end


@implementation	NSStream (Private)

- (void) _dispatch
{
}

- (BOOL) _isOpened
{
  return NO;
}

- (void*) _loopID
{
  return (void*)self;	// By default a stream is a TRIGGER event.
}

- (void) _recordError
{
}

- (void) _sendEvent: (NSStreamEvent)event
{
}

- (void) _setLoopID: (void *)ref
{
}

- (void) _setStatus: (NSStreamStatus)newStatus
{
}

- (BOOL) _unhandledData
{
  return NO;
}
@end

@implementation	GSStream (Private)

- (BOOL) _isOpened
{
  return !(_currentStatus == NSStreamStatusNotOpen
    || _currentStatus == NSStreamStatusOpening
    || _currentStatus == NSStreamStatusClosed);
}

- (void*) _loopID
{
  return _loopID;
}

- (void) _recordError
{
  NSError *theError;

#if	defined(__MINGW32__)
  errno = GetLastError();
#endif
  theError = [NSError errorWithDomain: NSPOSIXErrorDomain
					  code: errno
				      userInfo: nil];
  NSLog(@"%@ error(%d): - %s", self, errno, GSLastErrorStr(errno));
  ASSIGN(_lastError, theError);
  _currentStatus = NSStreamStatusError;
}

- (void) _sendEvent: (NSStreamEvent)event
{
  NSStreamStatus last = [self streamStatus];
  NSStreamStatus current;

  if (event == NSStreamEventNone)
    {
      return;
    }
  else if (event == NSStreamEventOpenCompleted)
    {
      if ((_events & event) == 0)
	{
	  _events |= NSStreamEventOpenCompleted;
	  if (_delegateValid == YES)
	    {
	      [_delegate stream: self
		    handleEvent: NSStreamEventOpenCompleted];
	    }
	}
    }
  else if (event == NSStreamEventHasBytesAvailable)
    {
      if ((_events & NSStreamEventOpenCompleted) == 0)
	{
	  _events |= NSStreamEventOpenCompleted;
	  if (_delegateValid == YES)
	    {
	      [_delegate stream: self
		    handleEvent: NSStreamEventOpenCompleted];
	    }
	}
      if ((_events & NSStreamEventHasBytesAvailable) == 0)
	{
	  _events |= NSStreamEventHasBytesAvailable;
	  if (_delegateValid == YES)
	    {
	      [_delegate stream: self
		    handleEvent: NSStreamEventHasBytesAvailable];
	    }
	}
    }
  else if (event == NSStreamEventHasSpaceAvailable)
    {
      if ((_events & NSStreamEventOpenCompleted) == 0)
	{
	  _events |= NSStreamEventOpenCompleted;
	  if (_delegateValid == YES)
	    {
	      [_delegate stream: self
		    handleEvent: NSStreamEventOpenCompleted];
	    }
	}
      if ((_events & NSStreamEventHasSpaceAvailable) == 0)
	{
	  _events |= NSStreamEventHasSpaceAvailable;
	  if (_delegateValid == YES)
	    {
	      [_delegate stream: self
		    handleEvent: NSStreamEventHasSpaceAvailable];
	    }
	}
    }
  else if (event == NSStreamEventErrorOccurred)
    {
      if ((_events & NSStreamEventErrorOccurred) == 0)
	{
	  _events |= NSStreamEventErrorOccurred;
	  if (_delegateValid == YES)
	    {
	      [_delegate stream: self
		    handleEvent: NSStreamEventErrorOccurred];
	    }
	}
    }
  else if (event == NSStreamEventEndEncountered)
    {
      if ((_events & NSStreamEventEndEncountered) == 0)
	{
	  _events |= NSStreamEventEndEncountered;
	  if (_delegateValid == YES)
	    {
	      [_delegate stream: self
		    handleEvent: NSStreamEventEndEncountered];
	    }
	}
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Unknown event (%d) passed to _sendEvent:", event];
    }

  /* If our status changed while the handler was dealing with an
   * event, we may need to send it the new event to let it know.
   */
  if ((current = [self streamStatus]) != last)
    {
      if (current == NSStreamStatusAtEnd)
	{
	  [self _sendEvent: NSStreamEventEndEncountered];
	}
      else if (current == NSStreamStatusError)
        {
	  [self _sendEvent: NSStreamEventErrorOccurred];
	}
    }
}

- (void) _setLoopID: (void *)ref
{
  _loopID = ref;
}

- (void) _setStatus: (NSStreamStatus)newStatus
{
  _currentStatus = newStatus;
}

- (BOOL) _unhandledData
{
  if (_events
    & (NSStreamEventHasBytesAvailable | NSStreamEventHasSpaceAvailable))
    {
      return YES;
    }
  return NO;
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  if ([self _unhandledData] == YES
    || _currentStatus == NSStreamStatusError
    || _currentStatus == NSStreamStatusAtEnd)
    {
      /* If we have an unhandled data event, we should not watch for more
       * or trigger until the appropriate rad or write has been done.
       * If an error has occurred, we should not watch for any events at all.
       */
      *trigger = NO;
      return NO;
    }
  else if (_loopID == (void*)self)
    {
      /* If _loopID is the receiver, the stream is not receiving external
       * input, so it must trigger an event when the loop runs and must not
       * block the loop from running.
       */
      *trigger = YES;
      return NO;
    }
  else
    {
      *trigger = YES;
      return YES;
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
@implementation	GSAbstractServerStream
+ (void) initialize
{
  if (self == [GSAbstractServerStream class])
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

  _events &= ~NSStreamEventHasSpaceAvailable;
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

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    return [NSNumber numberWithLong: _pointer];
  return [super propertyForKey: key];
}

- (void) _dispatch
{
  BOOL av = [self hasBytesAvailable];
  NSStreamEvent myEvent = av ? NSStreamEventHasBytesAvailable : 
    NSStreamEventEndEncountered;
  NSStreamStatus myStatus = av ? NSStreamStatusOpen : NSStreamStatusAtEnd;
  
  [self _setStatus: myStatus];
  [self _sendEvent: myEvent];
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
  _events &= ~NSStreamEventHasBytesAvailable;
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

- (void) _dispatch
{
  BOOL av = [self hasSpaceAvailable];
  NSStreamEvent myEvent = av ? NSStreamEventHasSpaceAvailable : 
    NSStreamEventEndEncountered;

  [self _sendEvent: myEvent];
}

@end

