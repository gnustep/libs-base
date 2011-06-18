#
#  src makefile for the GNUstep Base Library
#
#  Copyright (C) 1997 Free Software Foundation, Inc.
#
#  Written by:	Scott Christley <scottc@net-community.com>
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
#

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
# This must set be before reading common.make, which will read the
# Additional makefiles.
GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../base.make

include $(GNUSTEP_MAKEFILES)/common.make

-include ../config.mak
-include config.mak

srcdir = .
PACKAGE_NAME = gnustep-base

ifneq ($(base),no)
ifeq ($(HAVE_OPENSSL), yes)

# The bundles to be compiled
BUNDLE_NAME=SSL

# Interface version changes with each minor release
include ../Version
libgnustep-base_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
SSL_INSTALL_DIR = $(GNUSTEP_LIBRARY)/Libraries/gnustep-base/Versions/$(libgnustep-base_INTERFACE_VERSION)/Resources/

# Additional search directories for linking
SSL_LIB_DIRS += -L$(GNUSTEP_OBJ_DIR)

# The bundle Objective-C source files to be compiled
SSL_OBJC_FILES = GSSSLHandle.m

# The principal class in the bundle
SSL_PRINCIPAL_CLASS = GSSSLHandle

SSL_BUNDLE_LIBS = $(SSLLIBS) -lgnustep-base

SSL_NEEDS_GUI = NO

endif
endif

-include Makefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include Makefile.postamble
