/* Interface for NSFileHandle for GNUStep
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
   */

#ifndef __NSFileHandle_h_GNUSTEP_BASE_INCLUDE
#define __NSFileHandle_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>

@interface NSFileHandle : NSObject

// Allocating and Initializing a FileHandle Object

+ (id) fileHandleForReadingAtPath: (NSString*)path;
+ (id) fileHandleForWritingAtPath: (NSString*)path;
+ (id) fileHandleForUpdatingAtPath: (NSString*)path;
+ (id) fileHandleWithStandardError;
+ (id) fileHandleWithStandardInput;
+ (id) fileHandleWithStandardOutput;
+ (id) fileHandleWithNullDevice;

- (id) initWithFileDescriptor: (int)desc;
- (id) initWithFileDescriptor: (int)desc closeOnDealloc: (BOOL)flag;
- (id) initWithNativeHandle: (void*)hdl;
- (id) initWithNativeHandle: (void*)hdl closeOnDealloc: (BOOL)flag;

// Returning file handles

- (int) fileDescriptor;
- (void*) nativeHandle;

// Synchronous I/O operations

- (NSData*) availableData;
- (NSData*) readDataToEndOfFile;
- (NSData*) readDataOfLength: (unsigned int)len;
- (void) writeData: (NSData*)item;

// Asynchronous I/O operations

- (void) acceptConnectionInBackgroundAndNotifyForModes: (NSArray*)modes;
- (void) acceptConnectionInBackgroundAndNotify;
- (void) readInBackgroundAndNotifyForModes: (NSArray*)modes;
- (void) readInBackgroundAndNotify;
- (void) readToEndOfFileInBackgroundAndNotifyForModes: (NSArray*)modes;
- (void) readToEndOfFileInBackgroundAndNotify;
- (void) waitForDataInBackgroundAndNotifyForModes: (NSArray*)modes;
- (void) waitForDataInBackgroundAndNotify;

// Seeking within a file

- (unsigned long long) offsetInFile;
- (unsigned long long) seekToEndOfFile;
- (void) seekToFileOffset: (unsigned long long)pos;

// Operations on file

- (void) closeFile;
- (void) synchronizeFile;
- (void) truncateFileAtOffset: (unsigned long long)pos;

@end

// Notification names.

GS_EXPORT NSString*	NSFileHandleConnectionAcceptedNotification;
GS_EXPORT NSString*	NSFileHandleDataAvailableNotification;
GS_EXPORT NSString*	NSFileHandleReadCompletionNotification;
GS_EXPORT NSString*	NSFileHandleReadToEndOfFileCompletionNotification;

// Keys for accessing userInfo dictionary in notification handlers.

GS_EXPORT NSString*	NSFileHandleNotificationDataItem;
GS_EXPORT NSString*	NSFileHandleNotificationFileHandleItem;
GS_EXPORT NSString*	NSFileHandleNotificationMonitorModes;

// Exceptions

GS_EXPORT NSString*	NSFileHandleOperationException;

@interface NSPipe : NSObject
{
   NSFileHandle*	readHandle;
   NSFileHandle*	writeHandle;
}
+ (id) pipe;
- (NSFileHandle*) fileHandleForReading;
- (NSFileHandle*) fileHandleForWriting;
@end



#ifndef	NO_GNUSTEP

// GNUstep class extensions

@interface NSFileHandle (GNUstepExtensions)
+ (id) fileHandleAsServerAtAddress: (NSString*)address
			   service: (NSString*)service
			  protocol: (NSString*)protocol;
+ (id) fileHandleAsClientAtAddress: (NSString*)address
			   service: (NSString*)service
			  protocol: (NSString*)protocol;
+ (id) fileHandleAsClientInBackgroundAtAddress: (NSString*)address
				       service: (NSString*)service
				      protocol: (NSString*)protocol;
+ (id) fileHandleAsClientInBackgroundAtAddress: (NSString*)address
				       service: (NSString*)service
				      protocol: (NSString*)protocol
				      forModes: (NSArray*)modes;
- (BOOL) readInProgress;
- (NSString*) socketAddress;
- (NSString*) socketService;
- (NSString*) socketProtocol;
- (void) writeInBackgroundAndNotify: (NSData*)item forModes: (NSArray*)modes;
- (void) writeInBackgroundAndNotify: (NSData*)item;
- (BOOL) writeInProgress;
@end

/*
 * Where OpenSSL is available, you can use the GSUnixSSLHandle subclass
 * to handle SSL connections.
 *   The -sslConnect method is used to do SSL handlshake and start an
 *   encrypted session.
 *   The -sslDisconnect method is used to end the encrypted session.
 *   The -sslSetCertificate:privateKey:PEMpasswd: method is used to
 *   establish a client certificate before starting an encrypted session.
 */
@class	GSUnixSSLHandle;
@interface NSFileHandle (GNUstepOpenSSL)
- (void) sslConnect;
- (void) sslDisconnect;
- (void) sslSetCertificate: (NSString*)certFile
                privateKey: (NSString*)privateKey
                 PEMpasswd: (NSString*)PEMpasswd;
@end

// GNUstep Notification names.

GS_EXPORT NSString*	GSFileHandleConnectCompletionNotification;
GS_EXPORT NSString*	GSFileHandleWriteCompletionNotification;

// Message describing error in async accept,read,write operation.
GS_EXPORT NSString*	GSFileHandleNotificationError;
#endif

#endif /* __NSFileHandle_h_GNUSTEP_BASE_INCLUDE */
