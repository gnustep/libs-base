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
#  Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
"Mike Kienenberger"

# The GNU source files

GNU_MFILES = \
Archiver.m \
Array.m \
Bag.m \
BinaryCStream.m \
BinaryTree.m \
BinaryTreeNode.m \
CircularArray.m \
Collection.m \
ConnectedCoder.m \
Coder.m \
CStream.m \
Decoder.m \
DelegatePool.m \
Dictionary.m \
Encoder.m \
GapArray.m \
GetDefEncoding.m \
Heap.m \
IndexedCollection.m \
Invocation.m \
KeyedCollection.m \
LinkedList.m \
LinkedListNode.m \
MachPort.m \
MappedCollector.m \
MemoryStream.m \
NotificationDispatcher.m \
OrderedCollection.m \
Port.m \
Queue.m \
RawCStream.m \
RBTree.m \
RBTreeNode.m \
Set.m \
SplayTree.m \
Stack.m \
StdioStream.m \
Stream.m \
TcpPort.m \
TextCStream.m \
UdpPort.m \
Unicode.m \
UnixFileHandle.m \
behavior.m \
lex.pl.m \
lex.sf.m \
ostream.m \
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
proplist.tab.m \
stringsfile.tab.m \
mframe.m \
objc-gnu2next.m

GNU_EXTRAS_MFILES = \
Magnitude.m \
Random.m \
RNGAdditiveCongruential.m \
RNGBerkeley.m \
Time.m

GNU_CFILES = \
md5.c \
numbers.c \
o_vscanf.c 

GNU_OTHER_SRCFILES = \
o_x_bas.m.in \
o_x_cbs.m.in \
include/o_x_bas.h.in \
include/o_x_cbs.h.in \
md5.h \
proplist.l \
proplist.tab.h \
proplist.y \
stringsfile.l \
stringsfile.tab.h \
stringsfile.y \
win32-entry.m \
win32-def.top \
libgnustep-base.def

GNU_HEADERS = \
fast.x \
Archiver.h \
Array.h \
ArrayPrivate.h \
Bag.h \
BinaryCStream.h \
BinaryTree.h \
BinaryTreeNode.h \
CircularArray.h \
CircularArrayPrivate.h \
Coder.h \
CoderPrivate.h \
Coding.h \
Collecting.h \
Collection.h \
CollectionPrivate.h \
ConnectedCoder.h \
CStream.h \
CStreaming.h \
DelegatePool.h \
Dictionary.h \
Enumerating.h \
GapArray.h \
GapArrayPrivate.h \
GetDefEncoding.h \
Heap.h \
IndexedCollecting.h \
IndexedCollection.h \
IndexedCollectionPrivate.h \
InvalidationListening.h \
Invocation.h \
Invoking.h \
KeyedCollecting.h \
KeyedCollection.h \
LinkedList.h \
LinkedListNode.h \
Locking.h \
MachPort.h \
MappedCollector.h \
MemoryStream.h \
NotificationDispatcher.h \
Ordering.h \
OrderedCollecting.h \
OrderedCollection.h \
Port.h \
Queue.h \
RBTree.h \
RBTreeNode.h \
RawCStream.h \
Retaining.h \
RunLoop.h \
Set.h \
SplayTree.h \
Stack.h \
StdioStream.h \
Stream.h \
Streaming.h \
TcpPort.h \
TextCStream.h \
UdpPort.h \
Unicode.h \
UnixFileHandle.h \
ValueHolding.h \
behavior.h \
fake-main.h \
mframe.h \
numbers.h \
ostream.h \
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
README \
preface.h

GNU_EXTRAS_HFILES = \
all.h \
Magnitude.h \
Random.h \
RNGAdditiveCongruential.h \
RNGBerkeley.h \
RandomGenerating.h \
Time.h

# NEXTSTEP source files

NEXTSTEP_MFILES = \
HashTable.m \
List.m \
NXStringTable.m \
Storage.m

NEXTSTEP_CFILES = 

NEXTSTEP_DERIVED_CFILES = \
NXStringTable_scan.c

NEXTSTEP_OTHER_SRCFILES = \
NXStringTable_scan.l 

NEXTSTEP_HEADERS = \
objc/HashTable.h \
objc/List.h \
objc/NXStringTable.h \
objc/Storage.h \
objc/zone.h

# GNUStep source files

BASE_MFILES = \
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
NSCoder.m \
NSCopyObject.m \
NSConcreteValue.m \
NSCountedSet.m \
NSConnection.m \
NSData.m \
NSDate.m \
NSDateFormatter.m \
NSDebug.m \
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
NSGArchiver.m \
NSGArray.m \
NSGAttributedString.m \
NSGCountedSet.m \
NSGCString.m \
NSGDictionary.m \
NSGSet.m \
NSGSequence.m \
NSGString.m \
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
NSNumber.m \
NSObjCRuntime.m \
NSObject.m \
NSPage.m \
NSPipe.m \
NSPort.m \
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
NSUser.m \
NSUserDefaults.m \
NSValue.m \
NSZone.m \
externs.m

NSVALUE_MFILES = \
	NSValue0.m NSValue1.m NSValue2.m NSValue3.m \
	NSValue4.m
NSNUMBER_MFILES = \
	NSNumber0.m NSNumber1.m NSNumber2.m NSNumber3.m \
	NSNumber4.m NSNumber5.m NSNumber6.m NSNumber7.m \
	NSNumber8.m NSNumber9.m NSNumber10.m NSNumber11.m \
	NSNumber12.m

BASE_CFILES = \
find_exec.c \
objc-load.c

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
Foundation/Foundation.h \
Foundation/DistributedObjects.h \
Foundation/NSArchiver.h \
Foundation/NSArray.h \
Foundation/NSAttributedString.h \
Foundation/NSAutoreleasePool.h \
Foundation/NSBitmapCharSet.h \
Foundation/NSBundle.h \
Foundation/NSByteOrder.h \
Foundation/NSCharacterSet.h \
Foundation/NSCoder.h \
Foundation/NSConcreteNumber.h \
Foundation/NSConcreteValue.h \
Foundation/NSConnection.h \
Foundation/NSData.h \
Foundation/NSDate.h \
Foundation/NSDateFormatter.h \
Foundation/NSDebug.h \
Foundation/NSDictionary.h \
Foundation/NSDistantObject.h \
Foundation/NSDistributedLock.h \
Foundation/NSDistributedNotificationCenter.h \
Foundation/NSEnumerator.h \
Foundation/NSException.h \
Foundation/NSFileHandle.h \
Foundation/NSFileManager.h \
Foundation/NSFormatter.h \
Foundation/NSGeometry.h \
Foundation/NSGArchiver.h \
Foundation/NSGArray.h \
Foundation/NSGAttributedString.h \
Foundation/NSGCString.h \
Foundation/NSGSet.h \
Foundation/NSGSequence.h \
Foundation/NSGString.h \
Foundation/NSHashTable.h \
Foundation/NSHost.h \
Foundation/NSInvocation.h \
Foundation/NSLock.h \
Foundation/NSMapTable.h \
Foundation/NSMethodSignature.h \
Foundation/NSNotification.h \
Foundation/NSNotificationQueue.h \
Foundation/NSObjCRuntime.h \
Foundation/NSObject.h \
Foundation/NSPage.h \
Foundation/NSPathUtilities.h \
Foundation/NSPort.h \
Foundation/NSPortCoder.h \
Foundation/NSPortMessage.h \
Foundation/NSPortNameServer.h \
Foundation/NSProcessInfo.h \
Foundation/NSProtocolChecker.h \
Foundation/NSProxy.h \
Foundation/NSRange.h \
Foundation/NSRunLoop.h \
Foundation/NSScanner.h \
Foundation/NSSerialization.h \
Foundation/NSSet.h \
Foundation/NSString.h \
Foundation/NSTask.h \
Foundation/NSThread.h \
Foundation/NSTimer.h \
Foundation/NSUndoManager.h \
Foundation/NSUserDefaults.h \
Foundation/NSUtilities.h \
Foundation/NSValue.h \
Foundation/NSZone.h \
Foundation/objc-load.h

UNICODE_HEADERS = \
unicode/caseconv.h \
unicode/cop.h \
unicode/cyrillic.h \
unicode/decomp.h \
unicode/nextstep.h

HEADERS_INSTALL = $(GNU_HEADERS) \
                  $(BASE_HEADERS)

DIST_FILES = \
        GNUmakefile Makefile.preamble Makefile.postamble AUTHORS \
        include/config.h.in include/preface.h.in \
	include/config-win32.h \
        $(GNU_MFILES) \
        $(GNU_CFILES) \
        $(GNU_OTHER_SRCFILES) \
        $(BASE_MFILES) \
        $(BASE_CFILES) \
        $(BASE_OTHER_SRCFILES) \
	$(UNICODE_HEADERS)

GENERATED_HFILES = \
dynamic-load.h \
include/preface.h \
include/o_array.h \
include/o_hash.h \
include/o_list.h \
include/o_map.h \
$(GNUSTEP_TARGET_CPU)/$(GNUSTEP_TARGET_OS)/config.h

# The C source files to be compiled
libgnustep-base_C_FILES = $(GNU_CFILES) $(BASE_CFILES)

# The Objective-C source files to be compiled
libgnustep-base_OBJC_FILES = $(GNU_MFILES) \
	$(BASE_MFILES) $(NSVALUE_MFILES) $(NSNUMBER_MFILES)

libgnustep-base_HEADER_FILES_DIR = .
libgnustep-base_HEADER_FILES_INSTALL_DIR = /gnustep

libgnustep-base_HEADER_FILES = $(BASE_HEADERS)

-include Makefile.preamble

include $(GNUSTEP_MAKEFILES)/library.make

-include Makefile.postamble
