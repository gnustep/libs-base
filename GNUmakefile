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
#  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA
#

# This usually happens when you source GNUstep.sh, then run ./configure,
# then log out, then log in again and try to compile
ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to run the GNUstep configuration script before compiling!)
endif

# Install into the system root by default
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

RPM_DISABLE_RELOCATABLE=YES
PACKAGE_NEEDS_CONFIGURE = YES

CVS_MODULE_NAME = base

GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

#
# Include local (new) configuration - this will prevent the old one 
# (if any) from $(GNUSTEP_MAKEFILES)/Additional/base.make to be included
#
GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES=base.make
include $(GNUSTEP_MAKEFILES)/common.make

include ./Version

PACKAGE_NAME = gnustep-base

#
# The list of subproject directories
#
SUBPROJECTS = Source Tools NSCharacterSets NSTimeZones Resources

-include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include Makefile.postamble

