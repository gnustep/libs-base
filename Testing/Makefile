#
#  checks makefile for the GNUstep Base Library
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

include $(GNUSTEP_SYSTEM_ROOT)/Makefiles/common.make

include ../Version
include ../config.mak

# The tools to be compiled
TOOL_NAME = \
test01 \
test02 \
heap \
nxst \
randoms \
prepend \
pipes \
server \
client \
string \
values \
nsarray \
nsattributedstring \
nsbundle \
nsdata \
nsdictionary \
nsfilehandle \
nshost \
nsset \
nsprocessinfo \
nsarchiver \
oldclient \
oldserver \
invocation \
diningPhilosophers \
nsattributedstring \
nsmaptable \
nshashtable \
tcpport-server \
tcpport-client \
nsnotification \
nstimer \
coder \
cstream \
fref \
basic \
release \
nsscanner \
nsdate \
awake \
thread-except \
nscharacterset \
NSData-test

# The Objective-C source files to be compiled
test01_OBJC_FILES = test01.m
test02_OBJC_FILES = test02.m
heap_OBJC_FILES = heap.m
nxst_OBJC_FILES = nxst.m
randoms_OBJC_FILES = randoms.m
prepend_OBJC_FILES = prepend.m
pipes_OBJC_FILES = pipes.m
server_OBJC_FILES = server.m
client_OBJC_FILES = client.m
string_OBJC_FILES = string.m
values_OBJC_FILES = values.m
nsarray_OBJC_FILES = nsarray.m
nsattributedstring_OBJC_FILES = nsattributedstring.m
nsbundle_OBJC_FILES = nsbundle.m
nsdata_OBJC_FILES = nsdata.m
nsdictionary_OBJC_FILES = nsdictionary.m
nsfilehandle_OBJC_FILES = nsfilehandle.m
nshost_OBJC_FILES = nshost.m
nsset_OBJC_FILES = nsset.m
nsprocessinfo_OBJC_FILES = nsprocessinfo.m
nsarchiver_OBJC_FILES = nsarchiver.m
oldclient_OBJC_FILES = oldclient.m
oldserver_OBJC_FILES = oldserver.m
invocation_OBJC_FILES = invocation.m
diningPhilosophers_OBJC_FILES = diningPhilosophers.m
nsmaptable_OBJC_FILES = nsmaptable.m
nshashtable_OBJC_FILES = nshashtable.m
tcpport-server_OBJC_FILES = tcpport-server.m
tcpport-client_OBJC_FILES = tcpport-client.m
nsnotification_OBJC_FILES = nsnotification.m
nstimer_OBJC_FILES = nstimer.m
coder_OBJC_FILES = coder.m
cstream_OBJC_FILES = cstream.m
fref_OBJC_FILES = fref.m
basic_OBJC_FILES = basic.m
release_OBJC_FILES = release.m
nsscanner_OBJC_FILES = nsscanner.m
nsdate_OBJC_FILES = nsdate.m
awake_OBJC_FILES = awake.m
thread-except_OBJC_FILES = thread-except.m
nscharacterset_OBJC_FILES = nscharacterset.m
NSData-test_OBJC_FILES = NSData-test.m

SRCS = $(TOOL_NAME:=.m)

HDRS = \
server.h

BUNDLE_NAME=LoadMe
DYNAMIC_MFILES = \
LoadMe.m \
MyCategory.m \
SecondClass.m

DYNAMIC_HFILES = \
LoadMe.h \
MyCategory.h \
SecondClass.h

DIST_FILES = $(SRCS) $(HDRS) $(DYNAMIC_MFILES) $(DYNAMIC_HFILES) \
	Makefile Makefile.preamble Makefile.postamble NXStringTable.example

-include Makefile.preamble

include $(GNUSTEP_SYSTEM_ROOT)/Makefiles/tool.make

-include Makefile.postamble
