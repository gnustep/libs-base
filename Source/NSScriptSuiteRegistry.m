
/* Implementation of class NSScriptSuiteRegistry
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

#import "common.h"
#import "Foundation/NSScriptSuiteRegistry.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSBundle.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSScriptClassDescription.h"
#import "Foundation/NSScriptCommandDescription.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSLock.h"

static NSScriptSuiteRegistry *sharedRegistry = nil;
static NSLock *registryLock = nil;

@implementation NSScriptSuiteRegistry

+ (void) initialize
{
  if (self == [NSScriptSuiteRegistry class])
    {
      registryLock = [[NSLock alloc] init];
    }
}

+ (NSScriptSuiteRegistry *) sharedScriptSuiteRegistry
{
  NSScriptSuiteRegistry *registry;
  
  [registryLock lock];
  if (sharedRegistry == nil)
    {
      sharedRegistry = [[NSScriptSuiteRegistry alloc] init];
    }
  registry = sharedRegistry;
  [registryLock unlock];
  
  return registry;
}

+ (void) setSharedScriptSuiteRegistry: (NSScriptSuiteRegistry *)registry
{
  [registryLock lock];
  ASSIGN(sharedRegistry, registry);
  [registryLock unlock];
}

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      _suiteDescriptions = [[NSMutableDictionary alloc] init];
      _classDescriptions = [[NSMutableDictionary alloc] init];
      _commandDescriptions = [[NSMutableDictionary alloc] init];
      _bundles = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_suiteDescriptions);
  RELEASE(_classDescriptions);
  RELEASE(_commandDescriptions);
  RELEASE(_bundles);
  [super dealloc];
}

- (void) loadSuitesFromBundle: (NSBundle *)bundle
{
  NSString *suitesPath;
  NSArray *suitePaths;
  NSEnumerator *pathEnum;
  NSString *path;
  
  if (bundle == nil)
    {
      bundle = [NSBundle mainBundle];
    }
  
  if ([_bundles containsObject: bundle])
    {
      return;
    }
  
  [_bundles addObject: bundle];
  
  suitesPath = [bundle pathForResource: @"ScriptSuites" ofType: @"plist"];
  if (suitesPath != nil)
    {
      NSDictionary *suitesDict;
      NSEnumerator *suiteEnum;
      NSString *suiteName;
      
      suitesDict = [NSDictionary dictionaryWithContentsOfFile: suitesPath];
      if (suitesDict != nil)
        {
          suiteEnum = [suitesDict keyEnumerator];
          while ((suiteName = [suiteEnum nextObject]) != nil)
            {
              NSDictionary *suiteDecl;
              
              suiteDecl = [suitesDict objectForKey: suiteName];
              if (suiteDecl != nil)
                {
                  [self loadSuiteWithDictionary: suiteDecl fromBundle: bundle];
                }
            }
        }
    }
  
  suitePaths = [bundle pathsForResourcesOfType: @"scriptSuite" inDirectory: nil];
  pathEnum = [suitePaths objectEnumerator];
  while ((path = [pathEnum nextObject]) != nil)
    {
      NSDictionary *suiteDict;
      
      suiteDict = [NSDictionary dictionaryWithContentsOfFile: path];
      if (suiteDict != nil)
        {
          [self loadSuiteWithDictionary: suiteDict fromBundle: bundle];
        }
    }
}

- (void) loadSuiteWithDictionary: (NSDictionary *)suiteDeclaration
                    fromBundle: (NSBundle *)bundle
{
  NSString *suiteName;
  NSNumber *appleEventCode;
  NSDictionary *classes;
  NSDictionary *commands;
  NSEnumerator *classEnum;
  NSString *className;
  NSEnumerator *commandEnum;
  NSString *commandName;
  
  if (suiteDeclaration == nil)
    {
      return;
    }
  
  suiteName = [suiteDeclaration objectForKey: @"Name"];
  if (suiteName == nil)
    {
      return;
    }
  
  appleEventCode = [suiteDeclaration objectForKey: @"AppleEventCode"];
  if (appleEventCode != nil)
    {
      NSMutableDictionary *suiteInfo;
      
      suiteInfo = [NSMutableDictionary dictionaryWithCapacity: 3];
      [suiteInfo setObject: appleEventCode forKey: @"AppleEventCode"];
      [suiteInfo setObject: bundle forKey: @"Bundle"];
      [_suiteDescriptions setObject: suiteInfo forKey: suiteName];
    }
  
  classes = [suiteDeclaration objectForKey: @"Classes"];
  if (classes != nil)
    {
      classEnum = [classes keyEnumerator];
      while ((className = [classEnum nextObject]) != nil)
        {
          NSDictionary *classDecl;
          NSNumber *classCode;
          
          classDecl = [classes objectForKey: className];
          classCode = [classDecl objectForKey: @"AppleEventCode"];
          /* Superclass handling could be added here if needed */
          
          if (classCode != nil)
            {
              NSScriptClassDescription *classDesc;
              
              classDesc = [[NSScriptClassDescription alloc] initWithSuiteName: suiteName
                                                                     className: className
                                                                 appleEventCode: [classCode unsignedIntValue]];
              [self registerClassDescription: classDesc];
              RELEASE(classDesc);
            }
        }
    }
  
  commands = [suiteDeclaration objectForKey: @"Commands"];
  if (commands != nil)
    {
      commandEnum = [commands keyEnumerator];
      while ((commandName = [commandEnum nextObject]) != nil)
        {
          NSDictionary *commandDecl;
          NSNumber *commandCode;
          NSNumber *commandClassCode;
          
          commandDecl = [commands objectForKey: commandName];
          commandCode = [commandDecl objectForKey: @"AppleEventCode"];
          commandClassCode = [commandDecl objectForKey: @"AppleEventClassCode"];
          
          if (commandCode != nil && commandClassCode != nil)
            {
              NSScriptCommandDescription *commandDesc;
              
              commandDesc = [[NSScriptCommandDescription alloc] initWithSuiteName: suiteName
                                                                       commandName: commandName
                                                                    appleEventCode: [commandCode unsignedIntValue]
                                                               appleEventClassCode: [commandClassCode unsignedIntValue]];
              [self registerCommandDescription: commandDesc];
              RELEASE(commandDesc);
            }
        }
    }
}

- (void) registerClassDescription: (NSScriptClassDescription *)classDescription
{
  FourCharCode appleEventCode;
  NSNumber *codeNumber;
  
  if (classDescription == nil)
    {
      return;
    }
  
  appleEventCode = [classDescription appleEventCode];
  codeNumber = [NSNumber numberWithUnsignedInt: appleEventCode];
  
  [_classDescriptions setObject: classDescription forKey: codeNumber];
}

- (void) registerCommandDescription: (NSScriptCommandDescription *)commandDescription
{
  FourCharCode appleEventCode;
  FourCharCode appleEventClassCode;
  NSString *key;
  
  if (commandDescription == nil)
    {
      return;
    }
  
  appleEventCode = [commandDescription appleEventCode];
  appleEventClassCode = [commandDescription appleEventClassCode];
  
  key = [NSString stringWithFormat: @"%u-%u", 
         (unsigned int)appleEventClassCode, 
         (unsigned int)appleEventCode];
  
  [_commandDescriptions setObject: commandDescription forKey: key];
}

- (NSScriptClassDescription *) classDescriptionWithAppleEventCode: (FourCharCode)appleEventCode
{
  NSNumber *codeNumber;
  
  codeNumber = [NSNumber numberWithUnsignedInt: appleEventCode];
  return [_classDescriptions objectForKey: codeNumber];
}

- (NSScriptCommandDescription *) commandDescriptionWithAppleEventClass: (FourCharCode)appleEventClassCode
                                                 andAppleEventCode: (FourCharCode)appleEventCode
{
  NSString *key;
  
  key = [NSString stringWithFormat: @"%u-%u", 
         (unsigned int)appleEventClassCode, 
         (unsigned int)appleEventCode];
  
  return [_commandDescriptions objectForKey: key];
}

- (NSArray *) suiteNames
{
  return [_suiteDescriptions allKeys];
}

- (FourCharCode) appleEventCodeForSuite: (NSString *)suiteName
{
  NSDictionary *suiteInfo;
  NSNumber *codeNumber;
  
  if (suiteName == nil)
    {
      return 0;
    }
  
  suiteInfo = [_suiteDescriptions objectForKey: suiteName];
  if (suiteInfo == nil)
    {
      return 0;
    }
  
  codeNumber = [suiteInfo objectForKey: @"AppleEventCode"];
  if (codeNumber == nil)
    {
      return 0;
    }
  
  return [codeNumber unsignedIntValue];
}

- (NSBundle *) bundleForSuite: (NSString *)suiteName
{
  NSDictionary *suiteInfo;
  
  if (suiteName == nil)
    {
      return nil;
    }
  
  suiteInfo = [_suiteDescriptions objectForKey: suiteName];
  if (suiteInfo == nil)
    {
      return nil;
    }
  
  return [suiteInfo objectForKey: @"Bundle"];
}

@end

