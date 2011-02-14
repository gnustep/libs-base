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
 * The public class MUST declare its instance variables using code of the
 * form:
 * #if	GS_NONFRAGILE
 * #  if defined(GS_X_IVARS)
 * @public GS_X_IVARS;
 * #  endif
 * #else
 * @private id _internal;
 * #endif
 *
 * Before including the header file containing the public class declaration,
 * you must define GS_X_IVARS (where X is the class name) to be the
 * list of actual instance variable declarations for the class.
 *
 * Before including this file, you must define 'GSInternal' to be the name
 * of your public class with * 'Internal' appended.
 * eg. if your class is called 'MyClass' then use the following define:
 * #define GSInternal MyClassInternal
 *
 * After including this file you can use the GS_PRIVATE_INTERNAL() macro
 * to declare the private subclass used to hold real instance variables.
 * The argument to this macro is the public class name (the GS_X_IVARS
 * list must also be defined).
 *
 * You use GS_CREATE_INTERNAL() in your intialiser to create the object
 * holding the internal instance variables, and GS_DESTROY_INTERNAL() to
 * get rid of that object  in your -dealloc method.
 *
 * Instance variables are referenced using the 'internal->ivar' suntax or
 * the GSIV(classname,object,ivar) macro.
 *
 */
#if	!GS_NONFRAGILE

/* Code for when we don't have non-fragile instance variables
 */

/* Start declaration of internal ivars.
 */
#define	GS_PRIVATE_INTERNAL(name) \
@interface	name ## Internal : NSObject \
{ \
@public \
GS_##name##_IVARS; \
} \
@end \
@implementation	name ## Internal \
@end

/* Create holder for internal ivars.
 */
#define	GS_CREATE_INTERNAL(name) \
_internal = [name ## Internal new];

/* Destroy holder for internal ivars.
 */
#define	GS_DESTROY_INTERNAL(name) \
if (_internal != 0) DESTROY(_internal);

#undef	internal
#define	internal	((GSInternal*)_internal)
#undef	GSIVar
#define	GSIVar(X,Y)	(((GSInternal*)(X->_internal))->Y)

#else	/* GS_NONFRAGILE */

/* We have support for non-fragile ivars
 */

#define	GS_PRIVATE_INTERNAL(name) 

#define	GS_CREATE_INTERNAL(name)

#define	GS_DESTROY_INTERNAL(name)

/* Define constant to reference internal ivars.
 */
#undef	internal
#define	internal	self
#undef	GSIVar
#define	GSIVar(X,Y)	((X)->Y)

#endif	/* GS_NONFRAGILE */


