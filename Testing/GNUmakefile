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
#  modify it under the terms of the GNU General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public
#  License along with this library; if not, write to the Free
#  Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02111, USA.
#

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)$(warning computed GNUSTEP_MAKEFILES)
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../base.make

include $(GNUSTEP_MAKEFILES)/common.make

include ../Version
include ../config.mak

# The tools to be compiled
CHECKABLE_TOOLS = \
		awake \
		basic \
		benchmark \
		call \
		containers \
		exported-strings \
		fref \
		gsbehavior \
		gslock \
		nsarchiver \
		nsarray \
		nsattributedstring \
		nsbundle \
		nscharacterset \
		nsconnection \
		nsdata \
		nsdate \
		nsdictionary \
		nsfilehandle \
		nsfilemanager \
		nshashtable \
		nshost \
		nsindexset \
		nsinvocation \
		nsmaptable \
		nsmethodsignature \
		nsnotification \
		nspathutilities \
		nsprocessinfo \
		nsscanner \
		nsset \
		nstask \
		nstimer \
		nstimezone \
		nsundomanager \
		nsxmlparser \
		release \
		string \
		thread \
		thread-except \
		values \

TEST_TOOL_NAME = $(CHECKABLE_TOOLS)

# Don't make these normally
ADDITIONAL_TOOLS = \
		diningPhilosophers \
		nsconnection_client \
		nsconnection_server \

TEST_TOOL_NAME += $(ADDITIONAL_TOOLS)

# The tool Objective-C source files to be compiled
awake_OBJC_FILES = awake.m
basic_OBJC_FILES = basic.m
benchmark_OBJC_FILES = benchmark.m
call_OBJC_FILES = call.m
containers_OBJC_FILES = containers.m
diningPhilosophers_OBJC_FILES = diningPhilosophers.m
exported-strings_OBJC_FILES = exported-strings.m
fref_OBJC_FILES = fref.m
gsbehavior_OBJC_FILES = gsbehavior.m
gslock_OBJC_FILES = gslock.m
nsarchiver_OBJC_FILES = nsarchiver.m
nsarray_OBJC_FILES = nsarray.m
nsattributedstring_OBJC_FILES = nsattributedstring.m
nsbundle_OBJC_FILES = nsbundle.m
nscharacterset_OBJC_FILES = nscharacterset.m
nsconnection_OBJC_FILES = nsconnection.m
nsconnection_client_OBJC_FILES = nsconnection_client.m
nsconnection_server_OBJC_FILES = nsconnection_server.m
nsdata_OBJC_FILES = nsdata.m
nsdate_OBJC_FILES = nsdate.m
nsdictionary_OBJC_FILES = nsdictionary.m
nsfilehandle_OBJC_FILES = nsfilehandle.m
nsfilemanager_OBJC_FILES = nsfilemanager.m
nshashtable_OBJC_FILES = nshashtable.m
nshost_OBJC_FILES = nshost.m
nsindexset_OBJC_FILES = nsindexset.m
nsinvocation_OBJC_FILES = nsinvocation.m
nskvo_OBJC_FILES = nskvo.m
nsmaptable_OBJC_FILES = nsmaptable.m
nsmethodsignature_OBJC_FILES = nsmethodsignature.m
nsnotification_OBJC_FILES = nsnotification.m
nspathutilities_OBJC_FILES = nspathutilities.m
nsprocessinfo_OBJC_FILES = nsprocessinfo.m
nsscanner_OBJC_FILES = nsscanner.m
nsset_OBJC_FILES = nsset.m
nstask_OBJC_FILES = nstask.m
nstimer_OBJC_FILES = nstimer.m
nstimezone_OBJC_FILES = nstimezone.m
nsxmlparser_OBJC_FILES = nsxmlparser.m
nsundomanager_OBJC_FILES = nsundomanager.m
prepend_OBJC_FILES = prepend.m
release_OBJC_FILES = release.m
string_OBJC_FILES = string.m
testtool_OBJC_FILES = testtool.m
thread_OBJC_FILES = thread.m
thread-except_OBJC_FILES = thread-except.m
values_OBJC_FILES = values.m

# The bundles to be compiled
BUNDLE_NAME=LoadMe

# The bundle Objective-C source files to be compiled
LoadMe_OBJC_FILES = LoadMe.m MyCategory.m SecondClass.m

# The bundle resource files and directories
LoadMe_RESOURCE_FILES = English.lproj/NXStringTable.example
LoadMe_RESOURCE_DIRS = English.lproj

# Manually disable installation of LoadMe bundle
LoadMe_STANDARD_INSTALL = no

-include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/test-tool.make
include $(GNUSTEP_MAKEFILES)/bundle.make

-include Makefile.postamble
