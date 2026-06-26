/**Definition of NSScriptStandardSuiteCommands classes
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Sep 2019

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef _NSScriptStandardSuiteCommands_h_GNUSTEP_BASE_INCLUDE
#define _NSScriptStandardSuiteCommands_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSScriptCommand.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString;
@class NSScriptClassDescription;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_0, GS_API_LATEST)

typedef NS_ENUM(NSInteger, NSSaveOptions) {
  NSSaveOptionsYes = 0,
  NSSaveOptionsNo,
  NSSaveOptionsAsk
};

// Clone Command
GS_EXPORT_CLASS
@interface NSCloneCommand : NSScriptCommand
- (id) performDefaultImplementation;
@end

// Close Command
GS_EXPORT_CLASS
@interface NSCloseCommand : NSScriptCommand
{
  @private
  id _saveOptions;
  id _file;
}
- (NSSaveOptions) saveOptions;
- (id) performDefaultImplementation;
@end

// Count Command
GS_EXPORT_CLASS
@interface NSCountCommand : NSScriptCommand
- (id) performDefaultImplementation;
@end

// Create Command
GS_EXPORT_CLASS
@interface NSCreateCommand : NSScriptCommand
{
  @private
  NSScriptObjectSpecifier *_createClassDescription;
}
- (NSScriptClassDescription *) createClassDescription;
- (id) performDefaultImplementation;
@end

// Delete Command
GS_EXPORT_CLASS
@interface NSDeleteCommand : NSScriptCommand
{
  @private
  id _keySpecifier;
}
- (void) setReceiversSpecifier: (NSScriptObjectSpecifier *)receiversRef;
- (id) performDefaultImplementation;
@end

// Exists Command
GS_EXPORT_CLASS
@interface NSExistsCommand : NSScriptCommand
- (id) performDefaultImplementation;
@end

// Get Command
GS_EXPORT_CLASS
@interface NSGetCommand : NSScriptCommand
- (id) performDefaultImplementation;
@end

// Move Command
GS_EXPORT_CLASS
@interface NSMoveCommand : NSScriptCommand
{
  @private
  NSScriptObjectSpecifier *_keySpecifier;
}
- (void) setReceiversSpecifier: (NSScriptObjectSpecifier *)receiversRef;
- (id) performDefaultImplementation;
@end

// Quit Command
GS_EXPORT_CLASS
@interface NSQuitCommand : NSScriptCommand
{
  @private
  NSSaveOptions _saveOptions;
}
- (NSSaveOptions) saveOptions;
- (id) performDefaultImplementation;
@end

// Set Command
GS_EXPORT_CLASS
@interface NSSetCommand : NSScriptCommand
{
  @private
  id _keySpecifier;
}
- (void) setReceiversSpecifier: (NSScriptObjectSpecifier *)receiversRef;
- (id) performDefaultImplementation;
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSScriptStandardSuiteCommands_h_GNUSTEP_BASE_INCLUDE */

