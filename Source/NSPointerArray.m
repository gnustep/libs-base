/**Implementation for NSPointerArray for GNUStep
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

#import "config.h"
#import "GNUstepBase/preface.h"
#import	"Foundation/NSPointerArray.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSDebug.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSKeyedArchiver.h"

#import "GSPrivate.h"
#import "NSConcretePointerFunctions.h"

@class	NSConcretePointerArray;

static Class	abstractClass = Nil;
static Class	concreteClass = Nil;


@implementation NSPointerArray

+ (id) allocWithZone: (NSZone*)z
{
  if (abstractClass == self)
    {
      return NSAllocateObject(concreteClass, 0, z);
    }
  return [super allocWithZone: z];
}

+ (void) initialize
{
  if (abstractClass == Nil)
    {
      abstractClass = [NSPointerArray class];
      concreteClass = [NSConcretePointerArray class];
    }
}

+ (id) pointerArrayWithOptions: (NSPointerFunctionsOptions)options
{
  return AUTORELEASE([[self alloc] initWithOptions: options]);
}

+ (id) pointerArrayWithPointerFunctions: (NSPointerFunctions *)functions
{
  return AUTORELEASE([[self alloc] initWithPointerFunctions: functions]);
}

- (void) compact
{
  [self subclassResponsibility: _cmd];
}

- (id) copyWithZone: (NSZone*)zone
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSUInteger) count
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
}

- (id) init
{
  return [self initWithOptions: 0];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
{
  NSPointerFunctions	*functions;

  functions = [NSPointerFunctions pointerFunctionsWithOptions: options];
  return [self initWithPointerFunctions: functions];
}

- (id) initWithPointerFunctions: (NSPointerFunctions*)functions
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) isEqual: (id)other
{
  NSUInteger	count;

  if (other == self)
    {
      return YES;
    }
  if ([other isKindOfClass: abstractClass] == NO)
    {
      return NO;
    }
  if ([other hash] != [self hash])
    {
      return NO;
    }
  count = [self count];
  while (count-- > 0)
    {
// FIXME
    }
  return YES;
}

- (void) addPointer: (void*)pointer
{
  [self insertPointer: pointer atIndex: [self count]];
}

- (void) insertPointer: (void*)pointer atIndex: (NSUInteger)index
{
  [self subclassResponsibility: _cmd];
}

- (void*) pointerAtIndex: (NSUInteger)index
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSPointerFunctions*) pointerFunctions
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) removePointerAtIndex: (NSUInteger)index
{
  [self subclassResponsibility: _cmd];
}

- (void) replacePointerAtIndex: (NSUInteger)index withPointer: (void*)item
{
  [self subclassResponsibility: _cmd];
}

- (void) setCount: (NSUInteger)count
{
  [self subclassResponsibility: _cmd];
}

@end

@implementation NSPointerArray (NSArrayConveniences)  

+ (id) pointerArrayWithStrongObjects
{
  return [self pointerArrayWithOptions: NSPointerFunctionsStrongMemory];
}

+ (id) pointerArrayWithWeakObjects
{
  return [self pointerArrayWithOptions: NSPointerFunctionsZeroingWeakMemory];
}

- (NSArray*) allObjects
{
  [self subclassResponsibility: _cmd];
  return nil;
}

@end

@interface	NSConcretePointerArray : NSPointerArray
{
  NSUInteger		_count;
  void			**_contents_array;
  unsigned		_capacity;
  unsigned		_grow_factor;
  NSConcretePointerFunctions	*_functions;
}
@end

@implementation NSConcretePointerArray

- (void) _raiseRangeExceptionWithIndex: (NSUInteger)index from: (SEL)sel
{
  NSDictionary *info;
  NSException  *exception;
  NSString     *reason;

  info = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithUnsignedInt: index], @"Index",
    [NSNumber numberWithUnsignedInt: _count], @"Count",
    self, @"Array", nil, nil];

  reason = [NSString stringWithFormat:
    @"Index %d is out of range %d (in '%@')",
    index, _count, NSStringFromSelector(sel)];

  exception = [NSException exceptionWithName: NSRangeException
		                      reason: reason
                                    userInfo: info];
  [exception raise];
}

- (id) copyWithZone: (NSZone*)zone
{
  return RETAIN(self);	// FIXME
}

- (unsigned) count
{
  return _count;
}

- (void) dealloc
{
  [self finalize];
  if (_contents_array != 0)
    {
      NSZoneFree([self zone], _contents_array);
    }
  [_functions release];
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      [super encodeWithCoder: aCoder];
    }
  else
    {
      /* For performace we encode directly ... must exactly match the
       * superclass implemenation. */
      [aCoder encodeValueOfObjCType: @encode(unsigned)
				 at: &_count];
      if (_count > 0)
	{
	  [aCoder encodeArrayOfObjCType: @encode(id)
				  count: _count
				     at: _contents_array];
	}
    }
}

- (unsigned) hash
{
  return _count;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      self = [super initWithCoder: aCoder];
    }
  else
    {
      /* for performance, we decode directly into memory rather than
       * using the superclass method. Must exactly match superclass. */
      [aCoder decodeValueOfObjCType: @encode(unsigned)
				 at: &_count];
      if (_count > 0)
	{
#if	GS_WITH_GC
          _contents_array = NSAllocateCollectable(sizeof(id) * _count,
	    NSScannedOption);
#else
	  _contents_array = NSZoneCalloc([self zone], _count, sizeof(id));
#endif
	  if (_contents_array == 0)
	    {
	      [NSException raise: NSMallocException
			  format: @"Unable to make array"];
	    }
	  [aCoder decodeArrayOfObjCType: @encode(id)
				  count: _count
				     at: _contents_array];
	}
    }
  return self;
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
{
  _functions = [[NSConcretePointerFunctions alloc] initWithOptions: options];
  return self;
}

- (id) initWithPointerFunctions: (NSPointerFunctions*)functions
{
  if ([functions class] == [NSConcretePointerFunctions class])
    {
      _functions = [functions copy];
    }
  else
    {
      _functions = [NSConcretePointerFunctions new];
      [_functions setAcquireFunction: [functions acquireFunction]];
      [_functions setDescriptionFunction: [functions descriptionFunction]];
      [_functions setHashFunction: [functions hashFunction]];
      [_functions setIsEqualFunction: [functions isEqualFunction]];
      [_functions setRelinquishFunction: [functions relinquishFunction]];
      [_functions setSizeFunction: [functions sizeFunction]];
      [_functions setUsesStrongWriteBarrier:
	[functions usesStrongWriteBarrier]];
      [_functions setUsesWeakReadAndWriteBarriers:
	[functions usesWeakReadAndWriteBarriers]];
    }
  return self;
}

- (void) insertPointer: (void*)pointer atIndex: (NSUInteger)index
{
  if (index > _count)
    {
      [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
  if (_count >= _capacity)
    {
      void	**ptr;
      size_t	size = (_capacity + _grow_factor)*sizeof(void*);

      ptr = (void**)NSZoneRealloc([self zone], _contents_array, size);
      if (ptr == 0)
	{
	  [NSException raise: NSMallocException
		      format: @"Unable to grow array"];
	}
      _contents_array = ptr;
      _capacity += _grow_factor;
      _grow_factor = _capacity/2;
    }
// FIXME ... retain/copy in
  _contents_array[_count] = pointer;
  _count++;
}

@end

