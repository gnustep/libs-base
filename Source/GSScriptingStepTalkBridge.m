/* Implementation of GSScriptingStepTalkBridge for GNUstep
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

#import "common.h"
#import "GNUstepBase/GSScriptingStepTalkBridge.h"
#import "Foundation/NSScriptCommand.h"
#import "Foundation/NSScriptObjectSpecifier.h"
#import "Foundation/NSScriptSuiteRegistry.h"
#import "Foundation/NSScriptClassDescription.h"
#import "Foundation/NSScriptCommandDescription.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSString.h"
#import "Foundation/NSException.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSInvocation.h"

static GSScriptingStepTalkBridge *sharedInstance = nil;

@implementation GSScriptingStepTalkBridge

+ (void) initialize
{
  if (self == [GSScriptingStepTalkBridge class])
    {
      sharedInstance = [[GSScriptingStepTalkBridge alloc] init];
    }
}

+ (instancetype) sharedBridge
{
  return sharedInstance;
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _commandRegistry = [[NSMutableDictionary alloc] init];
      _cachedSpecifiers = [[NSMutableDictionary alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_commandRegistry);
  RELEASE(_cachedSpecifiers);
  [super dealloc];
}

- (NSScriptCommand *) createCommand:(NSString *)commandName
                           forSuite:(NSString *)suiteName
                      withArguments:(NSDictionary *)arguments
{
  NSScriptSuiteRegistry *registry;
  NSScriptCommandDescription *commandDesc;
  Class commandClass = Nil;
  NSScriptCommand *command;
  
  if (commandName == nil || suiteName == nil)
    {
      [NSException raise:NSInvalidArgumentException
                  format:@"Command name and suite name must not be nil"];
      return nil;
    }
  
  registry = [NSScriptSuiteRegistry sharedScriptSuiteRegistry];
  
  /* Look up the command description */
  commandDesc = [registry commandDescriptionWithName:commandName
                                              inSuite:suiteName];
  
  if (commandDesc == nil)
    {
      NSLog(@"Warning: Command '%@' not found in suite '%@'", 
            commandName, suiteName);
      /* Try to create a generic NSScriptCommand */
      commandClass = [NSScriptCommand class];
    }
  else
    {
      NSString *className = [commandDesc commandClassName];
      if (className != nil)
        {
          commandClass = NSClassFromString(className);
        }
      if (commandClass == Nil)
        {
          commandClass = [NSScriptCommand class];
        }
    }
  
  /* Create the command instance */
  command = [[commandClass alloc] init];
  
  /* Set command arguments if provided */
  if (arguments != nil)
    {
      NSEnumerator *keyEnum;
      NSString *key;
      
      keyEnum = [arguments keyEnumerator];
      while ((key = [keyEnum nextObject]) != nil)
        {
          id value;
          
          value = [arguments objectForKey:key];
          
          /* Handle special argument keys */
          if ([key isEqualToString:@"DirectParameter"])
            {
              [command setDirectParameter:value];
            }
          else if ([key isEqualToString:@"ObjectSpecifier"])
            {
              if ([value isKindOfClass:[NSScriptObjectSpecifier class]])
                {
                  [command setReceiversSpecifier:value];
                }
            }
          else
            {
              [command setArgument:value forKey:key];
            }
        }
    }
  
  return AUTORELEASE(command);
}

- (NSScriptObjectSpecifier *) createSpecifier:(NSString *)specifierType
                                   inContainer:(NSScriptObjectSpecifier *)containerSpecifier
                                        forKey:(NSString *)key
                                     withValue:(id)value
{
  NSScriptObjectSpecifier *specifier;
  Class specifierClass;
  
  if (specifierType == nil || key == nil)
    {
      [NSException raise:NSInvalidArgumentException
                  format:@"Specifier type and key must not be nil"];
      return nil;
    }
  
  specifier = nil;
  
  /* Determine the specifier class based on type */
  if ([specifierType isEqualToString:@"index"])
    {
      specifierClass = [NSIndexSpecifier class];
      specifier = [[specifierClass alloc] initWithContainerSpecifier:containerSpecifier
                                                                  key:key];
      if ([value respondsToSelector:@selector(integerValue)])
        {
          [(NSIndexSpecifier *)specifier setIndex:[value integerValue]];
        }
    }
  else if ([specifierType isEqualToString:@"name"])
    {
      specifierClass = [NSNameSpecifier class];
      specifier = [[specifierClass alloc] initWithContainerSpecifier:containerSpecifier
                                                                  key:key];
      if ([value isKindOfClass:[NSString class]])
        {
          [(NSNameSpecifier *)specifier setName:value];
        }
    }
  else if ([specifierType isEqualToString:@"property"])
    {
      specifierClass = [NSPropertySpecifier class];
      specifier = [[specifierClass alloc] initWithContainerSpecifier:containerSpecifier
                                                                  key:key];
    }
  else if ([specifierType isEqualToString:@"uniqueID"])
    {
      specifierClass = [NSUniqueIDSpecifier class];
      specifier = [[specifierClass alloc] initWithContainerSpecifier:containerSpecifier
                                                                  key:key];
      [(NSUniqueIDSpecifier *)specifier setUniqueID:value];
    }
  else if ([specifierType isEqualToString:@"range"])
    {
      specifierClass = [NSRangeSpecifier class];
      specifier = [[specifierClass alloc] initWithContainerSpecifier:containerSpecifier
                                                                  key:key];
      /* Value should be a dictionary with startSpecifier and endSpecifier */
      if ([value isKindOfClass:[NSDictionary class]])
        {
          id startSpec;
          id endSpec;
          
          startSpec = [value objectForKey:@"start"];
          endSpec = [value objectForKey:@"end"];
          
          if (startSpec != nil)
            {
              [(NSRangeSpecifier *)specifier setStartSpecifier:startSpec];
            }
          if (endSpec != nil)
            {
              [(NSRangeSpecifier *)specifier setEndSpecifier:endSpec];
            }
        }
    }
  else if ([specifierType isEqualToString:@"middle"])
    {
      specifierClass = [NSMiddleSpecifier class];
      specifier = [[specifierClass alloc] initWithContainerSpecifier:containerSpecifier
                                                                  key:key];
    }
  else if ([specifierType isEqualToString:@"random"])
    {
      specifierClass = [NSRandomSpecifier class];
      specifier = [[specifierClass alloc] initWithContainerSpecifier:containerSpecifier
                                                                  key:key];
    }
  else if ([specifierType isEqualToString:@"relative"])
    {
      specifierClass = [NSRelativeSpecifier class];
      specifier = [[specifierClass alloc] initWithContainerSpecifier:containerSpecifier
                                                                  key:key];
      if ([value isKindOfClass:[NSDictionary class]])
        {
          id baseSpec;
          NSString *position;
          
          baseSpec = [value objectForKey:@"base"];
          position = [value objectForKey:@"position"];
          
          if (baseSpec != nil)
            {
              [(NSRelativeSpecifier *)specifier setBaseSpecifier:baseSpec];
            }
          if (position != nil)
            {
              if ([position isEqualToString:@"before"])
                {
                  [(NSRelativeSpecifier *)specifier setRelativePosition:NSRelativeBefore];
                }
              else if ([position isEqualToString:@"after"])
                {
                  [(NSRelativeSpecifier *)specifier setRelativePosition:NSRelativeAfter];
                }
            }
        }
    }
  else
    {
      /* Default to property specifier */
      specifierClass = [NSPropertySpecifier class];
      specifier = [[specifierClass alloc] initWithContainerSpecifier:containerSpecifier
                                                                  key:key];
    }
  
  return AUTORELEASE(specifier);
}

- (id) executeCommand:(NSString *)commandName
             forSuite:(NSString *)suiteName
        withArguments:(NSDictionary *)arguments
{
  NSScriptCommand *command;
  id result;
  
  command = [self createCommand:commandName
                       forSuite:suiteName
                  withArguments:arguments];
  
  if (command == nil)
    {
      return nil;
    }
  
  result = [command executeCommand];
  
  /* Check for errors */
  if ([command scriptErrorNumber] != 0)
    {
      NSLog(@"Script command error %ld: %@",
            (long)[command scriptErrorNumber],
            [command scriptErrorString]);
    }
  
  return result;
}

- (id) getObject:(NSString *)objectName
          ofType:(NSString *)typeName
    fromContainer:(id)container
{
  NSScriptObjectSpecifier *containerSpec;
  NSScriptObjectSpecifier *objectSpec;
  NSScriptCommand *getCommand;
  NSDictionary *arguments;
  id result;
  
  /* Build the container specifier */
  if (container == nil)
    {
      containerSpec = nil; /* Application container */
    }
  else if ([container isKindOfClass:[NSScriptObjectSpecifier class]])
    {
      containerSpec = container;
    }
  else
    {
      /* Try to create a specifier from the container */
      containerSpec = nil;
    }
  
  /* Build the object specifier */
  objectSpec = [self createSpecifier:@"name"
                         inContainer:containerSpec
                              forKey:typeName
                           withValue:objectName];
  
  /* Create and execute get command */
  arguments = [NSDictionary dictionaryWithObject:objectSpec
                                          forKey:@"ObjectSpecifier"];
  
  getCommand = [self createCommand:@"get"
                          forSuite:@"CoreSuite"
                     withArguments:arguments];
  
  result = [getCommand executeCommand];
  
  return result;
}

- (void) setProperty:(NSString *)propertyName
            ofObject:(id)object
             toValue:(id)value
{
  NSScriptObjectSpecifier *objectSpec;
  NSScriptObjectSpecifier *propertySpec;
  NSScriptCommand *setCommand;
  NSDictionary *arguments;
  
  /* Build the object specifier */
  if ([object isKindOfClass:[NSScriptObjectSpecifier class]])
    {
      objectSpec = object;
    }
  else
    {
      /* Assume object is the container */
      objectSpec = nil;
    }
  
  /* Build the property specifier */
  propertySpec = [self createSpecifier:@"property"
                           inContainer:objectSpec
                                forKey:propertyName
                             withValue:nil];
  
  /* Create and execute set command */
  arguments = [NSDictionary dictionaryWithObjectsAndKeys:
                            propertySpec, @"ObjectSpecifier",
                            value, @"DirectParameter",
                            nil];
  
  setCommand = [self createCommand:@"set"
                          forSuite:@"CoreSuite"
                     withArguments:arguments];
  
  [setCommand executeCommand];
}

- (id) createObject:(NSString *)typeName
         atLocation:(id)location
     withProperties:(NSDictionary *)properties
{
  NSScriptObjectSpecifier *locationSpec;
  NSScriptCommand *createCommand;
  NSMutableDictionary *arguments;
  id result;
  
  /* Build the location specifier */
  if (location == nil)
    {
      locationSpec = nil;
    }
  else if ([location isKindOfClass:[NSScriptObjectSpecifier class]])
    {
      locationSpec = location;
    }
  else
    {
      locationSpec = nil;
    }
  
  /* Create arguments */
  arguments = [NSMutableDictionary dictionaryWithCapacity:3];
  [arguments setObject:typeName forKey:@"ObjectClass"];
  
  if (locationSpec != nil)
    {
      [arguments setObject:locationSpec forKey:@"Location"];
    }
  
  if (properties != nil)
    {
      [arguments setObject:properties forKey:@"WithProperties"];
    }
  
  /* Create and execute create command */
  createCommand = [self createCommand:@"create"
                             forSuite:@"CoreSuite"
                        withArguments:arguments];
  
  result = [createCommand executeCommand];
  
  return result;
}

- (void) deleteObject:(id)object
{
  NSScriptObjectSpecifier *objectSpec;
  NSScriptCommand *deleteCommand;
  NSDictionary *arguments;
  
  /* Build the object specifier */
  if ([object isKindOfClass:[NSScriptObjectSpecifier class]])
    {
      objectSpec = object;
    }
  else
    {
      /* Can't delete without a proper specifier */
      NSLog(@"Warning: Cannot delete object without specifier");
      return;
    }
  
  /* Create and execute delete command */
  arguments = [NSDictionary dictionaryWithObject:objectSpec
                                          forKey:@"ObjectSpecifier"];
  
  deleteCommand = [self createCommand:@"delete"
                             forSuite:@"CoreSuite"
                        withArguments:arguments];
  
  [deleteCommand executeCommand];
}

- (NSInteger) countObjects:(NSString *)typeName
               inContainer:(id)container
{
  NSScriptObjectSpecifier *containerSpec;
  NSScriptCommand *countCommand;
  NSDictionary *arguments;
  id result;
  NSInteger count;
  
  /* Build the container specifier */
  if (container == nil)
    {
      containerSpec = nil;
    }
  else if ([container isKindOfClass:[NSScriptObjectSpecifier class]])
    {
      containerSpec = container;
    }
  else
    {
      containerSpec = nil;
    }
  
  /* Create and execute count command */
  arguments = [NSDictionary dictionaryWithObjectsAndKeys:
                            typeName, @"ObjectClass",
                            containerSpec, @"ObjectSpecifier",
                            nil];
  
  countCommand = [self createCommand:@"count"
                            forSuite:@"CoreSuite"
                       withArguments:arguments];
  
  result = [countCommand executeCommand];
  
  count = 0;
  if ([result respondsToSelector:@selector(integerValue)])
    {
      count = [result integerValue];
    }
  
  return count;
}

- (void) registerCommandHandler:(id)handler
                     forCommand:(NSString *)commandName
                        inSuite:(NSString *)suiteName
{
  NSString *key;
  
  if (handler == nil || commandName == nil || suiteName == nil)
    {
      return;
    }
  
  key = [NSString stringWithFormat:@"%@.%@", suiteName, commandName];
  [_commandRegistry setObject:handler forKey:key];
}

- (void) clearCache
{
  [_cachedSpecifiers removeAllObjects];
}

@end
