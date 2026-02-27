
/* Implementation of class NSScriptKeyValueCoding
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
#import "Foundation/NSScriptKeyValueCoding.h"
#import "Foundation/NSString.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSException.h"
#import "Foundation/NSValue.h"

@implementation NSObject (NSScriptKeyValueCoding)

- (id) valueAtIndex: (NSUInteger)index inPropertyWithKey: (NSString *)key
{
  id collection;
  
  collection = [self valueForKey: key];
  
  if ([collection respondsToSelector: @selector(objectAtIndex:)])
    {
      if (index < [collection count])
        {
          return [collection objectAtIndex: index];
        }
    }
  
  return nil;
}

- (id) valueWithName: (NSString *)name inPropertyWithKey: (NSString *)key
{
  NSArray *collection;
  NSEnumerator *enumerator;
  id object;
  
  collection = [self valueForKey: key];
  
  if ([collection respondsToSelector: @selector(objectEnumerator)])
    {
      enumerator = [collection objectEnumerator];
      while ((object = [enumerator nextObject]) != nil)
        {
          id objectName;
          
          if ([object respondsToSelector: @selector(name)])
            {
              objectName = [object performSelector: @selector(name)];
              if ([objectName isEqual: name])
                {
                  return object;
                }
            }
        }
    }
  
  return nil;
}

- (id) valueWithUniqueID: (id)uniqueID inPropertyWithKey: (NSString *)key
{
  NSArray *collection;
  NSEnumerator *enumerator;
  id object;
  
  collection = [self valueForKey: key];
  
  if ([collection respondsToSelector: @selector(objectEnumerator)])
    {
      enumerator = [collection objectEnumerator];
      while ((object = [enumerator nextObject]) != nil)
        {
          id objectID;
          
          if ([object respondsToSelector: @selector(uniqueID)])
            {
              objectID = [object performSelector: @selector(uniqueID)];
              if ([objectID isEqual: uniqueID])
                {
                  return object;
                }
            }
        }
    }
  
  return nil;
}

- (void) insertValue: (id)value atIndex: (NSUInteger)index inPropertyWithKey: (NSString *)key
{
  NSMutableArray *array;
  
  array = [self mutableArrayValueForKey: key];
  [array insertObject: value atIndex: index];
}

- (void) insertValue: (id)value inPropertyWithKey: (NSString *)key
{
  NSMutableArray *array;
  
  array = [self mutableArrayValueForKey: key];
  [array addObject: value];
}

- (id) coerceValue: (id)value forKey: (NSString *)key
{
  return value;
}

- (void) removeValueAtIndex: (NSUInteger)index fromPropertyWithKey: (NSString *)key
{
  NSMutableArray *array;
  
  array = [self mutableArrayValueForKey: key];
  if (index < [array count])
    {
      [array removeObjectAtIndex: index];
    }
}

- (void) replaceValueAtIndex: (NSUInteger)index 
          inPropertyWithKey: (NSString *)key
                  withValue: (id)value
{
  NSMutableArray *array;
  
  array = [self mutableArrayValueForKey: key];
  if (index < [array count])
    {
      [array replaceObjectAtIndex: index withObject: value];
    }
}

@end
