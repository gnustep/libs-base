/**Implementation for NSPointerFunctions for GNUStep
   Copyright (C) 2009 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	2009
   
   This file is part of the GNUstep Base Library.

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

#import	"Foundation/NSPointerFunctions.h"

typedef struct {
  NSUInteger	options;

  void* (*acquireFunction)(const void *item,
    NSUInteger (*size)(const void *item), BOOL shouldCopy);

  NSString *(*descriptionFunction)(const void *item);

  NSUInteger (*hashFunction)(const void *item,
    NSUInteger (*size)(const void *item));

  BOOL (*isEqualFunction)(const void *item1, const void *item2,
    NSUInteger (*size)(const void *item));

  void (*relinquishFunction)(const void *item,
    NSUInteger (*size)(const void *item));

  NSUInteger (*sizeFunction)(const void *item);

  BOOL usesStrongWriteBarrier;

  BOOL usesWeakReadAndWriteBarriers;
} _internal;

#define	_options		((_internal*)(self+1))->options
#define	_acquireFunction	((_internal*)(self+1))->acquireFunction
#define	_descriptionFunction	((_internal*)(self+1))->descriptionFunction
#define	_hashFunction		((_internal*)(self+1))->hashFunction
#define	_isEqualFunction	((_internal*)(self+1))->isEqualFunction
#define	_relinquishFunction	((_internal*)(self+1))->relinquishFunction
#define	_sizeFunction		((_internal*)(self+1))->sizeFunction
#define	_usesStrongWriteBarrier	((_internal*)(self+1))->usesStrongWriteBarrier
#define	_usesWeakReadAndWriteBarriers	((_internal*)(self+1))->usesWeakReadAndWriteBarriers


@implementation NSPointerFunctions

+ (id) allocWithZone: (NSZone*)zone
{
  return (id) NSAllocateObject(self, sizeof(_internal), zone);
}

+ (id) pointerFunctionsWithOptions: (NSPointerFunctionsOptions)options
{
  return AUTORELEASE([[self alloc] initWithOptions: options]);
}

- (id) copyWithZone: (NSZone*)zone
{
  return NSCopyObject(self, sizeof(_internal), zone);
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
{
  _options = options;
  return self;
}

- (void* (*)(const void *item,
  NSUInteger (*size)(const void *item), BOOL shouldCopy)) acquireFunction
{
  return _acquireFunction;
}

- (NSString *(*)(const void *item)) descriptionFunction
{
  return _descriptionFunction;
}

- (NSUInteger (*)(const void *item,
  NSUInteger (*size)(const void *item))) hashFunction
{
  return _hashFunction;
}

- (BOOL (*)(const void *item1, const void *item2,
  NSUInteger (*size)(const void *item))) isEqualFunction
{
  return _isEqualFunction;
}

- (void (*)(const void *item,
  NSUInteger (*size)(const void *item))) relinquishFunction
{
  return _relinquishFunction;
}

- (void) setAcquireFunction: (void* (*)(const void *item,
  NSUInteger (*size)(const void *item), BOOL shouldCopy))func
{
  _acquireFunction = func;
}

- (void) setDescriptionFunction: (NSString *(*)(const void *item))func
{
  _descriptionFunction = func;
}

- (void) setHashFunction: (NSUInteger (*)(const void *item,
  NSUInteger (*size)(const void *item)))func
{
  _hashFunction = func;
}

- (void) setIsEqualFunction: (BOOL (*)(const void *item1, const void *item2,
  NSUInteger (*size)(const void *item)))func
{
  _isEqualFunction = func;
}

- (void) setRelinquishFunction: (void (*)(const void *item,
  NSUInteger (*size)(const void *item))) func
{
  _relinquishFunction = func;
}

- (void) setSizeFunction: (NSUInteger (*)(const void *item))func
{
  _sizeFunction = func;
}

- (void) setUsesStrongWriteBarrier: (BOOL)flag
{
  _usesStrongWriteBarrier = flag;
}

- (void) setUsesWeakReadAndWriteBarriers: (BOOL)flag
{
  _usesWeakReadAndWriteBarriers = flag;
}

- (NSUInteger (*)(const void *item)) sizeFunction
{
  return _sizeFunction;
}

- (BOOL) usesStrongWriteBarrier
{
  return _usesStrongWriteBarrier;
}

- (BOOL) usesWeakReadAndWriteBarriers
{
  return _usesStrongWriteBarrier;
}

@end

