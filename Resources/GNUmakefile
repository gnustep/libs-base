#
#  Resources makefile for GNUstep Base Library
#  Copyright (C) 2000 Free Software Foundation, Inc.
#
#  Written by:	Adam Fedor <fedor@doc.com>
#  Date: Oct 2000
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

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=../base.make
include $(GNUSTEP_MAKEFILES)/common.make

resourcedir = $(GNUSTEP_RESOURCES)
languagedir = $(GNUSTEP_RESOURCES)/Languages

LANGUAGES = English German French Italian

LOCALIZED_RESOURCE_FILES = Localizable.strings

LANGUAGE_FILES = \
Languages/Dutch \
Languages/English \
Languages/French  \
Languages/German  \
Languages/Italian

LANGUAGE_INSTALL_FILES = $(LANGUAGE_FILES) Languages/Locale.aliases

-include GNUmakefile.local

# We don't actually build anything in this directory so
# just include the common makefile rules
include $(GNUSTEP_MAKEFILES)/rules.make

-include GNUmakefile.postamble

