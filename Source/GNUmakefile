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
#  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
#

# Install into the system root by default
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../base.make
include $(GNUSTEP_MAKEFILES)/common.make

include ../Version
include ../config.mak

srcdir = .
PACKAGE_NAME = gnustep-base
LIBRARY_VAR = GNUSTEP_BASE

# The library to be compiled
LIBRARY_NAME=libgnustep-base

ifeq ($(HAVE_OPENSSL), yes)

# The bundles to be compiled
BUNDLE_NAME=SSL

# Additional search directories for linking
SSL_LIB_DIRS += -L$(GNUSTEP_OBJ_DIR)

# The bundle Objective-C source files to be compiled
SSL_OBJC_FILES = GSUnixSSLHandle.m

# The principal class in the bundle
SSL_PRINCIPAL_CLASS = GSUnixSSLHandle

SSL_BUNDLE_LIBS = -lgnustep-base -lobjc $(SSLLIBS)

endif

# GNUSTEP_INSTALL_PREFIX must be defined here and not in config.h because
# the installing person may set it on the `make' command line.

ifeq ($(GNUSTEP_TARGET_OS), mingw32)

GNUSTEP_TARGET_INSTALL_PREFIX := \
     $(shell echo $(GNUSTEP_SYSTEM_ROOT) | sed 's|^[a-zA-Z]:/|/|')
GNUSTEP_TARGET_LOCAL_ROOT := \
     $(shell echo $(GNUSTEP_LOCAL_ROOT) | sed 's|^[a-zA-Z]:/|/|')
GNUSTEP_TARGET_NETWORK_ROOT := \
     $(shell echo $(GNUSTEP_NETWORK_ROOT) | sed 's|^[a-zA-Z]:/|/|')
DEFS= -DGNUSTEP_INSTALL_PREFIX=$(GNUSTEP_TARGET_INSTALL_PREFIX) \
	-DGNUSTEP_LOCAL_ROOT=$(GNUSTEP_TARGET_LOCAL_ROOT) \
	-DGNUSTEP_NETWORK_ROOT=$(GNUSTEP_TARGET_NETWORK_ROOT) \
	-DGNUSTEP_TARGET_DIR=\"$(GNUSTEP_TARGET_DIR)\" \
	-DGNUSTEP_TARGET_CPU=\"$(GNUSTEP_TARGET_CPU)\" \
	-DGNUSTEP_TARGET_OS=\"$(GNUSTEP_TARGET_OS)\" \
	-DLIBRARY_COMBO=\"$(LIBRARY_COMBO)\"

else

GNUSTEP_INSTALL_PREFIX=$(GNUSTEP_SYSTEM_ROOT)
DEFS= -DGNUSTEP_INSTALL_PREFIX=$(GNUSTEP_INSTALL_PREFIX) \
	-DGNUSTEP_LOCAL_ROOT=$(GNUSTEP_LOCAL_ROOT) \
	-DGNUSTEP_NETWORK_ROOT=$(GNUSTEP_NETWORK_ROOT) \
	-DGNUSTEP_TARGET_DIR=\"$(GNUSTEP_TARGET_DIR)\" \
	-DGNUSTEP_TARGET_CPU=\"$(GNUSTEP_TARGET_CPU)\" \
	-DGNUSTEP_TARGET_OS=\"$(GNUSTEP_TARGET_OS)\" \
	-DLIBRARY_COMBO=\"$(LIBRARY_COMBO)\"

endif

# The GNU source files

GNU_MFILES = \
GSCompatibility.m \
GSLocale.m \
Unicode.m \
behavior.m \
preface.m \
mframe.m

ifeq ($(OBJC_RUNTIME), NeXT)
GNU_MFILES += objc-gnu2next.m
ifeq ($(HAVE_PTHREAD_H), yes)
GNU_MFILES += thr-pthread.m
else
GNU_MFILES += thr-mach.m
endif
endif

ifeq ($(GNUSTEP_TARGET_OS), mingw32)
GNU_MFILES += WindowsFileHandle.m libgnustep-base-entry.m
else
GNU_MFILES += UnixFileHandle.m 
endif

GNU_CFILES = \
md5.c \
numbers.c \
o_vscanf.c 

GNU_OTHER_SRCFILES = \
md5.h \
win32-entry.m \
win32-def.top \
libgnustep-base.def

GNU_HEADERS = \
DistributedObjects.h \
GSLocale.h \
GSUnion.h \
GSIArray.h \
GSIMap.h \
Unicode.h \
UnixFileHandle.h \
behavior.h \
numbers.h \
objc-gnu2next.h \
preface.h

ifeq ($(OBJC_RUNTIME), NeXT)
GNU_HEADERS += thr-mach.h
endif
# GNUStep source files

BASE_MFILES = \
GSArray.m \
GSAttributedString.m \
GSCountedSet.m \
GSDictionary.m \
GSFormat.m \
GSHTTPURLHandle.m \
GSMime.m \
GSSet.m \
GSString.m \
GSValue.m \
GSXML.m \
NSAttributedString.m \
NSArchiver.m \
NSArray.m \
NSAssertionHandler.m \
NSAutoreleasePool.m \
NSBitmapCharSet.m \
NSBundle.m \
NSCalendarDate.m \
NSCallBacks.m \
NSCharacterSet.m \
NSClassDescription.m \
NSCoder.m \
NSCopyObject.m \
NSCountedSet.m \
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
NSException.m \
NSFileHandle.m \
NSFileManager.m \
NSFormatter.m \
NSGeometry.m \
NSHashTable.m \
NSHost.m \
NSInvocation.m \
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
NSPipe.m \
NSPort.m \
GSTcpPort.m \
NSPortCoder.m \
NSPortMessage.m \
NSPortNameServer.m \
NSProcessInfo.m \
NSProtocolChecker.m \
NSProxy.m \
NSRange.m \
NSRunLoop.m \
NSScanner.m \
NSSerializer.m \
NSSet.m \
NSString.m \
NSTask.m \
NSThread.m \
NSTimer.m \
NSTimeZone.m \
NSUnarchiver.m \
NSUndoManager.m \
NSURL.m \
NSURLHandle.m \
NSUser.m \
NSUserDefaults.m \
NSValue.m \
NSZone.m \
externs.m \
objc-load.m

ifeq ($(WITH_FFI),libffi)
GNU_MFILES += cifframe.m
BASE_MFILES += GSFFIInvocation.m
endif
ifeq ($(WITH_FFI),ffcall)
GNU_MFILES += callframe.m
BASE_MFILES += GSFFCallInvocation.m
endif

NSVALUE_MFILES = \
	GSValue0.m GSValue1.m GSValue2.m GSValue3.m \
	GSValue4.m GSValue5.m
NSNUMBER_MFILES = \
	NSNumber0.m NSNumber1.m NSNumber2.m NSNumber3.m \
	NSNumber4.m NSNumber5.m NSNumber6.m NSNumber7.m \
	NSNumber8.m NSNumber9.m NSNumber10.m NSNumber11.m \
	NSNumber12.m

BASE_OTHER_SRCFILES = \
NSConcreteNumber.m \
GSTemplateValue.m \
dld-load.h \
hpux-load.h \
null-load.h \
simple-load.h \
win32-load.h \
NSCallBacks.h \
tzfile.h

AUTOGSDOC_HEADERS = \
GSMime.h \
GSXML.h \
NSArchiver.h \
NSArray.h \
NSAttributedString.h \
NSAutoreleasePool.h \
NSBitmapCharSet.h \
NSBundle.h \
NSCalendarDate.h \
NSCharacterSet.h \
NSClassDescription.h \
NSCoder.h \
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
NSException.h \
NSFileHandle.h \
NSFileManager.h \
NSFormatter.h \
NSGeometry.h \
NSHashTable.h \
NSHost.h \
NSInvocation.h \
NSLock.h \
NSMapTable.h \
NSMethodSignature.h \
NSNotification.h \
NSNotificationQueue.h \
NSNull.h \
NSNumberFormatter.h \
NSObjCRuntime.h \
NSObject.h \
NSPort.h \
NSPortCoder.h \
NSPortMessage.h \
NSPortNameServer.h \
NSProcessInfo.h \
NSProtocolChecker.h \
NSProxy.h \
NSRange.h \
NSRunLoop.h \
NSScanner.h \
NSSet.h \
NSString.h \
NSTask.h \
NSThread.h \
NSTimeZone.h \
NSTimer.h \
NSURL.h \
NSURLHandle.h \
NSUndoManager.h \
NSUserDefaults.h \
NSValue.h \
NSZone.h

FOUNDATION_HEADERS = \
Foundation.h \
NSByteOrder.h \
NSConcreteNumber.h \
NSKeyValueCoding.h \
NSPathUtilities.h \
NSSerialization.h \
NSUtilities.h \
$(AUTOGSDOC_HEADERS) \
objc-load.h


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
$(HEADER_DIR)/preface.h \
$(GNUSTEP_TARGET_DIR)/mframe.h \
$(GNUSTEP_TARGET_DIR)/config.h \
$(GNUSTEP_TARGET_DIR)/GSConfig.h

# The C source files to be compiled
libgnustep-base_C_FILES = $(GNU_CFILES)

# The Objective-C source files to be compiled
libgnustep-base_OBJC_FILES = $(GNU_MFILES) \
	$(BASE_MFILES) $(NSVALUE_MFILES) $(NSNUMBER_MFILES)

# Extra DLL exports file
libgnustep-base_DLL_DEF = libgnustep-base.def

libgnustep-base_HEADER_FILES_DIR = $(HEADER_DIR)
libgnustep-base_HEADER_FILES_INSTALL_DIR = /Foundation

libgnustep-base_HEADER_FILES = $(FOUNDATION_HEADERS)

DOCUMENT_NAME = Base

Base_HEADER_FILES_DIR = $(HEADER_DIR)
Base_AGSDOC_FILES = Base.gsdoc $(AUTOGSDOC_HEADERS)
Base_AGSDOC_FLAGS = \
	-HeaderDirectory ../Headers/Foundation \
	-Declared Foundation \
	-Standards YES \
	-Up Base

-include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/bundle.make

# Only build the doc if doc=yes was passed on the command line
ifeq ($(doc),yes)
include $(GNUSTEP_MAKEFILES)/documentation.make
endif

-include Makefile.postamble
