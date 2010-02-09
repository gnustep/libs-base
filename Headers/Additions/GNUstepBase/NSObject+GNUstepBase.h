/** Declaration of extension methods for base additions

   Copyright (C) 2003-2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   and:         Adam Fedor <fedor@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

*/

#ifndef	INCLUDED_NSObject_GNUstepBase_h
#define	INCLUDED_NSObject_GNUstepBase_h

#include <GNUstepBase/GSVersionMacros.h>
#include <Foundation/Foundation.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

@interface NSObject (GNUstepBase)
- (id) notImplemented: (SEL)aSel;
- (id) subclassResponsibility: (SEL)aSel;
- (id) shouldNotImplement: (SEL)aSel;
/**
  WARNING: The -compare: method for NSObject is deprecated
           due to subclasses declaring the same selector with 
	   conflicting signatures.
           Comparision of arbitrary objects is not just meaningless
           but also dangerous as most concrete implementations
           expect comparable objects as arguments often accessing
	   instance variables directly.
	   This method will be removed in a future release.
*/
- (NSComparisonResult) compare: (id)anObject;
@end

#endif	/* OS_API_VERSION */

#if	defined(__cplusplus)
}
#endif

#endif	/* INCLUDED_NSObject_GNUstepBase_h */

