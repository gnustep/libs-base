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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#include <config.h>
#include <gnustep/base/preface.h>
#include <objc/objc-api.h>

#ifndef	INLINE
#define	INLINE	inline
#endif

/*
 *	This file is all to do with improving performance by avoiding the
 *	Objective-C messaging overhead in time-critical code.
 *
 *	The motiviation behind it is to keep all the information needed to
 *	do that in one place (using a single mechanism), so that optimization 
 *	attempts can be kept track of.
 *
 *	The optimisations are of three sorts -
 *
 *	1.  inline functions
 *	    There are many operations that can be speeded up by using inline
 *	    code to examine objects rather than sending messages to them to
 *	    ask them about themselves.  Often, the objc runtime provides
 *	    functions to do this, but these sometimes perform unnecessary
 *	    checks.  Here we attempt to provide some basics.
 *
 *	2.  class comparison
 *	    It is often necessary to check the class of objects - instead of
 *	    using [+class] method, we can cache certain classes in a global
 *	    structure (The [NSObject +initialize] method does the caching)
 *	    and refer to the structure elements directly.
 *
 *	3.  direct method despatch
 *	    A common techique is to obtain the method implementation for a
 *	    specific message sent to a particular class of object, and call
 *	    the implementation directly to avoid repeated lookup within the
 *	    objc runtime.
 *	    While there is no huge speed advantage to caching the method
 *	    implementations, it does make it easy to search the source for
 *	    code that is using this technique and referring to a cached
 *	    method implementation.
 */

/*
 *	Structure to cache class information.
 *	By convention, the name of the structure element is the name of the
 *	class with an underscore prepended.
 */
typedef struct {
    /*
     *	String classes
     */
    Class	_NSString;
    Class	_NSGString;
    Class	_NSGMutableString;
    Class	_NSGCString;
    Class	_NSGMutableCString;
    Class	_NXConstantString;
    Class	_NSDataMalloc;
    Class	_NSMutableDataMalloc;
} fastCls;
extern	fastCls	_fastCls;	/* Populated by _fastBuildCache()	*/

/*
 *	Structure to cache method implementation information.
 *	By convention, the name of the structure element consists of an
 *	underscore followed by the name of the class, another underscore, and
 *	the name of the method (with colons replaced by underscores).
 */
typedef struct {
    /*
     *	String implementations.
     */
    unsigned		(*_NSString_hash)();
    BOOL		(*_NSString_isEqualToString_)();
    BOOL		(*_NSGString_isEqual_)();
    BOOL		(*_NSGCString_isEqual_)();
} fastImp;
extern	fastImp	_fastImp;	/* Populated by _fastBuildCache()	*/

/*
 *	The '_fastBuildCache()' function is called to populate the cache
 *	structures.  This is (at present) called in [NSObject +initialize]
 *	but you may call it explicitly later to repopulate the cache after
 *	changes have been made to the runtime by loading of categories or
 *	by classes posing as other classes.
 */
extern void	_fastBuildCache();


/*
 *	Fast access to class info - DON'T pass nil to these!
 *	These should really do different things conditional upon the objc
 *	runtime in use, but we will probably only ever want to support the
 *	latest GNU runtime, so I haven't bothered about that.
 */

static INLINE BOOL
fastIsInstance(id obj)
{
    return CLS_ISCLASS(obj->class_pointer);
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
    while (c0 != Nil) {
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
extern NSZone	*fastZone(NSObject* obj);

