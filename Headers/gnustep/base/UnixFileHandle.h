/* Interface for UnixFileHandle for GNUStep
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

#ifndef __UnixFileHandle_h_GNUSTEP_BASE_INCLUDE
#define __UnixFileHandle_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSFileHandle.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSRunLoop.h>

#include <GSConfig.h>

#if	USE_ZLIB
#include <zlib.h>
#endif

@interface UnixFileHandle : NSFileHandle <RunLoopEvents, GCFinalization>
{
  int			descriptor;
  BOOL			closeOnDealloc;
  BOOL			isStandardFile;
  BOOL			isNullDevice;
  BOOL			isNonBlocking;
  BOOL			wasNonBlocking;
  BOOL			acceptOK;
  BOOL			connectOK;
  BOOL			readOK;
  BOOL			writeOK;
  NSMutableDictionary	*readInfo;
  int			readMax;
  NSMutableArray	*writeInfo;
  int			writePos;
  NSString		*address;
  NSString		*service;
  NSString		*protocol;
#if	USE_ZLIB
  gzFile		gzDescriptor;
#endif
}

- (id) initAsClientAtAddress: (NSString*)address
		     service: (NSString*)service
		    protocol: (NSString*)protocol;
- (id) initAsClientInBackgroundAtAddress: (NSString*)address
				 service: (NSString*)service
				protocol: (NSString*)protocol
				forModes: (NSArray*)modes;
- (id) initAsServerAtAddress: (NSString*)address
		     service: (NSString*)service
		    protocol: (NSString*)protocol;
- (id) initForReadingAtPath: (NSString*)path;
- (id) initForWritingAtPath: (NSString*)path;
- (id) initForUpdatingAtPath: (NSString*)path;
- (id) initWithStandardError;
- (id) initWithStandardInput;
- (id) initWithStandardOutput;
- (id) initWithNullDevice;

- (void) checkAccept;
- (void) checkConnect;
- (void) checkRead;
- (void) checkWrite;

- (void) ignoreReadDescriptor;
- (void) ignoreWriteDescriptor;
- (void) setNonBlocking: (BOOL)flag;
- (void) postReadNotification;
- (void) postWriteNotification;
- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
	         extra: (void*)extra
	       forMode: (NSString*)mode;
- (void) setAddr: (struct sockaddr_in *)sin;
- (NSDate*) timedOutEvent: (void*)data
		    type: (RunLoopEventType)type
		 forMode: (NSString*)mode;
- (BOOL) useCompression;
- (void) watchReadDescriptorForModes: (NSArray*)modes;
- (void) watchWriteDescriptor;

@end

#endif /* __UnixFileHandle_h_GNUSTEP_BASE_INCLUDE */
