/**Interface for NSConcretePointerFunctions for GNUStep
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

@interface NSConcretePointerFunctions : NSPointerFunctions
{
@public
  NSUInteger	_options;

  void* (*_acquireFunction)(const void *item,
    NSUInteger (*size)(const void *item), BOOL shouldCopy);

  NSString *(*_descriptionFunction)(const void *item);

  NSUInteger (*_hashFunction)(const void *item,
    NSUInteger (*size)(const void *item));

  BOOL (*_isEqualFunction)(const void *item1, const void *item2,
    NSUInteger (*size)(const void *item));

  void (*_relinquishFunction)(const void *item,
    NSUInteger (*size)(const void *item));

  NSUInteger (*_sizeFunction)(const void *item);

  BOOL _shouldCopyIn;

  BOOL _usesStrongWriteBarrier;

  BOOL _usesWeakReadAndWriteBarriers;
}

@end

/* Wrapper functions to make use of the pointer functions.
 */

/* Acquire the pointer value to store for the specified item.
 */
static inline void
pointerFunctionsAcquire(NSConcretePointerFunctions *PF, void **dst, void *src)
{
  if (PF->_acquireFunction != 0)
    src = (*PF->_acquireFunction)(src, PF->_sizeFunction, PF->_shouldCopyIn);
#if	GS_WITH_GC
  if (PF->usesWeakReadAndWriteBarriers)
    GSAssignZeroingWeakPointer(dst, src);
  else
#endif
    *dst = src;
}


/* Generate an NSString description of the item
 */
static inline NSString *
pointerFunctionsDescribe(NSConcretePointerFunctions *PF, void *item)
{
  if (PF->_descriptionFunction != 0)
    return (*PF->_descriptionFunction)(item);
  return nil;
}


/* Generate the hash of the item
 */
static inline NSUInteger
pointerFunctionsHash(NSConcretePointerFunctions *PF, void *item)
{
  if (PF->_hashFunction != 0)
    return (*PF->_hashFunction)(item, PF->_sizeFunction);
  return (NSUInteger)item;
}


/* Compare two items for equality
 */
static inline BOOL
pointerFunctionsEqual(NSConcretePointerFunctions *PF, void *item1, void *item2)
{
  if (PF->_isEqualFunction != 0)
    return (*PF->_isEqualFunction)(item1, item2, PF->_sizeFunction);
  if (item1 == item2)
    return YES;
  return NO;
}


/* Relinquish the specified item and set it to zero.
 */
static inline void
pointerFunctionsRelinquish(NSConcretePointerFunctions *PF, void **itemptr)
{
  if (PF->_relinquishFunction != 0)
    (*PF->_relinquishFunction)(*itemptr, PF->_sizeFunction);
  if (PF->_usesWeakReadAndWriteBarriers)
    GSAssignZeroingWeakPointer(itemptr, (void*)0);
  else
    *itemptr = 0;
}

