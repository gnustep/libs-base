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
#include <Foundation/NSProcessInfo.h>

#include "../GSStream.h"

#define	BUFFERSIZE	(BUFSIZ*64)

typedef int socklen_t;

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
 * The concrete subclass of NSInputStream that reads from a pipe
 */
@interface GSPipeInputStream : GSInputStream
{
  HANDLE	handle;
  OVERLAPPED	ov;
  uint8_t	data[BUFFERSIZE];
  unsigned	offset;	// Read pointer within buffer
  unsigned	length;	// Amount of data in buffer
  unsigned	want;	// Amount of data we want to read.
  DWORD		size;	// Number of bytes returned by read.
}
- (NSStreamStatus) _check;
- (void) _queue;
- (void) _setHandle: (HANDLE)h;
@end

@class GSSocketOutputStream;
/** 
 * The abstract subclass of NSInputStream that reads from a socket
 */
@interface GSSocketInputStream : GSInputStream
{
@protected
  GSSocketOutputStream *_sibling;
  BOOL _passive;              /* YES means already connected */
  SOCKET  _sock;
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

- (void) setEvent: (WSAEVENT)event;
- (void) setSock: (SOCKET)sock;

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
@end

/** 
 * The concrete subclass of NSOutputStream that reads from a pipe
 */
@interface GSPipeOutputStream : GSOutputStream
{
  HANDLE	handle;
  OVERLAPPED	ov;
  uint8_t	data[BUFFERSIZE];
  unsigned	offset;
  unsigned	want;
  DWORD		size;
}
- (NSStreamStatus) _check;
- (void) _queue;
- (void) _setHandle: (HANDLE)h;
@end

/**
 * The concrete subclass of NSOutputStream that writes to a socket
 */
@interface GSSocketOutputStream : GSOutputStream
{
@protected
  GSSocketInputStream *_sibling;
  BOOL _passive;               /* YES means already connected */
  SOCKET  _sock;
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
- (void) setSock: (SOCKET)sock;

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
@interface GSSocketServerStream : GSAbstractServerStream
{
  SOCKET	_sock;
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

- (void) close
{
  if (_loopID != (void*)INVALID_HANDLE_VALUE)
    {
      if (CloseHandle((HANDLE)_loopID) == 0)
	{
          [self _recordError];
	}
    }
  [super close];
  _loopID = (void*)INVALID_HANDLE_VALUE;
}

- (void) dealloc
{
  if ([self _isOpened])
    [self close];
  RELEASE(_path);
  [super dealloc];
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

- (id) initWithFileAtPath: (NSString *)path
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_path, path);
    }
  return self;
}

- (void) open
{
  HANDLE	h;

  h = (void*)CreateFileW([_path fileSystemRepresentation],
    GENERIC_READ,
    FILE_SHARE_READ,
    0,
    OPEN_EXISTING,
    0,
    0);
  if (h == INVALID_HANDLE_VALUE)
    {
      [self _recordError];
      return;
    }
  [self _setLoopID: (void*)h];
  [super open];
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      DWORD offset = 0;

      if ([self _isOpened])
        offset = SetFilePointer((HANDLE)_loopID, 0, 0, FILE_CURRENT);
      return [NSNumber numberWithLong: (long)offset];
    }
  return [super propertyForKey: key];
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  DWORD readLen;

  _unhandledData = NO;
  if (ReadFile((HANDLE)_loopID, buffer, len, &readLen, NULL) == 0)
    {
      [self _recordError];
      return -1;
    }
  else if (readLen == 0)
    {
      [self _setStatus: NSStreamStatusAtEnd];
    }
  return (int)readLen;
}


- (void) _dispatch
{
  BOOL av = [self hasBytesAvailable];
  NSStreamEvent myEvent = av ? NSStreamEventHasBytesAvailable : 
    NSStreamEventEndEncountered;
  NSStreamStatus myStatus = av ? NSStreamStatusOpen : 
    NSStreamStatusAtEnd;
  
  [self _setStatus: myStatus];
  [self _sendEvent: myEvent];
}

@end

@implementation GSPipeInputStream

- (void) close
{
  if (want > 0 && handle != INVALID_HANDLE_VALUE)
    {
      want = 0;
      CancelIo(handle);
    }
  if (_loopID != INVALID_HANDLE_VALUE)
    {
      CloseHandle((HANDLE)_loopID);
    }
  if (handle != INVALID_HANDLE_VALUE)
    {
      if (CloseHandle(handle) == 0)
	{
	  [self _recordError];
	}
    }
  length = offset = 0;
  [super close];
  handle = INVALID_HANDLE_VALUE;
  _loopID = (void*)INVALID_HANDLE_VALUE;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  [super dealloc];
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len
{
  if (offset < length)
    {
      *buffer  = data + offset;
      *len = length - offset;
    }
  return NO;
}

- (BOOL) hasBytesAvailable
{
  if ([self _isOpened] && [self streamStatus] != NSStreamStatusAtEnd)
    return YES;
  return NO;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      handle = INVALID_HANDLE_VALUE;
      _loopID = (void*)INVALID_HANDLE_VALUE;
    }
  return self;
}

- (void) open
{
  if (_loopID == (void*)INVALID_HANDLE_VALUE)
    {
      _loopID = (void*)CreateEvent(NULL, FALSE, FALSE, NULL);
    }
  [super open];
  [self _queue];
}

- (NSStreamStatus) _check
{
  // Must only be called when current status is NSStreamStatusReading.

  if (GetOverlappedResult(handle, &ov, &size, TRUE) == 0)
    {
      errno = GetLastError();
      if (errno == ERROR_HANDLE_EOF
	|| errno == ERROR_BROKEN_PIPE)
	{
	  /*
	   * Got EOF, but we don't want to register it until a
	   * -read:maxLength: is called.
	   */
	  offset = length = want = 0;
	  [self _setStatus: NSStreamStatusOpen];
	}
      else if (errno != ERROR_IO_PENDING)
	{
	  /*
	   * Got an error ... record it.
	   */
	  want = 0;
	  [self _recordError];
	}
    }
  else
    {
      /*
       * Read completed and some data was read.
       */
      length = size;
      [self _setStatus: NSStreamStatusOpen];
    }
  return [self streamStatus];
}

- (void) _queue
{
  if ([self streamStatus] == NSStreamStatusOpen)
    {
      int	rc;

      want = sizeof(data);
      ov.Offset = 0;
      ov.OffsetHigh = 0;
      ov.hEvent = (HANDLE)_loopID;
      rc = ReadFile(handle, data, want, &size, &ov);
      if (rc != 0)
	{
	  // Read succeeded
	  want = 0;
	  length = size;
	  if (length == 0)
	    {
	      [self _setStatus: NSStreamStatusAtEnd];
	    }
	}
      else if ((errno = GetLastError()) == ERROR_HANDLE_EOF
        || errno == ERROR_BROKEN_PIPE)
	{
	  offset = length = 0;
	  [self _setStatus: NSStreamStatusOpen];	// Read of zero length
	}
      else if (errno != ERROR_IO_PENDING)
	{
          [self _recordError];
	}
      else
	{
	  [self _setStatus: NSStreamStatusReading];
	}
    }
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  NSStreamStatus myStatus = [self streamStatus];

  _unhandledData = NO;
  if (myStatus == NSStreamStatusReading)
    {
      myStatus = [self _check];
    }
  if (myStatus == NSStreamStatusAtEnd)
    {
      return 0;		// At EOF
    }
  if (len <= 0
    || (myStatus != NSStreamStatusReading && myStatus != NSStreamStatusOpen))
    {
      return -1;	// Bad length or status
    }
  if (offset == length)
    {
      if (myStatus == NSStreamStatusOpen)
	{
	  /*
	   * There is no buffered data and no read in progress,
	   * so we must be at EOF.
	   */
	  [self _setStatus: NSStreamStatusAtEnd];
	  return 0;
	}
      return -1;	// Waiting for read.
    }
  /*
   * We already have data buffered ... return some or all of it.
   */
  if (len > (length - offset))
    {
      len = length - offset;
    }
  memcpy(buffer, data, len);
  offset += len;
  if (offset == length && myStatus == NSStreamStatusOpen)
    {
      length = 0;
      offset = 0;
      [self _queue];	// Queue another read
    }
  return len;
}

- (void) _setHandle: (HANDLE)h
{
  handle = h;
}

- (void) _dispatch
{
  NSStreamEvent myEvent;
  NSStreamStatus oldStatus = [self streamStatus];
  NSStreamStatus myStatus = oldStatus;

  if (myStatus == NSStreamStatusReading
    || myStatus == NSStreamStatusOpening)
    {
      myStatus = [self _check];
    }

  if (myStatus == NSStreamStatusAtEnd)
    {
      myEvent = NSStreamEventEndEncountered;
    }
  else if (myStatus == NSStreamStatusError)
    {
      myEvent = NSStreamEventErrorOccurred;
    }
  else if (oldStatus == NSStreamStatusOpening)
    {
      myEvent = NSStreamEventOpenCompleted;
    }
  else
    {
      myEvent = NSStreamEventHasBytesAvailable;
    }

  [self _sendEvent: myEvent];
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  NSStreamStatus myStatus = [self streamStatus];

  if (_unhandledData == YES || myStatus == NSStreamStatusError)
    {
      *trigger = NO;
      return NO;
    }
  *trigger = YES;
  if (myStatus == NSStreamStatusReading)
    {
      return YES;	// Need to wait for I/O
    }
  return NO;		// Need to signal for an event
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
  _loopID = event;
}

- (void) setSock: (SOCKET)sock
{
  _sock = sock;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _sibling = nil;
      _passive = NO;
      _loopID = WSA_INVALID_EVENT;
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
      int connectReturn = connect(_sock, [self peerAddr], [self sockLen]);
      
      if (connectReturn == SOCKET_ERROR
	&& WSAGetLastError() != WSAEWOULDBLOCK)
        {// make an error
          [self _recordError];
          return;
        }
      // waiting on writable, as an indication of opened
      if (_runloop)
        {
          unsigned i = [_modes count];
          
          WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
          while (i-- > 0)
            {
              [_runloop addStream: self mode: [_modes objectAtIndex: i]];
            }
        }
      [self _setStatus: NSStreamStatusOpening];
      return;
    }

 open_ok: 
  [super open];
  setNonblocking(_sock);
  WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
}

- (void) close
{
  // read shutdown is ignored, because the other side may shutdown first.
  if (_sibling && [_sibling streamStatus] != NSStreamStatusClosed)
    {
      shutdown(_sock, SD_RECEIVE);
    }
  else
    {
      WSACloseEvent(_loopID);
      closesocket(_sock);
    }
  [super close];
  _loopID = WSA_INVALID_EVENT;
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  int readLen;

  _unhandledData = NO;
  readLen = recv(_sock, buffer, len, 0);
  if (readLen == SOCKET_ERROR)
    {
      errno = WSAGetLastError();
      if (errno == WSAEINPROGRESS || errno == WSAEWOULDBLOCK)
	{
	  [self _setStatus: NSStreamStatusReading];
	}
      else if (errno != WSAEINTR) 
	{
	  [self _recordError];
	}
      readLen = -1;
    }
  else if (readLen == 0)
    {
      [self _setStatus: NSStreamStatusAtEnd];
    }
  else 
    {
      [self _setStatus: NSStreamStatusOpen];
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
  if ([self streamStatus] == NSStreamStatusClosed)
    {
      /*
       * It is possible the stream is closed yet recieving event because
       * of not closed sibling
       */
      NSAssert([_sibling streamStatus] != NSStreamStatusClosed, 
	@"Received event for closed stream");
      [_sibling _dispatch];
    }
  else
    {
      WSANETWORKEVENTS events;
      int error = 0;
      int getReturn = -1;

      if (WSAEnumNetworkEvents(_sock, _loopID, &events) == SOCKET_ERROR)
	{
	  error = WSAGetLastError();
	}
//else NSLog(@"EVENTS 0x%x", events.lNetworkEvents);

      if ([self streamStatus] == NSStreamStatusOpening)
	{
	  unsigned	i = [_modes count];

	  while (i-- > 0)
	    {
	      [_runloop removeStream: self mode: [_modes objectAtIndex: i]];
	    }
	  if (error == 0)
	    {
	      unsigned len = sizeof(error);

	      getReturn = getsockopt(_sock, SOL_SOCKET, SO_ERROR,
		(char*)&error, &len);
	    }

	  if (getReturn >= 0 && error == 0
	    && (events.lNetworkEvents & FD_CONNECT))
	    { // finish up the opening
	      _passive = YES;
	      [self open];
	      // notify sibling
	      if (_sibling)
		{
		  [_sibling open];
		  [_sibling _sendEvent: NSStreamEventOpenCompleted];
		}
	      [self _sendEvent: NSStreamEventOpenCompleted];
	    }
	}

      if (error != 0)
	{
	  errno = error;
	  [self _recordError];
	  [_sibling _recordError];
	  [self _sendEvent: NSStreamEventErrorOccurred];
	  [_sibling _sendEvent: NSStreamEventErrorOccurred];
	}
      else
	{
	  if (events.lNetworkEvents & FD_WRITE)
	    {
	      [_sibling _setStatus: NSStreamStatusOpen];
	      while ([_sibling hasSpaceAvailable]
		&& [_sibling _unhandledData] == NO)
		{
	          [_sibling _sendEvent: NSStreamEventHasSpaceAvailable];
		}
	    }
	  if (events.lNetworkEvents & FD_READ)
	    {
	      [self _setStatus: NSStreamStatusOpen];
	      while ([self hasBytesAvailable]
		&& _unhandledData == NO)
		{
	          [self _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	  if (events.lNetworkEvents & FD_CLOSE)
	    {
	      [_sibling _setStatus: NSStreamStatusAtEnd];
	      [_sibling _sendEvent: NSStreamEventEndEncountered];
	      while ([self hasBytesAvailable]
		&& _unhandledData == NO)
		{
		  [self _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	}
    }
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  *trigger = YES;
  return YES;
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

- (void) close
{
  if (_loopID != (void*)INVALID_HANDLE_VALUE)
    {
      if (CloseHandle((HANDLE)_loopID) == 0)
	{
          [self _recordError];
	}
    }
  [super close];
  _loopID = (void*)INVALID_HANDLE_VALUE;
}

- (void) dealloc
{
  if ([self _isOpened])
    [self close];
  RELEASE(_path);
  [super dealloc];
}

- (BOOL) hasSpaceAvailable
{
  if ([self _isOpened])
    return YES;
  return NO;
}

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_path, path);
      _shouldAppend = shouldAppend;
    }
  return self;
}

- (void) open
{
  HANDLE	h;

  h = (void*)CreateFileW([_path fileSystemRepresentation],
    GENERIC_WRITE,
    FILE_SHARE_WRITE,
    0,
    OPEN_ALWAYS,
    0,
    0);
  if (h == INVALID_HANDLE_VALUE)
    {
      [self _recordError];
      return;
    }
  else if (_shouldAppend == NO)
    {
      if (SetEndOfFile(h) == 0)	// Truncate to current file pointer (0)
	{
          [self _recordError];
	}
    }
  [self _setLoopID: (void*)h];
  [super open];
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      DWORD offset = 0;

      if ([self _isOpened])
        offset = SetFilePointer((HANDLE)_loopID, 0, 0, FILE_CURRENT);
      return [NSNumber numberWithLong: (long)offset];
    }
  return [super propertyForKey: key];
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  DWORD writeLen;

  _unhandledData = NO;
  if (_shouldAppend == YES)
    {
      SetFilePointer((HANDLE)_loopID, 0, 0, FILE_END);
    }
  if (WriteFile((HANDLE)_loopID, buffer, len, &writeLen, NULL) == 0)
    {
      [self _recordError];
      return -1;
    }
  return (int)writeLen;
}

- (void) _dispatch
{
  BOOL av = [self hasSpaceAvailable];
  NSStreamEvent myEvent = av ? NSStreamEventHasSpaceAvailable : 
    NSStreamEventEndEncountered;

  [self _sendEvent: myEvent];
}

@end

@implementation GSPipeOutputStream

- (void) close
{
  if (_loopID != INVALID_HANDLE_VALUE)
    {
      CloseHandle((HANDLE)_loopID);
    }
  if (handle != INVALID_HANDLE_VALUE)
    {
      if (CloseHandle(handle) == 0)
	{
	  [self _recordError];
	}
    }
  offset = want = 0;
  [super close];
  _loopID = (void*)INVALID_HANDLE_VALUE;
  handle = INVALID_HANDLE_VALUE;
}

- (void) dealloc
{
  if ([self _isOpened])
    [self close];
  [super dealloc];
}

- (BOOL) hasSpaceAvailable
{
  if ([self _isOpened] && [self streamStatus] != NSStreamStatusWriting)
    return YES;
  return NO;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      handle = INVALID_HANDLE_VALUE;
      _loopID = (void*)INVALID_HANDLE_VALUE;
    }
  return self;
}

- (void) open
{
  if (_loopID == (void*)INVALID_HANDLE_VALUE)
    {
      _loopID = (void*)CreateEvent(NULL, FALSE, FALSE, NULL);
    }
  [super open];
}

- (void) _queue
{
  NSStreamStatus myStatus = [self streamStatus];

  if (myStatus == NSStreamStatusOpen)
    {
      while (offset < want)
	{
	  int	rc;

	  ov.Offset = 0;
	  ov.OffsetHigh = 0;
	  ov.hEvent = (HANDLE)_loopID;
	  size = 0;
	  rc = WriteFile(handle, data + offset, want - offset, &size, &ov);
	  if (rc != 0)
	    {
	      offset += size;
	    }
	  else if ((errno = GetLastError()) == ERROR_IO_PENDING)
	    {
	      [self _setStatus: NSStreamStatusWriting];
	      break;
	    }
	  else
	    {
	      [self _recordError];
	      break;
	    }
	}
    }
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  NSStreamStatus myStatus = [self streamStatus];

  _unhandledData = NO;
  if (len < 0)
    {
      return -1;
    }
  if (myStatus == NSStreamStatusWriting)
    {
      myStatus = [self _check];
    }
  if ((myStatus != NSStreamStatusOpen && myStatus != NSStreamStatusWriting))
    {
      return -1;
    }
  if (len > (sizeof(data) - offset))
    {
      len = sizeof(data) - offset;
    }
  if (len > 0)
    {
      memcpy(data + offset, buffer, len);
      want = offset + len;
      [self _queue];
    }
  return len;
}

- (NSStreamStatus) _check
{
  // Must only be called when current status is NSStreamStatusWriting.
  if (GetOverlappedResult(handle, &ov, &size, TRUE) == 0)
    {
      errno = GetLastError();
      if (errno != ERROR_IO_PENDING)
	{
          offset = 0;
          want = 0;
          [self _recordError];
	}
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
      offset += size;
      if (offset <= want)
	{
	  [self _queue];
	}
    }
  return [self streamStatus];
}

- (void) _setHandle: (HANDLE)h
{
  handle = h;
}

- (void) _dispatch
{
  NSStreamEvent myEvent;
  NSStreamStatus oldStatus = [self streamStatus];
  NSStreamStatus myStatus = oldStatus;

  if (myStatus == NSStreamStatusWriting
    || myStatus == NSStreamStatusOpening)
    {
      myStatus = [self _check];
    }

  if (myStatus == NSStreamStatusAtEnd)
    {
      myEvent = NSStreamEventEndEncountered;
    }
  else if (myStatus == NSStreamStatusError)
    {
      myEvent = NSStreamEventErrorOccurred;
    }
  else if (oldStatus == NSStreamStatusOpening)
    {
      myEvent = NSStreamEventOpenCompleted;
    }
  else
    {
      myEvent = NSStreamEventHasSpaceAvailable;
    }

  [self _sendEvent: myEvent];
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  NSStreamStatus myStatus = [self streamStatus];

  if (_unhandledData == YES || myStatus == NSStreamStatusError)
    {
      *trigger = NO;
      return NO;
    }
  *trigger = YES;
  if (myStatus == NSStreamStatusWriting)
    {
      return YES;
    }
  return NO;
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
  _loopID = event;
}

- (void) setSock: (SOCKET)sock
{
  _sock = sock;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _sibling = nil;
      _passive = NO;
      _loopID = WSA_INVALID_EVENT;
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

  _unhandledData = NO;
  writeLen = send(_sock, buffer, len, 0);
  if (writeLen == SOCKET_ERROR)
    {
      errno = WSAGetLastError();
      if (errno == WSAEINPROGRESS || errno == WSAEWOULDBLOCK)
	{
          [self _setStatus: NSStreamStatusWriting];
	}
      else if (errno != WSAEINTR)
	{
          [self _recordError];
	}
      writeLen = -1;
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
    }
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
      int connectReturn = connect(_sock, [self peerAddr], [self sockLen]);
      
      if (connectReturn == SOCKET_ERROR
	&& WSAGetLastError() != WSAEWOULDBLOCK)
        {// make an error
          [self _recordError];
          return;
        }
      // waiting on writable, as an indication of opened
      if (_runloop)
        {
          unsigned i = [_modes count];

          WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);

          while (i-- > 0)
            {
              [_runloop addStream: self mode: [_modes objectAtIndex: i]];
            }
        }
      [self _setStatus: NSStreamStatusOpening];
      return;
    }

 open_ok: 
  setNonblocking(_sock);
  WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
  [super open];
}

- (void) close
{
  // shutdown may fail (broken pipe). Record it.
  int closeReturn;

  if (_sibling && [_sibling streamStatus] != NSStreamStatusClosed)
    {
      closeReturn = shutdown(_sock, SD_SEND);
    }
  else
    {
      WSACloseEvent(_loopID);
      closeReturn = closesocket(_sock);
    }
  if (closeReturn < 0)
    {
      [self _recordError];
    }
  [super close];
  _loopID = WSA_INVALID_EVENT;
}

- (void) _dispatch
{
  if ([self streamStatus] == NSStreamStatusClosed)
    {
      /*
       * It is possible the stream is closed yet recieving event because
       * of not closed sibling
       */
      NSAssert([_sibling streamStatus] != NSStreamStatusClosed, 
	@"Received event for closed stream");
      [_sibling _dispatch];
    }
  else
    {
      WSANETWORKEVENTS events;
      int error = 0;
      int getReturn = -1;

      if (WSAEnumNetworkEvents(_sock, _loopID, &events) == SOCKET_ERROR)
	{
	  error = WSAGetLastError();
	}
//else NSLog(@"EVENTS 0x%x", events.lNetworkEvents);

      if ([self streamStatus] == NSStreamStatusOpening)
	{
	  unsigned	i = [_modes count];

	  while (i-- > 0)
	    {
	      [_runloop removeStream: self mode: [_modes objectAtIndex: i]];
	    }

	  if (error == 0)
	    {
	      unsigned len = sizeof(error);

	      getReturn = getsockopt(_sock, SOL_SOCKET, SO_ERROR,
		(char*)&error, &len);
	    }

	  if (getReturn >= 0 && error == 0
	    && (events.lNetworkEvents & FD_CONNECT))
	    { // finish up the opening
	      events.lNetworkEvents ^= FD_CONNECT;
	      _passive = YES;
	      [self open];
	      // notify sibling
	      if (_sibling)
		{
		  [_sibling open];
		  [_sibling _sendEvent: NSStreamEventOpenCompleted];
		}
	      [self _sendEvent: NSStreamEventOpenCompleted];
	    }
	}

      if (error != 0)
	{
	  errno = error;
	  [self _recordError];
	  [_sibling _recordError];
	  [self _sendEvent: NSStreamEventErrorOccurred];
	  [_sibling _sendEvent: NSStreamEventErrorOccurred];
	}
      else
	{
	  if (events.lNetworkEvents & FD_WRITE)
	    {
	      [self _setStatus: NSStreamStatusOpen];
	      while ([self hasSpaceAvailable]
		&& _unhandledData == NO)
		{
	          [self _sendEvent: NSStreamEventHasSpaceAvailable];
		}
	    }
	  if (events.lNetworkEvents & FD_READ)
	    {
	      [_sibling _setStatus: NSStreamStatusOpen];
	      while ([_sibling hasBytesAvailable]
		&& [_sibling _unhandledData] == NO)
		{
	          [_sibling _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	  if (events.lNetworkEvents & FD_CLOSE)
	    {
	      [self _setStatus: NSStreamStatusAtEnd];
	      [self _sendEvent: NSStreamEventEndEncountered];
	      while ([_sibling hasBytesAvailable]
		&& [_sibling _unhandledData] == NO)
		{
		  [_sibling _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	}
    }
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  *trigger = YES;
  return YES;
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
  [ins setSock: sock];
  [outs setSock: sock];
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
  const unichar *name;
  GSPipeInputStream *ins = nil;
  GSPipeOutputStream *outs = nil;
  SECURITY_ATTRIBUTES saAttr;
  HANDLE readh;
  HANDLE writeh;
  HANDLE event;
  OVERLAPPED ov;
  int rc;

  saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
  saAttr.bInheritHandle = TRUE;
  saAttr.lpSecurityDescriptor = NULL;

  /*
   * We have to use a named pipe since windows anonymous pipes do not
   * support asynchronous I/O!
   * We allocate a name known to be unique.
   */
  name = [[@"\\\\.\\pipe\\" stringByAppendingString:
    [[NSProcessInfo processInfo] globallyUniqueString]]
    fileSystemRepresentation];
  readh = CreateNamedPipeW(name,
    PIPE_ACCESS_INBOUND | FILE_FLAG_OVERLAPPED,
    PIPE_TYPE_BYTE,
    1,
    BUFSIZ*64,
    BUFSIZ*64,
    100000,
    &saAttr);

  NSAssert(readh != INVALID_HANDLE_VALUE, @"Cannot create pipe");

  // Start async connect
  event = CreateEvent(NULL, NO, NO, NULL);
  ov.Offset = 0;
  ov.OffsetHigh = 0;
  ov.hEvent = event;
  ConnectNamedPipe(readh, &ov);

  writeh = CreateFileW(name,
    GENERIC_WRITE,
    0,
    &saAttr,
    OPEN_EXISTING,
    FILE_FLAG_OVERLAPPED,
    NULL);
  if (writeh == INVALID_HANDLE_VALUE)
    {
      CloseHandle(event);
      CloseHandle(readh);
      [NSException raise: NSInternalInconsistencyException
		  format: @"Unable to create/open write pipe"];
    }

  rc = WaitForSingleObject(event, 10);
  CloseHandle(event);

  if (rc != WAIT_OBJECT_0)
    {
      CloseHandle(readh);
      CloseHandle(writeh);
      [NSException raise: NSInternalInconsistencyException
		  format: @"Unable to create/open read pipe"];
    }

  // the type of the stream does not matter, since we are only using the fd
  ins = AUTORELEASE([GSPipeInputStream new]);
  outs = AUTORELEASE([GSPipeOutputStream new]);

  [ins _setHandle: readh];
  [outs _setHandle: writeh];
  if (inputStream)
    *inputStream = ins;
  if (outputStream)
    *outputStream = outs;
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
}

+ (id) serverStreamToAddr: (NSString*)addr
{
  GSServerStream *s;

  [self notImplemented: _cmd];
//  s = [[GSLocalServerStream alloc] initToAddr: addr];
  return AUTORELEASE(s);
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  RELEASE(self);
  self = [[GSInetServerStream alloc] initToAddr: addr port: port];
  return self;
}

- (id) initToAddr: (NSString*)addr
{
  [self notImplemented: _cmd];
  RELEASE(self);
//  self = [[GSLocalServerStream alloc] initToAddr: addr];
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
    _loopID = WSA_INVALID_EVENT;
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

#define SOCKET_BACKLOG 255

- (void) open
{
  int bindReturn = bind(_sock, [self serverAddr], [self sockLen]);
  int listenReturn = listen(_sock, SOCKET_BACKLOG);

  if (bindReturn < 0 || listenReturn)
    {
      [self _recordError];
      return;
    }
  setNonblocking(_sock);
  _loopID = CreateEvent(NULL, NO, NO, NULL);
  WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
  [super open];
}

- (void) close
{
  WSACloseEvent(_loopID);
  // close a server socket is safe
  closesocket(_sock);
  [super close];
  _loopID = WSA_INVALID_EVENT;
}

- (void) acceptWithInputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream
{
  GSSocketInputStream *ins = AUTORELEASE([[self _inputStreamClass] new]);
  GSSocketOutputStream *outs = AUTORELEASE([[self _outputStreamClass] new]);
  socklen_t len = [ins sockLen];
  int acceptReturn = accept(_sock, [ins peerAddr], &len);

  _unhandledData = NO;
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
      [ins setSock: acceptReturn];
      [outs setSock: acceptReturn];
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

- (void) _dispatch
{
  WSANETWORKEVENTS events;
  
  if (WSAEnumNetworkEvents(_sock, _loopID, &events) == SOCKET_ERROR)
    {
      errno = WSAGetLastError();
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
    }
  else if (events.lNetworkEvents & FD_ACCEPT)
    {
      events.lNetworkEvents ^= FD_ACCEPT;
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
  _sock = socket(AF_INET, SOCK_STREAM, 0);
  if (_serverAddr.sin_addr.s_addr == INADDR_NONE || _loopID < 0)   // error
    {
      RELEASE(self);
      return nil;
    }
  return self;
}

@end
