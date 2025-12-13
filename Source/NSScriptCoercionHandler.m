
/* Implementation of class NSScriptCoercionHandler
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
#import "Foundation/NSScriptCoercionHandler.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSLock.h"

@implementation NSScriptCoercionHandler

static NSScriptCoercionHandler *sharedHandler = nil;

+ (void) initialize
{
  if (self == [NSScriptCoercionHandler class])
    {
      sharedHandler = [[NSScriptCoercionHandler alloc] init];
    }
}

+ (NSScriptCoercionHandler *) sharedCoercionHandler
{
  return sharedHandler;
}

- (id) init
{
  if ((self = [super init]))
    {
      _coercers = [[NSMutableDictionary alloc] init];
      _lock = [[NSLock alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_coercers);
  RELEASE(_lock);
  [super dealloc];
}

- (NSString *) _keyForFromClass: (Class)fromClass toClass: (Class)toClass
{
  return [NSString stringWithFormat: @"%@->%@", 
          NSStringFromClass(fromClass), 
          NSStringFromClass(toClass)];
}

- (id) coerceValue: (id)value toClass: (Class)toClass
{
  NSString *key;
  NSDictionary *coercerInfo;
  id coercer;
  SEL selector;
  id result;
  Class currentClass;
  
  if (value == nil)
    {
      return nil;
    }
    
  if ([value isKindOfClass: toClass])
    {
      return value;
    }
  
  [_lock lock];
  
  /* Try to find coercer for exact class first, then walk up the class hierarchy */
  coercerInfo = nil;
  currentClass = [value class];
  while (currentClass != Nil && coercerInfo == nil)
    {
      key = [self _keyForFromClass: currentClass toClass: toClass];
      coercerInfo = [_coercers objectForKey: key];
      currentClass = [currentClass superclass];
    }
  
  [_lock unlock];
  
  if (coercerInfo != nil)
    {
      coercer = [coercerInfo objectForKey: @"coercer"];
      selector = NSSelectorFromString([coercerInfo objectForKey: @"selector"]);
      
      if (coercer != nil && selector != NULL && [coercer respondsToSelector: selector])
        {
          result = [coercer performSelector: selector withObject: value];
          return result;
        }
    }
  
  return value;
}

- (void) registerCoercer: (id)coercer
                selector: (SEL)selector
      toConvertFromClass: (Class)fromClass
                 toClass: (Class)toClass
{
  NSString *key;
  NSDictionary *info;
  
  if (coercer == nil || selector == NULL || fromClass == Nil || toClass == Nil)
    return;
  
  [_lock lock];
  
  key = [self _keyForFromClass: fromClass toClass: toClass];
  info = [NSDictionary dictionaryWithObjectsAndKeys:
          coercer, @"coercer",
          NSStringFromSelector(selector), @"selector",
          nil];
  
  [_coercers setObject: info forKey: key];
  
  [_lock unlock];
}

@end

