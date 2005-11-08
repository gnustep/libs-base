/** Implementation of network port object based on windows mailboxes
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>

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

extern int	errno;

@interface	NSMessagePort (Internal)
+ (NSMessagePort*) recvPort: (NSString*)name;
+ (NSMessagePort*) sendPort: (NSString*)name;
- (id) initWithName: (NSString*)name;
- (NSString*) name;
- (void) receivedEventRead;
- (void) receivedEventWrite;
@end

#define	UNISTR(X) \
((const unichar*)[(X) cStringUsingEncoding: NSUnicodeStringEncoding])

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
  GSP_ITEM,		/* Expecting a port item header.	*/
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
  unsigned char version;
  unsigned char	port[24];
} GSPortMsgHeader;

typedef	struct {
  NSString              *name;
  NSRecursiveLock       *lock;
  HANDLE                handle;
  HANDLE                event;
  OVERLAPPED		ov;
  DWORD			size;
  BOOL			listener;

  NSMutableData		*wData;		/* Data object being written.	*/
  unsigned		wLength;	/* Amount written so far.	*/
  NSMutableArray	*wMsgs;		/* Message in progress.		*/
  NSMutableData		*rData;		/* Buffer for incoming data	*/
  gsu32			rLength;	/* Amount read so far.		*/
  gsu32			rWant;		/* Amount desired.		*/
  NSMessagePort		*rPort;		/* Port of message being read.	*/
  NSMutableArray	*rItems;	/* Message in progress.		*/
  GSPortItemType	rType;		/* Type of data being read.	*/
  gsu32			rId;		/* Id of incoming message.	*/
  unsigned		nItems;		/* Number of items to be read.	*/
} internal;
#define	PORT(X)		((internal*)((NSMessagePort*)X)->_internal)

/*
 * Largest chunk of data possible in DO
 */
static gsu32	maxDataLength = 10 * 1024 * 1024;

@implementation	NSMessagePort

static NSRecursiveLock	*messagePortLock = nil;

/*
 * Maps port name to NSMessagePort objects.
 */
static NSMapTable	*recvPorts = 0;
static NSMapTable	*sendPorts = 0;
static Class		messagePortClass;

#define	HDR	(sizeof(GSPortItemHeader) + sizeof(GSPortMsgHeader))

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
      recvPorts = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 0);
      sendPorts = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 0);

      messagePortLock = [GSLazyRecursiveLock new];
    }
}

+ (NSMessagePort*) recvPort: (NSString*)name
{
  NSMessagePort	*p;

  if (name == nil)
    {
      p = AUTORELEASE([[self alloc] init]);
    }
  else
    {
      M_LOCK(messagePortLock);
      p = AUTORELEASE(RETAIN((NSMessagePort*)NSMapGet(recvPorts, (void*)name)));
      M_UNLOCK(messagePortLock);
    }
  return p;
}

+ (NSMessagePort*) sendPort: (NSString*)name
{
  NSMessagePort	*p;

  NSAssert(p != nil, @"sendPort: called with nil name");
  M_LOCK(messagePortLock);
  p = AUTORELEASE(RETAIN((NSMessagePort*)NSMapGet(sendPorts, (void*)name)));
  if (p == nil)
    {
      p = AUTORELEASE([[self alloc] initWithName: name]);
    }
  M_UNLOCK(messagePortLock);
  return p;
}

- (void) addConnection: (NSConnection*)aConnection
             toRunLoop: (NSRunLoop*)aLoop
               forMode: (NSString*)aMode
{
  [aLoop addEvent: (void*)(gsaddr)PORT(self)->handle
	     type: ET_HANDLE
	  watcher: (id<RunLoopEvents>)self
	  forMode: aMode];
}

- (id) copyWithZone: (NSZone*)zone
{
  return RETAIN(self);
}

- (void) dealloc
{
  [self gcFinalize];
  [super dealloc];
}

- (NSString*) description
{
  NSString	*desc;

  desc = [NSString stringWithFormat: @"<NSMessagePort %p with name %@>",
    self, PORT(self)->name];
  return desc;
}

- (void) gcFinalize
{
  internal	*this;

  NSDebugMLLog(@"NSMessagePort", @"NSMessagePort 0x%x finalized", self);
  [self invalidate];
  this = PORT(self);
  if (this != 0)
    {
      DESTROY(this->name);
      DESTROY(this->rData);
      DESTROY(this->rItems);
      DESTROY(this->wMsgs);
      DESTROY(this->lock);
      NSZoneFree(NSDefaultMallocZone(), _internal);
      _internal = 0;
    }
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
  return [PORT(self)->name hash];
}

- (id) init
{
  static unsigned	sequence = 0;
  static int		ident;
  internal		*this;

  if (sequence == 0)
    {
      ident = [[NSProcessInfo processInfo] processIdentifier];
    }
  M_LOCK(messagePortLock);
  _internal = NSZoneMalloc(NSDefaultMallocZone(), sizeof(internal));
  memset(_internal, '\0', sizeof(internal));
  this = PORT(self);
  self->_is_valid = YES;
#if	(GS_SIZEOF_INT > 4)
  this->name = [[NSString alloc] initWithFormat: @"%08x%08x%08x",
    (((unsigned)ident) >> 32), (((unsigned)ident) & 0xffffffff), sequence++];
#else
  this->name = [[NSString alloc] initWithFormat: @"00000000%08x%08x",
    ((unsigned)ident), sequence++];
#endif

  this->listener = YES;
  this->event = CreateEvent(NULL, FALSE, FALSE, NULL);
  this->ov.hEvent = this->event;
  this->lock = [GSLazyRecursiveLock new];
  this->rData = [NSMutableData new];

  this->handle = CreateMailslotW(
    UNISTR(this->name),
    0,				/* No max message size.		*/
    MAILSLOT_WAIT_FOREVER,	/* No read/write timeout.	*/
    (LPSECURITY_ATTRIBUTES)0);

  if (this->handle == INVALID_HANDLE_VALUE)
    {
      NSLog(@"unable to create mailslot '%@' - %s",
	this->name, GSLastErrorStr(errno));
      DESTROY(self);
    }
  else
    {
      NSMapInsert(recvPorts, (void*)this->name, (void*)self);
      NSDebugMLLog(@"NSMessagePort", @"Created listening port: %@", self);

      /*
       * Simulate a read event to kick off the I/O for this handle.
       * If we can't start reading, we will be invalidated, and must
       * then destroy self.
       */
      [self receivedEventRead];
      if ([self isValid] == NO)
	{
	  DESTROY(self);
	}
    }

  M_UNLOCK(messagePortLock);
  return self;
}

- (id) initWithName: (NSString*)name
{
  NSMessagePort	*p;

  M_LOCK(messagePortLock);
  p = RETAIN((NSMessagePort*)NSMapGet(recvPorts, (void*)name));
  if (p == nil)
    {
      internal	*this;

      _internal = NSZoneMalloc(NSDefaultMallocZone(), sizeof(internal));
      memset(_internal, '\0', sizeof(internal));
      this = PORT(self);
      self->_is_valid = YES;
      this->name = [name copy];

      this->listener = NO;
      this->event = CreateEvent(NULL, FALSE, FALSE, NULL);
      this->ov.hEvent = this->event;
      this->lock = [GSLazyRecursiveLock new];
      this->wMsgs = [NSMutableArray new];

      this->handle = CreateFileW(
	UNISTR(this->name),
	GENERIC_WRITE,
	FILE_SHARE_READ,
	(LPSECURITY_ATTRIBUTES)0,
	OPEN_EXISTING,
	FILE_ATTRIBUTE_NORMAL,
	(HANDLE)0);
      if (this->handle == INVALID_HANDLE_VALUE)
	{
	  NSLog(@"unable to access mailslot '%@' - %s",
	    this->name, GSLastErrorStr(errno));
	  DESTROY(self);
	}
      else
	{
	  NSMapInsert(sendPorts, (void*)this->name, (void*)self);
	  NSDebugMLLog(@"NSMessagePort", @"Created speaking port: %@", self);
	}
    }
  else
    {
      RELEASE(self);
      self = p;
    }
  M_UNLOCK(messagePortLock);
  return self;
}

- (void) invalidate
{
  RETAIN(self);
  if ([self isValid] == YES)
    {
      internal	*this;

      this = PORT(self);
      M_LOCK(this->lock);
      if ([self isValid] == YES)
	{
	  M_LOCK(messagePortLock);
	  if (this->handle != INVALID_HANDLE_VALUE)
	    {
	      (void) CancelIo(this->handle);
	    }
	  if (this->event != INVALID_HANDLE_VALUE)
	    {
	      (void) CloseHandle(this->event);
	      this->event = INVALID_HANDLE_VALUE;
	    }
	  if (this->handle != INVALID_HANDLE_VALUE)
	    {
	      (void) CloseHandle(this->handle);
	      this->handle = INVALID_HANDLE_VALUE;
	    }
	  if (this->listener == YES)
	    {
	      NSMapRemove(recvPorts, (void*)this->name);
	    }
	  else
	    {
	      NSMapRemove(sendPorts, (void*)this->name);
	    }
	  M_UNLOCK(messagePortLock);

// FIXME	  [[NSMessagePortNameServer sharedInstance] removePort: self];
	  [super invalidate];
	}
      M_UNLOCK(this->lock);
    }
  RELEASE(self);
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

      return [PORT(o)->name isEqual: PORT(self)->name];
    }
  return NO;
}

- (NSString*) name
{
  return PORT(self)->name;
}


/*
 * Called when an event occurs on a listener port
 * ALSO called when the port is created, to start reading.
 */
- (void) receivedEventRead
{
  internal	*this = PORT(self);
  BOOL		shouldDispatch = NO;

  M_LOCK(this->lock);

  /*
   * Got something ... is it all we want?
   */
  this->rLength += this->size;
  this->size = 0;

  /*
   * Do next part only if we have completed a read.
   */
  if (this->rWant > 0 && this->rLength == this->rWant)
    {
      switch (this->rType)
	{
	  case GSP_ITEM:
	    {
	      GSPortItemHeader	*h;
	      unsigned		l;

	      /*
	       * We have read an item header - set up to read the
	       * remainder of the item.
	       */
	      h = (GSPortItemHeader*)[this->rData bytes];
	      this->rType = GSSwapBigI32ToHost(h->type);
	      l = GSSwapBigI32ToHost(h->length);
	      if (this->rType == GSP_HEAD)
		{
		  if (l + sizeof(GSPortItemHeader) > this->rWant)
		    {
		      // There is more to read ... do it.
		      this->rWant = l + sizeof(GSPortItemHeader);
		      this->rType = GSP_HEAD;
		    }
		  else
		    {
		      goto gsp_head;
		    }
		}
	      else if (this->rType == GSP_PORT)
		{
		  if (l != 24)
		    {
		      NSLog(@"%@ - unreasonable length (%u) for port", self, l);
		      [self invalidate];
		      break;
		    }
		  this->rWant = l;
		  [this->rData setLength: this->rWant];
		}
	      else if (this->rType == GSP_DATA)
		{
		  if (l == 0)
		    {
		      NSData	*d;

		      /*
		       * For a zero-length data chunk, we create an empty
		       * data object and add it to the current message.
		       */
		      d = [NSMutableData new];
		      [this->rItems addObject: d];
		      RELEASE(d);
		      if (this->nItems == [this->rItems count])
			{
			  shouldDispatch = YES;
			}
		    }
		  else
		    {
		      if (l > maxDataLength)
			{
			  NSLog(@"%@ - unreasonable length (%u) for data",
				self, l);
			  [self invalidate];
			  break;
			}
		      this->rWant = l;
		      [this->rData setLength: this->rWant];
		    }
		}
	      else
		{
		  NSLog(@"%@ - bad data received on port handle", self);
		  [self invalidate];
		  return;
		}
	    }
	  break;

	  case GSP_HEAD:
	    gsp_head:
	    {
	      unsigned char	*b = [this->rData mutableBytes];
	      GSPortItemHeader	*pih;
	      GSPortMsgHeader	*pmh;
	      NSString		*n;
	      NSMessagePort	*p;
	      unsigned		l;
	      NSMutableData	*d;

	      pih = (GSPortItemHeader*)b;
	      l = GSSwapBigI32ToHost(pih->length);
	      pmh = (GSPortMsgHeader*)(b + sizeof(GSPortItemHeader));
	      this->rId = GSSwapBigI32ToHost(pmh->mId);
	      this->nItems = GSSwapBigI32ToHost(pmh->nItems);
	      if (this->nItems == 0)
		{
		  NSLog(@"%@ - unable to decode remote port", self);
		  [self invalidate];
		  break;
		}
	      n = [[NSString alloc] initWithBytes: pmh->port
					   length: 24
					 encoding: NSASCIIStringEncoding];
	      NSDebugFLLog(@"NSMessagePort", @"Decoded port as '%@'", n);
	      p = [NSMessagePort sendPort: n];
	      RELEASE(n);
	      if (p == nil)
		{
		  NSLog(@"%@ - unable to decode remote port", self);
		  [self invalidate];
		  break;
		}
	      ASSIGN(this->rPort, p);
	      this->rItems
		= [NSMutableArray allocWithZone: NSDefaultMallocZone()];
	      this->rItems = [this->rItems initWithCapacity: this->nItems];
	      b = (unsigned char*)&pmh[1];
	      l -= sizeof(GSPortMsgHeader);
	      d = [[NSMutableData alloc] initWithBytes: b length: l];
	      [this->rItems addObject: d];
	      RELEASE(d);
	      if (this->nItems == [this->rItems count])
		{
		  shouldDispatch = YES;
		}
	    }
	  break;

	  case GSP_DATA:
	    {
	      NSMutableData	*d;

	      d = [this->rData mutableCopy];
	      [this->rItems addObject: d];
	      RELEASE(d);
	      if (this->nItems == [this->rItems count])
		{
		  shouldDispatch = YES;
		}
	    }
	  break;

	  case GSP_PORT:
	    {
	      NSMessagePort	*p;
	      NSString		*n;

	      n = [[NSString alloc] initWithBytes: [this->rData bytes]
					   length: 24
					 encoding: NSASCIIStringEncoding];
	      NSDebugFLLog(@"NSMessagePort", @"Decoded port as '%@'", n);
	      p = [NSMessagePort sendPort: n];
	      RELEASE(n);
	      if (p == nil)
		{
		  NSLog(@"%@ - unable to decode remote port", self);
		  [self invalidate];
		  break;
		}
	      [this->rItems addObject: p];
	      if (this->nItems == [this->rItems count])
		{
		  shouldDispatch = YES;
		}
	    }
	  break;
	}
    }

  if (shouldDispatch == YES)
    {
      NSPortMessage	*pm;

      pm = [NSPortMessage allocWithZone: NSDefaultMallocZone()];
      pm = [pm initWithSendPort: this->rPort
		    receivePort: self
		     components: this->rItems];
      [pm setMsgid: this->rId];
      this->rId = 0;
      DESTROY(this->rPort);
      DESTROY(this->rItems);
      NSDebugMLLog(@"GSTcpHandle", @"got message %@ on 0x%x", pm, self);
      M_UNLOCK(this->lock);
      NS_DURING
	{
	  [self handlePortMessage: pm];
	}
      NS_HANDLER
	{
	  M_LOCK(this->lock);
	  RELEASE(pm);
	  [localException raise];
	}
      NS_ENDHANDLER
      M_LOCK(this->lock);
      RELEASE(pm);
    }

  if ([self isValid] == YES && this->rWant == 0)
    {
      this->rType = GSP_ITEM;
      if (this->nItems > 0)
	{
	  this->rWant = sizeof(GSPortItemHeader);	// Want an item
	}
      else
	{
	  this->rWant = HDR;	// Want an item with a port message header
	}
      [this->rData setLength: this->rWant];
    }

  /*
   * Got something ... is it all we want? If not, ask to read more.
   */
  if ([self isValid] == YES && this->rLength < this->rWant)
    {
      this->ov.Offset = 0;
      this->ov.OffsetHigh = 0;
      this->ov.hEvent = this->event;
      if (ReadFile(this->handle,
	[this->rData mutableBytes],	// Store results here
	this->rWant - this->rLength,
	&this->size,
	&this->ov) == 0 && (errno = GetLastError()) != ERROR_HANDLE_EOF)
	{
	  NSLog(@"unable to read from mailslot '%@' - %s",
	    this->name, GSLastErrorStr(errno));
	  [self invalidate];
	}
    }
  M_UNLOCK(this->lock);
}

/*
 * Called when an event occurs on a speaker port
 * ALSO called when we start trying to write a new message and there
 * wasn't one in progress.
 */
- (void) receivedEventWrite
{
  internal	*this = PORT(self);

  M_LOCK(this->lock);

  this->wLength += this->size;
  this->size = 0;
  /*
   * Handle start of next data item if we havce completed one,
   * or if we are called without a write in progress.
   */
  if (this->wData == nil || this->wLength == [this->wData length])
    {
      unsigned	idx;

      if (this->wData == nil)
	{
	  idx = NSNotFound;
	}
      else
	{
	  NSDebugMLLog(@"GSTcpHandle",
	    @"completed 0x%x on 0x%x", this->wData, self);
	  idx = [this->wMsgs indexOfObjectIdenticalTo: this->wData];
	}
      [this->wMsgs removeObjectAtIndex: idx];
      if ([this->wMsgs count] > 0)
	{
	  this->wData = [this->wMsgs objectAtIndex: 0];
	}
      else
	{
	  this->wData = nil;	// Nothing to write.
	}
      this->wLength = 0;	// Nothing written yet.
    }

  if (this->wData != nil)
    {
      this->ov.Offset = 0;
      this->ov.OffsetHigh = 0;
      this->ov.hEvent = this->event;
      if (WriteFile(this->handle,
	[this->wData bytes],			// Output from here
	[this->wData length] - this->wLength,
	&this->size,				// Store number of bytes written
	&this->ov) == 0 && (errno = GetLastError()) != ERROR_HANDLE_EOF)
	{
	  NSLog(@"unable to write to mailslot '%@' - %s",
	    this->name, GSLastErrorStr(errno));
	  [self invalidate];
	}
    }
  M_UNLOCK(this->lock);
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  RETAIN(self);
  if ([self isValid] == YES)
    {
      internal	*this = PORT(self);

      if (this->listener == YES)
	{
	  [self receivedEventRead];
	}
      else
	{
	  [self receivedEventWrite];
	}
    }
  else
    {
      // Event on invalid port ... remove port from run loop
      [[NSRunLoop currentRunLoop] removeEvent: data
					 type: type
				      forMode: mode
					  all: YES];
    }
  RELEASE(self);
}


- (void) removeConnection: (NSConnection*)aConnection
              fromRunLoop: (NSRunLoop*)aLoop
                  forMode: (NSString*)aMode
{
  [aLoop removeEvent: (void*)(gsaddr)PORT(self)->handle
		type: ET_HANDLE
	     forMode: aMode
		 all: NO];
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
  return sizeof(GSPortItemHeader) + sizeof(GSPortMsgHeader) + 24;
}

- (BOOL) sendBeforeDate: (NSDate*)when
		  msgid: (int)msgId
             components: (NSMutableArray*)components
                   from: (NSPort*)receivingPort
               reserved: (unsigned)length
{
  NSMutableData	*h;
  NSRunLoop	*loop;
  BOOL		sent = NO;
  unsigned	rl;
  unsigned	l = 0;
  unsigned	c;
  unsigned	i;
  internal	*this;

  if ([self isValid] == NO)
    {
      return NO;
    }
  this = PORT(self);

  NSAssert(PORT(self)->listener == NO, @"Attempt to send through recv port");
  c = [components count];
  if (c == 0)
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
  NSAssert([receivingPort isKindOfClass: messagePortClass] == YES,
    @"Receiving port is not the correct type");
  NSAssert([receivingPort isValid] == YES,
    @"Receiving port is not valid");
  NSAssert(PORT(receivingPort)->listener == YES,
    @"Attempt to send to send port");

  if (c == 1 && length == rl)
    {
      GSPortItemHeader	*pih;
      GSPortMsgHeader	*pmh;

      h = [components objectAtIndex: 0];
      pih = (GSPortItemHeader*)[h mutableBytes];
      pih->type = GSSwapHostI32ToBig(GSP_HEAD);
      l = [h length] - sizeof(GSPortMsgHeader);
      pih->length = GSSwapHostI32ToBig(l);
      pmh = (GSPortMsgHeader*)&pih[1];
      pmh->mId = GSSwapHostI32ToBig(msgId);
      pmh->nItems = GSSwapHostI32ToBig(c);
      pmh->version = 0;
      memcpy(pmh->port, [[(NSMessagePort*)receivingPort name] UTF8String], 24);
    }
  else
    {
      for (i = 0; i < c; i++)
	{
	  id	o = [components objectAtIndex: i];

	  if ([o isKindOfClass: [NSData class]] == YES)
	    {
	      l += [[components objectAtIndex: i] length];
	      l += sizeof(GSPortItemHeader);
	    }
	  else
	    {
	      l += sizeof(GSPortItemHeader) + 24;	// A port
	    }
	}
      h = [[NSMutableData alloc] initWithCapacity: sizeof(GSPortMsgHeader) + l];
      
      for (i = 0; i < c; i++)
	{
	  id			o = [components objectAtIndex: i];
	  GSPortItemHeader	pih;

	  if (i == 0)
	    {
	      GSPortMsgHeader	pmh;

	      // First item must be an NSData
	      pih.type = GSSwapHostI32ToBig(GSP_HEAD);
	      l = sizeof(GSPortMsgHeader) + [o length];
	      pih.length = GSSwapHostI32ToBig(l);
	      [h appendBytes: &pih length: sizeof(pih)];
	      pmh.mId = GSSwapHostI32ToBig(msgId);
	      pmh.nItems = GSSwapHostI32ToBig(c);
	      pmh.version = 0;
	      memcpy(pmh.port,
		[[(NSMessagePort*)receivingPort name] UTF8String], 24);
	      [h appendBytes: &pmh length: sizeof(pmh)];
	      [h appendData: o];
	    }
	  else if ([o isKindOfClass: [NSData class]] == YES)
	    {
	      pih.type = GSSwapHostI32ToBig(GSP_DATA);
	      l = [o length];
	      pih.length = GSSwapHostI32ToBig(l);
	      [h appendBytes: &pih length: sizeof(pih)];
	      [h appendData: o];
	    }
	  else
	    {
	      pih.type = GSSwapHostI32ToBig(GSP_PORT);
	      l = 24;
	      pih.length = GSSwapHostI32ToBig(l);
	      [h appendBytes: &pih length: sizeof(pih)];
	      [h appendBytes: [o UTF8String] length: 24];
	    }
	}
    }
 
  /*
   * Now send the message.
   */
  M_LOCK(this->lock);
  [this->wMsgs addObject: h];
  if (this->wData == nil)
    {
      [self receivedEventWrite];	// Start async write.
    }

  loop = [NSRunLoop currentRunLoop];

  RETAIN(self);

  [loop addEvent: (void*)(gsaddr)this->handle
	    type: ET_HANDLE
	 watcher: (id<RunLoopEvents>)self
	 forMode: NSConnectionReplyMode];
  [loop addEvent: (void*)(gsaddr)this->handle
	    type: ET_HANDLE
	 watcher: (id<RunLoopEvents>)self
	 forMode: NSDefaultRunLoopMode];

  while ([self isValid] == YES
    && [this->wMsgs indexOfObjectIdenticalTo: h] != NSNotFound
    && [when timeIntervalSinceNow] > 0)
    {
      M_UNLOCK(this->lock);
      [loop runMode: NSConnectionReplyMode beforeDate: when];
      M_LOCK(this->lock);
    }

  [loop removeEvent: (void*)(gsaddr)this->handle
	       type: ET_HANDLE
	    forMode: NSConnectionReplyMode
		all: NO];
  [loop removeEvent: (void*)(gsaddr)this->handle
	       type: ET_HANDLE
	    forMode: NSDefaultRunLoopMode
		all: NO];

  if ([this->wMsgs indexOfObjectIdenticalTo: h] == NSNotFound)
    {
      sent = YES;
    }
  RELEASE(h);
  M_UNLOCK(this->lock);
  RELEASE(self);

  return sent;
}

- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode
{
  return nil;
}

@end


