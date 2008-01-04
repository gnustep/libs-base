#ifndef	INCLUDED_GSSTREAM_H
#define	INCLUDED_GSSTREAM_H

/** Implementation for GSStream for GNUStep
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Derek Zhou <derekzhou@gmail.com>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2006

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   NSInputStream and NSOutputStream are clusters rather than concrete classes
   The inherance graph is:
   NSStream 
   |-- GSStream
   |   `--GSSocketStream
   |-- NSInputStream
   |   `--GSInputStream
   |      |-- GSDataInputStream
   |      |-- GSFileInputStream
   |      |-- GSPipeInputStream (mswindows only)
   |      `-- GSSocketInputStream
   |          |-- GSInetInputStream
   |          |-- GSLocalInputStream
   |          `-- GSInet6InputStream
   |-- NSOutputStream
   |   `--GSOutputStream
   |      |-- GSBufferOutputStream
   |      |-- GSDataOutputStream
   |      |-- GSFileOutputStream
   |      |-- GSPipeOutputStream (mswindows only)
   |      `-- GSSocketOutputStream
   |          |-- GSInetOutputStream
   |          |-- GSLocalOutputStream
   |          `-- GSInet6InputStream
   `-- GSServerStream
       `-- GSAbstractServerStream
           |-- GSLocalServerStream (mswindows)
           `-- GSSocketServerStream
               |-- GSInetServerStream
               |-- GSInet6ServerStream
               `-- GSLocalServerStream (gnu/linux)
*/

#include <Foundation/NSStream.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSMapTable.h>

/**
 * Convenience methods used to add streams to the run loop.
 */
@interface	NSRunLoop (NSStream)
- (void) addStream: (NSStream*)aStream mode: (NSString*)mode;
- (void) removeStream: (NSStream*)aStream mode: (NSString*)mode;
@end

@class	NSMutableData;

#define	IVARS \
{ \
  id		         _delegate;	/* Delegate controls operation.	*/\
  NSMutableDictionary	*_properties;	/* storage for properties	*/\
  BOOL                   _delegateValid;/* whether the delegate responds*/\
  NSError               *_lastError;    /* last error occured           */\
  NSStreamStatus         _currentStatus;/* current status               */\
  NSMapTable		*_loops;	/* Run loops and their modes.	*/\
  void                  *_loopID;	/* file descriptor etc.		*/\
  int			_events;	/* Signalled events.		*/\
}

/**
 * GSInputStream and GSOutputStream both inherit methods from the
 * GSStream class using 'behaviors', and must therefore share
 * EXACTLY THE SAME initial ivar layout.
 */
@interface GSStream : NSStream
IVARS
@end

@interface GSAbstractServerStream : GSServerStream
IVARS
@end

@interface NSStream(Private)

/**
 * Async notification
 */
- (void) _dispatch;

/**
 * Return YES if the stream is opened, NO otherwise.
 */
- (BOOL) _isOpened;

/**
 * Return previously set reference for IO in run loop.
 */
- (void*) _loopID;

/**
 * Place the stream in all the scheduled runloops.
 */
- (void) _schedule;

/**
 * send an event to delegate
 */
- (void) _sendEvent: (NSStreamEvent)event;

/**
 * setter for IO event reference (file descriptor, file handle etc )
 */
- (void) _setLoopID: (void *)ref;

/**
 * set the status to newStatus. an exception is error cannot
 * be overwriten by closed
 */
- (void) _setStatus: (NSStreamStatus)newStatus;

/**
 * record an error based on errno
 */
- (void) _recordError; 

/**
 * say whether there is unhandled data for the stream.
 */
- (BOOL) _unhandledData;

/**
 * Remove the stream from all the scheduled runloops.
 */
- (void) _unschedule;

@end

@interface GSInputStream : NSInputStream
IVARS
@end

@interface GSOutputStream : NSOutputStream
IVARS
@end

/**
 * The concrete subclass of NSInputStream that reads from the memory 
 */
@interface GSDataInputStream : GSInputStream
{
@private
  NSData *_data;
  unsigned long _pointer;
}
@end

/**
 * The concrete subclass of NSOutputStream that writes to a buffer
 */
@interface GSBufferOutputStream : GSOutputStream
{
@private
  uint8_t	*_buffer;
  unsigned	_capacity;
  unsigned long _pointer;
}
@end

/**
 * The concrete subclass of NSOutputStream that writes to a variable sise buffer
 */
@interface GSDataOutputStream : GSOutputStream
{
@private
  NSMutableData *_data;
  unsigned long _pointer;
}
@end

#include "GSNetwork.h"


#define	SOCKIVARS \
{ \
  id            _sibling;       /* For bidirectional traffic.  	*/\
  BOOL          _passive;       /* YES means already connected. */\
  BOOL		_closing;	/* Must close on next failure.	*/\
  SOCKET        _sock;          /* Needed for ms-windows.       */\
}

/* The semi-abstract GSSocketStream class is not intended to be subclassed
 * but is used to add behaviors to other socket based classes.
 */
@interface GSSocketStream : GSStream
SOCKIVARS

/**
 * get the sockaddr
 */
- (struct sockaddr*) _peerAddr;

/**
 * setter for closing flag ... the remote end has stopped either sending
 * or receiving, so any I/O operation which would block means that the
 * connection is no longer operable in that direction.
 */
- (void) _setClosing: (BOOL)passive;

/**
 * setter for passive (the underlying socket connection is already open and
 * doesw not need to be re-opened).
 */
- (void) _setPassive: (BOOL)passive;

/**
 * setter for sibling
 */
- (void) _setSibling: (GSSocketStream*)sibling;

/*
 * Set the socket used for this stream.
 */
- (void) _setSock: (SOCKET)sock;

/* Return the socket
 */
- (SOCKET) _sock;

/** 
 * Get the length of the socket addr
 */
- (socklen_t) _sockLen;

@end

/**
 * The abstract subclass of NSInputStream that reads from a socket.
 * It inherits from GSInputStream and adds behaviors from GSSocketStream
 * so it must have the same instance variable layout as GSSocketStream.
 */
@interface GSSocketInputStream : GSInputStream
SOCKIVARS
@end
@interface GSSocketInputStream (AddedBehaviors)
- (struct sockaddr*) _peerAddr;
- (void) _setClosing: (BOOL)passive;
- (void) _setPassive: (BOOL)passive;
- (void) _setSibling: (GSSocketStream*)sibling;
- (void) _setSock: (SOCKET)sock;
- (SOCKET) _sock;
- (socklen_t) _sockLen;
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

/**
 * The abstract subclass of NSOutputStream that writes to a socket.
 * It inherits from GSOutputStream and adds behaviors from GSSocketStream
 * so it must have the same instance variable layout as GSSocketStream.
 */
@interface GSSocketOutputStream : GSOutputStream
SOCKIVARS
@end
@interface GSSocketOutputStream (AddedBehaviors)
- (struct sockaddr*) _peerAddr;
- (void) _setClosing: (BOOL)passive;
- (void) _setPassive: (BOOL)passive;
- (void) _setSibling: (GSSocketStream*)sibling;
- (void) _setSock: (SOCKET)sock;
- (SOCKET) _sock;
- (socklen_t) _sockLen;
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


/**
 * The subclass of NSStream that accepts connections from a socket.
 * It inherits from GSAbstractServerStream and adds behaviors from
 * GSSocketStream so it must have the same instance variable layout
 * as GSSocketStream.
 */
@interface GSSocketServerStream : GSAbstractServerStream
SOCKIVARS

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
 * Return the sockaddr for this server
 */
- (struct sockaddr*) _serverAddr;

@end
@interface GSSocketServerStream (AddedBehaviors)
- (struct sockaddr*) _peerAddr;
- (void) _setClosing: (BOOL)passive;
- (void) _setPassive: (BOOL)passive;
- (void) _setSibling: (GSSocketStream*)sibling;
- (void) _setSock: (SOCKET)sock;
- (SOCKET) _sock;
- (socklen_t) _sockLen;
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

#endif

