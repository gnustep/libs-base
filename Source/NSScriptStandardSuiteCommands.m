/* Implementation of NSScriptStandardSuiteCommands classes
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
#import "Foundation/NSScriptStandardSuiteCommands.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSScriptClassDescription.h"
#import "Foundation/NSScriptObjectSpecifier.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"

// NSCloneCommand

@implementation NSCloneCommand

- (id) performDefaultImplementation
{
  NSScriptObjectSpecifier *receiversSpec;
  id receivers;
  id result;
  
  receiversSpec = [self receiversSpecifier];
  if (receiversSpec == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Clone command requires object to clone"];
      return nil;
    }
  
  receivers = [receiversSpec objectsByEvaluatingSpecifier];
  if (receivers == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Could not evaluate object to clone"];
      return nil;
    }
  
  if ([receivers respondsToSelector: @selector(copy)])
    {
      result = [receivers copy];
      return AUTORELEASE(result);
    }
  
  [self setScriptErrorNumber: -1751];
  [self setScriptErrorString: @"Object does not support cloning"];
  return nil;
}

@end

// NSCloseCommand

@implementation NSCloseCommand

- (NSSaveOptions) saveOptions
{
  id saveOption;
  
  saveOption = [[self evaluatedArguments] objectForKey: @"SaveOptions"];
  if (saveOption == nil)
    {
      return NSSaveOptionsAsk;
    }
  
  if ([saveOption isKindOfClass: [NSNumber class]])
    {
      return [saveOption integerValue];
    }
  
  if ([saveOption isKindOfClass: [NSString class]])
    {
      if ([saveOption isEqualToString: @"yes"])
        {
          return NSSaveOptionsYes;
        }
      else if ([saveOption isEqualToString: @"no"])
        {
          return NSSaveOptionsNo;
        }
      else if ([saveOption isEqualToString: @"ask"])
        {
          return NSSaveOptionsAsk;
        }
    }
  
  return NSSaveOptionsAsk;
}

- (id) performDefaultImplementation
{
  NSScriptObjectSpecifier *receiversSpec;
  id receivers;
  
  receiversSpec = [self receiversSpecifier];
  if (receiversSpec == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Close command requires object to close"];
      return nil;
    }
  
  receivers = [receiversSpec objectsByEvaluatingSpecifier];
  if (receivers == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Could not evaluate object to close"];
      return nil;
    }
  
  (void)[self saveOptions]; /* Retrieve but don't use for now */
  
  if ([receivers respondsToSelector: @selector(close)])
    {
      [receivers performSelector: @selector(close)];
      return [NSNumber numberWithBool: YES];
    }
  
  [self setScriptErrorNumber: -1751];
  [self setScriptErrorString: @"Object does not support close"];
  return nil;
}

@end

// NSCountCommand

@implementation NSCountCommand

- (id) performDefaultImplementation
{
  NSScriptObjectSpecifier *receiversSpec;
  id receivers;
  NSUInteger count;
  
  receiversSpec = [self receiversSpecifier];
  if (receiversSpec == nil)
    {
      id directParam;
      
      directParam = [self directParameter];
      if (directParam != nil)
        {
          receivers = directParam;
        }
      else
        {
          [self setScriptErrorNumber: -1728];
          [self setScriptErrorString: @"Count command requires object to count"];
          return nil;
        }
    }
  else
    {
      receivers = [receiversSpec objectsByEvaluatingSpecifier];
    }
  
  if (receivers == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Could not evaluate object to count"];
      return nil;
    }
  
  if ([receivers isKindOfClass: [NSArray class]])
    {
      count = [receivers count];
    }
  else if ([receivers respondsToSelector: @selector(count)])
    {
      count = [receivers count];
    }
  else
    {
      count = 1;
    }
  
  return [NSNumber numberWithUnsignedInteger: count];
}

@end

// NSCreateCommand

@implementation NSCreateCommand

- (NSScriptClassDescription *) createClassDescription
{
  id classValue;
  NSString *className;
  
  classValue = [[self evaluatedArguments] objectForKey: @"ObjectClass"];
  if (classValue == nil)
    {
      return nil;
    }
  
  if ([classValue isKindOfClass: [NSString class]])
    {
      className = classValue;
    }
  else if ([classValue isKindOfClass: [NSScriptClassDescription class]])
    {
      return classValue;
    }
  else
    {
      return nil;
    }
  
  return [NSScriptClassDescription classDescriptionForClass: NSClassFromString(className)];
}

- (id) performDefaultImplementation
{
  NSScriptClassDescription *classDesc;
  NSString *className;
  Class createClass;
  id newObject;
  id container;
  NSScriptObjectSpecifier *containerSpec;
  NSString *key;
  id properties;
  
  classDesc = [self createClassDescription];
  if (classDesc == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Create command requires class to create"];
      return nil;
    }
  
  className = [classDesc className];
  createClass = NSClassFromString(className);
  if (createClass == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: [NSString stringWithFormat: @"Unknown class: %@", className]];
      return nil;
    }
  
  newObject = [[createClass alloc] init];
  if (newObject == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Could not create object"];
      return nil;
    }
  
  properties = [[self evaluatedArguments] objectForKey: @"KeyDictionary"];
  if (properties != nil && [properties isKindOfClass: [NSDictionary class]])
    {
      NSEnumerator *keyEnum;
      NSString *propKey;
      
      keyEnum = [properties keyEnumerator];
      while ((propKey = [keyEnum nextObject]) != nil)
        {
          id propValue;
          
          propValue = [properties objectForKey: propKey];
          [newObject setValue: propValue forKey: propKey];
        }
    }
  
  containerSpec = [[self evaluatedArguments] objectForKey: @"Location"];
  if (containerSpec != nil && [containerSpec isKindOfClass: [NSScriptObjectSpecifier class]])
    {
      container = [containerSpec objectsByEvaluatingSpecifier];
      key = [containerSpec key];
      
      if (container != nil && key != nil)
        {
          id collection;
          
          collection = [container valueForKey: key];
          if ([collection isKindOfClass: [NSMutableArray class]])
            {
              [collection addObject: newObject];
            }
          else if ([container respondsToSelector: @selector(insertObject:inPropertyWithKey:)])
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"
              [container insertObject: newObject inPropertyWithKey: key];
#pragma clang diagnostic pop
            }
        }
    }
  
  return AUTORELEASE(newObject);
}

- (void) dealloc
{
  RELEASE(_createClassDescription);
  [super dealloc];
}

@end

// NSDeleteCommand

@implementation NSDeleteCommand

- (void) setReceiversSpecifier: (NSScriptObjectSpecifier *)receiversRef
{
  [super setReceiversSpecifier: receiversRef];
  ASSIGN(_keySpecifier, receiversRef);
}

- (id) performDefaultImplementation
{
  NSScriptObjectSpecifier *receiversSpec;
  id receivers;
  NSScriptObjectSpecifier *containerSpec;
  id container;
  NSString *key;
  
  receiversSpec = [self receiversSpecifier];
  if (receiversSpec == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Delete command requires object to delete"];
      return nil;
    }
  
  receivers = [receiversSpec objectsByEvaluatingSpecifier];
  if (receivers == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Could not evaluate object to delete"];
      return nil;
    }
  
  containerSpec = [receiversSpec containerSpecifier];
  if (containerSpec != nil)
    {
      container = [containerSpec objectsByEvaluatingSpecifier];
      key = [receiversSpec key];
      
      if (container != nil && key != nil)
        {
          id collection;
          
          collection = [container valueForKey: key];
          if ([collection isKindOfClass: [NSMutableArray class]])
            {
              [collection removeObject: receivers];
              return [NSNumber numberWithBool: YES];
            }
          else if ([container respondsToSelector: @selector(removeValueForKey:)])
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"
              [container removeValueForKey: key];
#pragma clang diagnostic pop
              return [NSNumber numberWithBool: YES];
            }
        }
    }
  
  [self setScriptErrorNumber: -1751];
  [self setScriptErrorString: @"Could not delete object"];
  return nil;
}

- (void) dealloc
{
  RELEASE(_keySpecifier);
  [super dealloc];
}

@end

// NSExistsCommand

@implementation NSExistsCommand

- (id) performDefaultImplementation
{
  NSScriptObjectSpecifier *receiversSpec;
  id receivers;
  
  receiversSpec = [self receiversSpecifier];
  if (receiversSpec == nil)
    {
      id directParam;
      
      directParam = [self directParameter];
      if (directParam != nil)
        {
          return [NSNumber numberWithBool: YES];
        }
      return [NSNumber numberWithBool: NO];
    }
  
  receivers = [receiversSpec objectsByEvaluatingSpecifier];
  return [NSNumber numberWithBool: (receivers != nil)];
}

@end

// NSGetCommand

@implementation NSGetCommand

- (id) performDefaultImplementation
{
  NSScriptObjectSpecifier *receiversSpec;
  id receivers;
  
  receiversSpec = [self receiversSpecifier];
  if (receiversSpec == nil)
    {
      id directParam;
      
      directParam = [self directParameter];
      if (directParam != nil)
        {
          return directParam;
        }
      
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Get command requires object"];
      return nil;
    }
  
  receivers = [receiversSpec objectsByEvaluatingSpecifier];
  if (receivers == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Could not evaluate object"];
      return nil;
    }
  
  return receivers;
}

@end

// NSMoveCommand

@implementation NSMoveCommand

- (void) setReceiversSpecifier: (NSScriptObjectSpecifier *)receiversRef
{
  [super setReceiversSpecifier: receiversRef];
  ASSIGN(_keySpecifier, receiversRef);
}

- (id) performDefaultImplementation
{
  NSScriptObjectSpecifier *receiversSpec;
  id receivers;
  NSScriptObjectSpecifier *destinationSpec;
  id destination;
  NSScriptObjectSpecifier *sourceContainerSpec;
  id sourceContainer;
  NSString *sourceKey;
  NSString *destKey;
  
  receiversSpec = [self receiversSpecifier];
  if (receiversSpec == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Move command requires object to move"];
      return nil;
    }
  
  receivers = [receiversSpec objectsByEvaluatingSpecifier];
  if (receivers == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Could not evaluate object to move"];
      return nil;
    }
  
  destinationSpec = [[self evaluatedArguments] objectForKey: @"ToLocation"];
  if (destinationSpec == nil || ![destinationSpec isKindOfClass: [NSScriptObjectSpecifier class]])
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Move command requires destination"];
      return nil;
    }
  
  destination = [destinationSpec objectsByEvaluatingSpecifier];
  if (destination == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Could not evaluate destination"];
      return nil;
    }
  
  sourceContainerSpec = [receiversSpec containerSpecifier];
  if (sourceContainerSpec != nil)
    {
      sourceContainer = [sourceContainerSpec objectsByEvaluatingSpecifier];
      sourceKey = [receiversSpec key];
      destKey = [destinationSpec key];
      
      if (sourceContainer != nil && sourceKey != nil)
        {
          id sourceCollection;
          id destCollection;
          
          sourceCollection = [sourceContainer valueForKey: sourceKey];
          
          if ([sourceCollection isKindOfClass: [NSMutableArray class]])
            {
              RETAIN(receivers);
              [sourceCollection removeObject: receivers];
              
              if (destination != nil && destKey != nil)
                {
                  destCollection = [destination valueForKey: destKey];
                  if ([destCollection isKindOfClass: [NSMutableArray class]])
                    {
                      [destCollection addObject: receivers];
                    }
                }
              
              RELEASE(receivers);
              return [NSNumber numberWithBool: YES];
            }
        }
    }
  
  [self setScriptErrorNumber: -1751];
  [self setScriptErrorString: @"Could not move object"];
  return nil;
}

- (void) dealloc
{
  RELEASE(_keySpecifier);
  [super dealloc];
}

@end

// NSQuitCommand

@implementation NSQuitCommand

- (NSSaveOptions) saveOptions
{
  id saveOption;
  
  saveOption = [[self evaluatedArguments] objectForKey: @"SaveOptions"];
  if (saveOption == nil)
    {
      return NSSaveOptionsAsk;
    }
  
  if ([saveOption isKindOfClass: [NSNumber class]])
    {
      return [saveOption integerValue];
    }
  
  if ([saveOption isKindOfClass: [NSString class]])
    {
      if ([saveOption isEqualToString: @"yes"])
        {
          return NSSaveOptionsYes;
        }
      else if ([saveOption isEqualToString: @"no"])
        {
          return NSSaveOptionsNo;
        }
      else if ([saveOption isEqualToString: @"ask"])
        {
          return NSSaveOptionsAsk;
        }
    }
  
  return NSSaveOptionsAsk;
}

- (id) performDefaultImplementation
{
  /* NSApplication is not available in Foundation.
   * Applications should override this method or handle quit through
   * other mechanisms (notifications, delegates, etc.)
   */
  (void)[self saveOptions]; /* Retrieve but don't use for now */
  
  [self setScriptErrorNumber: -1751];
  [self setScriptErrorString: @"Quit command must be implemented by application"];
  return nil;
}

@end

// NSSetCommand

@implementation NSSetCommand

- (void) setReceiversSpecifier: (NSScriptObjectSpecifier *)receiversRef
{
  [super setReceiversSpecifier: receiversRef];
  ASSIGN(_keySpecifier, receiversRef);
}

- (id) performDefaultImplementation
{
  NSScriptObjectSpecifier *receiversSpec;
  id receivers;
  id newValue;
  NSScriptObjectSpecifier *containerSpec;
  id container;
  NSString *key;
  
  receiversSpec = [self receiversSpecifier];
  if (receiversSpec == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Set command requires object"];
      return nil;
    }
  
  newValue = [[self evaluatedArguments] objectForKey: @"Value"];
  if (newValue == nil)
    {
      newValue = [self directParameter];
    }
  
  if (newValue == nil)
    {
      [self setScriptErrorNumber: -1728];
      [self setScriptErrorString: @"Set command requires value"];
      return nil;
    }
  
  containerSpec = [receiversSpec containerSpecifier];
  if (containerSpec != nil)
    {
      container = [containerSpec objectsByEvaluatingSpecifier];
      key = [receiversSpec key];
      
      if (container != nil && key != nil)
        {
          [container setValue: newValue forKey: key];
          return newValue;
        }
    }
  
  receivers = [receiversSpec objectsByEvaluatingSpecifier];
  if (receivers != nil)
    {
      key = [receiversSpec key];
      if (key != nil)
        {
          [receivers setValue: newValue forKey: key];
          return newValue;
        }
    }
  
  [self setScriptErrorNumber: -1751];
  [self setScriptErrorString: @"Could not set value"];
  return nil;
}

- (void) dealloc
{
  RELEASE(_keySpecifier);
  [super dealloc];
}

@end

