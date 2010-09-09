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

#include <string.h>
#include <ctype.h>

#if defined(__GNUSTEP_RUNTIME__) || defined(NeXT_RUNTIME)
#define objc_malloc(x) malloc(x)
#define objc_realloc(p, s) realloc(p, s)
#define objc_free(x) free(x)
#endif

// Semi-private GNU[step] runtime function.  
IMP get_imp(Class, SEL);
