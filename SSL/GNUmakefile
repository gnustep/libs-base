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
#

# Install into the system root by default
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

-include config.mak
include $(GNUSTEP_MAKEFILES)/common.make

srcdir = .
PACKAGE_NAME = gnustep-base

ifeq ($(HAVE_OPENSSL), yes)

# The bundles to be compiled
BUNDLE_NAME=SSL

# Additional search directories for linking
SSL_LIB_DIRS += -L$(GNUSTEP_OBJ_DIR)

# The bundle Objective-C source files to be compiled
SSL_OBJC_FILES = GSUnixSSLHandle.m

# The principal class in the bundle
SSL_PRINCIPAL_CLASS = GSUnixSSLHandle

SSL_BUNDLE_LIBS = -lgnustep-base -lobjc $(SSLLIBS)

endif

# GNUSTEP_INSTALL_PREFIX must be defined here and not in config.h because
# the installing person may set it on the `make' command line.

ifeq ($(GNUSTEP_TARGET_OS), mingw32)

GNUSTEP_TARGET_INSTALL_PREFIX := \
     $(shell echo $(GNUSTEP_SYSTEM_ROOT) | sed 's|^[a-zA-Z]:/|/|')
GNUSTEP_TARGET_LOCAL_ROOT := \
     $(shell echo $(GNUSTEP_LOCAL_ROOT) | sed 's|^[a-zA-Z]:/|/|')
GNUSTEP_TARGET_NETWORK_ROOT := \
     $(shell echo $(GNUSTEP_NETWORK_ROOT) | sed 's|^[a-zA-Z]:/|/|')
DEFS= -DGNUSTEP_INSTALL_PREFIX=$(GNUSTEP_TARGET_INSTALL_PREFIX) \
	-DGNUSTEP_LOCAL_ROOT=$(GNUSTEP_TARGET_LOCAL_ROOT) \
	-DGNUSTEP_NETWORK_ROOT=$(GNUSTEP_TARGET_NETWORK_ROOT) \
	-DGNUSTEP_TARGET_DIR=\"$(GNUSTEP_TARGET_DIR)\" \
	-DGNUSTEP_TARGET_CPU=\"$(GNUSTEP_TARGET_CPU)\" \
	-DGNUSTEP_TARGET_OS=\"$(GNUSTEP_TARGET_OS)\" \
	-DLIBRARY_COMBO=\"$(LIBRARY_COMBO)\"

else

GNUSTEP_INSTALL_PREFIX=$(GNUSTEP_SYSTEM_ROOT)
DEFS= -DGNUSTEP_INSTALL_PREFIX=$(GNUSTEP_INSTALL_PREFIX) \
	-DGNUSTEP_LOCAL_ROOT=$(GNUSTEP_LOCAL_ROOT) \
	-DGNUSTEP_NETWORK_ROOT=$(GNUSTEP_NETWORK_ROOT) \
	-DGNUSTEP_TARGET_DIR=\"$(GNUSTEP_TARGET_DIR)\" \
	-DGNUSTEP_TARGET_CPU=\"$(GNUSTEP_TARGET_CPU)\" \
	-DGNUSTEP_TARGET_OS=\"$(GNUSTEP_TARGET_OS)\" \
	-DLIBRARY_COMBO=\"$(LIBRARY_COMBO)\"

endif

-include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/bundle.make

-include Makefile.postamble
