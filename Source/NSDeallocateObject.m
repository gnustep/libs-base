/* Implementation of NSDeallocateObject() for GNUStep
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994
   
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

void NSDeallocateObject(NSObject *anObject)
{
  if ((anObject!=nil) && CLS_ISCLASS(((id)anObject)->class_pointer))
    {
      NSZone z = [anObject zone];
      ((id)anObject)->class_pointer = (void*) 0xdeadface;
      NSZoneFree (z, anObject);
    }
  return;
}
