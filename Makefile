#
#  Main Makefile for GNUstep Base Library.
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
#  Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#

include $(GNUSTEP_SYSTEM_ROOT)/Makefiles/common.make

include ./Version

DIST_FILES = \
	Makefile.in Makeconf configure.in aclocal.m4 acconfig.h \
	configure.bat Makefile.sed.nt INSTALL.WIN32 \
	config/config.nested.c config/config.nextcc.h config/config.nextrt.m \
	config/config.vsprintf.c \
	README.ULTRIX README.foundation README.ucblib \
	STATUS RELEASE-NOTES \
	COPYING COPYING.LIB ChangeLog \
	configure Version \
	config.guess mkinstalldirs install-sh config.sub \
	NSBundle.README \
	gcc-2.7.2-objc.diff \
	gcc-2.7.2.1-objc.diff

#
# The list of subproject directories
#
SUBPROJECTS = src doc checks examples NSCharacterSets admin

-include Makefile.preamble

include $(GNUSTEP_SYSTEM_ROOT)/Makefiles/aggregate.make

-include Makefile.postamble
