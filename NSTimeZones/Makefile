#
#  NSTimeZones makefile for GNUstep Base Library
#  Copyright (C) 1995, 1996 Free Software Foundation, Inc.
#
#  Written by:	Adam Fedor <fedor@doc.com>
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

include ../Version
include ../config.mak

resourcedir = $(GNUSTEP_RESOURCES)/gnustep

TIMEZONE_ARCHIVE = \
NSTimeZones.tar

DIST_FILES = Makefile Makefile.postamble $(TIMEZONE_ARCHIVE)

-include Makefile.preamble

# We don't actually build anything in this directory so
# just include the common makefile rules
include $(GNUSTEP_SYSTEM_ROOT)/Makefiles/rules.make

-include Makefile.postamble
