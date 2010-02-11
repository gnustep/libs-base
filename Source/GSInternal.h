/* GSInternal
   Copyright (C) 2009 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02111 USA.
*/ 


/* This file defines macros for managing internal (hidden) instance variables
 * of a public class so that users of the public class don't need to recompile
 * their code when the class implementation is changed in new versions of the
 * library.
 *
 * The public class MUST contain an instance variable 'id _internal;' to be
 * used as a pointer to a private class containing the ivars.
 *
 * Before including this file, you must define 'GSInternal' to be the name
 * of your public class with * 'Internal' appended.
 * eg. if your class is called 'MyClass' then use the following define:
 * #define GSInternal MyClassInternal
 *
 * After including this file you can use the GS_BEGIN_INTERNAL() and
 * GS_END_INTERNAL() macros to bracket the declaration of the instance
 * variables.
 *
 * You use GS_CREATE_INTERNAL() in your intialiser to create the object
 * holding the internal instance variables, and GS_DESTROY_INTERNAL() to
 * get rid of that object (only do this if '_internal' is not nil) in
 * your -dealloc method.
 *
 * Instance variables are referenced using the 'internal->ivar' suntax or
 * the GSIV(classname,object,ivar) macro.
 *
 * If built with CLANG, with support for non-fragile instance variables,
 * rather than GCC, the compiler/runtime can simply declare instance variables
 * within the implementation file so that they are not part of the public ABI,
 * in which case the macros here mostly reduce to nothing and the generated
 * code can be much more efficient.
 */
#if	!__has_feature(objc_nonfragile_abi)

/* Code for when we don't have non-fragine instance variables
 */

/* Start declaration of internal ivars.
 */
#define	GS_BEGIN_INTERNAL(name) \
@interface	name ## Internal : NSObject \
{ \
  @public

/* Finish declaration of internal ivars.
 */
#define	GS_END_INTERNAL(name) \
} \
@end \
@implementation	name ## Internal \
@end

/* Create holder for internal ivars.
 */
#define	GS_CREATE_INTERNAL(name) \
_internal = [name ## Internal new];

/* Create holder for internal ivars.
 */
#define	GS_DESTROY_INTERNAL(name) \
DESTROY(_internal);

#undef	internal
#define	internal	((GSInternal*)_internal)
#undef	GSIVar
#define	GSIVar(X,Y)	(((GSInternal*)(X->_internal))->Y)

#else	/* !__has_feature(objc_nonfragile_abi) */

/* We have support for non-fragile ivars
 */

#define	GS_BEGIN_INTERNAL(name) \
@interface	name \
{

/* Finish declaration of internal ivars.
 */
#define	GS_END_INTERNAL(name) \
} \
@end

/* Create holder for internal ivars (nothing to do).
 */
#define	GS_CREATE_INTERNAL(name)

#define	GS_DESTROY_INTERNAL(name)

/* Define constant to reference internal ivars.
 */
#undef	internal
#define	internal	self
#undef	GSIVar
#define	GSIVar(X,Y)	((X)->Y)

#endif	/* !__has_feature(objc_nonfragile_abi) */


