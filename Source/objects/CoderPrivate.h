/* Private interface for GNU Objective-C coder object for use serializing
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: February 1996
   
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

#ifndef __CoderPrivate_h_OBJECTS_INCLUDE
#define __CoderPrivate_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/Coder.h>
#include <objects/CStreaming.h>

enum {
  CODER_OBJECT_NIL = 0, 
  CODER_OBJECT, 
  CODER_OBJECT_ROOT, 
  CODER_OBJECT_REPEATED, 
  CODER_OBJECT_FORWARD_REFERENCE,
  CODER_OBJECT_FORWARD_SATISFIER,
  CODER_OBJECT_CLASS, 
  CODER_CLASS_NIL, 
  CODER_CLASS, 
  CODER_CLASS_REPEATED,
  CODER_CONST_PTR_NULL, 
  CODER_CONST_PTR, 
  CODER_CONST_PTR_REPEATED
};

#define DOING_ROOT_OBJECT (interconnect_stack_height != 0)

@interface Coder (Private)
- _initWithCStream: (id <CStreaming>) cs formatVersion: (int) version;
- (BOOL) _coderHasObjectReference: (unsigned)xref;
@end

#define SIGNATURE_FORMAT_STRING \
@"GNU Objective C Class Library %s version %d\n"

#define NO_SEL_TYPES "none"

#endif /* __CoderPrivate_h_OBJECTS_INCLUDE */
