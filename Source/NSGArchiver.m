/* Concrete NSArchiver for GNUStep based on GNU Coder class
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: April 1995
   
   This file is part of the Gnustep Base Library.
   
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

#include <gnustep/base/preface.h>
#include <Foundation/NSGArchiver.h>
#include <gnustep/base/Archiver.h>
#include <gnustep/base/behavior.h>

@implementation NSGArchiver

+ (void) initialize
{
  if (self == [NSGArchiver class])
    class_add_behavior([NSGArchiver class], [Archiver class]);
}

@end

@implementation NSGUnarchiver

+ (void) initialize
{
  if (self == [NSGUnarchiver class])
    class_add_behavior([NSGUnarchiver class], [Unarchiver class]);
}

@end

/* Use this if you want to define any other methods... */
#define self ((Coder*)self)
