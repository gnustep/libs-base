#ifndef	INCLUDED_GS_CATEGORIES_H
#define	INCLUDED_GS_CATEGORIES_H
/** Declaration of extension methods and functions for standard classes

   Copyright (C) 2003 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

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

   AutogsdocSource: Additions/GSCategories.m

*/

#ifndef	NO_GNUSTEP

#ifndef NeXT_Foundation_LIBRARY
#include <Foundation/NSCalendarDate.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#else
#include <Foundation/Foundation.h>
#endif

@interface NSCalendarDate (GSCategories)

- (int) weekOfYear;

@end

@interface NSData (GSCategories)

- (NSString*) hexadecimalRepresentation;
- (id) initWithHexadecimalRepresentation: (NSString*)string;
- (NSData*) md5Digest;

@end

@interface NSString (GSCategories)
- (NSString*) stringByDeletingPrefix: (NSString*)prefix;
- (NSString*) stringByDeletingSuffix: (NSString*)suffix;
- (NSString*) stringByTrimmingLeadSpaces;
- (NSString*) stringByTrimmingTailSpaces;
- (NSString*) stringByTrimmingSpaces;
- (NSString*) stringByReplacingString: (NSString*)replace
                           withString: (NSString*)by;
@end

@interface NSMutableString (GSCategories)
- (void) deleteSuffix: (NSString*)suffix;
- (void) deletePrefix: (NSString*)prefix;
- (void) replaceString: (NSString*)replace
            withString: (NSString*)by;
- (void) trimLeadSpaces;
- (void) trimTailSpaces;
- (void) trimSpaces;
@end

@interface NSNumber(GSCategories)
+ (NSValue*) valueFromString: (NSString *)string;
@end

/* This is also defined in NSObject.h, but added here for use with the
   additions library */
#ifndef NSOBJECT_GSCATEGORIES_INTERFACE
@interface NSObject (GSCategories)
- notImplemented:(SEL)aSel;
- (id) subclassResponsibility: (SEL)aSel;
- (id) shouldNotImplement: (SEL)aSel;

- (NSComparisonResult) compare: (id)anObject;
@end
#endif



#ifndef	GS_MAX_OBJECTS_FROM_STACK
/**
 * The number of objects to try to get from varargs into an array on
 * the stack ... if there are more than this, use the heap.
 * NB. This MUST be a multiple of 2
 */
#define	GS_MAX_OBJECTS_FROM_STACK	128
#endif

/**
 * <p>This is a macro designed to minimise the use of memory allocation and
 * deallocation when you need to work with a vararg list of objects.<br />
 * The objects are unpacked from the vararg list into two 'C' arrays and
 * then a code fragment you specify is able to make use of them before
 * that 'C' array is destroyed. 
 * </p>
 * <p>The firstObject argument is the name of the formal parameter in your
 * method or function which precedes the ', ...' denoting variable args.
 * </p>
 * <p>The code argument is a piece of objective-c code to be executed to
 * make use of the objects stored in the 'C' arrays.<br />
 * When this code is called the unsigned integer '__count' will contain the
 * number of objects unpacked, the pointer '__objects' will point to
 * the first object in each pair, and the pointer '__pairs' will point
 * to an array containing the second halves of the pairs of objects
 * whose first halves are in '__objects'.<br />
 * This lets you pack a list of the form 'key, value, key, value, ...'
 * into an array of keys and an array of values.
 * </p>
 */
#define GS_USEIDPAIRLIST(firstObject, code...) ({\
  va_list	__ap; \
  unsigned int	__max = GS_MAX_OBJECTS_FROM_STACK; \
  unsigned int	__count = 0; \
  id		__buf[__max]; \
  id		*__objects = __buf; \
  id		*__pairs = &__objects[__max/2]; \
  id		__obj = firstObject; \
  va_start(__ap, firstObject); \
  while (__obj != nil && __count < __max) \
    { \
      if ((__count % 2) == 0) \
	{ \
	  __objects[__count/2] = __obj; \
	} \
      else \
	{ \
	  __pairs[__count/2] = __obj; \
	} \
      __obj = va_arg(__ap, id); \
      if (++__count == __max) \
	{ \
	  while (__obj != nil) \
	    { \
	      __count++; \
	      __obj = va_arg(__ap, id); \
	    } \
	} \
    } \
  if ((__count % 2) == 1) \
    { \
      __pairs[__count/2] = nil; \
      __count++; \
    } \
  va_end(__ap); \
  if (__count > __max) \
    { \
      unsigned int	__tmp; \
      __objects = (id*)objc_malloc(__count*sizeof(id)); \
      __pairs = &__objects[__count/2]; \
      __objects[0] = firstObject; \
      va_start(__ap, firstObject); \
      for (__tmp = 1; __tmp < __count; __tmp++) \
	{ \
	  if ((__tmp % 2) == 0) \
	    { \
	      __objects[__tmp/2] = va_arg(__ap, id); \
	    } \
	  else \
	    { \
	      __pairs[__tmp/2] = va_arg(__ap, id); \
	    } \
	} \
      va_end(__ap); \
    } \
  code; \
  if (__objects != __buf) objc_free(__objects); \
})

/**
 * <p>This is a macro designed to minimise the use of memory allocation and
 * deallocation when you need to work with a vararg list of objects.<br />
 * The objects are unpacked from the vararg list into a 'C' array and
 * then a code fragment you specify is able to make use of them before
 * that 'C' array is destroyed. 
 * </p>
 * <p>The firstObject argument is the name of the formal parameter in your
 * method or function which precedes the ', ...' denoting variable args.
 * </p>
 * <p>The code argument is a piece of objective-c code to be executed to
 * make use of the objects stored in the 'C' array.<br />
 * When this code is called the unsigned integer '__count' will contain the
 * number of objects unpacked, and the pointer '__objects' will point to
 * the unpacked objects, ie. firstObject followed by the vararg arguments
 * up to (but not including) the first nil.
 * </p>
 */
#define GS_USEIDLIST(firstObject, code...) ({\
  va_list	__ap; \
  unsigned int	__max = GS_MAX_OBJECTS_FROM_STACK; \
  unsigned int	__count = 0; \
  id		__buf[__max]; \
  id		*__objects = __buf; \
  id		__obj = firstObject; \
  va_start(__ap, firstObject); \
  while (__obj != nil && __count < __max) \
    { \
      __objects[__count] = __obj; \
      __obj = va_arg(__ap, id); \
      if (++__count == __max) \
	{ \
	  while (__obj != nil) \
	    { \
	      __count++; \
	      __obj = va_arg(__ap, id); \
	    } \
	} \
    } \
  va_end(__ap); \
  if (__count > __max) \
    { \
      unsigned int	__tmp; \
      __objects = (id*)objc_malloc(__count*sizeof(id)); \
      va_start(__ap, firstObject); \
      __objects[0] = firstObject; \
      for (__tmp = 1; __tmp < __count; __tmp++) \
	{ \
	  __objects[__tmp] = va_arg(__ap, id); \
	} \
      va_end(__ap); \
    } \
  code; \
  if (__objects != __buf) objc_free(__objects); \
})


#endif	/* NO_GNUSTEP */
#endif	/* INCLUDED_GS_CATEGORIES_H */
