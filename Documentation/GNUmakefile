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

include $(GNUSTEP_SYSTEM_ROOT)/Makefiles/common.make

include ../Version
include ../config.mak

MAKEINFO = makeinfo
TEXI2DVI = texi2dvi
TEXI2HTML = texi2html

TEXI_FILES = \
announce.texi \
base-desc.texi \
coding-standards.texi \
faq.texi \
gnustep-base.texi \
gnustep-faq.texi \
gnustep-howto.texi \
gnustep-zones.texi \
install.texi \
machines.texi \
news.texi \
objective-c.texi \
readme.texi \
todo.texi \
version.texi \
NSZone.texi

TEXT_FILES = \
TODO INSTALL NEWS CODING-STANDARDS README ANNOUNCE GNUstep-HOWTO

INFO_FILES = gnustep-base.info
PS_FILES = gnustep-base.dvi
HTML_FILES =
DVI_FILES = gnustep-base.dvi objective-c.dvi

TOP_DOC_FILES = README INSTALL NEWS
RCS_FILES =  $(TEXI_FILES) GNUmakefile Makefile.postamble
DIST_FILES = $(RCS_FILES) texinfo.tex $(TEXT_FILES)

-include Makefile.preamble

# We don't actually build anything in this directory so
# just include the common makefile rules
include $(GNUSTEP_SYSTEM_ROOT)/Makefiles/rules.make

-include Makefile.postamble




