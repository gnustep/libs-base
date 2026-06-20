#
#  Makefile for GNUstep Base Library documentation.
#  
#  Copyright (C) 2002 Free Software Foundation, Inc.
#
#  Written by:	Richard Frith-Macdonald <rfm.gnu.org>
#
#  This file is part of the GNUstep Base Library.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public
#  License as published by the Free Software Foundation; either
#  version 3 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public
#  License along with this library; if not, write to the Free
#  Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA
#

PACKAGE_NAME = gnustep-base

include $(GNUSTEP_MAKEFILES)/common.make
include ../../config.mak

DOCUMENT_NAME = General

General_AGSDOC_INSTALL_BUNDLE = General
General_AGSDOC_LOCAL_DIR = General
General_DOC_INSTALL_DIR = Developer/Base

General_AGSDOC_FILES = \
Debugging.gsdoc \
OpenStepCompliance.gsdoc \


General_AGSDOC_FLAGS = \
	-MakeFrames NO \
	-DTDs ../../Tools

# Use local version of autogsdoc in case it is not installed
AUTOGSDOC=../../Tools/$(GNUSTEP_OBJ_DIR_NAME)/autogsdoc
BASE_MAKE_LOADED=yes

include $(GNUSTEP_MAKEFILES)/documentation.make

#
# Ensure that our destination subdirectory exists in the Documentation
# directory, and temporarily copy the base source file here for autogsdoc
# to use.
#
#before-all::

#
# Clean up temporary files used while generating documentation.
#
after-clean::
	if [ -d General ]; then \
	  $(RM) General/stamp; \
	  $(RM) General/dependencies; \
	  rmdir General; \
	fi

