#
#  doc makefile for the GNUstep Base Library
#  Copyright (C) 1995 Free Software Foundation, Inc.
#
#  Written by:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
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

GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

include $(GNUSTEP_MAKEFILES)/common.make

include ../Version
include ../config.mak

# The documents to be generated
DOCUMENT_NAME = gnustep-base

# The text documents to be generated
DOCUMENT_TEXT_NAME = \
INSTALL NEWS CODING-STANDARDS README ANNOUNCE 

TOP_DOC_FILES = INSTALL NEWS README ANNOUNCE 

gnustep-base_TEXI_FILES = \
version.tmpl.texi \
gnustep-base.tmpl.texi \
gnustep-zones.tmpl.texi \
announce.tmpl.texi \
coding-standards.tmpl.texi \
install.tmpl.texi \
news.tmpl.texi \
readme.tmpl.texi

TODO_TEXI_FILES = version.tmpl.texi
TODO_TEXT_MAIN = todo.tmpl.texi

INSTALL_TEXI_FILES = version.tmpl.texi
INSTALL_TEXT_MAIN = install.tmpl.texi

NEWS_TEXI_FILES = version.tmpl.texi
NEWS_TEXT_MAIN = news.tmpl.texi

CODING-STANDARDS_TEXI_FILES = version.tmpl.texi
CODING-STANDARDS_TEXT_MAIN = coding-standards.tmpl.texi

README_TEXI_FILES = version.tmpl.texi
README_TEXT_MAIN = readme.tmpl.texi

ANNOUNCE_TEXI_FILES = version.tmpl.texi
ANNOUNCE_TEXT_MAIN = announce.tmpl.texi

STATUS_TEXI_FILES = version.tmpl.texi
STATUS_TEXT_MAIN = status.tmpl.texi

-include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/documentation.make

-include Makefile.postamble
