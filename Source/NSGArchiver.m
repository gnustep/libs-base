/* Concrete NSArchiver for GNUStep based on GNU Coder class
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: April 1995
   
   This file is part of the GNU Objective C Class Library.
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include <objects/stdobjects.h>
#include <Foundation/NSGArchiver.h>
#include <Foundation/NSGCoder.h>
#include <objects/behavior.h>

@implementation NSGArchiver

+ (void) initialize
{
  static int done = 0;
  [self error:"This class not ready for business yet."];
  if (!done)
    {
      done = 1;
      class_add_behavior([NSGArchiver class], [NSGCoder class]);
    }
}

/* This is the designated initializer */
- (id) initForWritingWithMutableData: (NSMutableData*)mdata
{
  [self initEncodingOnStream:mdata];
  return self;
}
@end
