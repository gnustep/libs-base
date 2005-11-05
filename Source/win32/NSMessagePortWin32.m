/** Implementation of network port object based on unix domain sockets
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Based on code by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>

   This file is part of the GNUstep Base Library.

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
   Software Foundation, Inc.,
   51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
   */

#include "config.h"
#include "GNUstepBase/preface.h"
#include "GNUstepBase/GSLock.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSNotification.h"
#include "Foundation/NSException.h"
#include "Foundation/NSRunLoop.h"
#include "Foundation/NSByteOrder.h"
#include "Foundation/NSData.h"
#include "Foundation/NSDate.h"
#include "Foundation/NSMapTable.h"
#include "Foundation/NSPortMessage.h"
#include "Foundation/NSPortNameServer.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSThread.h"
#include "Foundation/NSConnection.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSPathUtilities.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSFileManager.h"
#include "Foundation/NSProcessInfo.h"

#include "GSPortPrivate.h"

#include <stdio.h>
#include <stdlib.h>

/*
 * Largest chunk of data possible in DO
 */
static gsu32	maxDataLength = 10 * 1024 * 1024;

#if 0
#define	M_LOCK(X) {NSDebugMLLog(@"NSMessagePort",@"lock %@",X); [X lock];}
#define	M_UNLOCK(X) {NSDebugMLLog(@"NSMessagePort",@"unlock %@",X); [X unlock];}
#else
#define	M_LOCK(X) {[X lock];}
#define	M_UNLOCK(X) {[X unlock];}
#endif


/*
 * The GSPortItemType constant is used to identify the type of data in
 * each packet read.  All data transmitted is in a packet, each packet
 * has an initial packet type and packet length.
 */
typedef	enum {
  GSP_NONE,
  GSP_PORT,		/* Simple port item.			*/
  GSP_DATA,		/* Simple data item.			*/
  GSP_HEAD		/* Port message header + initial data.	*/
} GSPortItemType;

/*
 * The GSPortItemHeader structure defines the header for each item transmitted.
 * Its contents are transmitted in network byte order.
 */
typedef struct {
  gsu32	type;		/* A GSPortItemType as a 4-byte number.		*/
  gsu32	length;		/* The length of the item (excluding header).	*/
} GSPortItemHeader;

/*
 * The GSPortMsgHeader structure is at the start of any item of type GSP_HEAD.
 * Its contents are transmitted in network byte order.
 * Any additional data in the item is an NSData object.
 * NB. additional data counts as part of the same item.
 */
typedef struct {
  gsu32	mId;		/* The ID for the message starting with this.	*/
  gsu32	nItems;		/* Number of items (including this one).	*/
} GSPortMsgHeader;

typedef	struct {
  unsigned char	version;
  unsigned char	addr[0];	/* name of the port on the local host	*/
} GSPortInfo;

/*
 * Utility functions for encoding and decoding ports.
 */
static NSMessagePort*
decodePort(NSData *data)
{
  GSPortItemHeader	*pih;
  GSPortInfo		*pi;

  pih = (GSPortItemHeader*)[data bytes];
  NSCAssert(GSSwapBigI32ToHost(pih->type) == GSP_PORT,
    NSInternalInconsistencyException);
  pi = (GSPortInfo*)&pih[1];
  if (pi->version != 0)
    {
      NSLog(@"Remote version of GNUstep is more recent than this one (%i)",
	pi->version);
      return nil;
    }

  NSDebugFLLog(@"NSMessagePort", @"Decoded port as '%s'", pi->addr);

  return [NSMessagePort _portWithName: pi->addr
			     listener: NO];
}

static NSData*
newDataWithEncodedPort(NSMessagePort *port)
{
  GSPortItemHeader	*pih;
  GSPortInfo		*pi;
  NSMutableData		*data;
  unsigned		plen;
  const unsigned char	*name = [port _name];

  plen = 2 + strlen((char*)name);

  data = [[NSMutableData alloc] initWithLength: sizeof(GSPortItemHeader)+plen];
  pih = (GSPortItemHeader*)[data mutableBytes];
  pih->type = GSSwapHostI32ToBig(GSP_PORT);
  pih->length = GSSwapHostI32ToBig(plen);
  pi = (GSPortInfo*)&pih[1];
  strcpy((char*)pi->addr, (char*)name);

  NSDebugFLLog(@"NSMessagePort", @"Encoded port as '%s'", pi->addr);

  return data;
}


@implementation	NSMessagePort

static NSRecursiveLock	*messagePortLock = nil;

/*
 * Maps port name to NSMessagePort objects.
 */
static NSMapTable	*messagePortMap = 0;
static Class		messagePortClass;

#define	HDR	(sizeof(GSPortItemHeader) + sizeof(GSPortMsgHeader))

typedef	struct {
  NSString              *_name;
  NSRecursiveLock       *_lock;
  HANDLE                _handle;
  HANDLE                _event;
  OVERLAPPED		_ov;
  DWORD			_size;
  BOOL			_listen;
  NSMutableData		*_data;
  unsigned		_offset;
  unsigned		_target;
} internal;
#define	myName(P)	((internal*)(P)->_internal)->_name
#define	myLock(P)	((internal*)(P)->_internal)->_lock
#define	myHandle(P)	((internal*)(P)->_internal)->_handle
#define	myEvent(P)	((internal*)(P)->_internal)->_event
#define	myOv(P)		((internal*)(P)->_internal)->_ov
#define	myListen(P)	((internal*)(P)->_internal)->_listen
#define	mySize(P)	((internal*)(P)->_internal)->_size
#define	myData(P)	((internal*)(P)->_internal)->_data
#define	myOffset(P)	((internal*)(P)->_internal)->_offset
#define	myTarget(P)	((internal*)(P)->_internal)->_target

#if NEED_WORD_ALIGNMENT
static unsigned	wordAlign;
#endif

+ (void) initialize
{
  if (self == [NSMessagePort class])
    {
#if NEED_WORD_ALIGNMENT
      wordAlign = objc_alignof_type(@encode(gsu32));
#endif
      messagePortClass = self;
      messagePortMap = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 0);

      messagePortLock = [GSLazyRecursiveLock new];
    }
}

+ (id) new
{
  static int	unique_index = 0;
  unsigned char	path[BUFSIZ];

  M_LOCK(messagePortLock);
  sprintf(path, "\\\\.\\mailslot\\NSMessagePort\\%i.%i",
    [[NSProcessInfo processInfo] processIdentifier], unique_index++);
  M_UNLOCK(messagePortLock);

  return RETAIN([self _portWithName: path listener: YES]);
}

/*
 * This is the preferred initialisation method for NSMessagePort
 *
 * 'mailslotName' is the name of the mailslot to use.
 */
+ (NSMessagePort*) _portWithName: (const unsigned char*)mailslotName
			listener: (BOOL)shouldListen
{
  NSMessagePort		*port = nil;

  M_LOCK(messagePortLock);

  /*
   * First try to find a pre-existing port.
   */
  port = (NSMessagePort*)NSMapGet(messagePortMap, mailslotName);

  if (port == nil)
    {
      port = (NSMessagePort*)NSAllocateObject(self, 0, NSDefaultMallocZone());
      myName(port) = [[NSString alloc] initWithUTF8String: mailslotName];
      myEvent(port) = CreateEvent(NULL, FALSE, FALSE, NULL);
      myOv(port).Offset = 0;
      myOv(port).OffsetHigh = 0;
      myOv(port).hEvent = myEvent(port);
      myHandle(port) = INVALID_HANDLE_VALUE;
      myLock(port) = [GSLazyRecursiveLock new];
      port->_is_valid = YES;

      if (shouldListen == YES)
	{
	  myHandle(port) = CreateMailslot([myName(port) UTF8String],
	    0,				/* No max message size.		*/
	    MAILSLOT_WAIT_FOREVER,	/* No read/write timeout.	*/
	    (LPSECURITY_ATTRIBUTES)0);

	  if (myHandle(port) == INVALID_HANDLE_VALUE)
	    {
	      NSLog(@"unable to create mailslot - %s", GSLastErrorStr(errno));
	      DESTROY(port);
	    }
	  else
	    {
	      myListen(port) = YES;
	      NSMapInsert(messagePortMap, (void*)myName(port), (void*)port);
	      NSDebugMLLog(@"NSMessagePort", @"Created listening port: %@",
		port);

	      /* Set off an asynchronous read operation to get the header
	       * of an incoming message.
	       */
	      myOffset(port) = 0;
	      myTarget(port) = HDR;
	      [myData(port) setLength: HDR];
	      ReadFile(myHandle(port),
		[myData(port) mutableBytes],	// Store results here
		myTarget(port),			// Read a header size.
		&mySize(port),			// Store number of bytes read
		&myOv(port));
	    }
	}
      else
	{
	  myHandle(port) = CreateFile([myName(port) UTF8String],
	    GENERIC_WRITE,
	    FILE_SHARE_READ,
	    (LPSECURITY_ATTRIBUTES)0,
	    OPEN_EXISTING,
	    FILE_ATTRIBUTE_NORMAL,
	    (HANDLE)0);
	  if (myHandle(port) == INVALID_HANDLE_VALUE)
	    {
	      NSLog(@"unable to access mailslot - %s", GSLastErrorStr(errno));
	      DESTROY(port);
	    }
	  else
	    {
	      myListen(port) = NO;
	      NSMapInsert(messagePortMap, (void*)myName(port), (void*)port);
	      NSDebugMLLog(@"NSMessagePort", @"Created speaking port: %@",
		port);
	    }
	}
    }
  else
    {
      RETAIN(port);
      NSDebugMLLog(@"NSMessagePort", @"Using pre-existing port: %@", port);
    }
  IF_NO_GC(AUTORELEASE(port));

  M_UNLOCK(messagePortLock);
  return port;
}

- (id) copyWithZone: (NSZone*)zone
{
  return RETAIN(self);
}

- (void) dealloc
{
  [self gcFinalize];
  DESTROY(myName(self));
  [super dealloc];
}

- (NSString*) description
{
  NSString	*desc;

  desc = [NSString stringWithFormat: @"<NSMessagePort %p with name %@>",
    self, myName(self)];
  return desc;
}

- (void) gcFinalize
{
  NSDebugMLLog(@"NSMessagePort", @"NSMessagePort 0x%x finalized", self);
  [self invalidate];
}

- (id) conversation: (NSPort*)recvPort
{
  return nil;
}

- (void) handlePortMessage: (NSPortMessage*)m
{
  id	d = [self delegate];

  if (d == nil)
    {
      NSDebugMLLog(@"NSMessagePort",
	@"No delegate to handle incoming message", 0);
      return;
    }
  if ([d respondsToSelector: @selector(handlePortMessage:)] == NO)
    {
      NSDebugMLLog(@"NSMessagePort", @"delegate doesn't handle messages", 0);
      return;
    }
  [d handlePortMessage: m];
}

- (unsigned) hash
{
  return [myName(self) hash];
}

- (id) init
{
  RELEASE(self);
  self = [messagePortClass new];
  return self;
}

- (void) invalidate
{
  if ([self isValid] == YES)
    {
      M_LOCK(myLock(self));
      if ([self isValid] == YES)
	{
	  M_LOCK(messagePortLock);
	  if (myEvent(self) != INVALID_HANDLE_VALUE)
	    {
	      (void) CloseHandle(myEvent(self));
	      myEvent(self) = INVALID_HANDLE_VALUE;
	    }
	  if (myHandle(self) != INVALID_HANDLE_VALUE)
	    {
	      (void) CloseHandle(myHandle(self));
	      myHandle(self) = INVALID_HANDLE_VALUE;
	    }
	  NSMapRemove(messagePortMap, (void*)myName(self));
	  M_UNLOCK(messagePortLock);

// FIXME	  [[NSMessagePortNameServer sharedInstance] removePort: self];
	  [super invalidate];
	}
      M_UNLOCK(myLock(self));
    }
}

- (BOOL) isEqual: (id)anObject
{
  if (anObject == self)
    {
      return YES;
    }
  if ([anObject class] == [self class])
    {
      NSMessagePort	*o = (NSMessagePort*)anObject;

      return [myName(o) isEqual: myName(self)];
    }
  return NO;
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  HANDLE		h = (HANDLE)(gsaddr)extra;

}

/*
 * This returns the amount of space that a port coder should reserve at the
 * start of its encoded data so that the NSMessagePort can insert header info
 * into the data.
 * The idea is that a message consisting of a single data item with space at
 * the start can be written directly without having to copy data to another
 * buffer etc.
 */
- (unsigned int) reservedSpaceLength
{
  return sizeof(GSPortItemHeader) + sizeof(GSPortMsgHeader);
}

- (BOOL) sendBeforeDate: (NSDate*)when
		  msgid: (int)msgId
             components: (NSMutableArray*)components
                   from: (NSPort*)receivingPort
               reserved: (unsigned)length
{
  BOOL		sent = NO;
  unsigned	rl;

  if ([self isValid] == NO)
    {
      return NO;
    }
  if ([components count] == 0)
    {
      NSLog(@"empty components sent");
      return NO;
    }
  /*
   * If the reserved length in the first data object is wrong - we have to
   * fail, unless it's zero, in which case we can insert a data object for
   * the header.
   */
  rl = [self reservedSpaceLength];
  if (length != 0 && length != rl)
    {
      NSLog(@"bad reserved length - %u", length);
      return NO;
    }
  if ([receivingPort isKindOfClass: messagePortClass] == NO)
    {
      NSLog(@"woah there - receiving port is not the correct type");
      return NO;
    }

  return sent;
}

- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode
{
  return nil;
}

@end


