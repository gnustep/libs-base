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
#  Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.

# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../base.make
include $(GNUSTEP_MAKEFILES)/common.make

include ../Version
include ../config.mak

resourcedir = $(GNUSTEP_RESOURCES)/gnustep-base

TIMEZONE_ARCHIVE = \
NSTimeZones.tar

-include Makefile.preamble

-include GNUmakefile.local

# We don't actually build anything in this directory so
# just include the common makefile rules
include $(GNUSTEP_MAKEFILES)/rules.make

-include Makefile.postamble
