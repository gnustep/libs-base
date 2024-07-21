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
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.

   */ 

#import "common.h"
#import	"Foundation/NSException.h"
#import	"NSConcretePointerFunctions.h"

static void*
acquireMallocMemory(const void *item,
  NSUInteger (*size)(const void *item), BOOL shouldCopy)
{
  if (shouldCopy == YES)
    {
      NSUInteger	len = (*size)(item);
      void		*newItem = malloc(len);

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

static NSString*
describeString(const void *item)
{
  return [NSString stringWithFormat: @"%s", (char*)item];
}

static NSString*
describeInteger(const void *item)
{
  return [NSString stringWithFormat: @"%"PRIdPTR, (intptr_t)item];
}

static NSString*
describeObject(const void *item)
{
  return [(NSObject*)item description];
}

static NSString*
describePointer(const void *item)
{
  return [NSString stringWithFormat: @"%p", item];
}

static BOOL
equalDirect(const void *item1, const void *item2,
  NSUInteger (*size)(const void *item))
{
  return (item1 == item2) ? YES : NO;
}

static BOOL
equalObject(const void *item1, const void *item2,
  NSUInteger (*size)(const void *item))
{
  return [(NSObject*)item1 isEqual: (NSObject*)item2];
}

static BOOL
equalMemory(const void *item1, const void *item2,
  NSUInteger (*size)(const void *item))
{
  NSUInteger	s1 = (*size)(item1);
  NSUInteger	s2 = (*size)(item2);

  return (s1 == s2 && memcmp(item1, item2, s1) == 0) ? YES : NO;
}

static BOOL
equalString(const void *item1, const void *item2,
  NSUInteger (*size)(const void *item))
{
  return (strcmp((const char*)item1, (const char*)item2) == 0) ? YES : NO;
}

static NSUInteger
hashDirect(const void *item, NSUInteger (*size)(const void *item))
{
  return (NSUInteger)(uintptr_t)item;
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
  return ((NSUInteger)(uintptr_t)item) >> 2;
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
  free((void*)item);
}

static void
relinquishRetainedMemory(const void *item,
  NSUInteger (*size)(const void *item))
{
  [(NSObject*)item release];
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
#define Unsupported(X)	({\
  NSLog(@"*** An unsupported PointerFunctions configuration was requested,"\
    @" probably for use by NSMapTable, NSHashTable, or NSPointerArray.  %@",\
    X);\
  DESTROY(self);\
})

  if (memoryType(options, NSPointerFunctionsZeroingWeakMemory))
    {
      /* Garbage Collection is no longer supported, so we treat all weak
       * memory the same way.
       */
      _x.options = (options & 0xffffff00) | NSPointerFunctionsWeakMemory;
    }
  else
    {
      _x.options = options;
    }

  /* First we look at the memory management options to see which function
   * should be used to relinquish contents of a container with these
   * options.
   */
  if (memoryType(options, NSPointerFunctionsWeakMemory)
    || memoryType(options, NSPointerFunctionsZeroingWeakMemory))
    {
      _x.relinquishFunction = 0;
    }
  else if (memoryType(options, NSPointerFunctionsOpaqueMemory))
    {
      _x.relinquishFunction = 0;
    }
  else if (memoryType(options, NSPointerFunctionsMallocMemory))
    {
      _x.relinquishFunction = relinquishMallocMemory;
    }
  else if (memoryType(options, NSPointerFunctionsMachVirtualMemory))
    {
      _x.relinquishFunction = relinquishMallocMemory;
    }
  else
    {
      /* NSPointerFunctionsStrongMemory uses -release for objects
       */
      if (personalityType(options, NSPointerFunctionsObjectPersonality)
	|| personalityType(options, NSPointerFunctionsObjectPointerPersonality))
	{
          _x.relinquishFunction = relinquishRetainedMemory;
	}
      else
	{
	  _x.relinquishFunction = 0;
	}
    }

  /* Now we look at the personality options to determine other functions.
   */
  if (personalityType(options, NSPointerFunctionsOpaquePersonality))
    {
      _x.acquireFunction = 0;
      _x.descriptionFunction = describePointer;
      _x.hashFunction = hashShifted;
      _x.isEqualFunction = equalDirect;
    }
  else if (personalityType(options, NSPointerFunctionsObjectPointerPersonality))
    {
      if (memoryType(options, NSPointerFunctionsWeakMemory)
        || memoryType(options, NSPointerFunctionsZeroingWeakMemory))
	{
	  _x.acquireFunction = 0;
	}
      else
	{
	  _x.acquireFunction = acquireRetainedObject;
	}
      _x.descriptionFunction = describeObject;
      _x.hashFunction = hashShifted;
      _x.isEqualFunction = equalDirect;
    }
  else if (personalityType(options, NSPointerFunctionsCStringPersonality))
    {
      if (memoryType(options, NSPointerFunctionsMallocMemory))
	{
	  _x.acquireFunction = acquireMallocMemory;
	}
      else
	{
	  _x.acquireFunction = NULL;
	}
      _x.descriptionFunction = describeString;
      _x.hashFunction = hashString;
      _x.isEqualFunction = equalString;
    }
  else if (personalityType(options, NSPointerFunctionsStructPersonality))
    {
      _x.acquireFunction = acquireMallocMemory;
      _x.descriptionFunction = describePointer;
      _x.hashFunction = hashMemory;
      _x.isEqualFunction = equalMemory;
    }
  else if (personalityType(options, NSPointerFunctionsIntegerPersonality))
    {
      if (memoryType(options, NSPointerFunctionsOpaqueMemory))
	{
	  _x.acquireFunction = 0;
	  _x.descriptionFunction = describeInteger;
	  _x.hashFunction = hashDirect;
	  _x.isEqualFunction = equalDirect;
	}
      else
	{
	  Unsupported(@"The requested configuration fails due to"
	    @" integer personality not using opaque memory.");
	}
    }
  else		/* objects */
    {
      if (memoryType(options, NSPointerFunctionsWeakMemory)
        || memoryType(options, NSPointerFunctionsZeroingWeakMemory))
	{
	  _x.acquireFunction = 0;
	}
      else
	{
          _x.acquireFunction = acquireRetainedObject;
	}
      _x.descriptionFunction = describeObject;
      _x.hashFunction = hashObject;
      _x.isEqualFunction = equalObject;
    }

  return self;
}

- (void* (*)(const void *item,
  NSUInteger (*size)(const void *item), BOOL shouldCopy)) acquireFunction
{
  return _x.acquireFunction;
}

- (NSString *(*)(const void *item)) descriptionFunction
{
  return _x.descriptionFunction;
}

- (NSUInteger (*)(const void *item,
  NSUInteger (*size)(const void *item))) hashFunction
{
  return _x.hashFunction;
}

- (BOOL (*)(const void *item1, const void *item2,
  NSUInteger (*size)(const void *item))) isEqualFunction
{
  return _x.isEqualFunction;
}

- (void (*)(const void *item,
  NSUInteger (*size)(const void *item))) relinquishFunction
{
  return _x.relinquishFunction;
}

- (void) setAcquireFunction: (void* (*)(const void *item,
  NSUInteger (*size)(const void *item), BOOL shouldCopy))func
{
  _x.acquireFunction = func;
}

- (void) setDescriptionFunction: (NSString *(*)(const void *item))func
{
  _x.descriptionFunction = func;
}

- (void) setHashFunction: (NSUInteger (*)(const void *item,
  NSUInteger (*size)(const void *item)))func
{
  _x.hashFunction = func;
}

- (void) setIsEqualFunction: (BOOL (*)(const void *item1, const void *item2,
  NSUInteger (*size)(const void *item)))func
{
  _x.isEqualFunction = func;
}

- (void) setRelinquishFunction: (void (*)(const void *item,
  NSUInteger (*size)(const void *item))) func
{
  _x.relinquishFunction = func;
}

- (void) setSizeFunction: (NSUInteger (*)(const void *item))func
{
  _x.sizeFunction = func;
}

- (void) setUsesStrongWriteBarrier: (BOOL)flag
{
  [NSException raise: NSGenericException
	      format: @"Garbage collection no longer supported"];
}

- (void) setUsesWeakReadAndWriteBarriers: (BOOL)flag
{
  [NSException raise: NSGenericException
	      format: @"Garbage collection no longer supported"];
}

- (NSUInteger (*)(const void *item)) sizeFunction
{
  return _x.sizeFunction;
}

- (BOOL) usesStrongWriteBarrier
{
  NSLog(@"-usesStrongWriteBarrier does nothing:"
    @" garbage collection not supported");
  return NO;
}

- (BOOL) usesWeakReadAndWriteBarriers
{
  NSLog(@"-usesWeakReadAndWriteBarriers does nothing:"
    @" garbage collection not supported");
  return NO;
}

@end

