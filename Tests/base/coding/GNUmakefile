# __GENERATED__ makefile marker
#

include $(GNUSTEP_MAKEFILES)/common.make
-include ../GNUmakefile.super

GNUSTEP_OBJ_DIR=./obj

TEST_TOOL_NAME =  basictypes

ifeq ($(gcov),yes)
ADDITIONAL_OBJCFLAGS += -ftest-coverage -fprofile-arcs
ADDITIONAL_OBJCCFLAGS += -ftest-coverage -fprofile-arcs
ADDITIONAL_LDFLAGS += -ftest-coverage -fprofile-arcs
ADDITIONAL_TOOL_LIBS+=-lgcov
endif


basictypes_OBJC_FILES=basictypes.m

-include GNUmakefile.preamble
-include make-check.mak
include $(GNUSTEP_MAKEFILES)/test-tool.make
-include GNUmakefile.postamble

after-clean::
	rm -f core core.* *.core \
	test_*.out test_*.err \
	tests.log tests.sum oldtests.log oldtests.sum \
	*.type \

