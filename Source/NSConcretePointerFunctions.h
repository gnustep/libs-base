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

