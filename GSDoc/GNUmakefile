#
#  Documentation tools makefile for GNUstep Base Library
#  Copyright (C) 2000 Free Software Foundation, Inc.
#
#  Written by:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
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

include $(GNUSTEP_MAKEFILES)/common.make

include ../Version
include ../config.mak

dtddir = $(GNUSTEP_RESOURCES)/DTDs
DTD_FILES = gsdoc-0_6_5.dtd

# The application to be compiled
TOOL_NAME = gsdoc

# The source files to be compiled
gsdoc_OBJC_FILES = gsdoc.m

DIST_FILES = GNUmakefile Makefile.preamble Makefile.postamble

-include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/objc.make
include $(GNUSTEP_MAKEFILES)/tool.make

-include Makefile.postamble
