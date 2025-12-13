/** Implementation of class NSScriptClassDescription
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
#import "Foundation/NSScriptClassDescription.h"
#import "Foundation/NSScriptCommandDescription.h"
#import "Foundation/NSString.h"

@implementation NSScriptClassDescription
{
  Class _implementationClass;
  NSString *_className;
  NSString *_suiteName;
  NSString *_superclassName;
  NSScriptClassDescription *_superclassDescription;
  FourCharCode _appleEventCode;
}

+ (NSScriptClassDescription *) classDescriptionForClass: (Class)aClass
{
  return (NSScriptClassDescription *)[super classDescriptionForClass: aClass];
}

- (id) initWithSuiteName: (NSString *)suiteName
               className: (NSString *)className
          appleEventCode: (FourCharCode)appleEventCode
              superclass: (NSScriptClassDescription *)superclassDesc
{
  if ((self = [super init]))
    {
      ASSIGN(_suiteName, suiteName);
      ASSIGN(_className, className);
      _appleEventCode = appleEventCode;
      if (superclassDesc != nil)
        {
          ASSIGN(_superclassDescription, superclassDesc);
          ASSIGN(_superclassName, [superclassDesc className]);
        }
    }
  return self;
}

- (id) initWithSuiteName: (NSString *)suiteName
               className: (NSString *)className
          appleEventCode: (FourCharCode)appleEventCode
{
  return [self initWithSuiteName: suiteName
                       className: className
                  appleEventCode: appleEventCode
                      superclass: nil];
}

- (void) dealloc
{
  RELEASE(_className);
  RELEASE(_suiteName);
  RELEASE(_superclassDescription);
  RELEASE(_superclassName);
  [super dealloc];
}

- (FourCharCode) appleEventCode
{
  return _appleEventCode;
}

- (NSString *) className
{
  return _className;
}

- (NSScriptCommandDescription *) commandDescriptionWithAppleEventClass: (FourCharCode)appleEventClassCode
                                                    andAppleEventCode: (FourCharCode)appleEventIDCode
{
  return nil;
}

- (Class) implementationClass
{
  if (_implementationClass == Nil && _className != nil)
    {
      _implementationClass = NSClassFromString(_className);
    }
  return _implementationClass;
}

- (BOOL) isLocationRequiredToCreateForKey: (NSString *)toManyRelationshipKey
{
  return NO;
}

- (NSString *) suiteName
{
  return _suiteName;
}

- (NSScriptClassDescription *) superclassDescription
{
  Class superclass;
  /* If we have a direct reference, return it */
  if (_superclassDescription != nil)
    {
      return _superclassDescription;
    }
  
  /* Otherwise try to look it up by name */
  
  if (_superclassName != nil)
    {
      superclass = NSClassFromString(_superclassName);
      if (superclass != Nil)
        {
          return (NSScriptClassDescription *)[NSScriptClassDescription classDescriptionForClass: superclass];
        }
    }
  return nil;
}

- (BOOL) supportsCommand: (NSScriptCommandDescription *)commandDef
{
  return NO;
}

- (NSString *) typeForKey: (NSString *)key
{
  return nil;
}

@end

