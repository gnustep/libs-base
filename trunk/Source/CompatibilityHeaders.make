#   -*-makefile-*-
#   CompatibilityHeaders.make
#
#   Create compatibility headers so that code written before the big header
#   move will continue to compile (for a while).
#
#   Copyright (C) 2003 Free Software Foundation, Inc.
#
#
#   Author: Alexander Malmberg <alexander@malmberg.org>
#   Date: 2003-07-29
#
#   This file is part of the GNUstep project.
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#
#   You should have received a copy of the GNU General Public
#   License along with this library; see the file COPYING.LIB.
#   If not, write to the Free Software Foundation,
#   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# The usage should be fairly obvious. For each pair of OLD_DIR and NEW_DIR,
# make a copy and set OLD_DIR, NEW_DIR, and LIST. Note that LIST must be
# non-empty; if there are no files for a pair, remove it completely.

after-install::
	@echo Installing compatibility headers...

	@OLD_DIR=Foundation; NEW_DIR=GNUstepBase; \
	LIST="GSXML.h GSMime.h" ;\
	$(MKDIRS) $(GNUSTEP_HEADERS)/$$OLD_DIR; \
	for I in $$LIST ; do \
	  (echo "#warning $$I is now included using the path <$$NEW_DIR/$$I>";\
	  echo "#include <$$NEW_DIR/$$I>" ) \
	  > $(GNUSTEP_HEADERS)/$$OLD_DIR/$$I; \
	done

	@OLD_DIR=gnustep/unicode; NEW_DIR=GNUstepBase/unicode; \
	LIST="caseconv.h cop.h cyrillic.h latin2.h decomp.h nextstep.h" ;\
	$(MKDIRS) $(GNUSTEP_HEADERS)/$$OLD_DIR; \
	for I in $$LIST ; do \
	  (echo "#warning $$I is now included using the path <$$NEW_DIR/$$I>";\
	  echo "#include <$$NEW_DIR/$$I>" ) \
	  > $(GNUSTEP_HEADERS)/$$OLD_DIR/$$I;\
	done

	@OLD_DIR=gnustep/base; NEW_DIR=GNUstepBase; \
	LIST="$(GNU_HEADERS)" ;\
	$(MKDIRS) $(GNUSTEP_HEADERS)/$$OLD_DIR; \
	for I in $$LIST ; do \
	  (echo "#warning $$I is now included using the path <$$NEW_DIR/$$I>";\
 	  echo "#include <$$NEW_DIR/$$I>" ) \
	  > $(GNUSTEP_HEADERS)/$$OLD_DIR/$$I; \
	done


before-uninstall::
	-@OLD_DIR=Foundation; NEW_DIR=GNUstepBase; \
	LIST="GSXML.h GSMime.h" ;\
	for I in $$LIST ; do \
	  rm -f $(GNUSTEP_HEADERS)/$$OLD_DIR/$$I; \
	done;

	-@OLD_DIR=gnustep/unicode; NEW_DIR=GNUstepBase/unicode; \
	LIST="caseconv.h cop.h cyrillic.h latin2.h decomp.h nextstep.h" ;\
	for I in $$LIST ; do \
	  rm -f $(GNUSTEP_HEADERS)/$$OLD_DIR/$$I; \
	done; \
	rmdir $(GNUSTEP_HEADERS)/$$OLD_DIR

	-@OLD_DIR=gnustep/base; NEW_DIR=GNUstepBase; \
	LIST="$(GNU_HEADERS)" ;\
	for I in $$LIST ; do \
	  rm -f $(GNUSTEP_HEADERS)/$$OLD_DIR/$$I; \
	done; \
	rmdir $(GNUSTEP_HEADERS)/$$OLD_DIR; \
	rmdir $(GNUSTEP_HEADERS)/gnustep
