/* Interface for Objective-C MappedCollector collection object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#ifndef __MappedCollector_h_GNUSTEP_BASE_INCLUDE
#define __MappedCollector_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/KeyedCollection.h>

@interface MappedCollector : KeyedCollection
{
  id <KeyedCollecting> _map;
  id <KeyedCollecting> _domain;  
}

- initWithCollection: (id <KeyedCollecting>)aDomain 
  map: (id <KeyedCollecting>)aMap;

@end

#endif /* __MappedCollector_h_GNUSTEP_BASE_INCLUDE */
