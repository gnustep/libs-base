#
#  examples makefile for the GNUstep Base Library
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

GNUSTEP_MAKEFILE_DIR = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

include $(GNUSTEP_MAKEFILE_DIR)/common.make

include ../Version
include ../config.mak

# The tools to be compiled
TEST_TOOL_NAME = \
dictionary \
stdio-stream \
textcoding \
first-server \
first-client \
second-server \
second-client

# The Objective-C source files to be compiled
dictionary_OBJC_FILES = dictionary.m
stdio-stream_OBJC_FILES = stdio-stream.m
textcoding_OBJC_FILES = textcoding.m
first-server_OBJC_FILES = first-server.m
first-client_OBJC_FILES = first-client.m
second-server_OBJC_FILES = second-server.m
second-client_OBJC_FILES = second-client.m

SRCS = $(TEST_TOOL_NAME:=.m)

HDRS = \
first-server.h \
second-server.h \
second-client.h

DIST_FILES = $(SRCS) $(HDRS) GNUmakefile Makefile.postamble Makefile.preamble \
custom-zone.m

-include Makefile.preamble

include $(GNUSTEP_MAKEFILE_DIR)/test-tool.make

-include Makefile.postamble
