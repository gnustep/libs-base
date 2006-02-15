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
#include <unistd.h>
#include <errno.h>

#include <Foundation/NSData.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>
#include <Foundation/NSError.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSHost.h>

#include "../GSStream.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <arpa/inet.h>


/** 
 * The concrete subclass of NSInputStream that reads from a file
 */
@interface GSFileInputStream : GSInputStream <RunLoopEvents>
{
@private
  NSString *_path;
  int _fd;
}
@end

/** 
 * The abstract subclass of NSInputStream that reads from a socket
 */
@interface GSSocketInputStream : GSInputStream <RunLoopEvents>
{
@protected
  int _fd;
  GSOutputStream *_sibling;
  BOOL _passive;              /* YES means it is the server side */
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
 * setter for fd
 */
- (void) setFd: (int)fd;

@end

@interface GSInetInputStream : GSSocketInputStream
{
  @private
  struct sockaddr_in _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr port: (int)port passive: (BOOL)passive;

@end

@interface GSInet6InputStream : GSSocketInputStream
{
  @private
  struct sockaddr_in6 _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr port: (int)port passive: (BOOL)passive;

@end

@interface GSLocalInputStream : GSSocketInputStream
{
  @private
  struct sockaddr_un _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr passive: (BOOL)passive;

@end


/**
 * The concrete subclass of NSOutputStream that writes to a file
 */
@interface GSFileOutputStream : GSOutputStream <RunLoopEvents>
{
@private
  NSString *_path;
  int _fd;
  BOOL _shouldAppend;
}
@end

/**
 * The concrete subclass of NSOutputStream that writes to a socket
 */
@interface GSSocketOutputStream : GSOutputStream <RunLoopEvents>
{
@protected
  int _fd;
  GSInputStream *_sibling;
  BOOL _passive;              /* YES means it is the server side */
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
 * setter for fd
 */
- (void) setFd: (int)fd;

@end

@interface GSInetOutputStream : GSSocketOutputStream
{
  @private
  struct sockaddr_in _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr port: (int)port passive: (BOOL)passive;

@end

@interface GSInet6OutputStream : GSSocketOutputStream
{
  @private
  struct sockaddr_in6 _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr port: (int)port passive: (BOOL)passive;

@end

@interface GSLocalOutputStream : GSSocketOutputStream
{
  @private
  struct sockaddr_un _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr passive: (BOOL)passive;

@end


@implementation GSFileInputStream

- (id) initWithFileAtPath: (NSString *)path
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_path, path);
      // so that unopened access will fail
      _fd = -1;
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

  readLen = read(_fd, buffer, len);
  if (readLen < 0)
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
        offset = lseek(_fd, 0, SEEK_CUR);
      return [NSNumber numberWithLong: offset];
    }
  return [super propertyForKey: key];
}

- (void) open
{
  int fd;

  fd = open([_path fileSystemRepresentation], O_RDONLY|O_NONBLOCK);
  if (fd < 0)
    {  
      [self _recordError];
      return;
    }
  [super open];
  _fd = fd;
  // put it self to the runloop if we havn't do so.
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
  int closeReturn = close(_fd);

  if (closeReturn < 0)
    [self _recordError];
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
  _fd = -1;
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
      [_runloop addEvent: (void*)(uintptr_t)_fd
		    type: ET_RDESC
		 watcher: self
		 forMode: mode];
      [_runloop addEvent: (void*)(uintptr_t)_fd
		    type: ET_EDESC
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
      if ([self _isOpened])
        {
          [_runloop removeEvent: (void*)(uintptr_t)_fd
			   type: ET_RDESC
			forMode: mode
			    all: YES];
          [_runloop removeEvent: (void*)(uintptr_t)_fd
			   type: ET_EDESC
			forMode: mode
			    all: YES];
        }
      [_modes removeObject: mode];
      if ([_modes count] == 0)
	{
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
  int		desc = (int)(uintptr_t)extra;
  NSStreamEvent myEvent;

  NSAssert(desc == _fd, @"Wrong file descriptor received.");
  if (type == ET_RDESC)
    {
      [self _setStatus: NSStreamStatusReading];
      myEvent = NSStreamEventHasBytesAvailable;
    }
  else   
    {    // must be an error then
      [self _recordError];
      myEvent = NSStreamEventErrorOccurred;
    }

  [self _sendEvent: myEvent];
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

- (void) setFd: (int)fd
{
  _fd = fd;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      // so that unopened access will fail
      _fd = -1;
      _sibling = nil;
      _passive = NO;
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
      int connectReturn = connect(_fd, [self peerAddr], [self sockLen]);
      
      if (connectReturn < 0 && errno != EINPROGRESS)
        {// make an error
          [self _recordError];
          return;
        }
      // waiting on writable, as an indication of opened
      if (_runloop)
        {
          int i;

          for (i = 0; i < [_modes count]; i++)
            {
              NSString	*thisMode = [_modes objectAtIndex: i];

              [_runloop addEvent: (void*)(uintptr_t)_fd
			    type: ET_WDESC 
			 watcher: self
			 forMode: thisMode];
            }
        }
      [self _setStatus: NSStreamStatusOpening];
      return;
    }

 open_ok:
  // put itself to the runloop
  [super open];
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

- (void)close
{
  // read shutdown is ignored, because the other side may shutdown first.
  shutdown(_fd, SHUT_RD);
  // remove itself from the runloop, if any
  if (_runloop)
    {
      int i;

      for (i = 0; i < [_modes count]; i++)
        {
          NSString	*thisMode = [_modes objectAtIndex: i];

          if ([self streamStatus] == NSStreamStatusOpening)
            [_runloop removeEvent: (void*)(uintptr_t)_fd
			     type: ET_WDESC
			  forMode: thisMode
			      all: YES];
          else
            [self removeFromRunLoop: _runloop forMode: thisMode];
        }
    }
  // clean up 
  if ([_sibling streamStatus] == NSStreamStatusClosed)
    {
      close(_fd);
      _fd = -1;
    }
  [super close];
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  int readLen;

  readLen = read(_fd, buffer, len);
  if (readLen < 0)
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

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  NSAssert(!_runloop || _runloop == aRunLoop, 
    @"Attempt to schedule in more than one runloop.");
  ASSIGN(_runloop, aRunLoop);
  if (![_modes containsObject: mode])
    [_modes addObject: mode];
  if ([self _isOpened])
    {
      [_runloop addEvent: (void*)(uintptr_t)_fd
		    type: ET_RDESC
		 watcher: self
		 forMode: mode];
      [_runloop addEvent: (void*)(uintptr_t)_fd
		    type: ET_EDESC
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
          [_runloop removeEvent: (void*)(uintptr_t)_fd
			   type: ET_RDESC
			forMode: mode
			    all: YES];
          [_runloop removeEvent: (void*)(uintptr_t)_fd
			   type: ET_EDESC
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
  int		desc = (int)(uintptr_t)extra;
  NSStreamEvent myEvent;

  NSAssert(desc == _fd, @"Wrong file descriptor received.");
  if ([self streamStatus] == NSStreamStatusOpening)
    {
      int i, error;
      socklen_t len = sizeof(error);;
      int getReturn = getsockopt(_fd, SOL_SOCKET, SO_ERROR, &error, &len);

      if (getReturn >= 0 && !error && type == ET_WDESC)
        { // finish up the opening
          myEvent = NSStreamEventOpenCompleted;
          _passive = YES;
          [self open];
          // notify sibling
          [_sibling open];
          [_sibling _sendEvent: myEvent];
        }
      else // must be an error
        {
          if (error)
            errno = error;
          [self _recordError];
          myEvent = NSStreamEventErrorOccurred;
        }
      // clean up the event listener
      for (i = 0; i < [_modes count]; i++)
        {
          NSString	*thisMode = [_modes objectAtIndex: i];

          [_runloop removeEvent: (void*)(uintptr_t)_fd
			   type: ET_WDESC
			forMode: thisMode
			    all: YES];
        }
    }
  else 
    {
      if (type == ET_RDESC)
        {
          [self _setStatus: NSStreamStatusReading];
          myEvent = NSStreamEventHasBytesAvailable;
        }
      else   
        {    // must be an error then
          [self _recordError];
          myEvent = NSStreamEventErrorOccurred;
        }
    }
  [self _sendEvent: myEvent];
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

- (id) initToAddr: (NSString*)addr port: (int)port passive: (BOOL)passive
{

  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin_family = AF_INET;
      _peerAddr.sin_port = htons(port);
      _passive = passive;
      ptonReturn = inet_pton(AF_INET, addr_c, &(_peerAddr.sin_addr));
      if (ptonReturn == 0)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}

@end

@implementation GSInet6InputStream

- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_in6);
}

- (struct sockaddr*) peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port passive: (BOOL)passive
{
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin6_family = AF_INET6;
      _peerAddr.sin6_port = htons(port);
      _passive = passive;
      ptonReturn = inet_pton(AF_INET6, addr_c, &(_peerAddr.sin6_addr));
      if (ptonReturn == 0)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}

@end

@implementation GSLocalInputStream 

- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_un);
}

- (struct sockaddr*) peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr passive: (BOOL)passive
{
  const char* real_addr = [addr fileSystemRepresentation];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sun_family = AF_LOCAL;
      _passive = passive;
      if (strlen(real_addr)>sizeof(_peerAddr.sun_path)-1) // too long
	{
	  DESTROY(self);
	}
      else
	{
	  strncpy(_peerAddr.sun_path, real_addr, sizeof(_peerAddr.sun_path)-1);
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
      // so that unopened access will fail
      _fd = -1;
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
  writeLen = write(_fd, buffer, len);
  if (writeLen < 0)
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
  int flag = O_WRONLY | O_NONBLOCK | O_CREAT;
  mode_t mode = 0666;

  if (_shouldAppend)
    flag = flag | O_APPEND;
  else
    flag = flag | O_TRUNC;
  fd = open([_path fileSystemRepresentation], flag, mode);
  if (fd< 0)
    {  // make an error
      [self _recordError];
      return;
    }
  [super open];
  _fd = fd;
  // put it self to the runloop if we haven't do so.
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
  int closeReturn = close(_fd);
  if (closeReturn < 0)
    [self _recordError];
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
  _fd = -1;
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
      [_runloop addEvent: (void*)(uintptr_t)_fd
		    type: ET_WDESC
		 watcher: self
		 forMode: mode];
      [_runloop addEvent: (void*)(uintptr_t)_fd
		    type: ET_EDESC
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
          [_runloop removeEvent: (void*)(uintptr_t)_fd
			   type: ET_WDESC
			forMode: mode
			    all: YES];
          [_runloop removeEvent: (void*)(uintptr_t)_fd
			   type: ET_EDESC
			forMode: mode
			    all: YES];
        }
      if ([_modes count] == 0)
        DESTROY(_runloop);
    }
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      off_t offset = 0;

      if ([self _isOpened])
        offset = lseek(_fd, 0, SEEK_CUR);
      return [NSNumber numberWithLong: offset];
    }
  return [super propertyForKey: key];
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
  int		desc = (int)(uintptr_t)extra;
  NSStreamEvent myEvent;

  NSAssert(desc == _fd, @"Wrong file descriptor received.");
  if (type == ET_WDESC)
    {
      [self _setStatus: NSStreamStatusWriting];
      myEvent = NSStreamEventHasSpaceAvailable;
    }
  else   
    {    // must be an error then
      [self _recordError];
      myEvent = NSStreamEventErrorOccurred;
    }

  [self _sendEvent: myEvent];
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

- (void) setFd: (int)fd
{
  _fd = fd;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      // so that unopened access will fail
      _fd = -1;
      _sibling = nil;
      _passive = NO;
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
  writeLen = write(_fd, buffer, len);
  if (writeLen < 0)
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
      int connectReturn = connect(_fd, [self peerAddr], [self sockLen]);
      
      if (connectReturn < 0 && errno != EINPROGRESS)
        {// make an error
          [self _recordError];
          return;
        }
      // waiting on writable, as an indication of opened
      if (_runloop)
        {
          int i;
          for (i = 0; i < [_modes count]; i++)
            {
              NSString* thisMode = [_modes objectAtIndex: i];
              [_runloop addEvent: (void*)(uintptr_t)_fd type: ET_WDESC 
                        watcher: self forMode: thisMode];
            }
        }
      [self _setStatus: NSStreamStatusOpening];
      return;
    }

 open_ok:
  // put itself to the runloop
  [super open];
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
  // shutdown may fail (broken pipe). Record it.
  int closeReturn = shutdown(_fd, SHUT_WR);
  if (closeReturn < 0)
    [self _recordError];
  // remove itself from the runloop, if any
  if (_runloop)
    {
      int i;

      for (i = 0; i < [_modes count]; i++)
        {
          NSString	*thisMode = [_modes objectAtIndex: i];
          if ([self streamStatus] == NSStreamStatusOpening)
            [_runloop removeEvent: (void*)(uintptr_t)_fd
			     type: ET_WDESC
			  forMode: thisMode
			      all: YES];
          else
            [self removeFromRunLoop: _runloop forMode: thisMode];
        }
    }
  // clean up 
  if ([_sibling streamStatus] == NSStreamStatusClosed)
    {
      close(_fd);
      _fd = -1;
    }
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
      [_runloop addEvent: (void*)(uintptr_t)_fd
		    type: ET_WDESC
		 watcher: self
		 forMode: mode];
      [_runloop addEvent: (void*)(uintptr_t)_fd
		    type: ET_EDESC
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
          [_runloop removeEvent: (void*)(uintptr_t)_fd
			   type: ET_WDESC
			forMode: mode
			    all: YES];
          [_runloop removeEvent: (void*)(uintptr_t)_fd
			   type: ET_EDESC
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
  int		desc = (int)(uintptr_t)extra;
  NSStreamEvent myEvent;

  NSAssert(desc == _fd, @"Wrong file descriptor received.");
  if ([self streamStatus] == NSStreamStatusOpening)
    {
      int i, error;
      socklen_t len = sizeof(error);;
      int getReturn = getsockopt(_fd, SOL_SOCKET, SO_ERROR, &error, &len);

      if (getReturn >= 0 && !error && type == ET_WDESC)
        { // finish up the opening
          myEvent = NSStreamEventOpenCompleted;
          _passive = YES;
          [self open];
          // notify sibling
          [_sibling open];
          [_sibling _sendEvent: myEvent];
        }
      else // must be an error
        {
          if (error)
            errno = error;
          [self _recordError];
          myEvent = NSStreamEventErrorOccurred;
        }
      // clean up the event listener
      for (i = 0; i < [_modes count]; i++)
        {
          NSString	*thisMode = [_modes objectAtIndex: i];

          [_runloop removeEvent: (void*)(uintptr_t)_fd
			   type: ET_WDESC
			forMode: thisMode
			    all: YES];
        }
    }
  else 
    {
      if (type == ET_WDESC)
        {
          [self _setStatus: NSStreamStatusWriting];
          myEvent = NSStreamEventHasSpaceAvailable;
        }
      else   
        {    // must be an error then
          [self _recordError];
          myEvent = NSStreamEventErrorOccurred;
        }
    }

  [self _sendEvent: myEvent];
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

- (id) initToAddr: (NSString*)addr port: (int)port passive: (BOOL)passive
{
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin_family = AF_INET;
      _peerAddr.sin_port = htons(port);
      _passive = passive;
      ptonReturn = inet_pton(AF_INET, addr_c, &(_peerAddr.sin_addr));
      if (ptonReturn == 0)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}

@end

@implementation GSInet6OutputStream

- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_in6);
}

- (struct sockaddr*) peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port passive: (BOOL)passive
{
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin6_family = AF_INET6;
      _peerAddr.sin6_port = htons(port);
      _passive = passive;
      ptonReturn = inet_pton(AF_INET6, addr_c, &(_peerAddr.sin6_addr));
      if (ptonReturn == 0)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}

@end

@implementation GSLocalOutputStream 

- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_un);
}

- (struct sockaddr*) peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr passive: (BOOL)passive
{
  const char* real_addr = [addr fileSystemRepresentation];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sun_family = AF_LOCAL;
      _passive = passive;
      if (strlen(real_addr) > sizeof(_peerAddr.sun_path)-1) // too long
	{
	  DESTROY(self);
	}
      else
	{
	  strncpy(_peerAddr.sun_path, real_addr, sizeof(_peerAddr.sun_path)-1);
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
  int flags;

  // try ipv4 first
  ins = AUTORELEASE([[GSInetInputStream alloc]
    initToAddr: address port: port passive: NO]);
  outs = AUTORELEASE([[GSInetOutputStream alloc]
    initToAddr: address port: port passive: NO]);
  if (!ins)
    {
      ins = [[GSInet6InputStream alloc] initToAddr: address
					      port: port
					   passive: NO];
      outs = [[GSInet6OutputStream alloc] initToAddr: address
						port: port
					     passive: NO];
      sock = socket(PF_INET6, SOCK_STREAM, 0);
    }  
  else
    {
      sock = socket(PF_INET, SOCK_STREAM, 0);
    }

  // set nonblocking
  flags = fcntl(sock, F_GETFL, 0);
  fcntl(sock, F_SETFL, flags | O_NONBLOCK);

  [ins setFd: sock];
  [outs setFd: sock];
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

