/* Interface for NSScriptingStepTalkBridge for GNUstep
   Copyright (C) 2025 Free Software Foundation, Inc.

   Written by:  <heron>
   Created: 2025
   
   This file is part of the GNUstep Base Library.

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 Suite 500, USA.
*/

#ifndef __GSScriptingStepTalkBridge_h_GNUSTEP_BASE_INCLUDE
#define __GSScriptingStepTalkBridge_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString;
@class NSDictionary;
@class NSMutableDictionary;
@class NSArray;
@class NSScriptCommand;
@class NSScriptObjectSpecifier;

/**
 * GSScriptingStepTalkBridge provides a bridge between StepTalk scripting
 * and the GNUstep NSScripting framework. This allows StepTalk scripts to
 * create and execute script commands, build object specifiers, and interact
 * with scriptable applications.
 *
 * Example StepTalk usage:
 * <example>
 *   | bridge command |
 *   bridge := GSScriptingStepTalkBridge sharedBridge.
 *   command := bridge 
 *     createCommand: 'get'
 *     forSuite: 'CoreSuite'
 *     withArguments: nil.
 *   command executeCommand.
 * </example>
 */
@interface GSScriptingStepTalkBridge : NSObject
{
  @private
  NSMutableDictionary *_commandRegistry;
  NSMutableDictionary *_cachedSpecifiers;
}

/**
 * Returns the shared bridge instance.
 */
+ (instancetype) sharedBridge;

/**
 * Creates an NSScriptCommand instance from StepTalk parameters.
 * This is the primary method for StepTalk scripts to create commands.
 *
 * @param commandName The name of the command (e.g., @"get", @"set", @"create")
 * @param suiteName The suite name (e.g., @"CoreSuite", @"TextSuite")
 * @param arguments A dictionary of command arguments
 * @return A newly created NSScriptCommand instance
 */
- (NSScriptCommand *) createCommand:(NSString *)commandName
                           forSuite:(NSString *)suiteName
                      withArguments:(NSDictionary *)arguments;

/**
 * Creates an object specifier from StepTalk parameters.
 * This allows StepTalk scripts to build complex object specifiers.
 *
 * @param specifierType The type of specifier (@"index", @"name", @"property", etc.)
 * @param containerSpecifier The container specifier (or nil for application)
 * @param key The key or property name
 * @param value The value (index, name, etc.)
 * @return A newly created NSScriptObjectSpecifier instance
 */
- (NSScriptObjectSpecifier *) createSpecifier:(NSString *)specifierType
                                   inContainer:(NSScriptObjectSpecifier *)containerSpecifier
                                        forKey:(NSString *)key
                                     withValue:(id)value;

/**
 * Executes a command and returns the result.
 * This is a convenience method that creates and executes a command in one step.
 *
 * @param commandName The command name
 * @param suiteName The suite name
 * @param arguments The command arguments
 * @return The result of executing the command
 */
- (id) executeCommand:(NSString *)commandName
             forSuite:(NSString *)suiteName
        withArguments:(NSDictionary *)arguments;

/**
 * Convenience method to get an object by name.
 */
- (id) getObject:(NSString *)objectName
          ofType:(NSString *)typeName
    fromContainer:(id)container;

/**
 * Convenience method to set a property value.
 */
- (void) setProperty:(NSString *)propertyName
            ofObject:(id)object
             toValue:(id)value;

/**
 * Convenience method to create a new object.
 */
- (id) createObject:(NSString *)typeName
         atLocation:(id)location
     withProperties:(NSDictionary *)properties;

/**
 * Convenience method to delete an object.
 */
- (void) deleteObject:(id)object;

/**
 * Convenience method to count objects.
 */
- (NSInteger) countObjects:(NSString *)typeName
               inContainer:(id)container;

/**
 * Registers a custom command handler for StepTalk.
 * This allows extending the bridge with custom commands.
 *
 * @param handler A block or invocation that handles the command
 * @param commandName The command name to register
 * @param suiteName The suite name
 */
- (void) registerCommandHandler:(id)handler
                     forCommand:(NSString *)commandName
                        inSuite:(NSString *)suiteName;

/**
 * Clears cached specifiers and command handlers.
 */
- (void) clearCache;

@end

#if	defined(__cplusplus)
}
#endif

#endif /* __GSScriptingStepTalkBridge_h_GNUSTEP_BASE_INCLUDE */
