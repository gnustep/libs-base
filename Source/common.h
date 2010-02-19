/* Header file for all objective-c code in the base library.
 * This imports all the common headers in a consistent order such that
 * we can be sure only local headers are used rather than any which
 * might be from an earlier build.
 */

#import	"config.h"

#import	"GNUstepBase/GSConfig.h"
#import	"GNUstepBase/preface.h"

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

