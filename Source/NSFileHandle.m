/* Implementation for NSFileHandle for GNUStep
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

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/UnixFileHandle.h>

static Class NSFileHandle_abstract_class = nil;
static Class NSFileHandle_concrete_class = nil;

@implementation NSFileHandle

+ (void)initialize
{
  if (self == [NSFileHandle class])
    {
      NSFileHandle_abstract_class = self;
      NSFileHandle_concrete_class = [UnixFileHandle class];
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
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initForReadingAtPath: path]);
}

+ (id) fileHandleForWritingAtPath: (NSString*)path
{
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initForWritingAtPath: path]);
}

+ (id) fileHandleForUpdatingAtPath: (NSString*)path
{
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initForUpdatingAtPath: path]);
}

+ (id) fileHandleWithStandardError
{
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithStandardError]);
}

+ (id) fileHandleWithStandardInput
{
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithStandardInput]);
}

+ (id) fileHandleWithStandardOutput
{
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initWithStandardOutput]);
}

+ (id) fileHandleWithNullDevice
{
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

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

- (void) acceptConnectionInBackgroundAndNotifyForModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}

- (void) acceptConnectionInBackgroundAndNotify
{
  [self subclassResponsibility: _cmd];
}

- (void) readInBackgroundAndNotifyForModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}

- (void) readInBackgroundAndNotify
{
  [self subclassResponsibility: _cmd];
}

- (void) readToEndOfFileInBackgroundAndNotifyForModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}

- (void) readToEndOfFileInBackgroundAndNotify
{
  [self subclassResponsibility: _cmd];
}

- (void) waitForDataInBackgroundAndNotifyForModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}

- (void) waitForDataInBackgroundAndNotify
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

NSString*	NSFileHandleNotificationDataItem =
		@"NSFileHandleNotificationDataItem";
NSString*	NSFileHandleNotificationFileHandleItem =
		@"NSFileHandleNotificationFileHandleItem";
NSString*	NSFileHandleNotificationMonitorModes =
		@"NSFileHandleNotificationMonitorModes";

// Notification names

NSString*	NSFileHandleConnectionAcceptedNotification =
		@"NSFileHandleConnectionAcceptedNotification";
NSString*	NSFileHandleDataAvailableNotification =
		@"NSFileHandleDataAvailableNotification";
NSString*	NSFileHandleReadCompletionNotification =
		@"NSFileHandleReadCompletionNotification";
NSString*	NSFileHandleReadToEndOfFileCompletionNotification =
		@"NSFileHandleReadToEndOfFileCompletionNotification";

// Exceptions

NSString*	NSFileHandleOperationException =
		@"NSFileHandleOperationException";


// GNUstep class extensions

@implementation NSFileHandle (GNUstepExtensions)

+ (id) fileHandleAsClientAtAddress: (NSString*)address
			   service: (NSString*)service
			  protocol: (NSString*)protocol
{
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initAsClientAtAddress: address
				      service: service
				     protocol: protocol]);
}

+ (id) fileHandleAsClientInBackgroundAtAddress: (NSString*)address
				       service: (NSString*)service
				      protocol: (NSString*)protocol
{
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initAsClientInBackgroundAtAddress: address
						  service: service
						 protocol: protocol
						 forModes: nil]);
}

+ (id) fileHandleAsClientInBackgroundAtAddress: (NSString*)address
				       service: (NSString*)service
				      protocol: (NSString*)protocol
				      forModes: (NSArray*)modes
{
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initAsClientInBackgroundAtAddress: address
						  service: service
						 protocol: protocol
						 forModes: modes]);
}

+ (id) fileHandleAsServerAtAddress: (NSString*)address
			   service: (NSString*)service
			  protocol: (NSString*)protocol
{
  id	o = [NSFileHandle_concrete_class allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initAsServerAtAddress: address
				      service: service
				     protocol: protocol]);
}

- (BOOL) readInProgress
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (NSString*) socketAddress
{
  return nil;
}

- (NSString*) socketService
{
  return nil;
}

- (NSString*) socketProtocol
{
  return nil;
}

- (void) writeInBackgroundAndNotify: (NSData*)item forModes: (NSArray*)modes
{
  [self subclassResponsibility: _cmd];
}

- (void) writeInBackgroundAndNotify: (NSData*)item;
{
  [self subclassResponsibility: _cmd];
}

- (BOOL) writeInProgress
{
  [self subclassResponsibility: _cmd];
  return NO;
}

// GNUstep Notification names

NSString*	GSFileHandleConnectCompletionNotification =
		@"GSFileHandleConnectCompletionNotification";
NSString*	GSFileHandleWriteCompletionNotification =
		@"GSFileHandleWriteCompletionNotification";

// GNUstep key for getting error message.

NSString*	GSFileHandleNotificationError =
		@"GSFileHandleNotificationError";
@end

