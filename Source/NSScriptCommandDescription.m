
/* Implementation of class NSScriptCommandDescription
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
#import "Foundation/NSScriptCommandDescription.h"
#import "Foundation/NSString.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSValue.h"

@implementation NSScriptCommandDescription
{
  NSString *_suiteName;
  NSString *_commandName;
  NSString *_commandClassName;
  FourCharCode _appleEventCode;
  FourCharCode _appleEventClassCode;
  NSString *_returnType;
  FourCharCode _returnAppleEventCode;
  NSMutableDictionary *_arguments;
}

- (id) initWithSuiteName: (NSString *)suiteName
             commandName: (NSString *)commandName
          appleEventCode: (FourCharCode)appleEventCode
      appleEventClassCode: (FourCharCode)appleEventClassCode
{
  if ((self = [super init]))
    {
      ASSIGN(_suiteName, suiteName);
      ASSIGN(_commandName, commandName);
      _appleEventCode = appleEventCode;
      _appleEventClassCode = appleEventClassCode;
      _arguments = [[NSMutableDictionary alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_suiteName);
  RELEASE(_commandName);
  RELEASE(_commandClassName);
  RELEASE(_returnType);
  RELEASE(_arguments);
  [super dealloc];
}

- (FourCharCode) appleEventCode
{
  return _appleEventCode;
}

- (FourCharCode) appleEventClassCode
{
  return _appleEventClassCode;
}

- (NSString *) commandName
{
  return _commandName;
}

- (NSString *) commandClassName
{
  return _commandClassName;
}

- (NSString *) suiteName
{
  return _suiteName;
}

- (NSString *) returnType
{
  return _returnType;
}

- (FourCharCode) returnAppleEventCode
{
  return _returnAppleEventCode;
}

- (NSArray *) argumentNames
{
  return [_arguments allKeys];
}

- (NSString *) typeForArgumentWithName: (NSString *)argumentName
{
  NSDictionary *argInfo;
  
  argInfo = [_arguments objectForKey: argumentName];
  if (argInfo != nil)
    {
      return [argInfo objectForKey: @"type"];
    }
  return nil;
}

- (FourCharCode) appleEventCodeForArgumentWithName: (NSString *)argumentName
{
  NSDictionary *argInfo;
  NSNumber *codeNum;
  
  argInfo = [_arguments objectForKey: argumentName];
  if (argInfo != nil)
    {
      codeNum = [argInfo objectForKey: @"code"];
      if (codeNum != nil)
        {
          return [codeNum unsignedIntValue];
        }
    }
  return 0;
}

- (BOOL) isOptionalArgumentWithName: (NSString *)argumentName
{
  NSDictionary *argInfo;
  NSNumber *optional;
  
  argInfo = [_arguments objectForKey: argumentName];
  if (argInfo != nil)
    {
      optional = [argInfo objectForKey: @"optional"];
      if (optional != nil)
        {
          return [optional boolValue];
        }
    }
  return NO;
}

@end

