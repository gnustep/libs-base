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
#  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

# Install into the system root by default
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../base.make
include $(GNUSTEP_MAKEFILES)/common.make

include ../Version
include ../config.mak

# DTDs to install
dtddir = $(GNUSTEP_RESOURCES)/DTDs
DTD_FILES = gsdoc-0_6_5.dtd gsdoc-0_6_6.dtd

# DocTemplates to install
doctemplatesdir = $(GNUSTEP_RESOURCES)/DocTemplates
DOCTEMPLATES_FILES = indextemplate.gsdoc AutoDocTemplate.gsdoc

# The application to be compiled
TOOL_NAME = autogsdoc gdnc gsdoc defaults plmerge \
		plparse sfparse pldes plser
CTOOL_NAME = gdomap

TEST_TOOL_NAME = locale_alias

# The source files to be compiled
autogsdoc_OBJC_FILES = autogsdoc.m AGSParser.m AGSOutput.m
gdomap_C_FILES = gdomap.c
gdnc_OBJC_FILES = gdnc.m
gsdoc_OBJC_FILES = gsdoc.m
defaults_OBJC_FILES = defaults.m
dread_OBJC_FILES = dread.m
dremove_OBJC_FILES = dremove.m
dwrite_OBJC_FILES = dwrite.m
pldes_OBJC_FILES = pldes.m
plser_OBJC_FILES = plser.m
plmerge_OBJC_FILES = plmerge.m
plparse_OBJC_FILES = plparse.m
sfparse_OBJC_FILES = sfparse.m

locale_alias_OBJC_FILES = locale_alias.m

SOURCES = gdomap.c gdnc.m defaults.m dread.m dremove.m dwrite.m

HEADERS = gdomap.h gdnc.h

DIST_FILES = GNUmakefile Makefile.preamble Makefile.postamble \
$(SOURCES) $(HEADERS)

include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/ctool.make
include $(GNUSTEP_MAKEFILES)/tool.make
include $(GNUSTEP_MAKEFILES)/test-tool.make

include Makefile.postamble

