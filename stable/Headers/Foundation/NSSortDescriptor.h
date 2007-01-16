/* Interface for NSSortDescriptor for GNUStep
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by:  Saso Kiselkov <diablos@manga.sk>
   Date: 2005
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02111 USA.
   */ 

#ifndef __NSSortDescriptor_h_GNUSTEP_BASE_INCLUDE
#define __NSSortDescriptor_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSArray.h>

@class NSString;

@interface NSSortDescriptor : NSObject <NSCopying, NSCoding>
{
  NSString * _key;
  BOOL _ascending;
  SEL _selector;
}

// initialization
- (id) initWithKey: (NSString *) key ascending: (BOOL) ascending;
- (id) initWithKey: (NSString *) key
         ascending: (BOOL) ascending
          selector: (SEL) selector;

// getting information about a sort descriptor's setup
- (BOOL) ascending;
- (NSString *) key;
- (SEL) selector;

// using sort descriptors
- (NSComparisonResult) compareObject: (id) object1 toObject: (id) object2;
- (id) reversedSortDescriptor;

@end

@interface NSArray (NSSortDescriptorSorting)

- (NSArray *) sortedArrayUsingDescriptors: (NSArray *) sortDescriptors;

@end

@interface NSMutableArray (NSSortDescriptorSorting)

- (void) sortUsingDescriptors: (NSArray *) sortDescriptors;

@end

#endif /* __NSSortDescriptor_h_GNUSTEP_BASE_INCLUDE */
