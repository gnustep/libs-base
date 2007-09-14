/** Interface for behaviors for Obj-C, "for Protocols with implementations".
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

  AutogsdocSource: Additions/behavior.m

*/ 

#ifndef __behavior_h_GNUSTEP_BASE_INCLUDE
#define __behavior_h_GNUSTEP_BASE_INCLUDE
#include <GNUstepBase/GSVersionMacros.h>

#include <GNUstepBase/GSObjCRuntime.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

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

GS_EXPORT void behavior_class_add_class (Class class, 
			       Class behavior);
GS_EXPORT void behavior_class_add_category (Class class, 
				  struct objc_category *category);
GS_EXPORT void behavior_class_add_methods (Class class, 
				 struct objc_method_list *methods);

/* Set to non-zero if you want debugging messages on stderr. */
GS_EXPORT void behavior_set_debug(int i);

#endif	/* OS_API_VERSION(GS_API_NONE,GS_API_NONE) */

#if	defined(__cplusplus)
}
#endif

#endif /* __behavior_h_GNUSTEP_BASE_INCLUDE */
