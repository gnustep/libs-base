/* Interface for behaviors for Obj-C, "for Protocols with implementations".
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
*/ 

#ifndef __behavior_h_GNUSTEP_BASE_INCLUDE
#define __behavior_h_GNUSTEP_BASE_INCLUDE

#include <objc/objc-api.h>

/* Call this method from CLASS's +initialize method to add a behavior
   to CLASS.  A "behavior" is like a protocol with an implementation.

   This functions adds to CLASS all the instance and factory methods
   of BEHAVIOR as well as the instance and factory methods of
   BEHAVIOR's superclasses (We stop adding super classes as soon as we
   encounter a common ancestor.)  CLASS and BEHAVIOR should share the
   same instance variable layout.

   We do not yet deal with Protocols; perhaps we should. 

   The semantics of this stuff is pretty fragile.  I don't recommend
   that you use it in code you write.  It might go away completely in
   future. 

*/

void behavior_class_add_class (Class class, 
			       Class behavior);
void behavior_class_add_category (Class class, 
				  struct objc_category *category);
void behavior_class_add_methods (Class class, 
				 struct objc_method_list *methods);

/* The old deprecated interface */
void class_add_behavior (Class class, Class behavior);

/* This macro may go away in future.
   Use it carefully, you can really screw yourself up by sending to 
   a CLASS with a different instance variable layout than "self". */

#define CALL_METHOD_IN_CLASS(CLASS, METHOD, ARGS...)	\
((*(get_imp([CLASS class], @selector(METHOD))))		\
  (self, @selector(METHOD), ## ARGS))

/* Set to non-zero if you want debugging messages on stderr. */
void set_behavior_debug(int i);

#endif /* __behavior_h_GNUSTEP_BASE_INCLUDE */
