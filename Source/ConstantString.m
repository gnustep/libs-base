/* Implementation for GNU Objective-C ConstantString object
   Copyright (C) 1993,1994, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#include <gnustep/base/String.h>
#include <gnustep/base/IndexedCollectionPrivate.h>

@implementation ConstantString

// INITIALIZING;

/* This must work without sending any messages to content objects */
- (void) empty
{
  [self shouldNotImplement:_cmd];
}

// REPLACING;

- replaceAllStrings: (String*)oldString with: (String*)newString
{
  return [self shouldNotImplement:_cmd];
}

- replaceFirstString: (String*)oldString with: (String*)newString
{
  return [self shouldNotImplement:_cmd];
}

- replaceFirstString: (String*)oldString 
    afterIndex: (unsigned)index 
    with: (String*)newString
{
  return [self shouldNotImplement:_cmd];
}

- setToAllCapitals
{
  return [self shouldNotImplement:_cmd];
}

- setToInitialCapitals
{
  return [self shouldNotImplement:_cmd];
}

- setToLowerCase
{
  return [self shouldNotImplement:_cmd];
}

- trimBlanks
{
  return [self shouldNotImplement:_cmd];
}


// SETTING VALUES;

- setIntValue: (int)anInt
{
  return [self shouldNotImplement:_cmd];
}

- setFloatValue: (float)aFloat
{
  return [self shouldNotImplement:_cmd];
}

- setDoubleValue: (double)aDouble
{
  return [self shouldNotImplement:_cmd];
}

- setCStringValue: (const char *)aCString
{
  return [self shouldNotImplement:_cmd];
}

- setStringValue: (String*)aString
{
  return [self shouldNotImplement:_cmd];
}

@end

#if 0 /* Moved to NSString.m */
@implementation NXConstantString
@end
#endif
