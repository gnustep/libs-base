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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#ifndef __NSFileHandle_h_GNUSTEP_BASE_INCLUDE
#define __NSFileHandle_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>

@interface NSFileHandle : NSObject

// Allocating and Initializing a FileHandle Object

+ (id)fileHandleForReadingAtPath:(NSString*)path;
+ (id)fileHandleForWritingAtPath:(NSString*)path;
+ (id)fileHandleForUpdatingAtPath:(NSString*)path;
+ (id)fileHandleWithStandardError;
+ (id)fileHandleWithStandardInput;
+ (id)fileHandleWithStandardOutput;
+ (id)fileHandleWithNullDevice;

- (id)initWithFileDescriptor:(int)desc;
- (id)initWithFileDescriptor:(int)desc closeOnDealloc:(BOOL)flag;
- (id)initWithNativeHandle:(void*)hdl;
- (id)initWithNativeHandle:(void*)hdl closeOnDealloc:(BOOL)flag;

// Returning file handles

- (int)fileDescriptor;
- (void*)nativeHandle;

// Synchronous I/O operations

- (NSData*)availableData;
- (NSData*)readDataToEndOfFile;
- (NSData*)readDataOfLength:(unsigned int)len;
- (void)writeData:(NSData*)item;

// Asynchronous I/O operations

- (void)acceptConnectionInBackgroundAndNotifyForModes:(NSArray*)modes;
- (void)acceptConnectionInBackgroundAndNotify;
- (void)readInBackgroundAndNotifyForModes:(NSArray*)modes;
- (void)readInBackgroundAndNotify;
- (void)readToEndOfFileInBackgroundAndNotifyForModes:(NSArray*)modes;
- (void)readToEndOfFileInBackgroundAndNotify;

// Seeking within a file

- (unsigned long long)offsetInFile;
- (unsigned long long)seekToEndOfFile;
- (void)seekToFileOffset:(unsigned long long)pos;

// Operations on file

- (void)closeFile;
- (void)synchronizeFile;
- (void)truncateFileAtOffset:(unsigned long long)pos;

@end

// Notification names.

extern	NSString*	NSFileHandleConnectionAcceptedNotification;
extern	NSString*	NSFileHandleReadCompletionNotification;
extern	NSString*	NSFileHandleReadToEndOfFileCompletionNotification;

// Keys for accessing userInfo dictionary in notification handlers.

extern NSString*	NSFileHandleNotificationDataItem;
extern NSString*	NSFileHandleNotificationFileHandleItem;
extern NSString*	NSFileHandleNotificationMonitorModes;

// Exceptions

extern NSString*	NSFileHandleOperationException;

@interface NSPipe : NSObject
{
   NSFileHandle*	readHandle;
   NSFileHandle*	writeHandle;
}
+ (id)pipe;
- (NSFileHandle*)fileHandleForReading;
- (NSFileHandle*)fileHandleForWriting;
@end


// GNUstep class extensions

@interface NSFileHandle (GNUstepExtensions)
+ (id)fileHandleAsServerAtAddress:(NSString*)address
			  service:(NSString*)service
			 protocol:(NSString*)protocol;
+ (id)fileHandleAsClientAtAddress:(NSString*)address
			  service:(NSString*)service
			 protocol:(NSString*)protocol;
+ (id)fileHandleAsClientAtAddress:(NSString*)address
			  service:(NSString*)service
			 protocol:(NSString*)protocol
			 forModes:(NSArray*)modes;
- (BOOL)readInProgress;
- (void)writeInBackgroundAndNotify:(NSData*)item forModes:(NSArray*)modes;
- (void)writeInBackgroundAndNotify:(NSData*)item;
- (BOOL)writeInProgress;
@end

// GNUstep Notification names.

extern	NSString*	GSFileHandleConnectCompletionNotification;
extern	NSString*	GSFileHandleWriteCompletionNotification;

// Message describing error in async accept,read,write operation.
extern	NSString*	GSFileHandleNotificationError;

#endif /* __NSFileHandle_h_GNUSTEP_BASE_INCLUDE */
