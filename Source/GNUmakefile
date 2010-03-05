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
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  Library General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free
#  Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#  Boston, MA 02111 USA.
#

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

PACKAGE_NAME = gnustep-base
GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../base.make

include $(GNUSTEP_MAKEFILES)/common.make

include ../Version
include ../config.mak
-include pathconfig/pathconfig.mak

# Interface version changes with each minor release
libgnustep-base_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libgnustep-baseadd_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)

PACKAGE_NAME = gnustep-base

# The library to be compiled
LIBRARY_NAME=
ifeq ($(add),yes)
LIBRARY_NAME += libgnustep-baseadd
endif

ifneq ($(base),no)
LIBRARY_NAME += libgnustep-base
endif

ifeq ($(OBJC2RUNTIME),0)
libgnustep-base_SUBPROJECTS = ObjectiveC2
libgnustep-baseadd_SUBPROJECTS += Additions
endif

libgnustep-base_SUBPROJECTS += Additions
libgnustep-baseadd_SUBPROJECTS += Additions

ifeq ($(GNUSTEP_TARGET_OS), mingw32)
libgnustep-base_SUBPROJECTS+=win32
else
libgnustep-base_SUBPROJECTS+=unix
endif

DEFS= -DGNUSTEP_TARGET_DIR=\"$(GNUSTEP_TARGET_DIR)\" \
	-DGNUSTEP_TARGET_CPU=\"$(GNUSTEP_TARGET_CPU)\" \
	-DGNUSTEP_TARGET_OS=\"$(GNUSTEP_TARGET_OS)\" \
	-DGNUSTEP_IS_FLATTENED=\"$(GNUSTEP_IS_FLATTENED)\" \
	-DLIBRARY_COMBO=\"$(LIBRARY_COMBO)\" \
	-DGNUSTEP_BASE_INTERNAL=1

# The GNU source files

GNU_MFILES = \
GSLocale.m \
preface.m

ifeq ($(findstring openbsd, $(GNUSTEP_TARGET_OS)), openbsd)
  OBJC_LIBS += -lpthread
endif

ifeq ($(GNUSTEP_TARGET_OS), mingw32)
  GNU_MFILES += libgnustep-base-entry.m
endif

GNU_OTHER_SRCFILES = \
win32-entry.m \
win32-def.top \
libgnustep-base.def

ADD_HEADERS = \
GSBlocks.h \
GSVersionMacros.h \
GSObjCRuntime.h \
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
NSArray+GNUstepBase.h \
NSAttributedString+GNUstepBase.h \
NSBundle+GNUstepBase.h \
NSCalendarDate+GNUstepBase.h \
NSData+GNUstepBase.h \
NSDebug+GNUstepBase.h \
NSFileHandle+GNUstepBase.h \
NSLock+GNUstepBase.h \
NSMutableString+GNUstepBase.h \
NSNumber+GNUstepBase.h \
NSObject+GNUstepBase.h \
NSProcessInfo+GNUstepBase.h \
NSStream+GNUstepBase.h \
NSString+GNUstepBase.h \
NSTask+GNUstepBase.h \
NSThread+GNUstepBase.h \
NSURL+GNUstepBase.h \
Unicode.h \
GNUstep.h \
behavior.h \
preface.h \
Additions.h

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
GSHTTPAuthentication.m \
GSHTTPURLHandle.m \
GSRunLoopWatcher.m \
GSSet.m \
GSSocketStream.m \
GSStream.m \
GSString.m \
GSValue.m \
NSAffineTransform.m \
NSArchiver.m \
NSArray.m \
NSAssertionHandler.m \
NSAttributedString.m \
NSAutoreleasePool.m \
NSBundle.m \
NSCache.m \
NSCachedURLResponse.m \
NSCalendarDate.m \
NSCallBacks.m \
NSCharacterSet.m \
NSClassDescription.m \
NSCoder.m \
NSCopyObject.m \
NSCountedSet.m \
NSConcreteHashTable.m \
NSConcreteMapTable.m \
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
NSGarbageCollector.m \
NSGeometry.m \
NSHashTable.m \
NSHost.m \
NSHTTPCookie.m \
NSHTTPCookieStorage.m \
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
NSObject+NSComparisonMethods.m \
NSOperation.m \
NSPage.m \
NSPathUtilities.m \
NSPipe.m \
NSPointerArray.m \
NSPointerFunctions.m \
NSConcretePointerFunctions.m \
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
NSSpellServer.m \
NSString.m \
NSTask.m \
NSThread.m \
NSTimer.m \
NSTimeZone.m \
NSUnarchiver.m \
NSUndoManager.m \
NSURL.m \
NSURLAuthenticationChallenge.m \
NSURLCache.m \
NSURLCredential.m \
NSURLConnection.m \
NSURLCredentialStorage.m \
NSURLDownload.m \
NSURLProtectionSpace.m \
NSURLProtocol.m \
NSURLRequest.m \
NSURLResponse.m \
NSURLHandle.m \
NSUserDefaults.m \
NSValue.m \
NSValueTransformer.m \
NSXMLDocument.m \
NSXMLDTD.m \
NSXMLDTDNode.m \
NSXMLElement.m \
NSXMLNode.m \
NSXMLParser.m \
NSZone.m \
externs.m \
objc-load.m 

# Not sure that the following is ever needed ...
# we should have synchronisation support from the ObjC2 runtime or
# we should have synchronisation support from the ObjC2 compatibility code or
# we are without native exception and @synchronize support anyway.
#
#ifeq ($(HAVE_OBJC_SYNC_ENTER), no)
#  GNU_MFILES += synchronization.m
#endif

ifneq ($(GNUSTEP_TARGET_OS), mingw32)
BASE_MFILES += \
GSFileHandle.m \
NSMessagePort.m \
NSMessagePortNameServer.m

ifeq ($(GNUSTEP_BASE_HAVE_MDNS), 1)
  BASE_MFILES += NSNetServices.m
endif

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
FoundationErrors.h \
NSAffineTransform.h \
NSArchiver.h \
NSArray.h \
NSAttributedString.h \
NSAutoreleasePool.h \
NSBundle.h \
NSByteOrder.h \
NSCache.h\
NSCalendarDate.h \
NSCharacterSet.h \
NSClassDescription.h \
NSCoder.h \
NSComparisonPredicate.h \
NSCompoundPredicate.h \
NSConnection.h \
NSData.h \
NSDateFormatter.h \
NSDate.h \
NSDebug.h \
NSDecimal.h \
NSDecimalNumber.h \
NSDictionary.h \
NSDistantObject.h \
NSDistributedLock.h \
NSDistributedNotificationCenter.h \
NSEnumerator.h \
NSError.h \
NSErrorRecoveryAttempting.h \
NSException.h \
NSExpression.h \
NSFileHandle.h \
NSFileManager.h \
NSFormatter.h \
NSGarbageCollector.h \
NSGeometry.h \
NSHashTable.h \
NSHost.h \
NSHTTPCookie.h \
NSHTTPCookieStorage.h \
NSIndexPath.h \
NSIndexSet.h \
NSInvocation.h \
NSKeyedArchiver.h \
NSKeyValueCoding.h \
NSKeyValueObserving.h \
NSLock.h \
NSMapTable.h \
NSMethodSignature.h \
NSNetServices.h \
NSNotification.h \
NSNotificationQueue.h \
NSNull.h \
NSNumberFormatter.h \
NSObjCRuntime.h \
NSObject.h \
NSOperation.h \
NSPathUtilities.h \
NSPointerArray.h \
NSPointerFunctions.h \
NSPortCoder.h \
NSPort.h \
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
NSSpellServer.h \
NSStream.h \
NSString.h \
NSTask.h \
NSThread.h \
NSTimer.h \
NSTimeZone.h \
NSUndoManager.h \
NSURLAuthenticationChallenge.h \
NSURLCache.h \
NSURLConnection.h \
NSURLCredential.h \
NSURLCredentialStorage.h \
NSURLDownload.h \
NSURLError.h \
NSURL.h \
NSURLHandle.h \
NSURLProtectionSpace.h \
NSURLProtocol.h \
NSURLRequest.h \
NSURLResponse.h \
NSUserDefaults.h \
NSUtilities.h \
NSValue.h \
NSValueTransformer.h \
NSXMLDocument.h \
NSXMLDTD.h \
NSXMLDTDNode.h \
NSXMLElement.h \
NSXMLNode.h \
NSXMLNodeOptions.h \
NSXMLParser.h \
NSZone.h

HEADERS_INSTALL = $(GNU_HEADERS) \
                  $(FOUNDATION_HEADERS)

GENERATED_HFILES = \
dynamic-load.h \
$(HEADER_DIR_BASE)/preface.h \
$(GNUSTEP_TARGET_DIR)/config.h \
$(GNUSTEP_TARGET_DIR)/GNUstepBase/GSConfig.h


ifeq ($(HAVE_INET_PTON), no)
GNU_CFILES += inet_pton.c
endif
ifeq ($(HAVE_INET_NTOP), no)
GNU_CFILES += inet_ntop.c
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

# This is for gnustep-make >= 14-02-2007
libbase-resources_INSTALL_DIR = $(GNUSTEP_LIBRARY)/Libraries/gnustep-base/Versions/$(libgnustep-base_INTERFACE_VERSION)/Resources
# This is kept temporarily for gnustep-make < 14-02-2007
libbase-resources_RESOURCE_FILES_INSTALL_DIR = /Library/Libraries/Resources/gnustep-base

libbase-resources_LANGUAGES =
libbase-resources_LOCALIZED_RESOURCE_FILES =
libbase-resources_RESOURCE_DIRS =
libbase-resources_RESOURCE_FILES = Info-gnustep.plist

libgnustep-base_NEEDS_GUI = NO
libgnustep-baseadd_NEEDS_GUI = NO

# Build the Additions subproject first.  It can then be used in by
# both gnustep-base and gnustep-baseadd (otherwise, if we ever build
# gnustep-base and gnustep-baseadd in parallel, they'd both try to
# build Additions as a subproject, causing concurrency issues).  If it
# can be guaranteed that they'll never be built together, this could
# be removed.
ifeq ($(OBJC2RUNTIME),0)
SUBPROJECTS = ObjectiveC2
endif
SUBPROJECTS += Additions
 	 
-include Makefile.preamble

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/resource-set.make

-include Makefile.postamble

include CompatibilityHeaders.make
