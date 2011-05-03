#
#  NSCharacterSet makefile for GNUstep Base Library
#  Copyright (C) 1995, 1996 Free Software Foundation, Inc.
#
#  Written by:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
#
#  This file is part of the GNUstep Base Library.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  Library General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free
#  Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#  Boston, MA 02111 USA.

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

PACKAGE_NAME = gnustep-base
GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../base.make

include $(GNUSTEP_MAKEFILES)/common.make
-include ../config.mak

CHARSET_FILES = \
alphanumericCharSet.dat \
controlCharSet.dat \
decimalDigitCharSet.dat \
decomposableCharSet.dat \
illegalCharSet.dat \
letterCharSet.dat \
lowercaseLetterCharSet.dat \
nonBaseCharSet.dat \
punctuationCharSet.dat \
symbolAndOperatorCharSet.dat \
uppercaseLetterCharSet.dat \
whitespaceAndNlCharSet.dat \
whitespaceCharSet.dat

CTOOL_NAME = dataToHeader
dataToHeader_C_FILES = dataToHeader.c

include $(GNUSTEP_MAKEFILES)/ctool.make

after-all::	NSCharacterSetData.h

NSCharacterSetData.h: $(CHARSET_FILES)
	$(GNUSTEP_OBJ_DIR_NAME)/dataToHeader $(CHARSET_FILES)

