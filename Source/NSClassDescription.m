/** NSClassDescription 
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	2000

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSClassDescription class reference</title>
   $Date$ $Revision$
*/

#include <Foundation/NSClassDescription.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSNotification.h>


@implementation NSClassDescription

static NSRecursiveLock	*mapLock = nil;
static NSMapTable	*classMap;

+ (NSClassDescription*) classDescriptionForClass: (Class)aClass
{
  NSClassDescription	*description;

  [mapLock lock];
  description = NSMapGet(classMap, aClass);
  if (description == nil)
    {
      NSNotificationCenter	*nc;

      [mapLock unlock];
      nc = [NSNotificationCenter defaultCenter];
      [nc postNotificationName: NSClassDescriptionNeededForClassNotification
                        object: aClass];
      [mapLock lock];
      description = NSMapGet(classMap, aClass);
    }
  RETAIN(description);
  [mapLock unlock];
  
  return AUTORELEASE(description);
}

+ (void) initialize
{
  if (self == [NSClassDescription class])
    {
      classMap = NSCreateMapTable(NSObjectMapKeyCallBacks,
        NSObjectMapValueCallBacks, 100);
      mapLock = [NSRecursiveLock new];
    }
}

+ (void) invalidateClassDescriptionCache
{
  [mapLock lock];
  NSResetMapTable(classMap);
  [mapLock unlock];
}

+ (void) registerClassDescription: (NSClassDescription*)aDescription
			 forClass: (Class)aClass
{
  if (aDescription != nil && aClass != 0)
    {
      [mapLock lock];
      NSMapInsert(classMap, aClass, aDescription);
      [mapLock unlock];
    }
}

- (NSArray*) attributeKeys
{
  return nil;
}

- (NSString*) inverseForRelationshipKey: (NSString*)aKey
{
  return nil;
}

- (NSArray*) toManyRelationshipKeys
{
  return nil;
}

- (NSArray*) toOneRelationshipKeys
{
  return nil;
}

@end



@implementation NSObject(ClassDescriptionForwards)

static Class	NSClassDescriptionClass = 0;

- (NSArray*) attributeKeys
{
  return [[self classDescription] attributeKeys];
}

- (NSClassDescription*) classDescription
{
  if (NSClassDescriptionClass == 0)
    {
      NSClassDescriptionClass = [NSClassDescription class];
    } 
  return [NSClassDescriptionClass classDescriptionForClass: [self class]];
}

- (NSString*) inverseForRelationshipKey: (NSString*)aKey
{
  return [[self classDescription] inverseForRelationshipKey: aKey];
}

- (NSArray*) toManyRelationshipKeys
{
  return [[self classDescription] toManyRelationshipKeys];
}

- (NSArray*) toOneRelationshipKeys
{
  return [[self classDescription] toOneRelationshipKeys];
}

@end

