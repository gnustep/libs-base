#ifndef	INCLUDED_GSSTREAM_H
#define	INCLUDED_GSSTREAM_H

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

   NSInputStream and NSOutputStream are clusters rather than concrete classes
   The inherance graph is:
   NSStream 
   |-- NSInputStream
   |   `--GSInputStream
   |      |-- GSMemoryInputStream
   |      |-- GSFileInputStream
   |      `-- GSSocketInputStream
   |          |-- GSInetInputStream
   |          |-- GSLocalInputStream
   |          `-- GSInet6InputStream
   `-- NSOutputStream
       `--GSOutputStream
          |-- GSMemoryOutputStream
          |-- GSFileOutputStream
          `-- GSSocketOutputStream
              |-- GSInetOutputStream
              |-- GSLocalOutputStream
              `-- GSInet6InputStream
   */

#include <Foundation/NSStream.h>

#define	IVARS \
{ \
  id		         _delegate;	/* Delegate controls operation.	*/\
  NSMutableDictionary	*_properties;	/* storage for properties	*/\
  BOOL                   _delegateValid;/* whether the delegate responds*/\
  NSError               *_lastError;    /* last error occured           */\
  NSStreamStatus         _currentStatus;/* current status               */\
  NSMutableArray 	*_modes;	/* currently scheduled modes.	*/\
  NSRunLoop 		*_runloop;	/* currently scheduled loop.	*/\
}

/**
 * GSInputStream and GSOutputStream both inherit methods from the
 * GSStream class using 'behaviors', and must therefore share
 * EXACTLY THE SAME initial ivar layout.
 */
@interface GSStream : NSStream
IVARS
@end
@interface GSStream(Private)
/**
 * Return YES if the stream is opened, NO otherwise.
 */
- (BOOL) _isOpened;

/**
 * send an event to delegate
 */
- (void) _sendEvent: (NSStreamEvent)event;

/**
 * set the status to newStatus. an exception is error cannot
 * be overwriten by closed
 */
- (void) _setStatus: (NSStreamStatus)newStatus;

/**
 * record an error based on errno
 */
- (void) _recordError; 
@end

@interface GSInputStream : NSInputStream
IVARS
@end
@interface GSInputStream (Private)
- (BOOL) _isOpened;
- (void) _sendEvent: (NSStreamEvent)event;
- (void) _setStatus: (NSStreamStatus)newStatus;
- (void) _recordError; 
@end

@interface GSOutputStream : NSOutputStream
IVARS
@end
@interface GSOutputStream (Private)
- (BOOL) _isOpened;
- (void) _sendEvent: (NSStreamEvent)event;
- (void) _setStatus: (NSStreamStatus)newStatus;
- (void) _recordError; 
@end


/**
 * The concrete subclass of NSInputStream that reads from the memory 
 */
@interface GSMemoryInputStream : GSInputStream
{
@private
  NSData *_data;
  unsigned long _pointer;
}

/**
 * this is the bridge method for asynchronized operation. Do not call.
 */
- (void) dispatch;
@end

/**
 * The concrete subclass of NSOutputStream that writes to memory
 */
@interface GSMemoryOutputStream : GSOutputStream
{
@private
  NSMutableData *_data;
  unsigned long _pointer;
  BOOL _fixedSize;
}

/**
 * this is the bridge method for asynchronized operation. Do not call.
 */
- (void) dispatch;
@end

#endif

