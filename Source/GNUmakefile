#
#  src makefile for the GNUstep Base Library
#
#  Copyright (C) 1997 Free Software Foundation, Inc.
#
#  Written by:	Scott Christley <scottc@net-community.com>
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
#  Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#  Boston, MA 02111 USA.
#

# Install into the system root by default
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../base.make
include $(GNUSTEP_MAKEFILES)/common.make

include ../Version
include ../config.mak

# Interface version changes with each minor release
libgnustep-base_INTERFACE_VERSION=${MAJOR_VERSION}.${MINOR_VERSION}
libgnustep-baseadd_INTERFACE_VERSION=${MAJOR_VERSION}.${MINOR_VERSION}

PACKAGE_NAME = gnustep-base

# The library to be compiled
LIBRARY_NAME=
ifeq ($(add),yes)
LIBRARY_NAME += libgnustep-baseadd
endif

ifneq ($(base),no)
LIBRARY_NAME += libgnustep-base
endif

libgnustep-base_SUBPROJECTS=Additions
libgnustep-baseadd_SUBPROJECTS=Additions

ifeq ($(GNUSTEP_TARGET_OS), mingw32)
libgnustep-base_SUBPROJECTS+=win32
else
libgnustep-base_SUBPROJECTS+=unix
endif

ifeq ($(GNUSTEP_TARGET_OS), mingw32)

DEFS= -DGNUSTEP_TARGET_DIR=\"$(GNUSTEP_TARGET_DIR)\" \
	-DGNUSTEP_TARGET_CPU=\"$(GNUSTEP_TARGET_CPU)\" \
	-DGNUSTEP_TARGET_OS=\"$(GNUSTEP_TARGET_OS)\" \
	-DGNUSTEP_FLATTENED=\"$(GNUSTEP_FLATTENED)\" \
	-DLIBRARY_COMBO=\"$(LIBRARY_COMBO)\"


else

DEFS= -DGNUSTEP_TARGET_DIR=\"$(GNUSTEP_TARGET_DIR)\" \
	-DGNUSTEP_TARGET_CPU=\"$(GNUSTEP_TARGET_CPU)\" \
	-DGNUSTEP_TARGET_OS=\"$(GNUSTEP_TARGET_OS)\" \
	-DGNUSTEP_FLATTENED=\"$(GNUSTEP_FLATTENED)\" \
	-DLIBRARY_COMBO=\"$(LIBRARY_COMBO)\"

endif

# The GNU source files

GNU_MFILES = \
GSCompatibility.m \
GSLocale.m \
preface.m \
mframe.m

ifeq ($(findstring openbsd, $(GNUSTEP_TARGET_OS)), openbsd)
GNU_MFILES += thr-pthread.m
OBJC_LIBS += -lpthread
endif

ifneq ($(OBJC_RUNTIME_LIB), gnu)
GNU_MFILES += objc-gnu2next.m
ifeq ($(HAVE_PTHREAD_H), yes)
GNU_MFILES += thr-pthread.m
else
GNU_MFILES += thr-mach.m
endif
endif

ifeq ($(GNUSTEP_TARGET_OS), mingw32)
GNU_MFILES += libgnustep-base-entry.m
endif

GNU_OTHER_SRCFILES = \
win32-entry.m \
win32-def.top \
libgnustep-base.def

ADD_HEADERS = \
GSObjCRuntime.h \
GSCategories.h \
GSFileHandle.h \
GSUnion.h \
GSIArray.h \
GSIMap.h \
GCObject.h \
GSLock.h \
GSFunctions.h \
GSMime.h \
GSXML.h \
GSLocale.h \
Unicode.h \
GNUstep.h \
behavior.h \
preface.h \
objc-gnu2next.h \

GNU_HEADERS = $(ADD_HEADERS)

# GNUStep source files

BASE_MFILES = \
GSArray.m \
GSAttributedString.m \
GSConcreteValue.m \
GSCountedSet.m \
GSDictionary.m \
GSFormat.m \
GSFTPURLHandle.m \
GSHTTPURLHandle.m \
GSRunLoopWatcher.m \
GSSet.m \
GSStream.m \
GSString.m \
GSValue.m \
NSAttributedString.m \
NSArchiver.m \
NSArray.m \
NSAssertionHandler.m \
NSAutoreleasePool.m \
NSBundle.m \
NSCalendarDate.m \
NSCallBacks.m \
NSCharacterSet.m \
NSClassDescription.m \
NSCoder.m \
NSCopyObject.m \
NSCountedSet.m \
NSConcreteNumber.m \
NSConnection.m \
NSData.m \
NSDate.m \
NSDateFormatter.m \
NSDebug.m \
NSDecimal.m \
NSDecimalNumber.m \
NSDictionary.m \
NSDistantObject.m \
NSDistributedLock.m \
NSDistributedNotificationCenter.m \
NSEnumerator.m \
NSError.m \
NSException.m \
NSFileHandle.m \
NSFileManager.m \
NSFormatter.m \
NSGeometry.m \
NSHashTable.m \
NSHost.m \
NSIndexPath.m \
NSIndexSet.m \
NSInvocation.m \
NSKeyedArchiver.m \
NSKeyedUnarchiver.m \
NSKeyValueCoding.m \
NSKeyValueObserving.m \
NSLock.m \
NSLog.m \
NSMapTable.m \
NSMethodSignature.m \
NSNotification.m \
NSNotificationCenter.m \
NSNotificationQueue.m \
NSNull.m \
NSNumber.m \
NSNumberFormatter.m \
NSObjCRuntime.m \
NSObject.m \
NSPage.m \
NSPathUtilities.m \
NSPipe.m \
NSPort.m \
NSPortCoder.m \
NSPortMessage.m \
NSPortNameServer.m \
NSPredicate.m \
NSProcessInfo.m \
NSPropertyList.m \
NSProtocolChecker.m \
NSProxy.m \
NSRange.m \
NSRunLoop.m \
NSScanner.m \
NSSerializer.m \
NSSet.m \
NSSocketPort.m \
NSSocketPortNameServer.m \
NSSortDescriptor.m \
NSString.m \
NSTask.m \
NSThread.m \
NSTimer.m \
NSTimeZone.m \
NSUnarchiver.m \
NSUndoManager.m \
NSURL.m \
NSURLHandle.m \
NSUserDefaults.m \
NSValue.m \
NSXMLParser.m \
NSZone.m \
externs.m \
objc-load.m 


ifneq ($(GNUSTEP_TARGET_OS), mingw32)
BASE_MFILES += \
GSFileHandle.m \
NSMessagePort.m \
NSMessagePortNameServer.m
endif

ifeq ($(WITH_FFI),libffi)
GNU_MFILES += cifframe.m
BASE_MFILES += GSFFIInvocation.m
endif
ifeq ($(WITH_FFI),ffcall)
GNU_MFILES += callframe.m
BASE_MFILES += GSFFCallInvocation.m
endif

BASE_OTHER_SRCFILES = \
NSConcreteNumberTemplate.m \
GSConcreteValueTemplate.m \
GSTemplateValue.m \
dld-load.h \
hpux-load.h \
null-load.h \
simple-load.h \
win32-load.h \
NSCallBacks.h \
tzfile.h

FOUNDATION_HEADERS = \
Foundation.h \
NSArchiver.h \
NSArray.h \
NSAttributedString.h \
NSAutoreleasePool.h \
NSBundle.h \
NSByteOrder.h \
NSCalendarDate.h \
NSCharacterSet.h \
NSClassDescription.h \
NSCoder.h \
NSComparisonPredicate.h \
NSCompoundPredicate.h \
NSConnection.h \
NSData.h \
NSDate.h \
NSDateFormatter.h \
NSDebug.h \
NSDecimal.h \
NSDecimalNumber.h \
NSDictionary.h \
NSDistantObject.h \
NSDistributedLock.h \
NSDistributedNotificationCenter.h \
NSEnumerator.h \
NSError.h \
NSException.h \
NSExpression.h \
NSFileHandle.h \
NSFileManager.h \
NSFormatter.h \
NSGeometry.h \
NSHashTable.h \
NSHost.h \
NSIndexPath.h \
NSIndexSet.h \
NSInvocation.h \
NSKeyedArchiver.h \
NSKeyValueCoding.h \
NSKeyValueObserving.h \
NSLock.h \
NSMapTable.h \
NSMethodSignature.h \
NSNotification.h \
NSNotificationQueue.h \
NSNull.h \
NSNumberFormatter.h \
NSObjCRuntime.h \
NSObject.h \
NSPathUtilities.h \
NSPort.h \
NSPortCoder.h \
NSPortMessage.h \
NSPortNameServer.h \
NSPredicate.h \
NSProcessInfo.h \
NSPropertyList.h \
NSProtocolChecker.h \
NSProxy.h \
NSRange.h \
NSRunLoop.h \
NSScanner.h \
NSSerialization.h \
NSSet.h \
NSSortDescriptor.h \
NSStream.h \
NSString.h \
NSTask.h \
NSThread.h \
NSTimeZone.h \
NSTimer.h \
NSURL.h \
NSURLHandle.h \
NSUndoManager.h \
NSUserDefaults.h \
NSUtilities.h \
NSValue.h \
NSXMLParser.h \
NSZone.h

UNICODE_HEADERS = \
unicode/caseconv.h \
unicode/cop.h \
unicode/cyrillic.h \
unicode/latin2.h \
unicode/decomp.h \
unicode/nextstep.h

HEADERS_INSTALL = $(GNU_HEADERS) \
                  $(FOUNDATION_HEADERS) \
                  $(UNICODE_HEADERS)

GENERATED_HFILES = \
dynamic-load.h \
$(HEADER_DIR_BASE)/preface.h \
$(GNUSTEP_TARGET_DIR)/mframe.h \
$(GNUSTEP_TARGET_DIR)/config.h \
$(GNUSTEP_TARGET_DIR)/GSConfig.h

ifeq ($(HAVE_INET_PTON), no)
GNU_CFILES += inet_pton.c
endif

# The Objective-C source files to be compiled
libgnustep-base_OBJC_FILES = $(GNU_MFILES) \
	$(BASE_MFILES)
libgnustep-base_C_FILES = $(GNU_CFILES)

# Extra DLL exports file
libgnustep-base_DLL_DEF = libgnustep-base.def

libgnustep-base_HEADER_FILES_DIR = $(HEADER_DIR_FND)
libgnustep-base_HEADER_FILES_INSTALL_DIR = /Foundation

libgnustep-base_HEADER_FILES = $(FOUNDATION_HEADERS)

# Resources
RESOURCE_SET_NAME = libbase-resources
libbase-resources_RESOURCE_FILES_INSTALL_DIR = Library/Libraries/Resources/gnustep-base
libbase-resources_LANGUAGES =
libbase-resources_LOCALIZED_RESOURCE_FILES =
libbase-resources_RESOURCE_DIRS =
libbase-resources_RESOURCE_FILES = Info-gnustep.plist


-include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/resource-set.make

-include Makefile.postamble

include CompatibilityHeaders.make
