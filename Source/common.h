/* Header file for all objective-c code in the base library.
 * This imports all the common headers in a consistent order such that
 * we can be sure only local headers are used rather than any which
 * might be from an earlier build.
 */

#import	"config.h"

/* If this is included in a file in the Additions subdirectory, and we are
 * building for use with the NeXT/Apple Foundation, then we need to import
 * the native headers in preference to any of our own.
 */
#if	defined(NeXT_Foundation_LIBRARY)
#import	<Foundation/Foundation.h>
#endif

/* GNUstepBase/GSConfig.h includes <GNUstepBase/preface.h> so
 * we import local versions first.
 */
#import	"GNUstepBase/preface.h"
#import	"GNUstepBase/GSConfig.h"

/* Set localisation macro for use within the base library itsself.
 */
#define GS_LOCALISATION_BUNDLE \
  [NSBundle bundleForLibrary: @"gnustep-base" version: \
  OBJC_STRINGIFY(GNUSTEP_BASE_MAJOR_VERSION.GNUSTEP_BASE_MINOR_VERSION)]

#import	"GNUstepBase/GNUstep.h"

/* Foundation/NSObject.h imports <Foundation/NSZone.h> and
 * <Foundation/NSObjCRuntime.h> so we import local versions first.
 */
#import	"Foundation/NSZone.h"
#import	"Foundation/NSObjCRuntime.h"

/* Almost all headers import <Foundation/NSObject.h> so we import
 * "Foundation/NSObject.h" first, to ensure we have a local copy.
 */
#import	"Foundation/NSObject.h"

/* These headers are used in almost every file.
 */
#import	"Foundation/NSString.h"
#import	"Foundation/NSDebug.h"

#import	"Foundation/NSBundle.h"
#import	"GNUstepBase/NSBundle+GNUstepBase.h"


#include <string.h>
#include <ctype.h>

#if defined(__GNUSTEP_RUNTIME__) || defined(NeXT_RUNTIME)
#define objc_malloc(x) malloc(x)
#define objc_realloc(p, s) realloc(p, s)
#define objc_free(x) free(x)
#endif

/*
 * If we are not using the NeXT runtime, we are able to use typed selectors.
 * Unfortunately, the APIs for doing so differ between runtimes.  The old GCC
 * runtime used lower-case function names with underscore separation.  The
 * GNUstep runtime adopts the Apple runtime API naming convention, but suffixes
 * non-portable functions with _np to warn against their use where OS X
 * compatibility is required.  The newer GCC runtime uses the Apple convention,
 * but does not add the _np suffix, making it unclear that the calls are not
 * portable. 
 *
 * These macros allow the GNUstep runtime versions to be used everywhere, so
 * the _np suffix explicitly annotates the code as not compatible with the NeXT
 * and Mac runtimes.
 */
#ifdef NeXT_RUNTIME
#  ifdef __GNU_LIBOBJC__
#    define sel_getType_np sel_getTypeEncoding
#    define sel_registerTypedName_np sel_registerTypedName
#  elif !defined(__GNUSTEP_RUNTIME__)
#    define sel_getType_np sel_get_type
#    define sel_registerTypedName_np sel_register_typed_name
#  endif
#endif

// Semi-private GNU[step] runtime function.
IMP get_imp(Class, SEL);
