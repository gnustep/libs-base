#
#  Tools makefile for GNUstep Base Library
#  Copyright (C) 1997 Free Software Foundation, Inc.
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
#  Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

# Install into the system root by default
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_SYSTEM_ROOT)/Makefiles/common.make

# The application to be compiled
TOOL_NAME = defaults dread dwrite dremove
OBJC_PROGRAM_NAME = gdomap

# The source files to be compiled
gdomap_C_FILES = gdomap.c
defaults_OBJC_FILES = defaults.m
dread_OBJC_FILES = dread.m
dremove_OBJC_FILES = dremove.m
dwrite_OBJC_FILES = dwrite.m

SOURCES = gdomap.c dread.m dremove.m dwrite.m

HEADERS = gdomap.h

DIST_FILES = GNUmakefile Makefile.preamble Makefile.postamble \
$(SOURCES) $(HEADERS)

-include Makefile.preamble

include $(GNUSTEP_SYSTEM_ROOT)/Makefiles/objc.make
include $(GNUSTEP_SYSTEM_ROOT)/Makefiles/tool.make

-include Makefile.postamble
