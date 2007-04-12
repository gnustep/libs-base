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
#include <Foundation/NSDebug.h>

#include "../GSStream.h"
#include "../GSPrivate.h"

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

@class GSPipeOutputStream;

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
  GSPipeOutputStream *_sibling;
  BOOL		hadEOF;
}
- (NSStreamStatus) _check;
- (void) _queue;
- (void) _setHandle: (HANDLE)h;
- (void) setSibling: (GSPipeOutputStream*)s;
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
- (void) setSibling: (GSSocketOutputStream*)sibling;

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
  GSPipeInputStream *_sibling;
  BOOL		closing;
  BOOL		writtenEOF;
}
- (NSStreamStatus) _check;
- (void) _queue;
- (void) _setHandle: (HANDLE)h;
- (void) setSibling: (GSPipeInputStream*)s;
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
- (void) setSibling: (GSSocketInputStream*)sibling;

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


/**
 * The concrete subclass of NSServerStream that accepts named pipe connection
 */
@interface GSLocalServerStream : GSAbstractServerStream
{
  NSString	*path;
  HANDLE	handle;
  OVERLAPPED	ov;
}
@end

static void setNonblocking(SOCKET fd)
{
  unsigned long	dummy = 1;

  if (ioctlsocket(fd, FIONBIO, &dummy) == SOCKET_ERROR)
    NSLog(@"unable to set non-blocking mode - %@", [NSError _last]);
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
    {
      [self close];
    }
  RELEASE(_path);
  [super dealloc];
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len
{
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
      [self _sendEvent: NSStreamEventErrorOccurred];
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

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte length read requested"];
    }

  _events &= ~NSStreamEventHasBytesAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }

  if (ReadFile((HANDLE)_loopID, buffer, len, &readLen, NULL) == 0)
    {
      [self _recordError];
      return -1;
    }
  else if (readLen == 0)
    {
      [self _setStatus: NSStreamStatusAtEnd];
      [self _sendEvent: NSStreamEventEndEncountered];
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
  length = offset = 0;
  if (_loopID != INVALID_HANDLE_VALUE)
    {
      CloseHandle((HANDLE)_loopID);
    }
  if (handle != INVALID_HANDLE_VALUE)
    {
      /* If we have an outstanding read in progess, we must cancel it
       * before closing the pipe.
       */
      if (want > 0)
	{
	  want = 0;
	  CancelIo(handle);
	}

      /* We can only close the pipe if there is no sibling using it.
       */
      if ([_sibling _isOpened] == NO)
	{
	  if (DisconnectNamedPipe(handle) == 0)
	    {
	      if ((errno = GetLastError()) != ERROR_PIPE_NOT_CONNECTED)
		{
		  [self _recordError];
		}
	    }
	  if (CloseHandle(handle) == 0)
	    {
	      [self _recordError];
	    }
	}
      handle = INVALID_HANDLE_VALUE;
    }
  [super close];
  _loopID = (void*)INVALID_HANDLE_VALUE;

}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  [_sibling setSibling: nil];
  _sibling = nil;
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
      if ((errno = GetLastError()) == ERROR_HANDLE_EOF
	|| errno == ERROR_PIPE_NOT_CONNECTED
	|| errno == ERROR_BROKEN_PIPE)
	{
	  /*
	   * Got EOF, but we don't want to register it until a
	   * -read:maxLength: is called.
	   */
	  offset = length = want = 0;
	  [self _setStatus: NSStreamStatusOpen];
	  hadEOF = YES;
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
  else if (size == 0)
    {
      length = want = 0;
      [self _setStatus: NSStreamStatusOpen];
      hadEOF = YES;
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
  if (hadEOF == NO && [self streamStatus] == NSStreamStatusOpen)
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
	      hadEOF = YES;
	    }
	}
      else if ((errno = GetLastError()) == ERROR_HANDLE_EOF
	|| errno == ERROR_PIPE_NOT_CONNECTED
        || errno == ERROR_BROKEN_PIPE)
	{
	  hadEOF = YES;
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
  NSStreamStatus myStatus;

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte length read requested"];
    }

  _events &= ~NSStreamEventHasBytesAvailable;

  myStatus = [self streamStatus];
  if (myStatus == NSStreamStatusReading)
    {
      myStatus = [self _check];
    }
  if (myStatus == NSStreamStatusClosed)
    {
      return 0;
    }

  if (offset == length)
    {
      if (myStatus == NSStreamStatusError)
	{
	  [self _sendEvent: NSStreamEventErrorOccurred];
	  return -1;	// Waiting for read.
	}
      if (myStatus == NSStreamStatusOpen)
	{
	  /*
	   * There is no buffered data and no read in progress,
	   * so we must be at EOF.
	   */
	  [self _setStatus: NSStreamStatusAtEnd];
	  [self _sendEvent: NSStreamEventEndEncountered];
	}
      return 0;
    }

  /*
   * We already have data buffered ... return some or all of it.
   */
  if (len > (length - offset))
    {
      len = length - offset;
    }
  memcpy(buffer, data + offset, len);
  offset += len;
  if (offset == length)
    {
      length = 0;
      offset = 0;
      if (myStatus == NSStreamStatusOpen)
	{
          [self _queue];	// Queue another read
	}
    }
  return len;
}

- (void) _setHandle: (HANDLE)h
{
  handle = h;
}

- (void) setSibling: (GSPipeOutputStream*)s
{
  _sibling = s;
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

  if ([self _unhandledData] == YES || myStatus == NSStreamStatusError)
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

- (void) setSibling: (GSSocketOutputStream*)sibling
{
  _sibling = sibling;
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
    {
      [self close];
    }
  [_sibling setSibling: nil];
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
      int connectReturn = connect(_sock, [self peerAddr], [self sockLen]);
      
      if (connectReturn == SOCKET_ERROR
	&& WSAGetLastError() != WSAEWOULDBLOCK)
        {// make an error
          [self _recordError];
          [self _sendEvent: NSStreamEventErrorOccurred];
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
  if (_loopID != WSA_INVALID_EVENT)
    {
      WSACloseEvent(_loopID);
    }
  if (_sock != INVALID_SOCKET)
    {
      if (_sibling && [_sibling streamStatus] != NSStreamStatusClosed)
	{
	  /*
	   * Windows only permits a single event to be associated with a socket
	   * at any time, but the runloop system only allows an event handle to
	   * be added to the loop once, and we have two streams for each socket.
	   * So we use two events, one for each stream, and when one stream is
	   * closed, we must call WSAEventSelect to ensure that the event handle
	   * of the sibling is used to signal events from now on.
	   */
	  WSAEventSelect(_sock, [_sibling _loopID], FD_ALL_EVENTS);
	  shutdown(_sock, SD_RECEIVE);
	}
      else
	{
	  closesocket(_sock);
	}
      _sock = INVALID_SOCKET;
    }
  [super close];
  _loopID = WSA_INVALID_EVENT;
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
		  format: @"zero byte length read requested"];
    }

  _events &= ~NSStreamEventHasBytesAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }

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
      [self _sendEvent: NSStreamEventEndEncountered];
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

- (void) _dispatch
{
  /*
   * Windows only permits a single event to be associated with a socket
   * at any time, but the runloop system only allows an event handle to
   * be added to the loop once, and we have two streams for each socket.
   * So we use two events, one for each stream, and the _dispatch method
   * must handle things for both streams.
   */
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
//else NSLog(@"EVENTS 0x%x on %p", events.lNetworkEvents, self);

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
	      NSAssert([_sibling _isOpened], NSInternalInconsistencyException);
	      /* Clear NSStreamStatusWriting if it was set */
	      [_sibling _setStatus: NSStreamStatusOpen];
	    }
	  /* On winsock a socket is always writable unless it has had
	   * failure/closure or a write blocked and we have not been
	   * signalled again.
	   */
	  while ([_sibling _unhandledData] == NO
	    && [_sibling hasSpaceAvailable])
	    {
	      [_sibling _sendEvent: NSStreamEventHasSpaceAvailable];
	    }

	  if (events.lNetworkEvents & FD_READ)
	    {
	      [self _setStatus: NSStreamStatusOpen];
	      while ([self hasBytesAvailable]
		&& [self _unhandledData] == NO)
		{
	          [self _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	  if (events.lNetworkEvents & FD_CLOSE)
	    {
	      if ([_sibling _isOpened])
		{
		  [_sibling _setStatus: NSStreamStatusAtEnd];
		  [_sibling _sendEvent: NSStreamEventEndEncountered];
		}
	      while ([self hasBytesAvailable]
		&& [self _unhandledData] == NO)
		{
		  [self _sendEvent: NSStreamEventHasBytesAvailable];
		}
	      if ([self _isOpened])
		{
		  [self _setStatus: NSStreamStatusAtEnd];
		  [self _sendEvent: NSStreamEventEndEncountered];
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
      _peerAddr.sin_addr.s_addr = addr_c ? inet_addr(addr_c) : INADDR_NONE;
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
    {
      [self close];
    }
  RELEASE(_path);
  [super dealloc];
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
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }
  else if (_shouldAppend == NO)
    {
      if (SetEndOfFile(h) == 0)	// Truncate to current file pointer (0)
	{
          [self _recordError];
          [self _sendEvent: NSStreamEventErrorOccurred];
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
  /* If we have a write in progress, we must wait for it to complete,
   * so we just set a flag to close as soon as the write finishes.
   */
  if ([self streamStatus] == NSStreamStatusWriting)
    {
      closing = YES;
      return;
    }

  /* Where we have a sibling, we can't close the pipe handle, so the
   * only way to tell the remote end we have finished is to write a
   * zero length packet to it.
   */
  if ([_sibling _isOpened] == YES && writtenEOF == NO)
    {
      int	rc;

      writtenEOF = YES;
      ov.Offset = 0;
      ov.OffsetHigh = 0;
      ov.hEvent = (HANDLE)_loopID;
      size = 0;
      rc = WriteFile(handle, "", 0, &size, &ov);
      if (rc == 0)
	{
	  if ((errno = GetLastError()) == ERROR_IO_PENDING)
	    {
	      [self _setStatus: NSStreamStatusWriting];
	      return;		// Wait for write to complete
	    }
	  [self _recordError];	// Failed to write EOF
	}
    }

  offset = want = 0;
  if (_loopID != INVALID_HANDLE_VALUE)
    {
      CloseHandle((HANDLE)_loopID);
    }
  if (handle != INVALID_HANDLE_VALUE)
    {
      if ([_sibling _isOpened] == NO)
	{
	  if (DisconnectNamedPipe(handle) == 0)
	    {
	      if ((errno = GetLastError()) != ERROR_PIPE_NOT_CONNECTED)
		{
		  [self _recordError];
		}
	      [self _recordError];
	    }
	  if (CloseHandle(handle) == 0)
	    {
	      [self _recordError];
	    }
	}
      handle = INVALID_HANDLE_VALUE;
    }

  [super close];
  _loopID = (void*)INVALID_HANDLE_VALUE;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  [_sibling setSibling: nil];
  _sibling = nil;
  [super dealloc];
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
	      if (offset == want)
		{
		  offset = want = 0;
		}
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

  if (myStatus == NSStreamStatusWriting)
    {
      myStatus = [self _check];
    }
  if (myStatus == NSStreamStatusClosed)
    {
      return 0;
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
      if (offset < want)
	{
	  [self _queue];
	}
      else
	{
	  offset = want = 0;
	}
    }
  if (closing == YES && [self streamStatus] != NSStreamStatusWriting)
    {
      [self close];
    }
  return [self streamStatus];
}

- (void) _setHandle: (HANDLE)h
{
  handle = h;
}

- (void) setSibling: (GSPipeInputStream*)s
{
  _sibling = s;
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

  if ([self _unhandledData] == YES || myStatus == NSStreamStatusError)
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

- (void) setSibling: (GSSocketInputStream*)sibling
{
  _sibling = sibling;
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
    {
      [self close];
    }
  [_sibling setSibling: nil];
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
          [self _sendEvent: NSStreamEventErrorOccurred];
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
  if (_loopID != WSA_INVALID_EVENT)
    {
      WSACloseEvent(_loopID);
    }

  if (_sock != INVALID_SOCKET)
    {
      int closeReturn;	// shutdown may fail (broken pipe). Record it.

      if (_sibling && [_sibling streamStatus] != NSStreamStatusClosed)
	{
	  /*
	   * Windows only permits a single event to be associated with a socket
	   * at any time, but the runloop system only allows an event handle to
	   * be added to the loop once, and we have two streams for each socket.
	   * So we use two events, one for each stream, and when one stream is
	   * closed, we must call WSAEventSelect to ensure that the event handle
	   * of the sibling is used to signal events from now on.
	   */
	  WSAEventSelect(_sock, [_sibling _loopID], FD_ALL_EVENTS);
	  closeReturn = shutdown(_sock, SD_SEND);
	}
      else
	{
	  closeReturn = closesocket(_sock);
	}
      _sock = INVALID_SOCKET;
      if (closeReturn < 0)
	{
	  [self _recordError];
	}
    }
  [super close];
  _loopID = WSA_INVALID_EVENT;
}

- (void) _dispatch
{
  /*
   * Windows only permits a single event to be associated with a socket
   * at any time, but the runloop system only allows an event handle to
   * be added to the loop once, and we have two streams for each socket.
   * So we use two events, one for each stream, and the _dispatch method
   * must handle things for both streams.
   */
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
//else NSLog(@"EVENTS 0x%x on %p", events.lNetworkEvents, self);

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
	      /* Clear NSStreamStatusWriting if it was set */
	      [self _setStatus: NSStreamStatusOpen];
	    }

	  /* On winsock a socket is always writable unless it has had
	   * failure/closure or a write blocked and we have not been
	   * signalled again.
	   */
	  while ([self _unhandledData] == NO && [self hasSpaceAvailable])
	    {
	      [self _sendEvent: NSStreamEventHasSpaceAvailable];
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
	      if ([_sibling _isOpened])
		{
	          [_sibling _setStatus: NSStreamStatusAtEnd];
	          [_sibling _sendEvent: NSStreamEventEndEncountered];
		}
	    }
	}
    }
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  *trigger = YES;
  if ([self _unhandledData] == NO && [self streamStatus] == NSStreamStatusOpen)
    {
      /* In winsock, a writable status is only signalled if an earlier
       * write failed (because it would block), so we must simulate the
       * writable event by having the run loop trigger without blocking.
       */
      return NO;
    }
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
      _peerAddr.sin_addr.s_addr = addr_c ? inet_addr(addr_c) : INADDR_NONE;
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
  WSAEVENT ievent;
  WSAEVENT oevent;

  ins = AUTORELEASE([[GSInetInputStream alloc]
    initToAddr: address port: port]);
  outs = AUTORELEASE([[GSInetOutputStream alloc]
    initToAddr: address port: port]);
  sock = socket(PF_INET, SOCK_STREAM, 0);

  /*
   * Windows only permits a single event to be associated with a socket
   * at any time, but the runloop system only allows an event handle to
   * be added to the loop once, and we have two streams.
   * So we create two events, one for each stream, so that we can have
   * both streams scheduled in the run loop, but we make sure that the
   * _dispatch method in each stream actually handles things for both
   * streams so that whichever stream gets signalled, the correct
   * actions are taken.
   */
  ievent = CreateEvent(NULL, NO, NO, NULL);
  oevent = CreateEvent(NULL, NO, NO, NULL);
  
  NSAssert(sock != INVALID_SOCKET, @"Cannot open socket");
  [ins setSock: sock];
  [outs setSock: sock];
  [ins setEvent: ievent];
  [outs setEvent: oevent];
  
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
  const unichar *name;
  GSPipeInputStream *ins = nil;
  GSPipeOutputStream *outs = nil;
  SECURITY_ATTRIBUTES saAttr;
  HANDLE handle;

  if ([path length] == 0)
    {
      NSDebugMLog(@"address nil or empty");
      goto done;
    }
  if ([path length] > 240)
    {
      NSDebugMLog(@"address (%@) too long", path);
      goto done;
    }
  if ([path rangeOfString: @"\\"].length > 0)
    {
      NSDebugMLog(@"illegal backslash in (%@)", path);
      goto done;
    }
  if ([path rangeOfString: @"/"].length > 0)
    {
      NSDebugMLog(@"illegal slash in (%@)", path);
      goto done;
    }

  /*
   * We allocate a new within the local pipe area
   */
  name = [[@"\\\\.\\pipe\\GSLocal" stringByAppendingString: path]
    fileSystemRepresentation];

  saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
  saAttr.bInheritHandle = TRUE;
  saAttr.lpSecurityDescriptor = NULL;

  handle = CreateFileW(name,
    GENERIC_WRITE|GENERIC_READ,
    0,
    &saAttr,
    OPEN_EXISTING,
    FILE_FLAG_OVERLAPPED,
    NULL);
  if (handle == INVALID_HANDLE_VALUE)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Unable to open named pipe '%@'... %@",
	path, [NSError _last]];
    }

  // the type of the stream does not matter, since we are only using the fd
  ins = AUTORELEASE([GSPipeInputStream new]);
  outs = AUTORELEASE([GSPipeOutputStream new]);

  [ins _setHandle: handle];
  [ins setSibling: outs];
  [outs _setHandle: handle];
  [outs setSibling: ins];

done:
  if (inputStream)
    {
      *inputStream = ins;
    }
  if (outputStream)
    {
      *outputStream = outs;
    }
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

+ (id) outputStreamToMemory
{
  return AUTORELEASE([[GSDataOutputStream alloc] init]);  
}

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

  s = [[GSInetServerStream alloc] initToAddr: addr port: port];
  return AUTORELEASE(s);
}

+ (id) serverStreamToAddr: (NSString*)addr
{
  GSServerStream *s;

  s = [[GSLocalServerStream alloc] initToAddr: addr];
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
  RELEASE(self);
  self = [[GSLocalServerStream alloc] initToAddr: addr];
  return self;
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
    {
      _loopID = WSA_INVALID_EVENT;
    }
  return self;
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

#define SOCKET_BACKLOG 255

- (void) open
{
  int	bindReturn;
  int	listenReturn;
#ifndef	BROKEN_SO_REUSEADDR
  int	status = 1;

  /*
   * Under decent systems, SO_REUSEADDR means that the port can be reused
   * immediately that this process exits.  Under some it means
   * that multiple processes can serve the same port simultaneously.
   * We don't want that broken behavior!
   */
  setsockopt(_sock, SOL_SOCKET, SO_REUSEADDR, (char *)&status, sizeof(status));
#endif
  bindReturn = bind(_sock, [self serverAddr], [self sockLen]);
  listenReturn = listen(_sock, SOCKET_BACKLOG);
  if (bindReturn < 0 || listenReturn < 0)
    {
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }
  setNonblocking(_sock);
  _loopID = CreateEvent(NULL, NO, NO, NULL);
  WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
  [super open];
}

- (void) close
{
  if (_loopID != WSA_INVALID_EVENT)
    {
      WSACloseEvent(_loopID);
    }
  if (_sock != INVALID_SOCKET)
    {
      // close a server socket is safe
      closesocket(_sock);
      _sock = INVALID_SOCKET;
    }
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

  _events &= ~NSStreamEventHasBytesAvailable;
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
      /*
       * Windows only permits a single event to be associated with a socket
       * at any time, but the runloop system only allows an event handle to
       * be added to the loop once, and we have two streams.
       * So we create two events, one for each stream, so that we can have
       * both streams scheduled in the run loop, but we make sure that the
       * _dispatch method in each stream actually handles things for both
       * streams so that whichever stream gets signalled, the correct
       * actions are taken.
       */
      WSAEVENT  ievent = CreateEvent(NULL, NO, NO, NULL);
      WSAEVENT  oevent = CreateEvent(NULL, NO, NO, NULL);
      // no need to connect again
      [ins setPassive: YES];
      [outs setPassive: YES];
      // copy the addr to outs
      memcpy([outs peerAddr], [ins peerAddr], len);
      [ins setSock: acceptReturn];
      [outs setSock: acceptReturn];
      [ins setEvent: ievent];
      [outs setEvent: oevent];
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
  _serverAddr.sin_addr.s_addr = addr_c ? inet_addr(addr_c) : INADDR_NONE;
  _sock = socket(AF_INET, SOCK_STREAM, 0);
  if (_serverAddr.sin_addr.s_addr == INADDR_NONE || _loopID < 0)   // error
    {
      RELEASE(self);
      return nil;
    }
  return self;
}

@end

@implementation GSLocalServerStream

- (id) init
{
  DESTROY(self);
  return self;
}

- (id) initToAddr: (NSString*)addr
{
  if ([addr length] == 0)
    {
      NSDebugMLog(@"address nil or empty");
      DESTROY(self);
    }
  if ([addr length] > 246)
    {
      NSDebugMLog(@"address (%@) too long", addr);
      DESTROY(self);
    }
  if ([addr rangeOfString: @"\\"].length > 0)
    {
      NSDebugMLog(@"illegal backslash in (%@)", addr);
      DESTROY(self);
    }
  if ([addr rangeOfString: @"/"].length > 0)
    {
      NSDebugMLog(@"illegal slash in (%@)", addr);
      DESTROY(self);
    }

  if ((self = [super init]) != nil)
    {
      path = RETAIN([@"\\\\.\\pipe\\GSLocal" stringByAppendingString: addr]);
      _loopID = INVALID_HANDLE_VALUE;
      handle = INVALID_HANDLE_VALUE;
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  RELEASE(path);
  [super dealloc];
}

- (void) open
{
  SECURITY_ATTRIBUTES saAttr;
  BOOL alreadyConnected = NO;

  NSAssert(handle == INVALID_HANDLE_VALUE, NSInternalInconsistencyException);

  saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
  saAttr.bInheritHandle = TRUE;
  saAttr.lpSecurityDescriptor = NULL;

  handle = CreateNamedPipeW([path fileSystemRepresentation],
    PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
    PIPE_TYPE_MESSAGE,
    PIPE_UNLIMITED_INSTANCES,
    BUFSIZ*64,
    BUFSIZ*64,
    100000,
    &saAttr);
  if (handle == INVALID_HANDLE_VALUE)
    {
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }

  if ([self _loopID] == INVALID_HANDLE_VALUE)
    {
      /* No existing event to use ..,. create a new one.
       */
      [self _setLoopID: CreateEvent(NULL, NO, NO, NULL)];
    }
  ov.Offset = 0;
  ov.OffsetHigh = 0;
  ov.hEvent = [self _loopID];
  if (ConnectNamedPipe(handle, &ov) == 0)
    {
      errno = GetLastError();
      if (errno == ERROR_PIPE_CONNECTED)
	{
	  alreadyConnected = YES;
	}
      else if (errno != ERROR_IO_PENDING)
	{
	  [self _recordError];
          [self _sendEvent: NSStreamEventErrorOccurred];
	  return;
	}
    }

  if ([self _isOpened] == NO)
    {
      [super open];
    }
  if (alreadyConnected == YES)
    {
      [self _setStatus: NSStreamStatusOpen];
      [self _sendEvent: NSStreamEventHasBytesAvailable];
    }
}

- (void) close
{
  if (_loopID != INVALID_HANDLE_VALUE)
    {
      CloseHandle((HANDLE)_loopID);
    }
  if (handle != INVALID_HANDLE_VALUE)
    {
      CancelIo(handle);
      if (CloseHandle(handle) == 0)
	{
	  [self _recordError];
	}
      handle = INVALID_HANDLE_VALUE;
    }
  [super close];
  _loopID = INVALID_HANDLE_VALUE;
}

- (void) acceptWithInputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream
{
  GSPipeInputStream *ins = nil;
  GSPipeOutputStream *outs = nil;

  _events &= ~NSStreamEventHasBytesAvailable;

  // the type of the stream does not matter, since we are only using the fd
  ins = AUTORELEASE([GSPipeInputStream new]);
  outs = AUTORELEASE([GSPipeOutputStream new]);

  [ins _setHandle: handle];
  [outs _setHandle: handle];

  handle = INVALID_HANDLE_VALUE;
  [self open];	// Re-open to accept more

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
  DWORD		size;

  if (GetOverlappedResult(handle, &ov, &size, TRUE) == 0)
    {
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
      [self _sendEvent: NSStreamEventHasBytesAvailable];
    }
}

@end

