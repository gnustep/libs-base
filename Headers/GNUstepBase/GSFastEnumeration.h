/* GSFastEnumeration.h - Macros for portable fast enumeration
   Copyright (C) 2025 Free Software Foundation, Inc.

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef __GSFastEnumeration_h_GNUSTEP_BASE_INCLUDE
#define __GSFastEnumeration_h_GNUSTEP_BASE_INCLUDE

#import <GNUstepBase/GSVersionMacros.h>

#if	defined(__clang__) || (GS_GCC_MINREQ(6,1) && !defined(__MINGW__))
/** Macro to support fast enumeration on older compilers.  The arguments are
 * a type specification for the value returned by the iteration, the name of
 * a variable to hold that value, and the collection to be iterated over
 * (may also be an instance of [NSEnumerator] rather than a collection).
 */
#define GS_FOR_IN(type, var, collection) \
  for (type var in collection)\
  {
/** Macro to end a fast enumeration block on older compilers.  Its argument
 * must be identical to that of the corresponding GS_FOR_IN macro.
 */
#define GS_END_FOR(collection) }
#else
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wattributes"
void objc_enumerationMutation(id);
#pragma GCC diagnostic pop
#define GS_FOR_IN(type, var, c) \
do\
{\
  type var;\
  NSFastEnumerationState gs_##c##_enumState = { 0 };\
  id gs_##c##_items[16];\
  unsigned long gs_##c##_limit = \
    [c countByEnumeratingWithState: &gs_##c##_enumState \
                           objects: gs_##c##_items \
                             count: 16];\
  if (gs_##c##_limit)\
  {\
    unsigned long gs_startMutations = *gs_##c##_enumState.mutationsPtr;\
    do {\
      unsigned long gs_##c##counter = 0;\
      do {\
        if (gs_startMutations != *gs_##c##_enumState.mutationsPtr)\
        {\
          objc_enumerationMutation(c);\
        }\
        var = gs_##c##_enumState.itemsPtr[gs_##c##counter++];\

#define GS_END_FOR(c) \
      } while (gs_##c##counter < gs_##c##_limit);\
    } while ((gs_##c##_limit \
      = [c countByEnumeratingWithState: &gs_##c##_enumState\
			       objects: gs_##c##_items\
				 count: 16]));\
  }\
} while(0);
#endif

#endif /* __GSFastEnumeration_h_GNUSTEP_BASE_INCLUDE */
