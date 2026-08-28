include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = HTTPServer

NEEDS_GUI=NO

HTTPServer_OBJC_FILES = HTTPServer.m

ifeq ($(GNUSTEP_TARGET_OS), windows)
HTTPServer_OBJC_LIBS += -lws2_32
endif

# Built with the same memory rules as the rest of the tests, so that a
# compiler without -fobjc-arc can build it too.
#HTTPServer_RESOURCE_FILES += key.pem certificate.pem
HTTPServer_PRINCIPAL_CLASS = HTTPServer

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
