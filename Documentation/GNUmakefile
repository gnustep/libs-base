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

GNUSTEP_MAKEFILE_DIR = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

include $(GNUSTEP_MAKEFILE_DIR)/common.make

include ../Version
include ../config.mak

MAKEINFO = makeinfo
TEXI2DVI = texi2dvi
TEXI2HTML = texi2html

ORIG_FILES = \
version.tmpl.texi \
gnustep-base.tmpl.texi \
gnustep-howto.tmpl.texi \
gnustep-zones.tmpl.texi \
announce.tmpl.texi \
coding-standards.tmpl.texi \
install.tmpl.texi \
news.tmpl.texi \
readme.tmpl.texi \
status.tmpl.texi \
todo.tmpl.texi \
faq.tmpl.texi

TEXI_FILES = \
version.texi \
gnustep-base.texi \
gnustep-howto.texi \
gnustep-zones.texi \
announce.texi \
coding-standards.texi \
install.texi \
news.texi \
readme.texi \
status.texi \
todo.texi \
faq.texi \

TEXT_FILES = \
TODO INSTALL NEWS CODING-STANDARDS README ANNOUNCE FAQ STATUS GNUstep-HOWTO

INFO_FILES = gnustep-base.info
PS_FILES = gnustep-base.dvi
HTML_FILES = gnustep-base_toc.html
DVI_FILES = gnustep-base.dvi

TOP_DOC_FILES = TODO README INSTALL NEWS ANNOUNCE STATUS GNUstep-HOWTO
RCS_FILES =  $(ORIG_FILES) GNUmakefile Makefile.postamble
DIST_FILES = $(RCS_FILES) $(TEXT_FILES)

-include Makefile.preamble

# We don't actually build anything in this directory so
# just include the common makefile rules
include $(GNUSTEP_MAKEFILE_DIR)/rules.make

-include Makefile.postamble




