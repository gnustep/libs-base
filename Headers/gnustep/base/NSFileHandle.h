/** Interface for NSFileHandle for GNUStep
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

    AutogsdocSource: NSFileHandle.m
    AutogsdocSource: NSPipe.m
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

- (void) acceptConnectionInBackgroundAndNotify;
- (void) acceptConnectionInBackgroundAndNotifyForModes: (NSArray*)modes;
- (void) readInBackgroundAndNotify;
- (void) readInBackgroundAndNotifyForModes: (NSArray*)modes;
- (void) readToEndOfFileInBackgroundAndNotify;
- (void) readToEndOfFileInBackgroundAndNotifyForModes: (NSArray*)modes;
- (void) waitForDataInBackgroundAndNotify;
- (void) waitForDataInBackgroundAndNotifyForModes: (NSArray*)modes;

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

GS_EXPORT NSString * const NSFileHandleConnectionAcceptedNotification;
GS_EXPORT NSString * const NSFileHandleDataAvailableNotification;
GS_EXPORT NSString * const NSFileHandleReadCompletionNotification;
GS_EXPORT NSString * const NSFileHandleReadToEndOfFileCompletionNotification;

// Keys for accessing userInfo dictionary in notification handlers.

GS_EXPORT NSString * const NSFileHandleNotificationDataItem;
GS_EXPORT NSString * const NSFileHandleNotificationFileHandleItem;
GS_EXPORT NSString * const NSFileHandleNotificationMonitorModes;

// Exceptions

GS_EXPORT NSString * const NSFileHandleOperationException;

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
- (void) readDataInBackgroundAndNotifyLength: (unsigned)len;
- (void) readDataInBackgroundAndNotifyLength: (unsigned)len
				    forModes: (NSArray*)modes;
- (BOOL) readInProgress;
- (NSString*) socketAddress;
- (NSString*) socketService;
- (NSString*) socketProtocol;
- (BOOL) useCompression;
- (void) writeInBackgroundAndNotify: (NSData*)item forModes: (NSArray*)modes;
- (void) writeInBackgroundAndNotify: (NSData*)item;
- (BOOL) writeInProgress;
@end

/*
 * Where OpenSSL is available, you can use the subclass returned by +sslClass
 * to handle SSL connections.
 *   The -sslConnect method is used to do SSL handlshake and start an
 *   encrypted session.
 *   The -sslDisconnect method is used to end the encrypted session.
 *   The -sslSetCertificate:privateKey:PEMpasswd: method is used to
 *   establish a client certificate before starting an encrypted session.
 */
@interface NSFileHandle (GNUstepOpenSSL)
+ (Class) sslClass;
- (BOOL) sslConnect;
- (void) sslDisconnect;
- (void) sslSetCertificate: (NSString*)certFile
                privateKey: (NSString*)privateKey
                 PEMpasswd: (NSString*)PEMpasswd;
@end

// GNUstep Notification names.

GS_EXPORT NSString * const GSFileHandleConnectCompletionNotification;
GS_EXPORT NSString * const GSFileHandleWriteCompletionNotification;

// Message describing error in async accept,read,write operation.
GS_EXPORT NSString * const GSFileHandleNotificationError;
#endif

#endif /* __NSFileHandle_h_GNUSTEP_BASE_INCLUDE */
