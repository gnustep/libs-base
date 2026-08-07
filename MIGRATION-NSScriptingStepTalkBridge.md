# NSScriptingStepTalkBridge Migration to GNUstepBase

## Overview

Moved NSScriptingStepTalkBridge from Foundation to GNUstepBase headers, as this is a GNUstep-specific integration feature rather than a standard Foundation class.

## Changes Made

### File Locations

- **Header**: `Headers/GNUstepBase/NSScriptingStepTalkBridge.h` (moved from Headers/Foundation/)
- **Implementation**: `Source/NSScriptingStepTalkBridge.m` (unchanged)

### Updated Files

1. **Source/NSScriptingStepTalkBridge.m**
   - Changed import from `"Foundation/NSScriptingStepTalkBridge.h"` to `"GNUstepBase/NSScriptingStepTalkBridge.h"`

2. **Headers/Foundation/Foundation.h**
   - Removed: `#import <Foundation/NSScriptingStepTalkBridge.h>`

3. **Source/GNUmakefile**
   - Removed `NSScriptingStepTalkBridge.h` from Foundation headers list
   - Added `NSScriptingStepTalkBridge.h` to GNUstepBase headers list (after NSProcessInfo+GNUstepBase.h)

4. **Source/DocMakefile**
   - Removed `NSScriptingStepTalkBridge.h` from Foundation headers documentation list  
   - Added `NSScriptingStepTalkBridge.h` to GNUstepBase headers documentation list (after NSProcessInfo+GNUstepBase.h)

## Usage

Applications using the bridge should now import it via:

```objc
#import <GNUstepBase/NSScriptingStepTalkBridge.h>
```

## Rationale

NSScriptingStepTalkBridge is a GNUstep-specific extension that bridges StepTalk (GNUstep's Smalltalk-based scripting) with the NSScripting framework. Since it's not part of Apple's Foundation framework and is specific to GNUstep, it belongs in GNUstepBase alongside other GNUstep-specific extensions like NSObject+GNUstepBase.h.

## Build System

The class is still compiled into gnustep-base library and exported, just categorized correctly as a GNUstepBase extension rather than a Foundation class.
