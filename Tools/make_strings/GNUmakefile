#
#  make_strings makefile for GNUstep Base Library
#  Copyright (C) 2002 Free Software Foundation, Inc.
#
#  Written by:	Adam Fedor <fedor@gnu.org>
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

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../../base.make
include $(GNUSTEP_MAKEFILES)/common.make

VERSION = 0.4.2
PACKAGE_NAME = make_strings
TOOL_NAME = make_strings

make_strings_OBJC_FILES = \
	make_strings.m \
	SourceEntry.m \
	StringsEntry.m \
	StringsFile.m

include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/tool.make

