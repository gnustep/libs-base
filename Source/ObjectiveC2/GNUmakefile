include $(GNUSTEP_MAKEFILES)/common.make

#
# Application
#
VERSION = 0.1
FRAMEWORK_NAME = ObjectiveC2

#
# Resource files
#
ObjectiveC2_LANGUAGES = English

ObjectiveC2_OBJC_FILES = \
				blocks_runtime.m\
				properties.m\
				sync.m


ObjectiveC2_C_FILES = \
				runtime.c

ObjectiveC2_HEADER_FILES = \
					  Availability.h\
					  blocks_runtime.h\
					  runtime.h

ADDITIONAL_CFLAGS = -std=c99 -fexceptions 
ADDITIONAL_OBJCFLAGS = -fobjc-exceptions -fexceptions

ifeq ($(CC), clang)
	ADDITIONAL_OBJCFLAGS = -fblocks
endif
ifeq ($(GNUSTEP_TARGET_CPU), ix86)
	ADDITIONAL_OBJCFLAGS += -march=i686
endif

ObjectiveC2_OBJCFLAGS += -std=c99

include $(GNUSTEP_MAKEFILES)/framework.make
-include ../../etoile.make
