/** Implementation for NSFileHandle for GNUStep
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1997

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSFileHandle class reference</title>
   $Date$ $Revision$
   */

#import "config.h"
#define	EXPOSE_NSFileHandle_IVARS	1
#import "GNUstepBase/preface.h"
#import "Foundation/NSObject.h"
#import "Foundation/NSData.h"
#import "Foundation/NSString.h"
#import "Foundation/NSFileHandle.h"
#import "Foundation/NSPathUtilities.h"
#import "Foundation/NSBundle.h"
#import "GNUstepBase/GSFileHandle.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

// GNUstep Notification names

NSString * const GSFileHandleConnectCompletionNotification
  = @"GSFileHandleConnectCompletionNotification";
NSString * const GSFileHandleWriteCompletionNotification
  = @"GSFileHandleWriteCompletionNotification";

// GNUstep key for getting error message.

NSString * const GSFileHandleNotificationError
  = @"GSFileHandleNotificationError";

static Class NSFileHandle_abstract_class = nil;
static Class NSFileHandle_concrete_class = nil;
static Class NSFileHandle_ssl_class = nil;

/**
 * <p>
 * <code>NSFileHandle</code> is a class that provides a wrapper for accessing
 * system files and socket connections. You can open connections to a
 * file using class methods such as +fileHandleForReadingAtPath:.
 * </p>
 * <p>
 * GNUstep extends the use of this class to allow you to create
 * network connections (sockets), secure connections and also allows
 * you to use compression with these files and connections (as long as
 * GNUstep Base was compiled with the zlib library).
 * </p>
 */
@implementation NSFileHandle

+ (void) initialize
{
  if (self == [NSFileHandle class])
    {
      NSFileHandle_abstract_class = self;
      NSFileHandle_concrete_class = [GSFileHandle class];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSFileHandle_abstract_class)
    {
      return NSAllocateObject (NSFileHandle_concrete_class, 0, z);
    }
  else
    {
      return NSAllocateObject (self, 0, z);
    }
}

// Allocating and Initializing a FileHandle Object
/**
 * Returns an <code>NSFileHandle</code> object set up for reading from the
 * file listed at path. If the file does not exist or cannot
 * be opened for some other reason, nil is returned.
 */
+ (id) fileHandleForReadingAtPath: (NSString*)path
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initForReadingAtPath: path]);
}

/**
 * Returns an <code>NSFileHandle</code> object set up for writing to the
 * file listed at path. If the file does not exist or cannot
 * be opened for some other reason, nil is returned.
 */
+ (id) fileHandleForWritingAtPath: (NSString*)path
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initForWritingAtPath: path]);
}

/**
 * Returns an <code>NSFileHandle</code> object setup for updating (reading and
 * writing) from the file listed at path. If the file does not exist
 * or cannot be opened for some other reason, nil is returned.
 */
+ (id) fileHandleForUpdatingAtPath: (NSString*)path
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initForUpdatingAtPath: path]);
}

/**
 * Returns an <code>NSFileHandle</code> object for the standard error
 * descriptor.  The returned object is a shared instance as there can only be
 * one standard error per process.
 */
+ (id) fileHandleWithStandardError
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithStandardError]);
}

/**
 * Returns an <code>NSFileHandle</code> object for the standard input
 * descriptor.  The returned object is a shared instance as there can only be
 * one standard input per process.
 */
+ (id) fileHandleWithStandardInput
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithStandardInput]);
}

/**
 * Returns an <code>NSFileHandle</code> object for the standard output
 * descriptor.  The returned object is a shared instance as there can only be
 * one standard output per process.
 */
+ (id) fileHandleWithStandardOutput
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithStandardOutput]);
}

/**
 * Returns a file handle object that is connected to the null device
 * (i.e. a device that does nothing.)  It is typically used in arrays
 * and other collections of file handle objects as a place holder
 * (null) object, so that all objects can respond to the same
 * messages.
 */
+ (id) fileHandleWithNullDevice
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithNullDevice]);
}

/**
 *  Initialize with desc, which can point to either a regular file or
 *  socket connection.
 */
- (id) initWithFileDescriptor: (int)desc
{
  return [self initWithFileDescriptor: desc closeOnDealloc: NO];
}

/**
 *  Initialize with desc, which can point to either a regular file or
 *  socket connection.  Close desc when this instance is deallocated if
 *  flag is YES.
 */
- (id) initWithFileDescriptor: (int)desc closeOnDealloc: (BOOL)flag
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 *  Windows-Unix compatibility support.
 */
- (id) initWithNativeHandle: (void*)hdl
{
  return [self initWithNativeHandle: hdl closeOnDealloc: NO];
}

// This is the designated initializer.

/**
 *  <init/>
 *  Windows-Unix compatibility support.
 */
- (id) initWithNativeHandle: (void*)hdl closeOnDealloc: (BOOL)flag
{
  [self subclassResponsibility: _cmd];
  return nil;
}

// Returning file handles

/**
 *  Return the underlying file descriptor for this instance.
 */
- (int) fileDescriptor
{
  [self subclassResponsibility: _cmd];
  return -1;
}

/**
 *  Windows-Unix compatibility support.
 */
- (void*) nativeHandle
{
  [self subclassResponsibility: _cmd];
  return 0;
}

// Synchronous I/O operations

/**
 *  Synchronously returns data available through this file or connection.
 *  If the handle represents a file, the entire contents from current file
 *  pointer to end are returned.  If this is a network connection, reads
 *  what is available, blocking if nothing is available.  Raises
 *  <code>NSFileHandleOperationException</code> if problem encountered.
 */
- (NSData*) availableData
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 * Reads up to maximum unsigned int bytes from file or communications
 * channel into return data.<br />
 * If the file is empty, returns an empty data item.
 */
- (NSData*) readDataToEndOfFile
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 *  Reads up to len bytes from file or communications channel into return data.
 */
- (NSData*) readDataOfLength: (unsigned int)len
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 *  Synchronously writes given data item to file or connection.
 */
- (void) writeData: (NSData*)item
{
  [self subclassResponsibility: _cmd];
}


// Asynchronous I/O operations

/**
 *  Asynchronously accept a stream-type socket connection and act as the
 *  (server) end of the communications channel.  This instance should have
 *  been created by -initWithFileDescriptor: with a stream-type socket created
 *  by the appropriate system routine.  Posts a
 *  <code>NSFileHandleConnectionAcceptedNotification</code> when connection
 *  initiated, returning an <code>NSFileHandle</code> for the client side with
 *  that notification.
 */
- (void) acceptConnectionInBackgroundAndNotify
{
  [self acceptConnectionInBackgroundAndNotifyForModes: nil];
}

/**
 *  <p>Asynchronously accept a stream-type socket connection and act as the
 *  (server) end of the communications channel.  This instance should have
 *  been created by -initWithFileDescriptor: with a stream-type socket created
 *  by the appropriate system routine.  Posts a
 *  <code>NSFileHandleConnectionAcceptedNotification</code> when connection
 *  initiated, returning an <code>NSFileHandle</code> for the client side with
 *  that notification.</p>
 *
 *  <p>The modes array specifies [NSRunLoop] modes that the notification can
 *  be posted in.</p>
 */
- (void) acceptConnectionInBackgroundAndNotifyForModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}

/**
 * Call -readInBackgroundAndNotifyForModes: with nil modes.
 */
- (void) readInBackgroundAndNotify
{
  [self readInBackgroundAndNotifyForModes: nil];
}

/**
 * Set up an asynchronous read operation which will cause a notification to
 * be sent when any amount of data (or end of file) is read. Note that
 * the file handle will not continuously send notifications when data
 * is available. If you want to continue to receive notifications, you
 * need to send this message again after receiving a notification.
 */
- (void) readInBackgroundAndNotifyForModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}

/**
 * Call -readToEndOfFileInBackgroundAndNotifyForModes: with nil modes.
 */
- (void) readToEndOfFileInBackgroundAndNotify
{
  [self readToEndOfFileInBackgroundAndNotifyForModes: nil];
}

/**
 * Set up an asynchronous read operation which will cause a notification to
 * be sent when end of file is read.
 */
- (void) readToEndOfFileInBackgroundAndNotifyForModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}

/**
 * Call -waitForDataInBackgroundAndNotifyForModes: with nil modes.
 */
- (void) waitForDataInBackgroundAndNotify
{
  [self waitForDataInBackgroundAndNotifyForModes: nil];
}

/**
 * Set up to provide a notification when data can be read from the handle.
 */
- (void) waitForDataInBackgroundAndNotifyForModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}


// Seeking within a file

/**
 *  Return current position in file, or raises exception if instance does
 *  not represent a regular file.
 */
- (unsigned long long) offsetInFile
{
  [self subclassResponsibility: _cmd];
  return 0;
}

/**
 *  Position file pointer at end of file, raising exception if instance does
 *  not represent a regular file.
 */
- (unsigned long long) seekToEndOfFile
{
  [self subclassResponsibility: _cmd];
  return 0;
}

/**
 *  Position file pointer at pos, raising exception if instance does
 *  not represent a regular file.
 */
- (void) seekToFileOffset: (unsigned long long)pos
{
  [self subclassResponsibility: _cmd];
}


// Operations on file

/**
 *  Disallows further reading from read-access files or connections, and sends
 *  EOF on write-access files or connections.  Descriptor is only
 *  <em>deleted</em> when this instance is deallocated.
 */
- (void) closeFile
{
  [self subclassResponsibility: _cmd];
}

/**
 *  Flush in-memory buffer to file or connection, then return.
 */
- (void) synchronizeFile
{
  [self subclassResponsibility: _cmd];
}

/**
 *  Chops file beyond pos then sets file pointer to that point.
 */
- (void) truncateFileAtOffset: (unsigned long long)pos
{
  [self subclassResponsibility: _cmd];
}


@end

// Keys for accessing userInfo dictionary in notification handlers.

NSString * const NSFileHandleNotificationDataItem
  = @"NSFileHandleNotificationDataItem";
NSString * const NSFileHandleNotificationFileHandleItem
  = @"NSFileHandleNotificationFileHandleItem";
NSString * const NSFileHandleNotificationMonitorModes
  = @"NSFileHandleNotificationMonitorModes";

// Notification names

NSString * const NSFileHandleConnectionAcceptedNotification
  = @"NSFileHandleConnectionAcceptedNotification";
NSString * const NSFileHandleDataAvailableNotification
  = @"NSFileHandleDataAvailableNotification";
NSString * const NSFileHandleReadCompletionNotification
  = @"NSFileHandleReadCompletionNotification";
NSString * const NSFileHandleReadToEndOfFileCompletionNotification
  = @"NSFileHandleReadToEndOfFileCompletionNotification";

// Exceptions

/**
 * An exception used when a file error occurs.
 */
NSString * const NSFileHandleOperationException
  = @"NSFileHandleOperationException";


// GNUstep class extensions

/**
 *  A set of convenience methods for utilizing the socket communications
 *  capabilities of the [NSFileHandle] class.
 */
@implementation NSFileHandle (GNUstepExtensions)

/**
 * Opens an outgoing network connection by initiating an asynchronous
 * connection (see
 * [+fileHandleAsClientInBackgroundAtAddress:service:protocol:forModes:])
 * and waiting for it to succeed, fail, or time out.
 */
+ (id) fileHandleAsClientAtAddress: (NSString*)address
			   service: (NSString*)service
			  protocol: (NSString*)protocol
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initAsClientAtAddress: address
				      service: service
				     protocol: protocol]);
}

/**
 * Opens an outgoing network connection asynchronously using
 * [+fileHandleAsClientInBackgroundAtAddress:service:protocol:forModes:]
 */
+ (id) fileHandleAsClientInBackgroundAtAddress: (NSString*)address
				       service: (NSString*)service
				      protocol: (NSString*)protocol
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initAsClientInBackgroundAtAddress: address
						  service: service
						 protocol: protocol
						 forModes: nil]);
}

/**
 * <p>
 *   Opens an outgoing network connection asynchronously.
 * </p>
 * <list>
 *   <item>
 *     The address is the name (or IP dotted quad) of the machine to
 *     which the connection should be made.
 *   </item>
 *   <item>
 *     The service is the name (or number) of the port to
 *     which the connection should be made.
 *   </item>
 *   <item>
 *     The protocol is provided so support different network protocols,
 *     but at present only 'tcp' is supported.  However, a protocol
 *     specification of the form 'socks-...' can be used to control socks5
 *     support.<br />
 *     If '...' is empty (ie the string is just 'socks-' then the connection
 *     is <em>not</em> made via a socks server.<br />
 *     Otherwise, the text '...' must be the name of the host on which the
 *     socks5 server is running, with an optional port number separated
 *     from the host name by a colon.<br />
 *     Alternatively a prefix of the form 'bind-' followed by an IP address
 *     may be used (for non-socks connections) to ensure that the connection
 *     is made from the specified address.
 *   </item>
 *   <item>
 *     If modes is nil or empty, uses NSDefaultRunLoopMode.
 *   </item>
 * </list>
 * <p>
 *   This method supports connection through a firewall via socks5.  The
 *   socks5 connection may be controlled via the protocol argument, but if
 *   no socks information is supplied here, the <em>GSSOCKS</em> user default
 *   will be used, and failing that, the <em>SOCKS5_SERVER</em> or
 *   <em>SOCKS_SERVER</em> environment variables will be used to set the
 *   socks server.  If none of these mechanisms specify a socks server, the
 *   connection will be made directly rather than through socks.
 * </p>
 */
+ (id) fileHandleAsClientInBackgroundAtAddress: (NSString*)address
				       service: (NSString*)service
				      protocol: (NSString*)protocol
				      forModes: (NSArray*)modes
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initAsClientInBackgroundAtAddress: address
						  service: service
						 protocol: protocol
						 forModes: modes]);
}

/**
 * Opens a network server socket and listens for incoming connections
 * using the specified service and protocol.
 * <list>
 *   <item>
 *     The service is the name (or number) of the port to
 *     which the connection should be made.
 *   </item>
 *   <item>
 *     The protocol may at present only be 'tcp'
 *   </item>
 * </list>
 */
+ (id) fileHandleAsServerAtAddress: (NSString*)address
			   service: (NSString*)service
			  protocol: (NSString*)protocol
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initAsServerAtAddress: address
				      service: service
				     protocol: protocol]);
}

/**
 * Call -readDataInBackgroundAndNotifyLength:forModes: with nil modes.
 */
- (void) readDataInBackgroundAndNotifyLength: (unsigned)len
{
  [self readDataInBackgroundAndNotifyLength: len forModes: nil];
}

/**
 * Set up an asynchronous read operation which will cause a notification to
 * be sent when the specified amount of data (or end of file) is read.
 */
- (void) readDataInBackgroundAndNotifyLength: (unsigned)len
				    forModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}

/**
 * Returns a boolean to indicate whether a read operation of any kind is
 * in progress on the handle.
 */
- (BOOL) readInProgress
{
  [self subclassResponsibility: _cmd];
  return NO;
}

/**
 * Returns the host address of the network connection represented by
 * the file handle.  If this handle is an incoming connection which
 * was received by a local server handle, this is the name or address
 * of the client machine.
 */
- (NSString*) socketAddress
{
  return nil;
}

/**
 * Returns the local address of the network connection or nil.
 */
- (NSString*) socketLocalAddress
{
  return nil;
}

/**
 * Returns the local service/port of the network connection or nil.
 */
- (NSString*) socketLocalService
{
  return nil;
}

/**
 * Returns the name (or number) of the service (network port) in use for
 * the network connection represented by the file handle.
 */
- (NSString*) socketService
{
  return nil;
}

/**
 * Returns the name of the protocol in use for the network connection
 * represented by the file handle.
 */
- (NSString*) socketProtocol
{
  return nil;
}

/**
 * <p>
 *   Return a flag to indicate whether compression has been turned on for
 *   the file handle ... this is only available on systems where GNUstep
 *   was built with 'zlib' support for compressing/decompressing data.
 * </p>
 * <p>
 *   On systems which support it, this method may be called after
 *   a file handle has been initialised to turn on compression or
 *   decompression of the data being written/read.
 * </p>
 * Returns YES on success, NO on failure.<br />
 * Reasons for failure are - <br />
 * <list>
 *   <item>Not supported/built in to GNUstep</item>
 *   <item>File handle has been closed</item>
 *   <item>File handle is open for both read and write</item>
 *   <item>Failure in compression/decompression library</item>
 * </list>
 */
- (BOOL) useCompression
{
  return NO;
}

/**
 * Call -writeInBackgroundAndNotify:forModes: with nil modes.
 */
- (void) writeInBackgroundAndNotify: (NSData*)item
{
  [self writeInBackgroundAndNotify: item forModes: nil];
}

/**
 * Write the specified data asynchronously, and notify on completion.
 */
- (void) writeInBackgroundAndNotify: (NSData*)item forModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}

/**
 * Returns a boolean to indicate whether a write operation of any kind is
 * in progress on the handle.  An outgoing network connection attempt
 * (as a client) is considered to be a write operation.
 */
- (BOOL) writeInProgress
{
  [self subclassResponsibility: _cmd];
  return NO;
}

@end

@implementation NSFileHandle (GNUstepOpenSSL)
/**
 * returns the concrete class used to implement SSL connections.
 */
+ (Class) sslClass
{
  if (NSFileHandle_ssl_class == 0)
    {
      NSString  *path;
      NSBundle	*bundle;

      path = [[NSBundle bundleForClass: [NSObject class]] bundlePath];
      path = [path stringByAppendingPathComponent: @"SSL.bundle"];

      bundle = [NSBundle bundleWithPath: path];
      NSFileHandle_ssl_class = [bundle principalClass];
      if (NSFileHandle_ssl_class == 0 && bundle != nil)
	{
	  NSLog(@"Failed to load principal class from bundle (%@)", path);
	}
    }
  return NSFileHandle_ssl_class;
}

/** <override-dummy />
 * Establishes an SSL connection from the system that the handle
 * is talking to.<br />
 * This is implented by an SSL handling subclass.<br />
 * The default implementation just returns NO.
 */
- (BOOL) sslAccept
{
  return NO;
}

/** <override-dummy />
 * Establishes an SSL connection to the system that the handle
 * is talking to.<br />
 * This is implented by an SSL handling subclass.<br />
 * The default implementation just returns NO.
 */
- (BOOL) sslConnect
{
  return NO;
}

/** <override-dummy />
 * Shuts down the SSL connection to the system that the handle is talking to.
 */
- (void) sslDisconnect
{
}

/** <override-dummy />
 * Sets the certificate to be used to identify this process to the server
 * at the opposite end of the network connection.
 */
- (void) sslSetCertificate: (NSString*)certFile
                privateKey: (NSString*)privateKey
                 PEMpasswd: (NSString*)PEMpasswd
{
}
@end

