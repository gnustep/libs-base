/* Performance enhancing utilities GNUStep
   Copyright (C) 1998 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: October 1998
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#ifndef fast_x_INCLUDE
#define fast_x_INCLUDE

#include <base/preface.h>
#include <objc/objc-api.h>
#include <Foundation/NSObject.h>

#ifndef	INLINE
#define	INLINE	inline
#endif

/*
 *	This file is all to do with improving performance by avoiding the
 *	Objective-C messaging overhead in time-critical code.
 *
 *	THIS STUFF IS GOING AWAY!
 *
 *	The intention is to provide similar functionality in NSObjCRuntime.h
 *	There will be GNUstep specific (mostly inline) functions added to
 *	the header to provide direct access to runtime functinality and the
 *	internals of objects.  Hopefully a simple configuration option will
 *	let us build for either the GNU or the Apple runtime.
 */

/*
 *	The '_fastMallocBuffer()' function is called to get a chunk of
 *	memory that will automatically be released when the current
 *	autorelease pool goes away.
 */
GS_EXPORT void	*_fastMallocBuffer(unsigned size);

/*
 *	Fast access to class info - DON'T pass nil to these!
 */

static INLINE BOOL
fastIsInstance(id obj)
{
  return CLS_ISCLASS(obj->class_pointer);
}

static INLINE BOOL
fastIsClass(Class c)
{
  return CLS_ISCLASS(c);
}

static INLINE Class
fastClass(NSObject* obj)
{
  return ((id)obj)->class_pointer;
}

static INLINE Class
fastClassOfInstance(NSObject* obj)
{
  if (fastIsInstance((id)obj))
    return fastClass(obj);
  return Nil;
}

static INLINE Class
fastSuper(Class cls)
{
  return cls->super_class;
}

static INLINE BOOL
fastClassIsKindOfClass(Class c0, Class c1)
{
  while (c0 != Nil)
    {
      if (c0 == c1)
        return YES;
      c0 = class_get_super_class(c0);
    }
  return NO;
}

static INLINE BOOL
fastInstanceIsKindOfClass(NSObject *obj, Class c)
{
  Class	ic = fastClassOfInstance(obj);

  if (ic == Nil)
    return NO;
  return fastClassIsKindOfClass(ic, c);
}

static INLINE const char*
fastClassName(Class c)
{
  return c->name;
}

static INLINE int
fastClassVersion(Class c)
{
  return c->version;
}

static INLINE const char*
fastSelectorName(SEL s)
{
  return sel_get_name(s);
}

static INLINE const char*
fastSelectorTypes(SEL s)
{
  return sel_get_type(s);
}

/*
 *	fastZone(NSObject *obj)
 *	This function gets the zone that would be returned by the
 *	[NSObject -zone] instance method.  Using this could mess you up in
 *	the unlikely event that you had an object that had overridden the
 *	'-zone' method.
 *	This function DOES know about NXConstantString, so it's pretty safe
 *	for normal use.
 */
GS_EXPORT NSZone	*fastZone(NSObject* obj);


#endif
