/* Interface for behaviors for Obj-C, "for Protocols with implementations".
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995

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

#ifndef __behavior_h_OBJECTS_INCLUDE
#define __behavior_h_OBJECTS_INCLUDE

/* Call this method from CLASS's +initialize method to add a behavior
   to CLASS.  A "behavior" is like a protocol with an implementation.

   This functions adds to CLASS all the instance and factory methods
   of BEHAVIOR as well as the instance and factory methods of
   BEHAVIOR's superclasses (We stop adding super classes as soon as we
   encounter a common ancestor.)  CLASS and BEHAVIOR should share the
   same instance variable layout.

   xxx We do not yet deal with Protocols, but we should. */
void class_add_behavior (Class class, Class behavior);


/* Set to non-zero if you want debugging messages on stderr. */
void set_behavior_debug(int i);

#endif /* __behavior_h_OBJECTS_INCLUDE */
