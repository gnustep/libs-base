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

include $(GNUSTEP_MAKEFILES)/common.make

include ../Version
include ../config.mak

srcdir = .
PACKAGE_NAME = gstep-base
LIBRARY_VAR = GNUSTEP_BASE

# The library to be compiled
LIBRARY_NAME=libgnustep-base

# GNUSTEP_INSTALL_PREFIX must be defined here and not in config.h because
# the installing person may set it on the `make' command line.
GNUSTEP_INSTALL_PREFIX=$(GNUSTEP_SYSTEM_ROOT)
DEFS= -DGNUSTEP_INSTALL_PREFIX=$(GNUSTEP_INSTALL_PREFIX) \
	-DGNUSTEP_TARGET_DIR=\"$(GNUSTEP_TARGET_DIR)\" \
	-DGNUSTEP_TARGET_CPU=\"$(GNUSTEP_TARGET_CPU)\" \
	-DGNUSTEP_TARGET_OS=\"$(GNUSTEP_TARGET_OS)\" \
	-DLIBRARY_COMBO=\"$(LIBRARY_COMBO)\"

# Grep for these names to build the legally-required "AUTHORS" file.
FILE_AUTHORS = \
"Andrew Kachites McCallum" \
"Kresten Krab Thorup" \
"Adam Fedor" \
"Mark Lakata" \
"Jeremy Bettis" \
"Georg Tuparev" \
"Peter Burka" \
"Albin L. Jones" \
"Scott Christley" \
"Luke Howard" \
"Yoo C. Chung" \
"Richard Frith-Macdonald" \
"Stevo Crvenkovski" \
"Mike Kienenberger" \
"Manuel Guesdon"

# The GNU source files

GNU_MFILES = \
GSCompatibility.m \
GSLocale.m \
Unicode.m \
behavior.m \
o_array.m \
o_array_bas.m \
o_array_cbs.m \
o_cbs.m \
o_cbs_char_p.m \
o_cbs_id.m \
o_cbs_int.m \
o_cbs_int_p.m \
o_cbs_void_p.m \
o_hash.m \
o_hash_bas.m \
o_hash_cbs.m \
o_list.m \
o_list_bas.m \
o_list_cbs.m \
o_map.m \
o_map_bas.m \
o_map_cbs.m \
preface.m \
mframe.m \
objc-gnu2next.m

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
o_x_bas.m.in \
o_x_cbs.m.in \
Foundation/o_x_bas.h.in \
Foundation/o_x_cbs.h.in \
md5.h \
win32-entry.m \
win32-def.top \
libgnustep-base.def

GNU_HEADERS = \
GSLocale.h \
GSUnion.h \
GSIArray.h \
GSIMap.h \
Unicode.h \
UnixFileHandle.h \
behavior.h \
numbers.h \
o_array.h \
o_array_bas.h \
o_array_cbs.h \
o_cbs.h \
o_hash.h \
o_hash_bas.h \
o_hash_cbs.h \
o_list.h \
o_list_bas.h \
o_list_cbs.h \
o_map.h \
o_map_bas.h \
o_map_cbs.h \
objc-gnu2next.h \
preface.h

# GNUStep source files

BASE_MFILES = \
GSCountedSet.m \
GSHTTPURLHandle.m \
GSMime.m \
GSSet.m \
GSString.m \
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
NSConcreteValue.m \
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
NSGArray.m \
NSGAttributedString.m \
NSGDictionary.m \
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

ifeq ($(HAVE_LIBXML),1)
BASE_MFILES += GSXML.m
endif

NSVALUE_MFILES = \
	NSValue0.m NSValue1.m NSValue2.m NSValue3.m \
	NSValue4.m
NSNUMBER_MFILES = \
	NSNumber0.m NSNumber1.m NSNumber2.m NSNumber3.m \
	NSNumber4.m NSNumber5.m NSNumber6.m NSNumber7.m \
	NSNumber8.m NSNumber9.m NSNumber10.m NSNumber11.m \
	NSNumber12.m

BASE_OTHER_SRCFILES = \
NSConcreteNumber.m \
NSCTemplateValue.m \
dld-load.h \
hpux-load.h \
null-load.h \
simple-load.h \
win32-load.h \
NSCallBacks.h \
tzfile.h

BASE_HEADERS = \
Foundation.h \
DistributedObjects.h \
GSMime.h \
NSArchiver.h \
NSArray.h \
NSAttributedString.h \
NSAutoreleasePool.h \
NSBitmapCharSet.h \
NSBundle.h \
NSByteOrder.h \
NSCharacterSet.h \
NSClassDescription.h \
NSCoder.h \
NSConcreteNumber.h \
NSConcreteValue.h \
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
NSGArray.h \
NSGAttributedString.h \
NSHashTable.h \
NSHost.h \
NSInvocation.h \
NSKeyValueCoding.h \
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
NSProcessInfo.h \
NSProtocolChecker.h \
NSProxy.h \
NSRange.h \
NSRunLoop.h \
NSScanner.h \
NSSerialization.h \
NSSet.h \
NSString.h \
NSTask.h \
NSThread.h \
NSTimer.h \
NSUndoManager.h \
NSUserDefaults.h \
NSUtilities.h \
NSValue.h \
NSZone.h \
objc-load.h \
NSURL.h \
NSURLHandle.h

ifeq ($(HAVE_LIBXML),1)
BASE_HEADERS += GSXML.h
endif

UNICODE_HEADERS = \
unicode/caseconv.h \
unicode/cop.h \
unicode/cyrillic.h \
unicode/latin2.h \
unicode/decomp.h \
unicode/nextstep.h

HEADERS_INSTALL = $(GNU_HEADERS) \
                  $(BASE_HEADERS) \
                  $(UNICODE_HEADERS)

GENERATED_HFILES = \
dynamic-load.h \
$(HEADER_DIR)/preface.h \
$(HEADER_DIR)/o_array.h \
$(HEADER_DIR)/o_hash.h \
$(HEADER_DIR)/o_list.h \
$(HEADER_DIR)/o_map.h \
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

libgnustep-base_HEADER_FILES = $(BASE_HEADERS)

-include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/library.make

-include Makefile.postamble
