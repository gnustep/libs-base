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
#include "config.h"
#include "GNUstepBase/preface.h"
#include <winsock2.h>
#include <io.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <Foundation/NSData.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>
#include <Foundation/NSError.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSHost.h>

#include "../GSStream.h"

#ifndef	O_BINARY
#ifdef	_O_BINARY
#define	O_BINARY	_O_BINARY
#else
#define	O_BINARY	0
#endif
#endif
typedef int socklen_t;

/** 
 * The concrete subclass of NSInputStream that reads from a file
 */
@interface GSFileInputStream : GSInputStream
{
@private
  NSString *_path;
}
/**
 * this is the bridge method for asynchronized operation. Do not call.
 */
- (void) _dispatch;
@end

@class GSSocketOutputStream;
/** 
 * The abstract subclass of NSInputStream that reads from a socket
 */
@interface GSSocketInputStream : GSInputStream <RunLoopEvents>
{
@protected
  GSSocketOutputStream *_sibling;
  BOOL _passive;              /* YES means already connected */
  WSAEVENT  _event;
}

/** 
 * get the length of the socket addr
 */
- (socklen_t) sockLen;

/**
 * get the sockaddr
 */
- (struct sockaddr*) peerAddr;

/**
 * setter for sibling
 */
- (void) setSibling: (GSOutputStream*)sibling;

/**
 * setter for passive
 */
- (void) setPassive: (BOOL)passive;

/**
 * setter for event
 */
- (void) setEvent: (WSAEVENT)event;

/**
 * this is the bridge method for asynchronized operation. Do not call.
 */
- (void) _dispatch;
@end

@interface GSInetInputStream : GSSocketInputStream
{
  @private
  struct sockaddr_in _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr port: (int)port;

@end

/**
 * The concrete subclass of NSOutputStream that writes to a file
 */
@interface GSFileOutputStream : GSOutputStream
{
@private
  NSString *_path;
  BOOL _shouldAppend;
}
/**
 * this is the bridge method for asynchronized operation. Do not call.
 */
- (void) _dispatch;
@end

/**
 * The concrete subclass of NSOutputStream that writes to a socket
 */
@interface GSSocketOutputStream : GSOutputStream <RunLoopEvents>
{
@protected
  GSSocketInputStream *_sibling;
  BOOL _passive;               /* YES means already connected */
  WSAEVENT  _event;
}

/** 
 * get the length of the socket addr
 */
- (socklen_t) sockLen;

/**
 * get the sockaddr
 */
- (struct sockaddr*) peerAddr;

/**
 * setter for sibling
 */
- (void) setSibling: (GSInputStream*)sibling;

/**
 * setter for passive
 */
- (void) setPassive: (BOOL)passive;

/**
 * setter for event
 */
- (void) setEvent: (WSAEVENT)event;

/**
 * this is the bridge method for asynchronized operation. Do not call.
 */
- (void) _dispatch;
@end

@interface GSInetOutputStream : GSSocketOutputStream
{
  @private
  struct sockaddr_in _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr port: (int)port;

@end

/**
 * The concrete subclass of NSServerStream that accept connection from a socket
 */
@interface GSSocketServerStream : GSAbstractServerStream <RunLoopEvents>
{
  WSAEVENT  _event;
}
/**
 * Return the class of the inputStream associated with this
 * type of serverStream.
 */
- (Class) _inputStreamClass;
/**
 * Return the class of the outputStream associated with this
 * type of serverStream.
 */
- (Class) _outputStreamClass;
/** 
 * get the length of the socket addr
 */
- (socklen_t) sockLen;
/**
 * get the sockaddr
 */
- (struct sockaddr*) serverAddr;

@end

@interface GSInetServerStream : GSSocketServerStream
{
  @private
  struct sockaddr_in _serverAddr;
}
@end

static void setNonblocking(SOCKET fd)
{
  unsigned long	dummy = 1;

  if (ioctlsocket(fd, FIONBIO, &dummy) == SOCKET_ERROR)
    NSLog(@"unable to set non-blocking mode - %s",GSLastErrorStr(errno));
}

@implementation GSFileInputStream

- (id) initWithFileAtPath: (NSString *)path
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_path, path);
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    [self close];
  RELEASE(_path);
  [super dealloc];
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  int readLen;

  readLen = read((int)_fd, buffer, len);
  if (readLen < 0 && errno != EAGAIN && errno != EINTR)
    [self _recordError];
  else if (readLen == 0)
    [self _setStatus: NSStreamStatusAtEnd];
  return readLen;
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len
{
  return NO;
}

- (BOOL) hasBytesAvailable
{
  if ([self _isOpened] && [self streamStatus] != NSStreamStatusAtEnd)
    return YES;
  return NO;
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      off_t offset = 0;

      if ([self _isOpened])
        offset = lseek((int)_fd, 0, SEEK_CUR);
      return [NSNumber numberWithLong: offset];
    }
  return [super propertyForKey: key];
}

- (void) open
{
  int fd;

  fd = _wopen((unichar*)[_path cStringUsingEncoding: NSUnicodeStringEncoding], 
    O_RDONLY|O_BINARY);   
  if (fd < 0)
    {  
      [self _recordError];
      return;
    }
  [super open];
  _fd = (void*)fd;
  // put it self to the runloop if we havn't do so.
  if (_runloop)
    {
      [_runloop performSelector: @selector(_dispatch)
    		         target: self
		       argument: nil
			  order: 0
			  modes: _modes];
    }
}


- (void) close
{
  int closeReturn = close((int)_fd);

  if (closeReturn < 0)
    [self _recordError];
 // remove itself from the runloop, if any
  if (_runloop)
    {
      [_runloop cancelPerformSelectorsWithTarget: self];
    }
  _fd = (void*)-1;
  [super close];
}

- (void) _dispatch
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
      [_runloop performSelector: @selector(_dispatch) 
                         target: self
                       argument: nil 
                          order: 0 
                          modes: _modes];
    }
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(!_runloop || _runloop == aRunLoop, 
    @"Attempt to schedule in more than one runloop.");
  ASSIGN(_runloop, aRunLoop);
  if (![_modes containsObject: mode])
    [_modes addObject: mode];
  if ([self _isOpened])
    {  
      [_runloop performSelector: @selector(_dispatch) 
                         target: self
                       argument: nil 
                          order: 0 
                          modes: _modes];
    }
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(_runloop == aRunLoop, 
    @"Attempt to remove unscheduled runloop");
  if ([_modes containsObject: mode])
    {
      [_modes removeObject: mode];
      if ([self _isOpened])
        {
          [_runloop cancelPerformSelector: @selector(_dispatch) 
                                   target: self 
                                 argument: nil];
        }
      if ([_modes count] == 0)
        DESTROY(_runloop);
    }
}

@end

@implementation GSSocketInputStream

- (socklen_t) sockLen
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (struct sockaddr*) peerAddr
{
  [self subclassResponsibility: _cmd];
  return NULL;
}

- (void) setSibling: (GSOutputStream*)sibling
{
  ASSIGN(_sibling, sibling);
}

-(void) setPassive: (BOOL)passive
{
  _passive = passive;
}

- (void) setEvent: (WSAEVENT)event
{
  _event = event;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _sibling = nil;
      _passive = NO;
      _event = WSA_INVALID_EVENT;
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    [self close];
  RELEASE(_sibling);
  [super dealloc];
}

- (void) open
{
  // could be opened because of sibling
  if ([self _isOpened])
    return;
  if (_passive || (_sibling && [_sibling _isOpened]))
    goto open_ok;
  // check sibling status, avoid double connect
  if (_sibling && [_sibling streamStatus] == NSStreamStatusOpening)
    {
      [self _setStatus: NSStreamStatusOpening];
      return;
    }
  else
    {
      int connectReturn = connect((SOCKET)_fd, [self peerAddr], [self sockLen]);
      
      if (connectReturn == SOCKET_ERROR
	&& WSAGetLastError() != WSAEWOULDBLOCK)
        {// make an error
          [self _recordError];
          return;
        }
      // waiting on writable, as an indication of opened
      if (_runloop)
        {
          int i;
          
          WSAEventSelect((SOCKET)_fd, _event, FD_ALL_EVENTS);
          for (i = 0; i < [_modes count]; i++)
            {
              NSString	*thisMode = [_modes objectAtIndex: i];

              [_runloop addEvent: (void*)_event
			    type: ET_HANDLE 
			 watcher: self
			 forMode: thisMode];
            }
        }
      [self _setStatus: NSStreamStatusOpening];
      return;
    }

 open_ok: 
  [super open];
  setNonblocking((SOCKET)_fd);
  WSAEventSelect((SOCKET)_fd, _event, FD_ALL_EVENTS);
  // put itself to the runloop
  if (_runloop)
    {
      int i;
      
      for (i = 0; i < [_modes count]; i++)
        {
          NSString	*thisMode = [_modes objectAtIndex: i];
          
          [self scheduleInRunLoop: _runloop forMode: thisMode];
        }
    }
}

- (void) close
{
  // read shutdown is ignored, because the other side may shutdown first.
  if (_sibling && [_sibling streamStatus]!=NSStreamStatusClosed)
    shutdown((SOCKET)_fd, SD_RECEIVE);
  else
    {
      // remove itself from the runloop, if any
      if (_runloop)
        {
          int i;
        
          for (i = 0; i < [_modes count]; i++)
            {
              NSString	*thisMode = [_modes objectAtIndex: i];

              [self removeFromRunLoop: _runloop forMode: thisMode];
            }
        }
      WSACloseEvent(_event);
      closesocket((SOCKET)_fd);
    }
  // safety against double close
  _event = WSA_INVALID_EVENT;
  _fd = (void*)-1;
  [super close];
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  int readLen;

  readLen = recv((SOCKET)_fd, buffer, len, 0);
  if (readLen == SOCKET_ERROR)
    {
      errno = WSAGetLastError();
      if (errno == WSAEINPROGRESS || errno == WSAEWOULDBLOCK)
        [self _setStatus: NSStreamStatusReading];
      else if (errno != WSAEINTR) 
        [self _recordError];
    }
  else if (readLen == 0)
    [self _setStatus: NSStreamStatusAtEnd];
  else 
    [self _setStatus: NSStreamStatusOpen];
  return readLen;
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len
{
  return NO;
}

- (BOOL) hasBytesAvailable
{
  if ([self _isOpened] && [self streamStatus] != NSStreamStatusAtEnd)
    return YES;
  return NO;
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(!_runloop || _runloop == aRunLoop, 
    @"Attempt to schedule in more than one runloop.");
  ASSIGN(_runloop, aRunLoop);
  if (![_modes containsObject: mode])
    [_modes addObject: mode];
  if ([self _isOpened])
    {
      [_runloop addEvent: (void*)_event
		    type: ET_HANDLE
		 watcher: self
		 forMode: mode];
    }
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(_runloop == aRunLoop, 
    @"Attempt to remove unscheduled runloop");
  if ([_modes containsObject: mode])
    {
      [_modes removeObject: mode];
      if ([self _isOpened])
        {
          [_runloop removeEvent: (void*)_event
			   type: ET_HANDLE
			forMode: mode
			    all: YES];
        }
      if ([_modes count] == 0)
        {
          [_runloop cancelPerformSelector: @selector(_dispatch) 
                                   target: self 
                                 argument: nil];
          DESTROY(_runloop);
        }
    }
}

- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode
{
  return nil;
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  WSANETWORKEVENTS ocurredEvents;
  int error, getReturn; 
  unsigned len = sizeof(error);

  /*
   * it is possible the stream is closed yet recieving event because
   * of not closed sibling
   */
  if ([self streamStatus] == NSStreamStatusClosed)
    {
      NSAssert([_sibling streamStatus] != NSStreamStatusClosed, 
               @"Received event for closed stream");
      [_sibling receivedEvent: data 
                         type: type
                        extra: extra
                      forMode: mode];
      return;
    }
    
  if (WSAEnumNetworkEvents((SOCKET)_fd, _event, &ocurredEvents) == SOCKET_ERROR)
    {
      errno = WSAGetLastError();
      [self _recordError];
    }
  else if ([self streamStatus] == NSStreamStatusOpening)
    {
      getReturn = getsockopt((SOCKET)_fd, SOL_SOCKET, SO_ERROR,
	(char*)&error, &len);

      if (getReturn >= 0 && !error
	&& (ocurredEvents.lNetworkEvents & FD_CONNECT))
        { // finish up the opening
          ocurredEvents.lNetworkEvents ^= FD_CONNECT;
          _passive = YES;
          [self open];
          [self _sendEvent: NSStreamEventOpenCompleted];
          // notify sibling
          if (_sibling)
            {
              [_sibling open];
              [_sibling _sendEvent: NSStreamEventOpenCompleted];
            }
        }
      else // must be an error
        {
          if (error)
            errno = error;
          [self _recordError];
        }
    }
  else
    {
      if (ocurredEvents.lNetworkEvents & FD_READ)
        {
          ocurredEvents.lNetworkEvents ^= FD_READ;
          [self _setStatus: NSStreamStatusOpen];
        }
      if ((ocurredEvents.lNetworkEvents & FD_WRITE)
	&& (_sibling && [_sibling _isOpened]))
        {
          ocurredEvents.lNetworkEvents ^= FD_WRITE;
          [_sibling _setStatus: NSStreamStatusOpen];
        }
    }
  [self _dispatch];
  if (_sibling && [_sibling _isOpened])
    [_sibling _dispatch];
}

- (void) _dispatch
{
  NSStreamStatus myStatus = [self streamStatus];

  switch (myStatus)
    {
      case NSStreamStatusError: 
	{
	  [self _sendEvent: NSStreamEventErrorOccurred];
	  break;
	}
      case NSStreamStatusOpen: 
	{
	  [self _sendEvent: NSStreamEventHasBytesAvailable];
	  break;        
	}
      default: 
	break;
    }
  // status may change now
  myStatus = [self streamStatus];
  if (myStatus == NSStreamStatusOpen)    
    {
      [_runloop performSelector: @selector(_dispatch) 
                         target: self
                       argument: nil 
                          order: 0 
                          modes: _modes];
    }    
}

@end

@implementation GSInetInputStream

- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_in);
}

- (struct sockaddr*) peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin_family = AF_INET;
      _peerAddr.sin_port = htons(port);
      _peerAddr.sin_addr.s_addr = inet_addr(addr_c);
      if (_peerAddr.sin_addr.s_addr == INADDR_NONE)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}

@end

@implementation GSFileOutputStream

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_path, path);
      _shouldAppend = shouldAppend;
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    [self close];
  RELEASE(_path);
  [super dealloc];
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  int writeLen;

  writeLen = write((int)_fd, buffer, len);
  if (writeLen < 0 && errno != EAGAIN && errno != EINTR)
    [self _recordError];
  return writeLen;
}

- (BOOL) hasSpaceAvailable
{
  if ([self _isOpened])
    return YES;
  return NO;
}
                                                                                 
- (void) open
{
  int fd;
  int flag = O_WRONLY | O_CREAT | O_BINARY;
  int mode = _S_IREAD | _S_IWRITE; 

  if (_shouldAppend)
    flag = flag | O_APPEND;
  else
    flag = flag | O_TRUNC;
  fd = _wopen((unichar*)[_path cStringUsingEncoding: NSUnicodeStringEncoding], 
        flag, mode);
  if (fd < 0)
    {  // make an error
      [self _recordError];
      return;
    }
  [super open];
  _fd = (void*)fd;
  // put it self to the runloop if we haven't do so.
  if (_runloop)
    {
      [_runloop performSelector: @selector(_dispatch)
    		         target: self
		       argument: nil
			  order: 0
			  modes: _modes];
    }
}

- (void) close
{
  int closeReturn = close((int)_fd);

  if (closeReturn < 0)
    [self _recordError];
  // remove itself from the runloop, if any
  if (_runloop)
    {
      [_runloop cancelPerformSelectorsWithTarget: self];
    }
  _fd = (void*)-1;
  [super close];
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      off_t offset = 0;

      if ([self _isOpened])
        offset = lseek((int)_fd, 0, SEEK_CUR);
      return [NSNumber numberWithLong: offset];
    }
  return [super propertyForKey: key];
}

- (void) _dispatch
{
  BOOL av = [self hasSpaceAvailable];
  NSStreamEvent myEvent = av ? NSStreamEventHasSpaceAvailable : 
    NSStreamEventEndEncountered;

  [self _sendEvent: myEvent];
  // dispatch again iff still opened, and last event is not eos
  if (av && [self _isOpened])
    {
      [_runloop performSelector: @selector(_dispatch) 
                         target: self
                       argument: nil 
                          order: 0 
                          modes: _modes];
    }
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(!_runloop || _runloop == aRunLoop, 
    @"Attempt to schedule in more than one runloop.");
  ASSIGN(_runloop, aRunLoop);
  if (![_modes containsObject: mode])
    [_modes addObject: mode];
  if ([self _isOpened])
    {
      [_runloop performSelector: @selector(_dispatch) 
                         target: self
                       argument: nil 
                          order: 0 
                          modes: _modes];
    }
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(_runloop == aRunLoop, 
    @"Attempt to remove unscheduled runloop");
  if ([_modes containsObject: mode])
    {
      [_modes removeObject: mode];
      if ([self _isOpened])
        {
          [_runloop cancelPerformSelector: @selector(_dispatch) 
                                   target: self 
				 argument: nil];
        }
      if ([_modes count] == 0)
        {
          [_runloop cancelPerformSelector: @selector(_dispatch) 
                                   target: self 
                                 argument: nil];
          DESTROY(_runloop);
        }
    }
}

@end

@implementation GSSocketOutputStream

- (socklen_t) sockLen
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (struct sockaddr*) peerAddr
{
  [self subclassResponsibility: _cmd];
  return NULL;
}

- (void) setSibling: (GSInputStream*)sibling
{
  ASSIGN(_sibling, sibling);
}

-(void)setPassive: (BOOL)passive
{
  _passive = passive;
}

- (void) setEvent: (WSAEVENT)event
{
  _event = event;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _sibling = nil;
      _passive = NO;
      _event = WSA_INVALID_EVENT;
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    [self close];
  RELEASE(_sibling);
  [super dealloc];
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  int writeLen;

  writeLen = send((SOCKET)_fd, buffer, len, 0);
  if (writeLen == SOCKET_ERROR)
    {
      errno = WSAGetLastError();
      if (errno == WSAEINPROGRESS || errno == WSAEWOULDBLOCK)
        [self _setStatus: NSStreamStatusWriting];
      else if (errno != WSAEINTR)
        [self _recordError];
    }
  else
    [self _setStatus: NSStreamStatusOpen];
  return writeLen;
}

- (BOOL) hasSpaceAvailable
{
  if ([self _isOpened])
    return YES;
  return NO;
}

- (void) open
{
  // could be opened because of sibling
  if ([self _isOpened])
    return;
  if (_passive || (_sibling && [_sibling _isOpened]))
    goto open_ok;
  // check sibling status, avoid double connect
  if (_sibling && [_sibling streamStatus] == NSStreamStatusOpening)
    {
      [self _setStatus: NSStreamStatusOpening];
      return;
    }
  else
    {
      int connectReturn = connect((SOCKET)_fd, [self peerAddr], [self sockLen]);
      
      if (connectReturn == SOCKET_ERROR
	&& WSAGetLastError() != WSAEWOULDBLOCK)
        {// make an error
          [self _recordError];
          return;
        }
      // waiting on writable, as an indication of opened
      if (_runloop)
        {
          int i;

          WSAEventSelect((SOCKET)_fd, _event, FD_ALL_EVENTS);

          for (i = 0; i < [_modes count]; i++)
            {
              NSString	*thisMode = [_modes objectAtIndex: i];

              [_runloop addEvent: (void*)_event
			    type: ET_HANDLE 
			 watcher: self
			 forMode: thisMode];
            }
        }
      [self _setStatus: NSStreamStatusOpening];
      return;
    }

 open_ok: 
  [super open];
  setNonblocking((SOCKET)_fd);
  WSAEventSelect((SOCKET)_fd, _event, FD_ALL_EVENTS);
  // put itself to the runloop
  if (_runloop)
    {
      int i;
      
      for (i = 0; i < [_modes count]; i++)
        {
          NSString	*thisMode = [_modes objectAtIndex: i];
          
          [self scheduleInRunLoop: _runloop forMode: thisMode];
        }
    }
}

- (void) close
{
  // shutdown may fail (broken pipe). Record it.
  int closeReturn;
  if (_sibling && [_sibling streamStatus]!=NSStreamStatusClosed)
    closeReturn = shutdown((SOCKET)_fd, SD_SEND);
  else
    {
      // remove itself from the runloop, if any
      if (_runloop)
        {
          int i;

          for (i = 0; i < [_modes count]; i++)
            {
              NSString	*thisMode = [_modes objectAtIndex: i];
   
              [self removeFromRunLoop: _runloop forMode: thisMode];
            }
        }
      WSACloseEvent(_event);
      closeReturn = closesocket((SOCKET)_fd);
    }
  if (closeReturn < 0)
    [self _recordError];
  // safety against double close 
  _event = WSA_INVALID_EVENT;
  _fd = (void*)-1;
  [super close];
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(!_runloop || _runloop == aRunLoop, 
    @"Attempt to schedule in more than one runloop.");
  ASSIGN(_runloop, aRunLoop);
  if (![_modes containsObject: mode])
    [_modes addObject: mode];
  if ([self _isOpened])
    {
      [_runloop addEvent: (void*)_event
		    type: ET_HANDLE
		 watcher: self
		 forMode: mode];
    }
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(_runloop == aRunLoop, 
    @"Attempt to remove unscheduled runloop");
  if ([_modes containsObject: mode])
    {
      [_modes removeObject: mode];
      if ([self _isOpened])
        {
          [_runloop removeEvent: (void*)_event
			   type: ET_HANDLE
			forMode: mode
			    all: YES];
        }
      if ([_modes count] == 0)
        DESTROY(_runloop);
    }
}

- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode
{
  return nil;
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  WSANETWORKEVENTS ocurredEvents;
  int error, getReturn;
  unsigned len = sizeof(error);

  /*
   * it is possible the stream is closed yet recieving event
   * because of not closed sibling
   */
  if ([self streamStatus] == NSStreamStatusClosed)
    {
      NSAssert([_sibling streamStatus] != NSStreamStatusClosed, 
	@"Received event for closed stream");
      [_sibling receivedEvent: data 
                         type: type
                        extra: extra
                      forMode: mode];
      return;
    }
    
  if (WSAEnumNetworkEvents((SOCKET)_fd, _event, &ocurredEvents) == SOCKET_ERROR)
    {
      errno = WSAGetLastError();
      [self _recordError];
    }
  else if ([self streamStatus] == NSStreamStatusOpening)
    {
      getReturn = getsockopt((SOCKET)_fd, SOL_SOCKET, SO_ERROR,
	(char*)&error, &len);

      if (getReturn >= 0 && !error
	&& (ocurredEvents.lNetworkEvents & FD_CONNECT))
        { // finish up the opening
          ocurredEvents.lNetworkEvents ^= FD_CONNECT;
          _passive = YES;
          [self open];
          // notify sibling
          if (_sibling)
            {
              [_sibling open];
              [_sibling _sendEvent: NSStreamEventOpenCompleted];
            }
        }
      else // must be an error
        {
          if (error)
            errno = error;
          [self _recordError];
        }
    }
  else
    {
      if ((ocurredEvents.lNetworkEvents & FD_READ) && 
          (_sibling && [_sibling _isOpened]))
        {
          ocurredEvents.lNetworkEvents ^= FD_READ;
          [_sibling _setStatus: NSStreamStatusOpen];
        }
      if (ocurredEvents.lNetworkEvents & FD_WRITE)
        {
          ocurredEvents.lNetworkEvents ^= FD_WRITE;
          [self _setStatus: NSStreamStatusOpen];
        }
    }
  [self _dispatch];
  if (_sibling && [_sibling _isOpened])
    [_sibling _dispatch];
}

- (void)_dispatch
{
  NSStreamStatus myStatus = [self streamStatus];
  switch (myStatus)
    {
      case NSStreamStatusError: 
	{
	  [self _sendEvent: NSStreamEventErrorOccurred];
	  break;
	}
      case NSStreamStatusOpen: 
	{
	  [self _sendEvent: NSStreamEventHasSpaceAvailable];
	  break;        
	}
      default: 
	break;
    }
  // status may change now
  myStatus = [self streamStatus];
  if (myStatus == NSStreamStatusOpen)    
    {
      [_runloop performSelector: @selector(_dispatch) 
                         target: self
                       argument: nil 
                          order: 0 
                          modes: _modes];
    }    
}

@end

@implementation GSInetOutputStream

- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_in);
}

- (struct sockaddr*) peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin_family = AF_INET;
      _peerAddr.sin_port = htons(port);
      _peerAddr.sin_addr.s_addr = inet_addr(addr_c);
      if (_peerAddr.sin_addr.s_addr == INADDR_NONE)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}

@end

@implementation NSStream

+ (void) getStreamsToHost: (NSHost *)host 
                     port: (int)port 
              inputStream: (NSInputStream **)inputStream 
             outputStream: (NSOutputStream **)outputStream
{
  NSString *address = [host address];
  GSSocketInputStream *ins = nil;
  GSSocketOutputStream *outs = nil;
  int sock;
  WSAEVENT event;

  ins = AUTORELEASE([[GSInetInputStream alloc]
    initToAddr: address port: port]);
  outs = AUTORELEASE([[GSInetOutputStream alloc]
    initToAddr: address port: port]);
  sock = socket(PF_INET, SOCK_STREAM, 0);
  event = CreateEvent(NULL, NO, NO, NULL);
  
  NSAssert(sock >= 0, @"Cannot open socket");
  [ins _setFd: (void*)(intptr_t)sock];
  [outs _setFd: (void*)(intptr_t)sock];
  [ins setEvent: event];
  [outs setEvent: event];
  
  if (inputStream)
    {
      [ins setSibling: outs];
      *inputStream = ins;
    }
  if (outputStream)
    {
      [outs setSibling: ins];
      *outputStream = outs;
    }
  return;
}

+ (void) getLocalStreamsToPath: (NSString *)path 
                   inputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream
{
  [self notImplemented: _cmd];
}

+ (void) pipeWithInputStream: (NSInputStream **)inputStream 
                outputStream: (NSOutputStream **)outputStream
{
  [self notImplemented: _cmd];
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
  return AUTORELEASE([[GSMemoryInputStream alloc] initWithData: data]);
}

+ (id) inputStreamWithFileAtPath: (NSString *)path
{
  return AUTORELEASE([[GSFileInputStream alloc] initWithFileAtPath: path]);
}

- (id) initWithData: (NSData *)data
{
  RELEASE(self);
  return [[GSMemoryInputStream alloc] initWithData: data];
}

- (id) initWithFileAtPath: (NSString *)path
{
  RELEASE(self);
  return [[GSFileInputStream alloc] initWithFileAtPath: path];
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
  return AUTORELEASE([[GSMemoryOutputStream alloc] 
    initToBuffer: NULL capacity: 0]);  
}

+ (id) outputStreamToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity
{
  return AUTORELEASE([[GSMemoryOutputStream alloc] 
    initToBuffer: buffer capacity: capacity]);  
}

+ (id) outputStreamToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  return AUTORELEASE([[GSFileOutputStream alloc]
    initToFileAtPath: path append: shouldAppend]);
}

- (id) initToMemory
{
  RELEASE(self);
  return [[GSMemoryOutputStream alloc] initToBuffer: NULL capacity: 0];
}

- (id) initToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity
{
  RELEASE(self);
  return [[GSMemoryOutputStream alloc] initToBuffer: buffer capacity: capacity];
}

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  RELEASE(self);
  return [[GSFileOutputStream alloc] initToFileAtPath: path
					       append: shouldAppend];  
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

@implementation GSServerStream

+ (id) serverStreamToAddr: (NSString*)addr port: (int)port
{
  GSServerStream *s;

  s = [[GSInetServerStream alloc] initToAddr: addr port: port];
  return AUTORELEASE(s);
  return nil;
}

+ (id) serverStreamToAddr: (NSString*)addr
{
  [self notImplemented: _cmd];
  return nil;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  RELEASE(self);
  self = [[GSInetServerStream alloc] initToAddr: addr port: port];
  return self;
}

- (id) initToAddr: (NSString*)addr
{
  RELEASE(self);
  [self notImplemented: _cmd];
  return nil;
}

- (void) acceptWithInputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream
{
  [self subclassResponsibility: _cmd];
}

@end

@implementation GSSocketServerStream

- (Class) _inputStreamClass
{
  [self subclassResponsibility: _cmd];
  return Nil;
}

- (Class) _outputStreamClass
{
  [self subclassResponsibility: _cmd];
  return Nil;
}

- (id) init
{
  if ((self = [super init]) != nil)
    _event = WSA_INVALID_EVENT;
  return self;
}
- (void) dealloc
{
  if ([self _isOpened])
    [self close];
  [super dealloc];
}

- (socklen_t) sockLen
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (struct sockaddr*) serverAddr
{
  [self subclassResponsibility: _cmd];
  return 0;
}

#define SOCKET_BACKLOG 5

- (void) open
{
  int bindReturn = bind((SOCKET)_fd, [self serverAddr], [self sockLen]);
  int listenReturn = listen((SOCKET)_fd, SOCKET_BACKLOG);

  if (bindReturn < 0 || listenReturn)
    {
      [self _recordError];
      return;
    }
  setNonblocking((SOCKET)_fd);
  // put itself to the runloop
  [super open];
  _event = CreateEvent(NULL, NO, NO, NULL);
  WSAEventSelect((SOCKET)_fd, _event, FD_ALL_EVENTS);
  if (_runloop)
    {
      int i;

      for (i = 0; i < [_modes count]; i++)
        {
          NSString* thisMode = [_modes objectAtIndex: i];
          [self scheduleInRunLoop: _runloop forMode: thisMode];
        }
    }
}

- (void) close
{
  // remove itself from the runloop, if any
  if (_runloop)
    {
      int i;

      for (i = 0; i < [_modes count]; i++)
        {
          NSString* thisMode = [_modes objectAtIndex: i];
          [self removeFromRunLoop: _runloop forMode: thisMode];
        }
    }
  WSACloseEvent(_event);
  // close a server socket is safe
  closesocket((SOCKET)_fd);
  _event = WSA_INVALID_EVENT;
  _fd = (void*)-1;
  [super close];
}

- (void) acceptWithInputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream
{
  GSSocketInputStream *ins = AUTORELEASE([[self _inputStreamClass] new]);
  GSSocketOutputStream *outs = AUTORELEASE([[self _outputStreamClass] new]);
  socklen_t len = [ins sockLen];
  int acceptReturn = accept((SOCKET)_fd, [ins peerAddr], &len);

  if (acceptReturn == INVALID_SOCKET)
    { 
      errno = WSAGetLastError();// test for real error
      if (errno != WSAEWOULDBLOCK && errno != WSAECONNRESET && 
          errno != WSAEINPROGRESS && errno != WSAEINTR)
	{
          [self _recordError];
	}
      ins = nil;
      outs = nil;
    }
  else
    {
      WSAEVENT  event = CreateEvent(NULL, NO, NO, NULL);
      // no need to connect again
      [ins setPassive: YES];
      [outs setPassive: YES];
      // copy the addr to outs
      memcpy([outs peerAddr], [ins peerAddr], len);
      [ins _setFd: (void*)(intptr_t)acceptReturn];
      [outs _setFd: (void*)(intptr_t)acceptReturn];
      [ins setEvent: event];
      [outs setEvent: event];
    }
  if (inputStream)
    {
      [ins setSibling: outs];
      *inputStream = ins;
    }
  if (outputStream)
    {
      [outs setSibling: ins];
      *outputStream = outs;
    }
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(!_runloop || _runloop == aRunLoop, 
    @"Attempt to schedule in more than one runloop.");
  ASSIGN(_runloop, aRunLoop);
  if (![_modes containsObject: mode])
    [_modes addObject: mode];
  if ([self _isOpened])
    {
      [_runloop addEvent: (void*)_event
		    type: ET_HANDLE
		 watcher: self
		 forMode: mode];
    }
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(_runloop == aRunLoop, 
    @"Attempt to remove unscheduled runloop");
  if ([_modes containsObject: mode])
    {
      [_modes removeObject: mode];
      if ([self _isOpened])
        {
          [_runloop removeEvent: (void*)_event
			   type: ET_HANDLE
			forMode: mode
			    all: YES];
        }
      if ([_modes count] == 0)
        DESTROY(_runloop);
    }
}

- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode
{
  return nil;
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  WSANETWORKEVENTS ocurredEvents;
  
  if (WSAEnumNetworkEvents((SOCKET)_fd, _event, &ocurredEvents) == SOCKET_ERROR)
    {
      errno = WSAGetLastError();
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
    }
  else if (ocurredEvents.lNetworkEvents & FD_ACCEPT)
    {
      ocurredEvents.lNetworkEvents ^= FD_ACCEPT;
      [self _setStatus: NSStreamStatusReading];
      [self _sendEvent: NSStreamEventHasBytesAvailable];
    }
}

@end

@implementation GSInetServerStream

- (Class) _inputStreamClass
{
  return [GSInetInputStream class];
}

- (Class) _outputStreamClass
{
  return [GSInetOutputStream class];
}

- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_in);
}

- (struct sockaddr*) serverAddr
{
  return (struct sockaddr*)&_serverAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  [super init];
  _serverAddr.sin_family = AF_INET;
  _serverAddr.sin_port = htons(port);
  _serverAddr.sin_addr.s_addr = inet_addr(addr_c);
  _fd = (void*)socket(AF_INET, SOCK_STREAM, 0);
  if (_serverAddr.sin_addr.s_addr == INADDR_NONE || _fd < 0)   // error
    {
      RELEASE(self);
      return nil;
    }
  return self;
}

@end
