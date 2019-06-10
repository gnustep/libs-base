
/** Interface for NSOrderedSet, NSMutableOrderedSet for GNUStep
   Copyright (C) 2019 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Created: May 17 2019

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
#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSOrderedSet.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPredicate.h"
#import "Foundation/NSLock.h"

#import <GNUstepBase/GSBlocks.h>
#import "Foundation/NSKeyedArchiver.h"
#import "GSPrivate.h"
#import "GSFastEnumeration.h"
#import "GSDispatch.h"
#import "GSSorting.h"

@class	GSOrderedSet;
@interface GSOrderedSet : NSObject	// Help the compiler
@end
@class	GSMutableOrderedSet;
@interface GSMutableOrderedSet : NSObject	// Help the compiler
@end

@implementation NSOrderedSet

static Class NSOrderedSet_abstract_class;
static Class NSMutableOrderedSet_abstract_class;
static Class NSOrderedSet_concrete_class;
static Class NSMutableOrderedSet_concrete_class;

static SEL	addSel;
static SEL	appSel;
static SEL	countSel;
static SEL	eqSel;
static SEL	oaiSel;
static SEL	remSel;
static SEL	rlSel;

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSOrderedSet_abstract_class)
    {
      return NSAllocateObject(NSOrderedSet_concrete_class, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

+ (void) initialize
{
  if (self == [NSOrderedSet class])
    {
      [self setVersion: 1];
      
      addSel = @selector(addObject:);
      appSel = @selector(appendString:);
      countSel = @selector(count);
      eqSel = @selector(isEqual:);
      oaiSel = @selector(objectAtIndex:);
      remSel = @selector(removeObjectAtIndex:);
      rlSel = @selector(removeLastObject);

      NSOrderedSet_abstract_class = self;
      NSOrderedSet_concrete_class = [GSOrderedSet class];
      [NSMutableSet class];
    }
}

- (Class) classForCoder
{
  return NSOrderedSet_abstract_class;
}

// NSCoding
- (instancetype) initWithCoder: (NSCoder *)coder
{
  /*
  Class		c;

  c = object_getClass(self);
  if (c == NSOrderedSet_abstract_class)
    {
      DESTROY(self);
      self = [NSOrderedSet_concrete_class allocWithZone: NSDefaultMallocZone()];
      return [self initWithCoder: coder];
    }
  else if (c == NSMutableOrderedSet_abstract_class)
    {
      DESTROY(self);
      self = [NSMutableOrderedSet_concrete_class allocWithZone: NSDefaultMallocZone()];
      return [self initWithCoder: coder];
    }
  */
  if ([coder allowsKeyedCoding])
    {
      id	array;

      array = [(NSKeyedUnarchiver*)coder _decodeArrayOfObjectsForKey:
						@"NS.objects"];
      if (array == nil)
	{
	  unsigned	i = 0;
	  NSString	*key;
	  id		val;

	  array = [NSMutableArray arrayWithCapacity: 2];
	  key = [NSString stringWithFormat: @"NS.object.%u", i];
	  val = [(NSKeyedUnarchiver*)coder decodeObjectForKey: key];

	  while (val != nil)
	    {
	      [array addObject: val];
	      i++;
	      key = [NSString stringWithFormat: @"NS.object.%u", i];
	      val = [(NSKeyedUnarchiver*)coder decodeObjectForKey: key];
	    }
	}
      self = [self initWithArray: array];
    }
  else
    {
      unsigned	count;

      [coder decodeValueOfObjCType: @encode(unsigned) at: &count];
      if (count > 0)
        {
	  unsigned	i;
	  GS_BEGINIDBUF(objs, count);

	  for (i = 0; i < count; i++)
	    {
	      [coder decodeValueOfObjCType: @encode(id) at: &objs[i]];
	    }
	  self = [self initWithObjects: objs count: count];
	  while (count-- > 0)
	    {
	      [objs[count] release];
	    }
	  GS_ENDIDBUF();
	}
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)aCoder
{
   if ([aCoder allowsKeyedCoding])
    {
      NSMutableArray *array = [NSMutableArray array];
      NSEnumerator *en = [self objectEnumerator];
      id obj = nil;
      /* HACK ... MacOS-X seems to code differently if the coder is an
       * actual instance of NSKeyedArchiver
       */
      
      // Collect all objects...
      while((obj = [en nextObject]) != nil)
	{
	  [array addObject: obj];
	}
      
      if ([aCoder class] == [NSKeyedArchiver class])
	{
	  [(NSKeyedArchiver*)aCoder _encodeArrayOfObjects: array
						   forKey: @"NS.objects"];
	}
      else
	{
	  unsigned	i = 0;
	  NSEnumerator	*e = [self objectEnumerator];
	  id		o;

	  while ((o = [e nextObject]) != nil)
	    {
	      NSString	*key;

	      key = [NSString stringWithFormat: @"NS.object.%u", i++];
	      [(NSKeyedArchiver*)aCoder encodeObject: o forKey: key];
	    }
	}
    }
  else
    {
      unsigned		count = [self count];
      NSEnumerator	*e = [self objectEnumerator];
      id		o;

      [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
      while ((o = [e nextObject]) != nil)
	{
	  [aCoder encodeValueOfObjCType: @encode(id) at: &o];
	}
    } 
}

- (id) copyWithZone: (NSZone*)zone
{
  NSOrderedSet	*copy = [NSOrderedSet_concrete_class allocWithZone: zone];
  return [copy initWithOrderedSet: self copyItems: YES];
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
   NSMutableOrderedSet	*copy = [NSMutableOrderedSet_concrete_class allocWithZone: zone];
   return [copy initWithOrderedSet: self copyItems: NO];
}

// NSFastEnumeration 
- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *)state
				   objects: (__unsafe_unretained id[])stackbuf
				     count: (NSUInteger)len
{
  NSInteger count;

  /* In a mutable subclass, the mutationsPtr should be set to point to a
   * value (unsigned long) which will be changed (incremented) whenever
   * the container is mutated (content added, removed, re-ordered).
   * This is cached in the caller at the start and compared at each
   * iteration.   If it changes during the iteration then
   * objc_enumerationMutation() will be called, throwing an exception.
   * The abstract base class implementation points to a fixed value
   * (the enumeration state pointer should exist and be unchanged for as
   * long as the enumeration process runs), which is fine for enumerating
   * an immutable array.
   */
  state->mutationsPtr = (unsigned long *)&state->mutationsPtr;
  count = MIN(len, [self count] - state->state);
  /* If a mutation has occurred then it's possible that we are being asked to
   * get objects from after the end of the array.  Don't pass negative values
   * to memcpy.
   */
  if (count > 0)
    {
      IMP	imp = [self methodForSelector: @selector(objectAtIndex:)];
      int	p = state->state;
      int	i;

      for (i = 0; i < count; i++, p++)
	{
	  stackbuf[i] = (*imp)(self, @selector(objectAtIndex:), p);
	}
      state->state += count;
    }
  else
    {
      count = 0;
    }
  state->itemsPtr = stackbuf;
  return count;
}

// class methods
+ (instancetype) orderedSet
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] init]);
}

+ (instancetype) orderedSetWithArray:(NSArray *)objects
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
			 initWithArray: objects]);
}

+ (instancetype) orderedSetWithArray:(NSArray *)objects
                               range:(NSRange)range
                           copyItems:(BOOL)flag
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
			 initWithArray: objects
				 range: range
			     copyItems: flag]);
}

+ (instancetype) orderedSetWithObject:(id)anObject
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
			 initWithObject: anObject]);
}

+ (instancetype) orderedSetWithObjects:(id)firstObject, ...
{
  id	set;
  GS_USEIDLIST(firstObject,
	       set = [[self allocWithZone: NSDefaultMallocZone()]
		       initWithObjects: __objects count: __count]);
  return AUTORELEASE(set);
 }

+ (instancetype) orderedSetWithObjects:(const id [])objects
                                 count:(NSUInteger) count
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
		       initWithObjects: objects count: count]);
}

+ (instancetype) orderedSetWithOrderedSet:(NSOrderedSet *)aSet
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
		       initWithOrderedSet: aSet]);
}


+ (instancetype) orderedSetWithSet:(NSSet *)aSet
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
		       initWithSet: aSet]);
}

+ (instancetype) orderedSetWithSet:(NSSet *)aSet
                         copyItems:(BOOL)flag
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
			initWithSet: aSet
			  copyItems: flag]);
}

// instance methods
- (instancetype) initWithArray:(NSArray *)other
{
  unsigned	count = [other count];

  if (count == 0)
    {
      return [self init];
    }
  else
    {
      GS_BEGINIDBUF(objs, count);

      if ([other isProxy])
	{
	  unsigned	i;

	  for (i = 0; i < count; i++)
	    {
	      objs[i] = [other objectAtIndex: i];
	    }
	}
      else
	{
          [other getObjects: objs];
	}
      self = [self initWithObjects: objs count: count];
      GS_ENDIDBUF();
      return self;
    }

  return nil;
}

- (instancetype) initWithArray:(NSArray *)other copyItems:(BOOL)flag
{
  unsigned	count = [other count];
  unsigned      j = count;
  
  if (count == 0)
    {
      return [self init];
    }
  
  GS_BEGINIDBUF(objs, count);
  {
    unsigned	i;
    
    for (i = 0; i < count; i++)
      {
	if (flag == NO)
	  {
	    objs[i] = [other objectAtIndex: i];
	  }
	else // copy the items.
	  {
	    objs[i] = [[other objectAtIndex: i] copy];
	  }
      }
  }
  
  self = [self initWithObjects: objs count: count];
  
  if(flag == YES)
    {
      while(j--)
	{
	  [objs[j] release];
	}
    }
  GS_ENDIDBUF();
  return self;
}

- (instancetype) initWithArray:(NSArray *)other
                         range:(NSRange)range
                     copyItems:(BOOL)flag
{
  unsigned	count = [other count];
  unsigned      i = 0, j = 0;
    
  if (count == 0)
    {
      return [self init];
    }

  GS_BEGINIDBUF(objs, range.length);
  {
    unsigned      loc = range.location;
    unsigned      len = range.length;
    
    for (i = 0; i < count; i++)
      {
	if(i >= loc && j < len)
	  {
	    if(flag == YES)
	      {		  
		objs[i] = [[other objectAtIndex: i] copy];
	      }
	    else
	      {
		objs[i] = [other objectAtIndex: i];
	      }
	    j++;
	  }
	
	if(j >= len)
	  {
	    break;
	  }
      }
  }
  self = [self initWithObjects: objs count: count];

  if(flag == YES)
    {
      while(j--)
	{
	  [objs[j] release];
	}
    }
  GS_ENDIDBUF();

  return self;
}

- (instancetype) initWithObject:(id)object
{
  self = [super init];
  if(self != nil)
    {
      // Need proper implementation to happen in subclass since it will define how data
      // is stored.
    }
  return self;
}

- (instancetype) initWithObjects:(id)firstObject, ...
{
  GS_USEIDLIST(firstObject,
    self = [self initWithObjects: __objects count: __count]);
  return self;
}

/** <init /> <override-subclass />
 * Initialize to contain (unique elements of) objects.<br />
 * Calls -init (which does nothing but maintain MacOS-X compatibility),
 * and needs to be re-implemented in subclasses in order to have all
 * other initialisers work.
 */
- (instancetype) initWithObjects:(const id [])objects // required override.
                           count:(NSUInteger)count
{
  self = [self init];
  if(self != nil)
    {
      // Need proper implementation in subclass since that is where data will be stored.
    }
  return self;
}

- (instancetype) initWithOrderedSet:(NSOrderedSet *)aSet
{
  return [self initWithOrderedSet: aSet copyItems: NO];
}

- (instancetype) initWithOrderedSet:(NSOrderedSet *)other
                          copyItems:(BOOL)flag
{
  unsigned	c = [other count];
  id		o, e = [other objectEnumerator];
  unsigned	i = 0;
  GS_BEGINIDBUF(os, c);

  while ((o = [e nextObject]))
    {
      if (flag)
	os[i] = [o copy];
      else
	os[i] = o;
      i++;
    }
  self = [self initWithObjects: os count: c];
  if (flag)
    {
      while (i--)
        {
          [os[i] release];
        }
    }
  GS_ENDIDBUF();
  return self;
}

- (instancetype) initWithOrderedSet:(NSOrderedSet *)other
                              range:(NSRange)range
                          copyItems:(BOOL)flag
{
  unsigned	c = [other count];
  id		o, e = [other objectEnumerator];
  unsigned	i = 0, j = 0;
  unsigned      loc = range.location;
  unsigned      len = range.length;
  GS_BEGINIDBUF(os, c);

  while ((o = [e nextObject]))
    {
      if(i >= loc && j < len)
	{
	  if (flag)
	    os[i] = [o copy];
	  else
	    os[i] = o;
	  j++;
	}
      i++;

      if(j >= len)
	{
	  break;
	}
    }
  
  self = [self initWithObjects: os count: c];
  if (flag)
    {
      while (i--)
        {
          [os[i] release];
        }
    }
  GS_ENDIDBUF();
  return self;
}

- (instancetype) initWithSet:(NSSet *)aSet
{
  return [self initWithSet: aSet copyItems: NO];
}

- (instancetype) initWithSet:(NSSet *)other copyItems:(BOOL)flag
{
    unsigned	c = [other count];
  id		o, e = [other objectEnumerator];
  unsigned	i = 0;
  GS_BEGINIDBUF(os, c);

  while ((o = [e nextObject]))
    {
      if (flag)
	os[i] = [o copy];
      else
	os[i] = o;
      i++;
    }
  self = [self initWithObjects: os count: c];
  if (flag)
    {
      while (i--)
        {
          [os[i] release];
        }
    }
  GS_ENDIDBUF();
  return self;
}

- (instancetype) init
{
  self = [super init];
  if(self == nil)
    {
      NSLog(@"NSOrderedSet not allocated.");
    }
  return self;
}

- (NSUInteger) count // required override
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (BOOL)containsObject:(id)anObject // required override
{
  [self subclassResponsibility: _cmd];
  return NO; 
}

- (void) enumerateObjectsAtIndexes:(NSIndexSet *)indexSet
                           options:(NSEnumerationOptions)opts
                        usingBlock:(GSEnumeratorBlock)aBlock
{
  [[self objectsAtIndexes: indexSet] enumerateObjectsWithOptions: opts
						      usingBlock: aBlock];
}

- (void) enumerateObjectsUsingBlock:(GSEnumeratorBlock)aBlock
{
  [self enumerateObjectsWithOptions: 0 usingBlock: aBlock];
}

- (void) enumerateObjectsWithOptions:(NSEnumerationOptions)opts
                          usingBlock:(GSEnumeratorBlock)aBlock
{
  NSUInteger count = 0;
  BLOCK_SCOPE BOOL shouldStop = NO;
  BOOL isReverse = (opts & NSEnumerationReverse);
  id<NSFastEnumeration> enumerator = self;

  /* If we are enumerating in reverse, use the reverse enumerator for fast
   * enumeration. */
  if (isReverse)
    {
      enumerator = [self reverseObjectEnumerator];
      count = ([self count] - 1);
    }

  {
  GS_DISPATCH_CREATE_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
  FOR_IN (id, obj, enumerator)
    GS_DISPATCH_SUBMIT_BLOCK(enumQueueGroup, enumQueue, if (YES == shouldStop) {return;}, return, aBlock, obj, count, &shouldStop);
      if (isReverse)
        {
          count--;
        }
      else
        {
          count++;
        }

      if (shouldStop)
        {
          break;
        }
    END_FOR_IN(enumerator)
    GS_DISPATCH_TEARDOWN_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
  }
}

- (id) firstObject
{
  NSUInteger count = [self count];
  if (count == 0)
    return nil;
  return [self objectAtIndex: 0];
}

- (id) lastObject
{
   NSUInteger count = [self count];
  if (count == 0)
    return nil;
  return [self objectAtIndex: 0];
}

- (id) objectAtIndex: (NSUInteger)index  // required override...
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) objectAtIndexedSubscript: (NSUInteger)index  // required override...
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSArray *) objectsAtIndexes: (NSIndexSet *)indexes
{
  NSMutableArray *group = [NSMutableArray arrayWithCapacity: [indexes count]];

  NSUInteger i = [indexes firstIndex];
  while (i != NSNotFound)
    {
      [group addObject: [self objectAtIndex: i]];
      i = [indexes indexGreaterThanIndex: i];
    }

  return GS_IMMUTABLE(group);
}

    
- (NSUInteger) indexOfObject:(id)anObject
{
  NSUInteger	c = [self count];
  
  if (c > 0 && anObject != nil)
    {
      NSUInteger	i;
      IMP	get = [self methodForSelector: oaiSel];
      BOOL	(*eq)(id, SEL, id)
	= (BOOL (*)(id, SEL, id))[anObject methodForSelector: eqSel];
      
      for (i = 0; i < c; i++)
	if ((*eq)(anObject, eqSel, (*get)(self, oaiSel, i)) == YES)
	  return i;
    }
  return NSNotFound;
}

- (NSUInteger) indexOfObject: (id)key
               inSortedRange: (NSRange)range
                     options: (NSBinarySearchingOptions)options
             usingComparator: (NSComparator)comparator
{
    if (range.length == 0)
    {
      return options & NSBinarySearchingInsertionIndex
        ? range.location : NSNotFound;
    }
  if (range.length == 1)
    {
      switch (CALL_BLOCK(comparator, key, [self objectAtIndex: range.location]))
        {
          case NSOrderedSame:
            return range.location;
          case NSOrderedAscending:
            return options & NSBinarySearchingInsertionIndex
              ? range.location : NSNotFound;
          case NSOrderedDescending:
            return options & NSBinarySearchingInsertionIndex
              ? (range.location + 1) : NSNotFound;
          default:
            // Shouldn't happen
            return NSNotFound;
        }
    }
  else
    {
      NSUInteger index = NSNotFound;
      NSUInteger count = [self count];
      NSRange range = NSMakeRange(0, [self count]);
      GS_BEGINIDBUF(objects, count);

      [self getObjects: objects range: range];
      // We use the timsort galloping to find the insertion index:
      if (options & NSBinarySearchingLastEqual)
        {
          index = GSRightInsertionPointForKeyInSortedRange(key,
            objects, range, comparator);
        }
      else
        {
          // Left insertion is our default
          index = GSLeftInsertionPointForKeyInSortedRange(key,
            objects, range, comparator);
        }
      GS_ENDIDBUF()

      // If we were looking for the insertion point, we are done here
      if (options & NSBinarySearchingInsertionIndex)
        {
          return index;
        }

      /* Otherwise, we need need another equality check in order to
       * know whether we need return NSNotFound.
       */

      if (options & NSBinarySearchingLastEqual)
        {
          /* For search from the right, the equal object would be
           * the one before the index, but only if it's not at the
           * very beginning of the range (though that might not
           * actually be possible, it's better to check nonetheless).
           */
          if (index > range.location)
            {
              index--;
            }
        }
      if (index >= NSMaxRange(range))
        {
          return NSNotFound;
        }
      /*
       * For a search from the left, we'd have the correct index anyways. Check
       * whether it's equal to the key and return NSNotFound otherwise
       */
      return (NSOrderedSame == CALL_BLOCK(comparator,
        key, [self objectAtIndex: index]) ? index : NSNotFound);
    }
  // Never reached
  return NSNotFound;
}

- (NSUInteger) indexOfObjectAtIndexes:(NSIndexSet *)indexSet
                              options:(NSEnumerationOptions)opts
                          passingTest:(GSPredicateBlock)predicate
{
  return [[self objectsAtIndexes: indexSet]
        indexOfObjectWithOptions: 0
                     passingTest: predicate];
}

- (NSUInteger) indexOfObjectPassingTest:(GSPredicateBlock)predicate
{
  return [self indexOfObjectWithOptions: 0 passingTest: predicate];
}

- (NSUInteger) indexOfObjectWithOptions:(NSEnumerationOptions)opts
                            passingTest:(GSPredicateBlock)predicate
{
   /* TODO: Concurrency. */
  id<NSFastEnumeration> enumerator = self;
  BLOCK_SCOPE BOOL      shouldStop = NO;
  NSUInteger            count = 0;
  BLOCK_SCOPE NSUInteger index = NSNotFound;
  BLOCK_SCOPE NSLock    *indexLock = nil;

  /* If we are enumerating in reverse, use the reverse enumerator for fast
   * enumeration. */
  if (opts & NSEnumerationReverse)
    {
      enumerator = [self reverseObjectEnumerator];
    }

  if (opts & NSEnumerationConcurrent)
    {
      indexLock = [NSLock new];
    }
  {
    GS_DISPATCH_CREATE_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
    FOR_IN (id, obj, enumerator)
#     if __has_feature(blocks) && (GS_USE_LIBDISPATCH == 1)
      dispatch_group_async(enumQueueGroup, enumQueue, ^(void){
        if (shouldStop)
        {
	  return;
        }
        if (predicate(obj, count, &shouldStop))
        {
	  // FIXME: atomic operation on the shouldStop variable would be nicer,
	  // but we don't expose the GSAtomic* primitives anywhere.
	  [indexLock lock];
	  index =  count;
	  // Cancel all other predicate evaluations:
	  shouldStop = YES;
	  [indexLock unlock];
        }
      });
#     else
      if (CALL_BLOCK(predicate, obj, count, &shouldStop))
        {

	  index = count;
	  shouldStop = YES;
        }
#     endif
      if (shouldStop)
        {
	  break;
        }
      count++;
    END_FOR_IN(enumerator)
    GS_DISPATCH_TEARDOWN_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts);
  }
  RELEASE(indexLock);
  return index;
}

- (NSIndexSet *) indexesOfObjectsAtIndexes:(NSIndexSet *)indexSet
                              options:(NSEnumerationOptions)opts
                          passingTest:(GSPredicateBlock)predicate
{
  return [[self objectsAtIndexes: indexSet]
	   indexesOfObjectsWithOptions: opts
			   passingTest: predicate];
}

- (NSIndexSet *) indexesOfObjectsPassingTest:(GSPredicateBlock)predicate
{
  return [self indexesOfObjectsWithOptions: 0 passingTest: predicate];
}

- (NSIndexSet *) indexesOfObjectsWithOptions:(NSEnumerationOptions)opts
                            passingTest:(GSPredicateBlock)predicate
{
  /* TODO: Concurrency. */
  NSMutableIndexSet     *set = [NSMutableIndexSet indexSet];
  BLOCK_SCOPE BOOL      shouldStop = NO;
  id<NSFastEnumeration> enumerator = self;
  NSUInteger            count = 0;
  BLOCK_SCOPE NSLock    *setLock = nil;

  /* If we are enumerating in reverse, use the reverse enumerator for fast
   * enumeration. */
  if (opts & NSEnumerationReverse)
    {
      enumerator = [self reverseObjectEnumerator];
    }
  if (opts & NSEnumerationConcurrent)
    {
      setLock = [NSLock new];
    }
  {
    GS_DISPATCH_CREATE_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts)
    FOR_IN (id, obj, enumerator)
#     if __has_feature(blocks) && (GS_USE_LIBDISPATCH == 1)

      dispatch_group_async(enumQueueGroup, enumQueue, ^(void){
        if (shouldStop)
        {
	  return;
        }
        if (predicate(obj, count, &shouldStop))
        {
	  [setLock lock];
	  [set addIndex: count];
	  [setLock unlock];
        }
      });
#     else
      if (CALL_BLOCK(predicate, obj, count, &shouldStop))
        {
	  /* TODO: It would be more efficient to collect an NSRange and only
	   * pass it to the index set when CALL_BLOCK returned NO. */
	  [set addIndex: count];
        }
#     endif
      if (shouldStop)
        {
	  break;
        }
      count++;
    END_FOR_IN(enumerator)
    GS_DISPATCH_TEARDOWN_QUEUE_AND_GROUP_FOR_ENUMERATION(enumQueue, opts);
  }
  RELEASE(setLock);
  return set;
}

- (NSEnumerator *) objectEnumerator
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSEnumerator *) reverseObjectEnumerator
{
    [self subclassResponsibility: _cmd];
    return nil;
}

- (NSOrderedSet *)reversedOrderedSet
{
  NSEnumerator *e = [self reverseObjectEnumerator];
  NSMutableArray *a = [NSMutableArray arrayWithCapacity: [self count]];
  id o = nil;

  // Build the reverse array...
  while ((o = [e nextObject]) != nil)
    {
      [a addObject: o];
    }

  // Create and return reverse ordered set...
  return [NSOrderedSet orderedSetWithArray: a];
}

- (void) getObjects: (__unsafe_unretained id[])aBuffer range: (NSRange)aRange
{
  NSUInteger i, j = 0, c = [self count], e = aRange.location + aRange.length;
  IMP	get = [self methodForSelector: oaiSel];

  GS_RANGE_CHECK(aRange, c);

  for (i = aRange.location; i < e; i++)
    aBuffer[j++] = (*get)(self, oaiSel, i);
}
 
// Key value coding support
- (void) setValue: (id)value forKey: (NSString*)key
{
  NSUInteger    i;
  NSUInteger	count = [self count];
  volatile id	object = nil;

  for (i = 0; i < count; i++)
    {
      object = [self objectAtIndex: i];
      [object setValue: value
		forKey: key];
    }
}

- (id) valueForKey: (NSString*)key
{
  NSEnumerator *e = [self objectEnumerator];
  id object = nil;
  NSMutableSet *results = [NSMutableSet setWithCapacity: [self count]];

  while ((object = [e nextObject]) != nil)
    {
      id result = [object valueForKey: key];

      if (result == nil)
        continue;

      [results addObject: result];
    }
  return results;
}

// Key-Value Observing Support
/*
- addObserver:forKeyPath:options:context:
- removeObserver:forKeyPath:
- removeObserver:forKeyPath:context:
*/

- (NSUInteger)_countForObject: (id)object  // required override...
{
  return 1;
}

// Comparing Sets
- (BOOL) isEqualToOrderedSet: (NSOrderedSet *)aSet
{
  if ([self count] == 0 &&
      [aSet count] == 0)
    return YES;
  
  if (self == aSet)
    return YES;
  
  if ([self count] != [aSet count])
    return NO;

  // if they are equal, then this set will be a subset of aSet.
  return [self isSubsetOfOrderedSet: aSet];
}

- (BOOL) isEqual: (id)other
{
  if ([other isKindOfClass: [NSOrderedSet class]])
    return [self isEqualToOrderedSet: other];
  return NO;
}

// Set operations
- (BOOL) intersectsOrderedSet: (NSOrderedSet *)otherSet
{
  id	o = nil, e = nil;

  // -1. If this set is empty, this method should return NO.
  if ([self count] == 0)
    return NO;

  // 0. Loop for all members in otherSet
  e = [otherSet objectEnumerator];
  while ((o = [e nextObject])) // 1. pick a member from otherSet.
    {
      if ([self containsObject: o])    // 2. check the member is in this set(self).
        return YES;
    }
  return NO;
}

- (BOOL) intersectsSet: (NSSet *)otherSet
{
  id	o = nil, e = nil;

  // -1. If this set is empty, this method should return NO.
  if ([self count] == 0)
    return NO;

  // 0. Loop for all members in otherSet
  e = [otherSet objectEnumerator];
  while ((o = [e nextObject])) // 1. pick a member from otherSet.
    {
      if ([self containsObject: o])    // 2. check the member is in this set(self).
        return YES;
    }
  return NO;
}

- (BOOL) isSubsetOfOrderedSet: (NSOrderedSet *)otherSet
{
  id    f = nil;
  NSUInteger s = 0, l = [self count], i = 0;
  
  // -1. If this set is empty, this method should return NO.
  if (l == 0)
    return NO;

  // If count of set is more than otherSet it's not a subset
  if (l > [otherSet count])
    return NO;

  // Find the first object's index in otherset, if not found
  // it's not a subset...
  f = [self firstObject];
  s = [otherSet indexOfObject: f];
  if(s == NSNotFound)
    return NO;

  for(i = 0; i < l; i++)
    {
      NSUInteger j = s + i;
      id oo = [otherSet objectAtIndex: j];
      id o = [self objectAtIndex: i];

      if([o isEqual: oo] == NO)
	{
	  return NO;
	}
    }
  
  return YES; // if all members are in set.
}

- (BOOL) isSubsetOfSet:(NSSet *)otherSet
{
    id	o = nil, e = nil;

  // -1. If this set is empty, this method should return NO.
  if ([self count] == 0)
    return NO;

  // 0. Loop for all members in otherSet
  e = [otherSet objectEnumerator];
  while ((o = [e nextObject])) // 1. pick a member from otherSet.
    {
      if ([self containsObject: o] == NO)    // 2. check the member is in this set(self).
        return NO;
    }
  return YES; // if all members are in set.
}

// Creating a Sorted Array
- (NSArray *) sortedArrayUsingDescriptors:(NSArray *)sortDescriptors
{
  NSMutableArray *sortedArray = [NSMutableArray arrayWithArray: [self array]];
  
  [sortedArray sortUsingDescriptors: sortDescriptors];
  
  return GS_IMMUTABLE(sortedArray);
}

- (NSArray *) sortedArrayUsingComparator: (NSComparator)comparator
{
  return [self sortedArrayWithOptions: 0
		      usingComparator: comparator];
}

- (NSArray *)
    sortedArrayWithOptions: (NSSortOptions)options
           usingComparator: (NSComparator)comparator 
{
  return [[self array] sortedArrayWithOptions: options
			      usingComparator: comparator];
}

// Filtering Ordered Sets
- (NSOrderedSet *)filteredOrderedSetUsingPredicate: (NSPredicate *)predicate
{
  NSMutableOrderedSet   *result = nil;
  NSEnumerator		*e = [self objectEnumerator];
  id			object = nil;

  result = [NSMutableOrderedSet orderedSetWithCapacity: [self count]];
  while ((object = [e nextObject]) != nil)
    {
      if ([predicate evaluateWithObject: object] == YES)
        {
          [result addObject: object];  // passes filter
        }
    }
  return GS_IMMUTABLE(result);
}

// Describing a set
- (NSString *) description
{
  return [self descriptionWithLocale: nil];
}

- (NSString *) descriptionWithLocale: (NSLocale *)locale
{
  return [self descriptionWithLocale: locale indent: NO];
}

- (NSString*) descriptionWithLocale: (NSLocale *)locale indent: (BOOL)flag
{
  NSArray *allObjects = [self array];
  return [NSString stringWithFormat: @"%@", allObjects];
}

- (NSArray *) array
{
  NSEnumerator *en = [self objectEnumerator];
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [self count]];
  id o = nil;
  
  while((o = [en nextObject]) != nil)
    {
      [result addObject: o];
    }
  
  return GS_IMMUTABLE(result);
}

- (NSSet *) set
{
  NSEnumerator *en = [self objectEnumerator];
  NSMutableSet *result = [NSMutableSet setWithCapacity: [self count]];
  id o = nil;
  
  while((o = [en nextObject]) != nil)
    {
      [result addObject: o];
    }
  
  return GS_IMMUTABLE(result);
}
@end

// Mutable Ordered Set
@implementation NSMutableOrderedSet
// Creating a Mutable Ordered Set
+ (void) initialize
{
  if (self == [NSMutableOrderedSet class])
    {
      NSMutableOrderedSet_abstract_class = self;
      NSMutableOrderedSet_concrete_class = [GSMutableOrderedSet class];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSMutableOrderedSet_abstract_class)
    {
      return NSAllocateObject(NSMutableOrderedSet_concrete_class, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

+ (instancetype)orderedSetWithCapacity: (NSUInteger)capacity
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] initWithCapacity: capacity]);
}

- (Class) classForCoder
{
  return NSMutableOrderedSet_abstract_class;
}

- (instancetype)initWithCapacity: (NSUInteger)capacity
{
  self = [self init];
  return self;
}

- (instancetype) init
{
  self = [super init];
  if(self == nil)
    {
      NSLog(@"Could not init class");
    }
  return self;
}

- (void)addObject:(id)anObject
{
  [self subclassResponsibility: _cmd];
}

- (void)addObjects:(const id[])objects count:(NSUInteger)count
{
  NSUInteger i = 0;
  for (i = 0; i < count; i++)
    {
      id obj = objects[i];
      [self addObject: obj];
    }
}

- (void)addObjectsFromArray:(NSArray *)otherArray
{
  NSEnumerator *en = [otherArray objectEnumerator];
  id obj = nil;
  while((obj = [en nextObject]) != nil)
    {
      [self addObject: obj];
    }
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index  // required override
{
  [self subclassResponsibility: _cmd];
}

- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index
{
  if ([self count] == index)
    {
      [self addObject: object];
    }
  else
    {
      [self replaceObjectAtIndex: index withObject: object];
    }
}

- (void)insertObjects:(NSArray *)array atIndexes:(NSIndexSet *)indexes
{
  NSUInteger	index = [indexes firstIndex];
  NSEnumerator	*enumerator = [array objectEnumerator];
  id		object = [enumerator nextObject];
 
  while (object != nil && index != NSNotFound)
    {
      [self insertObject: object atIndex: index];
      object = [enumerator nextObject];
      index = [indexes indexGreaterThanIndex: index];
    }
}

- (void)removeObject:(id)anObject
{
  NSUInteger	i;

  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object");
      return;
    }
  i = [self count];
  if (i > 0)
    {
      IMP	rem = 0;
      IMP	get = [self methodForSelector: oaiSel];
      BOOL	(*eq)(id, SEL, id)
	= (BOOL (*)(id, SEL, id))[anObject methodForSelector: eqSel];

      while (i-- > 0)
	{
	  id	o = (*get)(self, oaiSel, i);

	  if (o == anObject || (*eq)(anObject, eqSel, o) == YES)
	    {
	      if (rem == 0)
		{
		  rem = [self methodForSelector: remSel];
		  /*
		   * We need to retain the object so that when we remove the
		   * first equal object we don't get left with a bad object
		   * pointer for later comparisons.
		   */
		  RETAIN(anObject);
		}
	      (*rem)(self, remSel, i);
	    }
	}
      if (rem != 0)
	{
	  RELEASE(anObject);
	}
    }
}

- (void)removeObjectAtIndex:(NSUInteger)index  // required override
{
  [self subclassResponsibility: _cmd];
}

- (void) _removeObjectsFromIndices: (NSUInteger*)indices
			numIndices: (NSUInteger)count
{
  if (count > 0)
    {
      NSUInteger	to = 0;
      NSUInteger	from = 0;
      NSUInteger	i;
      GS_BEGINITEMBUF(sorted, count, NSUInteger);

      while (from < count)
	{
	  NSUInteger	val = indices[from++];

	  i = to;
	  while (i > 0 && sorted[i-1] > val)
	    {
	      i--;
	    }
	  if (i == to)
	    {
	      sorted[to++] = val;
	    }
	  else if (sorted[i] != val)
	    {
	      NSUInteger	j = to++;

	      if (sorted[i] < val)
		{
		  i++;
		}
	      while (j > i)
		{
		  sorted[j] = sorted[j-1];
		  j--;
		}
	      sorted[i] = val;
	    }
	}

      if (to > 0)
	{
	  IMP	rem = [self methodForSelector: remSel];

	  while (to--)
	    {
	      (*rem)(self, remSel, sorted[to]);
	    }
	}
      GS_ENDITEMBUF();
    }
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes
{
  NSUInteger count = [indexes count];
  NSUInteger indexArray[count];

  [indexes getIndexes: indexArray
             maxCount: count
         inIndexRange: NULL];

  [self _removeObjectsFromIndices: indexArray
		       numIndices: count];
}

- (void)removeObjectsInArray:(NSArray *)otherArray
{
  NSUInteger	c = [otherArray count];

  if (c > 0)
    {
      NSUInteger	i;
      IMP	get = [otherArray methodForSelector: oaiSel];
      IMP	rem = [self methodForSelector: @selector(removeObject:)];

      for (i = 0; i < c; i++)
	(*rem)(self, @selector(removeObject:), (*get)(otherArray, oaiSel, i));
    }
}

- (void)removeObjectsInRange:(NSRange)aRange
{
  NSUInteger	i;
  NSUInteger	s = aRange.location;
  NSUInteger	c = [self count];

  i = aRange.location + aRange.length;

  if (c < i)
    i = c;

  if (i > s)
    {
      IMP	rem = [self methodForSelector: remSel];

      while (i-- > s)
	{
	  (*rem)(self, remSel, i);
	}
    }
}

- (void)removeAllObjects
{
  NSUInteger	c = [self count];

  if (c > 0)
    {
      IMP	remLast = [self methodForSelector: rlSel];

      while (c--)
	{
	  (*remLast)(self, rlSel);
	}
    }  
}

- (void)replaceObjectAtIndex:(NSUInteger)index // required override...
                  withObject:(id)object
{
  [self subclassResponsibility: _cmd];
}

- (void) replaceObjectsAtIndexes: (NSIndexSet *)indexes
                     withObjects: (NSArray *)objects
{
  NSUInteger count = [indexes count];
  NSUInteger indexArray[count];

  [indexes getIndexes: indexArray
             maxCount: count
         inIndexRange: NULL];

  [self _removeObjectsFromIndices: indexArray
		       numIndices: count]; 
}

- (void) replaceObjectsInRange: (NSRange)aRange
                   withObjects: (const id[])objects
                         count: (NSUInteger)count
{
  id o = nil;
  NSUInteger i = 0;
  
  if (count < (aRange.location + aRange.length))
    [NSException raise: NSRangeException
		 format: @"Replacing objects beyond end of const[] id."];
  [self removeObjectsInRange: aRange];

  for(i = 0; i < count; i++)
    {
      o = objects[i];
      [self insertObject: o atIndex: aRange.location]; 
    }
}

- (void)setObject:(id)anObject atIndex:(NSUInteger)anIndex
{
  if ([self count] == anIndex)
    {
      [self addObject: anObject];
    }
  else
    {
      [self replaceObjectAtIndex: anIndex withObject: anObject];
    }
}

- (void)moveObjectsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)index
{
  NSUInteger i = 0;
  NSUInteger count = [indexes count];
  NSUInteger indexArray[count];
  NSMutableArray *tmpArray = [NSMutableArray arrayWithCapacity: count];
  id o = nil;
  NSEnumerator *e = nil;
  
  [indexes getIndexes: indexArray
             maxCount: count
         inIndexRange: NULL];

  // Build the temporary array....
  for(i = 0; i < count; i++)
    {
      NSUInteger index = indexArray[i];
      id obj = [self objectAtIndex: index];
      [tmpArray addObject: obj];
    }

  // Move the objects
  e = [tmpArray objectEnumerator];
  while((o = [e nextObject]) != nil)
    {
      [self insertObject: o atIndex: index];
    }

  // Remove the originals...  
  for(i = 0; i < count; i++)
    {
      NSUInteger index = indexArray[i];
      [self removeObjectAtIndex: index];
    }
}

- (void) exchangeObjectAtIndex:(NSUInteger)index withObjectAtIndex:(NSUInteger)otherIndex
{
  id	tmp = [self objectAtIndex: index];

  RETAIN(tmp);
  [self replaceObjectAtIndex: index withObject: [self objectAtIndex: otherIndex]];
  [self replaceObjectAtIndex: otherIndex withObject: tmp];
  RELEASE(tmp);
}

- (void)filterUsingPredicate:(NSPredicate *)predicate
{
  unsigned	count = [self count];

  while (count-- > 0)
    {
      id	object = [self objectAtIndex: count];
	
      if ([predicate evaluateWithObject: object] == NO)
        {
          [self removeObjectAtIndex: count];
        }
    }
}

- (void) sortUsingDescriptors:(NSArray *)descriptors
{
  NSArray *result = [[self array] sortedArrayUsingDescriptors: descriptors];
  [self removeAllObjects];
  [self addObjectsFromArray: result];
}

- (void) sortUsingComparator: (NSComparator)comparator
{
  [self sortWithOptions: 0 usingComparator: comparator];
}

- (void) sortWithOptions: (NSSortOptions)options
         usingComparator: (NSComparator)comparator
{
  NSUInteger count = [self count];
  
  if ((1 < count) && (NULL != comparator))
    {
      NSArray *res = nil;
      NSUInteger i, c = [self count];
      IMP	get = [self methodForSelector: oaiSel];

      GS_BEGINIDBUF(objects, count);
      for (i = 0; i < c; i++)
	{
	  objects[i] = (*get)(self, oaiSel, i);
	}
      
      if (options & NSSortStable)
        {
          if (options & NSSortConcurrent)
            {
              GSSortStableConcurrent(objects, NSMakeRange(0,count),
                (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
          else
            {
              GSSortStable(objects, NSMakeRange(0,count),
                (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
        }
      else
        {
          if (options & NSSortConcurrent)
            {
              GSSortUnstableConcurrent(objects, NSMakeRange(0,count),
                (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
          else
            {
              GSSortUnstable(objects, NSMakeRange(0,count),
                (id)comparator, GSComparisonTypeComparatorBlock, NULL);
            }
        }
      res = [[NSArray alloc] initWithObjects: objects count: count];
      [self removeAllObjects];
      [self addObjectsFromArray: res];

      RELEASE(res);
      GS_ENDIDBUF();
    } 
}

- (void) sortRange: (NSRange)range
           options:(NSSortOptions)options
   usingComparator: (NSComparator)comparator
{
}

- (void) intersectOrderedSet:(NSOrderedSet *)other
{
    if (other != self)
    {
      id keys = [self objectEnumerator];
      id key;

      while ((key = [keys nextObject]))
	{
	  if ([other containsObject: key] == NO)
	    {
	      [self removeObject: key];
	    }
	}
    }
}

- (void) intersectSet:(NSSet *)other
{
  id keys = [self objectEnumerator];
  id key;
  
  while ((key = [keys nextObject]))
    {
      if ([other containsObject: key] == NO)
	{
	  [self removeObject: key];
	}
    }
}

- (void) minusOrderedSet:(NSOrderedSet *)other
{
  if(other != self)
    {
      [self removeAllObjects];
    }
  else
    {
      id keys = [other objectEnumerator];
      id key;
      
      while ((key = [keys nextObject]))
	{
	  [self removeObject: key];
	}
    }
}

- (void) minusSet:(NSSet *)other
{
  id keys = [other objectEnumerator];
  id key;
  
  while ((key = [keys nextObject]))
    {
      [self removeObject: key];
    }
}

- (void) unionOrderedSet:(NSOrderedSet *)other
{
    if (other != self)
    {
      id keys = [other objectEnumerator];
      id key;

      while ((key = [keys nextObject]))
	{
	  [self addObject: key];
	}
    }
}

- (void) unionSet:(NSSet *)other
{
  id keys = [other objectEnumerator];
  id key;
  
  while ((key = [keys nextObject]))
    {
      [self addObject: key];
    }
}

- (instancetype) initWithCoder: (NSCoder *)acoder
{
  return [super initWithCoder: acoder];
}
@end
