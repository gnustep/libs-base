/** Implementation for NSFileHandle for GNUStep
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1997

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSFileHandle class reference</title>
   $Date$ $Revision$
   */

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSBundle.h>
#include <Foundation/GSFileHandle.h>

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

+ (id) fileHandleForReadingAtPath: (NSString*)path
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initForReadingAtPath: path]);
}

+ (id) fileHandleForWritingAtPath: (NSString*)path
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initForWritingAtPath: path]);
}

+ (id) fileHandleForUpdatingAtPath: (NSString*)path
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initForUpdatingAtPath: path]);
}

+ (id) fileHandleWithStandardError
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithStandardError]);
}

+ (id) fileHandleWithStandardInput
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithStandardInput]);
}

+ (id) fileHandleWithStandardOutput
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithStandardOutput]);
}

+ (id) fileHandleWithNullDevice
{
  id	o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithNullDevice]);
}

- (id) initWithFileDescriptor: (int)desc
{
  return [self initWithFileDescriptor: desc closeOnDealloc: NO];
}

- (id) initWithFileDescriptor: (int)desc closeOnDealloc: (BOOL)flag
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithNativeHandle: (void*)hdl
{
  return [self initWithNativeHandle: hdl closeOnDealloc: NO];
}

// This is the designated initializer.

- (id) initWithNativeHandle: (void*)hdl closeOnDealloc: (BOOL)flag
{
  [self subclassResponsibility: _cmd];
  return nil;
}

// Returning file handles

- (int) fileDescriptor
{
  [self subclassResponsibility: _cmd];
  return -1;
}

- (void*) nativeHandle
{
  [self subclassResponsibility: _cmd];
  return 0;
}

// Synchronous I/O operations

- (NSData*) availableData
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSData*) readDataToEndOfFile
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSData*) readDataOfLength: (unsigned int)len
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) writeData: (NSData*)item
{
  [self subclassResponsibility: _cmd];
}


// Asynchronous I/O operations

- (void) acceptConnectionInBackgroundAndNotify
{
  [self acceptConnectionInBackgroundAndNotifyForModes: nil];
}

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
 * Set up an asynchonous read operation which will cause a notification to
 * be sent when any amount of data (or end of file) is read.
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
 * Set up an asynchonous read operation which will cause a notification to
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

- (unsigned long long) offsetInFile
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned long long) seekToEndOfFile
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) seekToFileOffset: (unsigned long long)pos
{
  [self subclassResponsibility: _cmd];
}


// Operations on file

- (void) closeFile
{
  [self subclassResponsibility: _cmd];
}

- (void) synchronizeFile
{
  [self subclassResponsibility: _cmd];
}

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

NSString * const NSFileHandleOperationException
  = @"NSFileHandleOperationException";


// GNUstep class extensions

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
 *     from the host name by a colon.
 *   </item>
 *   <item>
 *     If modes is nil or empty, uses NSDefaultRunLoopMode.
 *   </item>
 * </list>
 * <p>
 *   This method supports connection through a firewall via socks5.  The
 *   socks5 connection may be controlled via the protocol argument, but if
 *   no socks infromation is supplied here, the <em>GSSOCKS</em> user default
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
 * Set up an asynchonous read operation which will cause a notification to
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
 * Return a flag to indicate whether compression has been turned on for
 * the file handle ... this is only available on systems where GNUstep
 * was built with 'zlib' support for compressing/decompressing data.
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
      NSBundle	*bundle;
      NSString	*path;

      path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
	NSSystemDomainMask, NO) lastObject];
      path = [path stringByAppendingPathComponent: @"Bundles"];
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

/**
 * Establishes an SSL connection to the system that the handle is talking to.
 */
- (BOOL) sslConnect
{
  return NO;
}

/**
 * Shuts down the SSL connection to the system that the handle is talking to.
 */
- (void) sslDisconnect
{
}

/**
 * Sets the certificate to be used to identify this process to the server
 * at the opposite end of the network connection.
 */
- (void) sslSetCertificate: (NSString*)certFile
                privateKey: (NSString*)privateKey
                 PEMpasswd: (NSString*)PEMpasswd
{
}
@end

