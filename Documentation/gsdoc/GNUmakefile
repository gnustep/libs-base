#
#  doc makefile for the GNUstep Base Library
#  Copyright (C) 2000 Free Software Foundation, Inc.
#
#  Written by:	Richard Frith-Macdonald <rfm@gnu.org>
#
#  This file is part of the GNUstep Base Library.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Library General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  Library General Public License for more details.
#
#  You should have received a copy of the GNU Library General Public
#  License along with this library; if not, write to the Free
#  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

# Install into the system root by default
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../../base.make
include $(GNUSTEP_MAKEFILES)/common.make

# The documents to be generated
DOCUMENT_NAME = Base

Base_GSDOC_FILES = Base.gsdoc \
	NSArchiver.gsdoc \
	NSArray.gsdoc \
	NSAssertionHandler.gsdoc \
	NSAttributedString.gsdoc \
	NSAutoreleasePool.gsdoc \
	NSBundle.gsdoc \
	NSCalendarDate.gsdoc \
	NSCharacterSet.gsdoc \
	NSCoder.gsdoc \
	NSConditionLock.gsdoc \
	NSConnection.gsdoc \
	NSCountedSet.gsdoc \
	NSDate.gsdoc \
	NSDateFormatter.gsdoc \
	NSDecimalNumber.gsdoc \
	NSDecimalNumberHandler.gsdoc \
	NSDeserializer.gsdoc \
	NSDictionary.gsdoc \
	NSDirectoryEnumerator.gsdoc \
	NSDistantObject.gsdoc \
	NSDistantObjectRequest.gsdoc \
	NSDistributedLock.gsdoc \
	NSDistributedNotificationCenter.gsdoc \
	NSEnumerator.gsdoc \
	NSException.gsdoc \
	NSFileHandle.gsdoc \
	NSFileManager.gsdoc \
	NSFormatter.gsdoc \
	NSHost.gsdoc \
	NSInvocation.gsdoc \
	NSLock.gsdoc \
	NSMethodSignature.gsdoc \
	NSMutableArray.gsdoc \
	NSMutableAttributedString.gsdoc \
	NSMutableCharacterSet.gsdoc \
	NSMutableData.gsdoc \
	NSMutableDictionary.gsdoc \
	NSMutableSet.gsdoc \
	NSMutableString.gsdoc \
	NSNotification.gsdoc \
	NSNotificationCenter.gsdoc \
	NSNotificationQueue.gsdoc \
	NSNull.gsdoc \
	NSNumber.gsdoc \
	NSNumberFormatter.gsdoc \
	NSPort.gsdoc \
	NSPortCoder.gsdoc \
	NSPortMessage.gsdoc \
	NSPortNameServer.gsdoc \
	NSProcessInfo.gsdoc \
	NSProtocolChecker.gsdoc \
	NSProxy.gsdoc \
	NSRecursiveLock.gsdoc \
	NSRunLoop.gsdoc \
	NSScanner.gsdoc \
	NSSerializer.gsdoc \
	NSSet.gsdoc \
	NSString.gsdoc \
	NSTask.gsdoc \
	NSThread.gsdoc \
	NSTimeZone.gsdoc \
	NSTimer.gsdoc \
	NSUnarchiver.gsdoc \
	NSUndoManager.gsdoc \
	NSUserDefaults.gsdoc \
	NSValue.gsdoc \
	NSFunctions.gsdoc

Base_DOC_INSTALL_DIR = Developer/Base/Reference

-include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/documentation.make

-include Makefile.postamble
