/* Definition of class NSPersonNameComponents
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   Implemented by: Gregory Casamento <greg.casamento@gmail.com>
   Date: Sep 2019

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#import "Foundation/NSPersonNameComponentsFormatter.h"
#import "Foundation/NSString.h"
#import "Foundation/NSPersonNameComponents.h"

@implementation NSPersonNameComponentsFormatter

// Designated init...
+ (NSString *) localizedStringFromPersonNameComponents: (NSPersonNameComponents *)components
                                                 style: (NSPersonNameComponentsFormatterStyle)nameFormatStyle
                                               options: (NSPersonNameComponentsFormatterOptions)nameOptions
{
  return nil;
}

// Setters
- (NSPersonNameComponentsFormatterStyle) style
{
  return 0;
}

- (void) setStyle: (NSPersonNameComponentsFormatterStyle)style
{
}

- (BOOL) isPhonetic
{
  return NO;
}

- (void) setPhonetic: (BOOL)flag
{
}

// Convenience methods...
- (NSString *) stringFromPersonNameComponents: (NSPersonNameComponents *)components
{
  return nil;
}

- (NSAttributedString *) annotatedStringFromPersonNameComponents: (NSPersonNameComponents *)components
{
  return nil;
}

- (NSPersonNameComponents *) personNameComponentsFromString: (NSString *)string
{
  return nil;
}

- (BOOL)getObjectValue: (id *)obj
             forString: (NSString *)string
      errorDescription: (NSString **)error
{
  return NO;
}

@end

// components for attributed strings;
NSString * const NSPersonNameComponentKey = @"NSPersonNameComponentKey";
NSString * const NSPersonNameComponentGivenName = @"NSPersonNameComponentGivenName";
NSString * const NSPersonNameComponentFamilyName = @"NSPersonNameComponentFamilyName";
NSString * const NSPersonNameComponentMiddleName = @"NSPersonNameComponentMiddleName";
NSString * const NSPersonNameComponentPrefix = @"NSPersonNameComponentPrefix";
NSString * const NSPersonNameComponentSuffix = @"NSPersonNameComponentSuffix";
NSString * const NSPersonNameComponentNickname = @"NSPersonNameComponentNickname";
NSString * const NSPersonNameComponentDelimiter = @"NSPersonNameComponentDelimiter";
