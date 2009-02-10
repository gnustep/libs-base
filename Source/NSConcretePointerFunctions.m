/**Implementation for NSConcretePointerFunctions for GNUStep
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

#import	"NSConcretePointerFunctions.h"

static void*
acquireMallocMemory(const void *item,
  NSUInteger (*size)(const void *item), BOOL shouldCopy)
{
  if (shouldCopy == YES)
    {
      NSUInteger	len = (*size)(item);
      void		*newItem = objc_malloc(len);

      memcpy(newItem, item, len);
      item = newItem;
    }
  return (void*)item;
}

static void*
acquireRetainedObject(const void *item,
  NSUInteger (*size)(const void *item), BOOL shouldCopy)
{
  if (shouldCopy == YES)
    {
      return [(NSObject*)item copy];
    }
  return [(NSObject*)item retain];
}

static void*
acquireExistingMemory(const void *item,
  NSUInteger (*size)(const void *item), BOOL shouldCopy)
{
  return (void*)item;
}

static NSUInteger
hashDirect(const void *item, NSUInteger (*size)(const void *item))
{
  return (NSUInteger)item;
}

static NSUInteger
hashObject(const void *item, NSUInteger (*size)(const void *item))
{
  return [(NSObject*)item hash];
}

static NSUInteger
hashMemory(const void *item, NSUInteger (*size)(const void *item))
{
  unsigned	len = (*size)(item);
  NSUInteger	hash = 0;

  while (len-- > 0)
    {
      hash = (hash << 5) + hash + *(const uint8_t*)item++;
    }
  return hash;
}

static NSUInteger
hashShifted(const void *item, NSUInteger (*size)(const void *item))
{
  return ((NSUInteger)item) >> 2;
}

static NSUInteger
hashString(const void *item, NSUInteger (*size)(const void *item))
{
  NSUInteger	hash = 0;

  while (*(const uint8_t*)item != 0)
    {
      hash = (hash << 5) + hash + *(const uint8_t*)item++;
    }
  return hash;
}

static void
relinquishMallocMemory(const void *item,
  NSUInteger (*size)(const void *item))
{
  objc_free((void*)item);
}

static void
relinquishRetainedMemory(const void *item,
  NSUInteger (*size)(const void *item))
{
#if	!GS_WITH_GC
  [(NSObject*)item release];
#endif
}

static void
relinquishZeroingWeakMemory(const void *item,
  NSUInteger (*size)(const void *item))
{
#if	GS_WITH_GC
  GSAssignZeroingWeakPointer((void**)&item, 0);
#endif
}

@implementation NSConcretePointerFunctions

+ (id) allocWithZone: (NSZone*)zone
{
  return (id) NSAllocateObject(self, 0, zone);
}

- (id) copyWithZone: (NSZone*)zone
{
  return NSCopyObject(self, 0, zone);
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
{
  _options = options;

  /* First we look at the memory management options to see which function
   * should be used to relinquish contents of a container with these
   * options.
   */
  _usesWeakReadAndWriteBarriers = YES;
  if (options & NSPointerFunctionsZeroingWeakMemory)
    {
      _relinquishFunction = relinquishZeroingWeakMemory;
    }
  else if (options & NSPointerFunctionsOpaqueMemory)
    {
      _relinquishFunction = 0;
    }
  else if (options & NSPointerFunctionsMallocMemory)
    {
      _relinquishFunction = relinquishMallocMemory;
    }
  else if (options & NSPointerFunctionsMachVirtualMemory)
    {
      _relinquishFunction = relinquishMallocMemory;
    }
  else
    {
      /* Only retained pointers need the array memory to be scanned,
       * so for these we set the usesStrongWriteBarrier flag to tell
       * containers to allocate scanned memory.
       */
      _usesStrongWriteBarrier = YES;
      _usesWeakReadAndWriteBarriers = NO;
      _relinquishFunction = relinquishRetainedMemory;
    }

  if (options & NSPointerFunctionsCopyIn)
    {
      _shouldCopyIn = YES;
    }

  /* Now we look at the personality options to determine other functions.
   */
  if (options & NSPointerFunctionsOpaquePersonality)
    {
      _acquireFunction = acquireExistingMemory;
      _hashFunction = hashShifted;
    }
  else if (options & NSPointerFunctionsObjectPointerPersonality)
    {
      _acquireFunction = acquireRetainedObject;
      _hashFunction = hashShifted;
    }
  else if (options & NSPointerFunctionsCStringPersonality)
    {
      _acquireFunction = acquireMallocMemory;
      _hashFunction = hashString;
    }
  else if (options & NSPointerFunctionsStructPersonality)
    {
      _acquireFunction = acquireMallocMemory;
      _hashFunction = hashMemory;
    }
  else if (options & NSPointerFunctionsIntegerPersonality)
    {
      _acquireFunction = acquireExistingMemory;
      _hashFunction = hashDirect;
    }
  else		/* objects */
    {
      _acquireFunction = acquireRetainedObject;
      _hashFunction = hashObject;
    }

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

