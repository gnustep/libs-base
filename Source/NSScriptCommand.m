
/* Implementation of class NSScriptCommand
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
#import "Foundation/NSScriptCommand.h"
#import "Foundation/NSScriptCommandDescription.h"
#import "Foundation/NSScriptObjectSpecifier.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSString.h"
#import "Foundation/NSAppleEventDescriptor.h"
#import "Foundation/NSCoder.h"

@implementation NSScriptCommand

- (id) initWithCommandDescription: (NSScriptCommandDescription *)commandDef
{
  if ((self = [super init]))
    {
      ASSIGN(_commandDescription, commandDef);
      _arguments = [[NSMutableDictionary alloc] init];
      _isSuspended = NO;
    }
  return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
  if ((self = [super init]))
    {
      _commandDescription = RETAIN([coder decodeObjectForKey: @"commandDescription"]);
      _arguments = RETAIN([coder decodeObjectForKey: @"arguments"]);
      _directParameter = RETAIN([coder decodeObjectForKey: @"directParameter"]);
      _receiversSpecifier = RETAIN([coder decodeObjectForKey: @"receiversSpecifier"]);
      _isSuspended = NO;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_commandDescription);
  RELEASE(_arguments);
  RELEASE(_evaluatedArguments);
  RELEASE(_directParameter);
  RELEASE(_receiversSpecifier);
  RELEASE(_evaluatedReceivers);
  RELEASE(_appleEvent);
  RELEASE(_errorString);
  [super dealloc];
}

- (NSScriptCommandDescription *) commandDescription
{
  return _commandDescription;
}

- (NSDictionary *) arguments
{
  return _arguments;
}

- (void) setArguments: (NSDictionary *)args
{
  ASSIGN(_arguments, args);
  DESTROY(_evaluatedArguments);
}

- (NSDictionary *) evaluatedArguments
{
  NSEnumerator *keyEnum;
  NSString *key;
  id value;
  NSMutableDictionary *evaluated;
  
  if (_evaluatedArguments != nil)
    return _evaluatedArguments;
    
  if (_arguments == nil)
    return nil;
  
  evaluated = [NSMutableDictionary dictionaryWithCapacity: [_arguments count]];
  keyEnum = [_arguments keyEnumerator];
  
  while ((key = [keyEnum nextObject]) != nil)
    {
      value = [_arguments objectForKey: key];
      
      if ([value isKindOfClass: [NSScriptObjectSpecifier class]])
        {
          value = [(NSScriptObjectSpecifier *)value objectsByEvaluatingSpecifier];
        }
      
      if (value != nil)
        {
          [evaluated setObject: value forKey: key];
        }
    }
  
  _evaluatedArguments = [evaluated copy];
  return _evaluatedArguments;
}

- (NSScriptObjectSpecifier *) directParameter
{
  return _directParameter;
}

- (void) setDirectParameter: (NSScriptObjectSpecifier *)directParameter
{
  ASSIGN(_directParameter, directParameter);
}

- (id) evaluatedReceivers
{
  if (_evaluatedReceivers == nil && _receiversSpecifier != nil)
    {
      _evaluatedReceivers = RETAIN([_receiversSpecifier objectsByEvaluatingSpecifier]);
    }
  return _evaluatedReceivers;
}

- (BOOL) isWellFormed
{
  return _commandDescription != nil;
}

- (id) performDefaultImplementation
{
  return nil;
}

- (id) executeCommand
{
  id result;
  
  if (![self isWellFormed])
    {
      return nil;
    }
  
  result = [self performDefaultImplementation];
  
  return result;
}

- (void) suspendExecution
{
  _isSuspended = YES;
}

- (void) resumeExecutionWithResult: (id)result
{
  _isSuspended = NO;
}

- (NSScriptObjectSpecifier *) receiversSpecifier
{
  return _receiversSpecifier;
}

- (void) setReceiversSpecifier: (NSScriptObjectSpecifier *)receiversRef
{
  ASSIGN(_receiversSpecifier, receiversRef);
  DESTROY(_evaluatedReceivers);
}

- (id) currentCommand
{
  return self;
}

- (NSAppleEventDescriptor *) appleEvent
{
  return _appleEvent;
}

- (void) setScriptErrorNumber: (NSInteger)errorNumber
{
  _errorNumber = errorNumber;
}

- (void) setScriptErrorString: (NSString *)errorString
{
  ASSIGN(_errorString, errorString);
}

- (NSInteger) scriptErrorNumber
{
  return _errorNumber;
}

- (NSString *) scriptErrorString
{
  return _errorString;
}

@end

