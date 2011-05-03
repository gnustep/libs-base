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

#ifndef	AF_LOCAL
#define	AF_LOCAL	AF_UNIX
#endif
#ifndef	PF_LOCAL
#define	PF_LOCAL	PF_UNIX
#endif

#ifndef	socklen_t
#define	socklen_t	uint32_t
#endif

/** 
 * The concrete subclass of NSInputStream that reads from a file
 */
@interface GSFileInputStream : GSInputStream
{
@private
  NSString *_path;
}
@end

/** 
 * The abstract subclass of NSInputStream that reads from a socket
 */
@interface GSSocketInputStream : GSInputStream
{
@protected
  GSOutputStream *_sibling;
  BOOL _passive;              /* YES means already connected */
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

@interface GSInet6InputStream : GSSocketInputStream
{
  @private
#if	defined(AF_INET6)
  struct sockaddr_in6 _peerAddr;
#endif
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr port: (int)port;

@end

@interface GSLocalInputStream : GSSocketInputStream
{
  @private
  struct sockaddr_un _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr;

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
@end

/**
 * The concrete subclass of NSOutputStream that writes to a socket
 */
@interface GSSocketOutputStream : GSOutputStream
{
@protected
  GSInputStream *_sibling;
  BOOL _passive;              /* YES means already connected */
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

@interface GSInet6OutputStream : GSSocketOutputStream
{
  @private
#if	defined(AF_INET6)
  struct sockaddr_in6 _peerAddr;
#endif
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr port: (int)port;

@end

@interface GSLocalOutputStream : GSSocketOutputStream
{
  @private
  struct sockaddr_un _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr;

@end

/**
 * The concrete subclass of NSServerStream that accept connection from a socket
 */
@interface GSSocketServerStream : GSAbstractServerStream
/**
 * return the class of the inputStream associated with this
 * type of serverStream.
 */
- (Class) _inputStreamClass;
/**
 * return the class of the outputStream associated with this
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

@interface GSInet6ServerStream : GSSocketServerStream
{
  @private
#if	defined(AF_INET6)
  struct sockaddr_in6 _serverAddr;
#endif
}
@end

@interface GSLocalServerStream : GSSocketServerStream
@end

/**
 * set the file descriptor to non-blocking
 */
static void setNonblocking(int fd)
{
  int flags = fcntl(fd, F_GETFL, 0);
  fcntl(fd, F_SETFL, flags | O_NONBLOCK);
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
    {
      [self close];
    }
  DESTROY(_path);
  [super dealloc];
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  int readLen;

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte read write requested"];
    }

  _events &= ~NSStreamEventHasBytesAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }

  readLen = read((intptr_t)_loopID, buffer, len);
  if (readLen < 0 && errno != EAGAIN && errno != EINTR)
    {
      [self _recordError];
      readLen = -1;
    }
  else if (readLen == 0)
    {
      [self _setStatus: NSStreamStatusAtEnd];
      [self _sendEvent: NSStreamEventEndEncountered];
    }
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
        offset = lseek((intptr_t)_loopID, 0, SEEK_CUR);
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
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }
  _loopID = (void*)(intptr_t)fd;
  [super open];
}

- (void) close
{
  int closeReturn = close((intptr_t)_loopID);

  if (closeReturn < 0)
    [self _recordError];
  [super close];
}

- (void) _dispatch
{
  if ([self streamStatus] == NSStreamStatusOpen)
    {
      [self _sendEvent: NSStreamEventHasBytesAvailable];
    }
  else
    {
      NSLog(@"_dispatch with unexpected status %d", [self streamStatus]);
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
  _sibling = sibling;
}

- (void) setPassive: (BOOL)passive
{
  _passive = passive;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      // so that unopened access will fail
      _sibling = nil;
      _passive = NO;
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  [(GSSocketOutputStream*)_sibling setSibling: nil];
  _sibling = nil;
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
      int result;
      
      if (_runloop)
	{
	  setNonblocking((intptr_t)_loopID);
	}
      result = connect((intptr_t)_loopID, [self peerAddr], [self sockLen]);
      if (result < 0)
	{
	  if (errno == EINPROGRESS && _runloop != nil)
	    {
	      unsigned i = [_modes count];

	      /*
	       * Need to set the status first, so that the run loop can tell
	       * it needs to add the stream as waiting on writable, as an
	       * indication of opened
	       */
	      [self _setStatus: NSStreamStatusOpening];
	      while (i-- > 0)
		{
		  [_runloop addStream: self mode: [_modes objectAtIndex: i]];
		}
	      return;
	    }
          [self _recordError];
          [self _sendEvent: NSStreamEventErrorOccurred];
          return;
        }
    }

 open_ok:
  // put itself to the runloop
  [super open];
  setNonblocking((intptr_t)_loopID);
}

- (void) close
{
  // read shutdown is ignored, because the other side may shutdown first.
  if (!_sibling || [_sibling streamStatus] == NSStreamStatusClosed)
    close((intptr_t)_loopID);
  else
    shutdown((intptr_t)_loopID, SHUT_RD);
  [super close];
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  int readLen;

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte read write requested"];
    }

  _events &= ~NSStreamEventHasBytesAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }

  readLen = read((intptr_t)_loopID, buffer, len);
  if (readLen < 0 && errno != EAGAIN && errno != EINTR)
    {
      [self _recordError];
      readLen = -1;
    }
  else if (readLen == 0)
    {
      [self _setStatus: NSStreamStatusAtEnd];
      [self _sendEvent: NSStreamEventEndEncountered];
    }
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

- (void) _dispatch
{
  NSStreamEvent myEvent;

  if ([self streamStatus] == NSStreamStatusOpening)
    {
      int error;
      int result;
      socklen_t len = sizeof(error);
      unsigned i = [_modes count];

      while (i-- > 0)
	{
	  [_runloop removeStream: self mode: [_modes objectAtIndex: i]];
	}
      result
	= getsockopt((intptr_t)_loopID, SOL_SOCKET, SO_ERROR, &error, &len);

      if (result >= 0 && !error)
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
          [_sibling _recordError];
          [_sibling _sendEvent: myEvent];
        }
    }
  else if ([self streamStatus] == NSStreamStatusAtEnd)
    {
      myEvent = NSStreamEventEndEncountered;
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
      myEvent = NSStreamEventHasBytesAvailable;
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

- (id) initToAddr: (NSString*)addr port: (int)port
{

  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin_family = AF_INET;
      _peerAddr.sin_port = htons(port);
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
#if	defined(AF_INET6)
- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_in6);
}

- (struct sockaddr*) peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin6_family = AF_INET6;
      _peerAddr.sin6_port = htons(port);
      ptonReturn = inet_pton(AF_INET6, addr_c, &(_peerAddr.sin6_addr));
      if (ptonReturn == 0)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}
#else
- (id) initToAddr: (NSString*)addr port: (int)port
{
  RELEASE(self);
  return nil;
}
#endif
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

- (id) initToAddr: (NSString*)addr
{
  const char* real_addr = [addr fileSystemRepresentation];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sun_family = AF_LOCAL;
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
      _shouldAppend = shouldAppend;
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  RELEASE(_path);
  [super dealloc];
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  int writeLen;

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte length write requested"];
    }

  _events &= ~NSStreamEventHasSpaceAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }

  writeLen = write((intptr_t)_loopID, buffer, len);
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
  int flag = O_WRONLY | O_NONBLOCK | O_CREAT;
  mode_t mode = 0666;

  if (_shouldAppend)
    flag = flag | O_APPEND;
  else
    flag = flag | O_TRUNC;
  fd = open([_path fileSystemRepresentation], flag, mode);
  if (fd < 0)
    {  // make an error
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }
  _loopID = (void*)(intptr_t)fd;
  [super open];
}

- (void) close
{
  int closeReturn = close((intptr_t)_loopID);
  if (closeReturn < 0)
    [self _recordError];
  [super close];
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      off_t offset = 0;

      if ([self _isOpened])
        offset = lseek((intptr_t)_loopID, 0, SEEK_CUR);
      return [NSNumber numberWithLong: offset];
    }
  return [super propertyForKey: key];
}

- (void) _dispatch
{
  if ([self streamStatus] == NSStreamStatusOpen)
    {
      [self _sendEvent: NSStreamEventHasSpaceAvailable];
    }
  else
    {
      NSLog(@"_dispatch with unexpected status %d", [self streamStatus]);
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
  _sibling = sibling;
}

- (void) setPassive: (BOOL)passive
{
  _passive = passive;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _sibling = nil;
      _passive = NO;
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  [(GSSocketInputStream*)_sibling setSibling: nil];
  _sibling = nil;
  [super dealloc];
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  int writeLen;

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte length write requested"];
    }

  _events &= ~NSStreamEventHasSpaceAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }

  writeLen = write((intptr_t)_loopID, buffer, len);
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
      int result;
      
      if (_runloop)
	{
	  setNonblocking((intptr_t)_loopID);
	}
      result = connect((intptr_t)_loopID, [self peerAddr], [self sockLen]);
      if (result < 0)
	{
	  if (errno == EINPROGRESS && _runloop != nil)
	    {
	      unsigned i = [_modes count];

	      /*
	       * Need to set the status first, so that the run loop can tell
	       * it needs to add the stream as waiting on writable, as an
	       * indication of opened
	       */
	      [self _setStatus: NSStreamStatusOpening];
	      while (i-- > 0)
		{
		  [_runloop addStream: self mode: [_modes objectAtIndex: i]];
		}
	      return;
	    }
          [self _recordError];
          [self _sendEvent: NSStreamEventErrorOccurred];
          return;
        }
    }

 open_ok:
  // put itself to the runloop
  [super open];
  setNonblocking((intptr_t)_loopID);
}

- (void) close
{
  // shutdown may fail (broken pipe). Record it.
  int closeReturn;
  if (!_sibling || [_sibling streamStatus]==NSStreamStatusClosed)
    closeReturn = close((intptr_t)_loopID);
  else
    closeReturn = shutdown((intptr_t)_loopID, SHUT_WR);
  if (closeReturn < 0)
    [self _recordError];
  [super close];
}

- (void) _dispatch
{
  NSStreamEvent myEvent;

  if ([self streamStatus] == NSStreamStatusOpening)
    {
      int error;
      socklen_t len = sizeof(error);
      int result;
      unsigned i = [_modes count];

      while (i-- > 0)
	{
	  [_runloop removeStream: self mode: [_modes objectAtIndex: i]];
	}
      result
	= getsockopt((intptr_t)_loopID, SOL_SOCKET, SO_ERROR, &error, &len);
      if (result >= 0 && !error)
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
          [_sibling _recordError];
          [_sibling _sendEvent: myEvent];
        }
    }
  else if ([self streamStatus] == NSStreamStatusAtEnd)
    {
      myEvent = NSStreamEventEndEncountered;
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
      myEvent = NSStreamEventHasSpaceAvailable;
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

- (id) initToAddr: (NSString*)addr port: (int)port
{
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin_family = AF_INET;
      _peerAddr.sin_port = htons(port);
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
#if	defined(AF_INET6)
- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_in6);
}

- (struct sockaddr*) peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin6_family = AF_INET6;
      _peerAddr.sin6_port = htons(port);
      ptonReturn = inet_pton(AF_INET6, addr_c, &(_peerAddr.sin6_addr));
      if (ptonReturn == 0)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}
#else
- (id) initToAddr: (NSString*)addr port: (int)port
{
  RELEASE(self);
  return nil;
}
#endif
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

- (id) initToAddr: (NSString*)addr
{
  const char* real_addr = [addr fileSystemRepresentation];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sun_family = AF_LOCAL;
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

  // try ipv4 first
  ins = AUTORELEASE([[GSInetInputStream alloc]
    initToAddr: address port: port]);
  outs = AUTORELEASE([[GSInetOutputStream alloc]
    initToAddr: address port: port]);
  if (!ins)
    {
#if	defined(PF_INET6)
      ins = [[GSInet6InputStream alloc] initToAddr: address
                                        port: port];
      outs = [[GSInet6OutputStream alloc] initToAddr: address
                                          port: port];
      sock = socket(PF_INET6, SOCK_STREAM, 0);
#else
      sock = -1;
#endif
    }  
  else
    {
      sock = socket(PF_INET, SOCK_STREAM, 0);
    }

  NSAssert(sock >= 0, @"Cannot open socket");
  [ins _setLoopID: (void*)(intptr_t)sock];
  [outs _setLoopID: (void*)(intptr_t)sock];
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
  GSSocketInputStream *ins = nil;
  GSSocketOutputStream *outs = nil;
  int sock;

  ins = AUTORELEASE([[GSLocalInputStream alloc] initToAddr: path]);
  outs = AUTORELEASE([[GSLocalOutputStream alloc] initToAddr: path]);
  sock = socket(PF_LOCAL, SOCK_STREAM, 0);

  NSAssert(sock >= 0, @"Cannot open socket");
  [ins _setLoopID: (void*)(intptr_t)sock];
  [outs _setLoopID: (void*)(intptr_t)sock];
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

+ (void) pipeWithInputStream: (NSInputStream **)inputStream 
                outputStream: (NSOutputStream **)outputStream
{
  GSSocketInputStream *ins = nil;
  GSSocketOutputStream *outs = nil;
  int fds[2];
  int pipeReturn;

  // the type of the stream does not matter, since we are only using the fd
  ins = AUTORELEASE([GSLocalInputStream new]);
  outs = AUTORELEASE([GSLocalOutputStream new]);
  pipeReturn = pipe(fds);

  NSAssert(pipeReturn >= 0, @"Cannot open pipe");
  [ins _setLoopID: (void*)(intptr_t)fds[0]];
  [outs _setLoopID: (void*)(intptr_t)fds[1]];
  // no need to connect
  [ins setPassive: YES];
  [outs setPassive: YES];
  if (inputStream)
    *inputStream = ins;
  if (outputStream)
    *outputStream = outs;
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
  return AUTORELEASE([[GSDataInputStream alloc] initWithData: data]);
}

+ (id) inputStreamWithFileAtPath: (NSString *)path
{
  return AUTORELEASE([[GSFileInputStream alloc] initWithFileAtPath: path]);
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

- (id) initWithData: (NSData *)data
{
  RELEASE(self);
  return [[GSDataInputStream alloc] initWithData: data];
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

@end

@implementation NSOutputStream

+ (id) outputStreamToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity
{
  return AUTORELEASE([[GSBufferOutputStream alloc] 
    initToBuffer: buffer capacity: capacity]);  
}

+ (id) outputStreamToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  return AUTORELEASE([[GSFileOutputStream alloc]
    initToFileAtPath: path append: shouldAppend]);
}

+ (id) outputStreamToMemory
{
  return AUTORELEASE([[GSDataOutputStream alloc] init]);  
}

- (BOOL) hasSpaceAvailable
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) initToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity
{
  RELEASE(self);
  return [[GSBufferOutputStream alloc] initToBuffer: buffer capacity: capacity];
}

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  RELEASE(self);
  return [[GSFileOutputStream alloc] initToFileAtPath: path
					       append: shouldAppend];  
}

- (id) initToMemory
{
  RELEASE(self);
  return [[GSDataOutputStream alloc] init];
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  [self subclassResponsibility: _cmd];
  return -1;  
}

@end

@implementation GSServerStream

+ (id) serverStreamToAddr: (NSString*)addr port: (int)port
{
  GSServerStream *s;

  // try inet first, then inet6
  s = [[GSInetServerStream alloc] initToAddr: addr port: port];
  if (!s)
    s = [[GSInet6ServerStream alloc] initToAddr: addr port: port];
  return AUTORELEASE(s);
}

+ (id) serverStreamToAddr: (NSString*)addr
{
  return AUTORELEASE([[GSLocalServerStream alloc] initToAddr: addr]);
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  RELEASE(self);
  // try inet first, then inet6
  self = [[GSInetServerStream alloc] initToAddr: addr port: port];
  if (!self)
    self = [[GSInet6ServerStream alloc] initToAddr: addr port: port];
  return self;
}

- (id) initToAddr: (NSString*)addr
{
  RELEASE(self);
  return [[GSLocalServerStream alloc] initToAddr: addr];
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

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
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

#define SOCKET_BACKLOG 256

- (void) open
{
  int bindReturn;
  int listenReturn;

#ifndef	BROKEN_SO_REUSEADDR
  /*
   * Under decent systems, SO_REUSEADDR means that the port can be reused
   * immediately that this process exits.  Under some it means
   * that multiple processes can serve the same port simultaneously.
   * We don't want that broken behavior!
   */
  int	status = 1;

  setsockopt((int)(intptr_t)_loopID, SOL_SOCKET, SO_REUSEADDR,
    (char *)&status, sizeof(status));
#endif

  bindReturn = bind((int)(intptr_t)_loopID, [self serverAddr], [self sockLen]);
  listenReturn = listen((intptr_t)_loopID, SOCKET_BACKLOG);
  if (bindReturn < 0 || listenReturn < 0)
    {
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }
  setNonblocking((intptr_t)_loopID);
  // put itself to the runloop
  [super open];
}

- (void) close
{
  // close a server socket is safe
  close((intptr_t)_loopID);
  [super close];
}

- (void) acceptWithInputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream
{
  GSSocketInputStream *ins = AUTORELEASE([[self _inputStreamClass] new]);
  GSSocketOutputStream *outs = AUTORELEASE([[self _outputStreamClass] new]);
  socklen_t len = [ins sockLen];
  int acceptReturn = accept((intptr_t)_loopID, [ins peerAddr], &len);

  _events &= ~NSStreamEventHasBytesAvailable;
  if (acceptReturn < 0)
    { // test for real error
      if (errno != EWOULDBLOCK
#if	defined(EAGAIN)
	&& errno != EAGAIN
#endif
#if	defined(ECONNABORTED)
	&& errno != ECONNABORTED
#endif
#if	defined(EPROTO)
	&& errno != EPROTO
#endif
	&& errno != EINTR)
	{
          [self _recordError];
	}
      ins = nil;
      outs = nil;
    }
  else
    {
      // no need to connect again
      [ins setPassive: YES];
      [outs setPassive: YES];
      // copy the addr to outs
      memcpy([outs peerAddr], [ins peerAddr], len);
      [ins _setLoopID: (void*)(intptr_t)acceptReturn];
      [outs _setLoopID: (void*)(intptr_t)acceptReturn];
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

- (void) _dispatch
{
  NSStreamEvent myEvent;

  [self _setStatus: NSStreamStatusOpen];
  myEvent = NSStreamEventHasBytesAvailable;
  [self _sendEvent: myEvent];
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
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  [super init];
  _serverAddr.sin_family = AF_INET;
  _serverAddr.sin_port = htons(port);
  ptonReturn = inet_pton(AF_INET, addr_c, &(_serverAddr.sin_addr));
  _loopID = (void*)(intptr_t)socket(AF_INET, SOCK_STREAM, 0);
  if (ptonReturn == 0 || _loopID < 0)   // error
    {
      RELEASE(self);
      return nil;
    }
  NSAssert(_loopID >= 0, @"cannot open socket");
  return self;
}

@end

@implementation GSInet6ServerStream
#if	defined(AF_INET6)
- (Class) _inputStreamClass
{
  return [GSInet6InputStream class];
}

- (Class) _outputStreamClass
{
  return [GSInet6OutputStream class];
}

- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_in6);
}

- (struct sockaddr*) serverAddr
{
  return (struct sockaddr*)&_serverAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  [super init];
  _serverAddr.sin6_family = AF_INET6;
  _serverAddr.sin6_port = htons(port);
  ptonReturn = inet_pton(AF_INET6, addr_c, &(_serverAddr.sin6_addr));
  _loopID = (void*)(intptr_t)socket(AF_INET6, SOCK_STREAM, 0);
  if (ptonReturn == 0 || _loopID < 0)   // error
    {
      RELEASE(self);
      return nil;
    }
  NSAssert(_loopID >= 0, @"cannot open socket");
  return self;
}
#else
- (id) initToAddr: (NSString*)addr port: (int)port
{
  RELEASE(self);
  return nil;
}
#endif
@end

@implementation GSLocalServerStream 

- (Class) _inputStreamClass
{
  return [GSLocalInputStream class];
}

- (Class) _outputStreamClass
{
  return [GSLocalOutputStream class];
}

- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_un);
}

- (struct sockaddr*) serverAddr
{
  return (struct sockaddr*)&_serverAddr;
}

- (id) initToAddr: (NSString*)addr
{
  const char* real_addr = [addr fileSystemRepresentation];
  [super init];
  _serverAddr.sun_family = AF_LOCAL;
  _loopID = (void *)(intptr_t)socket(AF_LOCAL, SOCK_STREAM, 0);
  if (strlen(real_addr) > sizeof(_serverAddr.sun_path)-1 || _loopID < 0)
    {
      RELEASE(self);
      return nil;
    }
  strncpy(_serverAddr.sun_path, real_addr, sizeof(_serverAddr.sun_path)-1);
  return self;
}

@end

