/* Collection definitions for the use of subclass implementations only
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#ifndef __CollectionPrivate_h_INCLUDE_GNU
#define __CollectionPrivate_h_INCLUDE_GNU

#include <objects/stdobjects.h>
#include <objects/eltfuncs.h>

@interface Collection (ArchivingHelpers)
/* These methods should never be called except in order inside 
   -write: and -read: */
- _writeInit: (TypedStream*)aStream;
- _readInit: (TypedStream*)aStream;
- _writeContents: (TypedStream*)aStream;
- _readContents: (TypedStream*)aStream;

/* The Coding versions of the above */
- (void) _encodeCollectionWithCoder: (Coder*) aCoder;
+ _newCollectionWithCoder: (Coder*) aCoder;
- (void) _encodeContentsWithCoder: (Coder*)aCoder;
- (void) _decodeContentsWithCoder: (Coder*)aCoder;
@end

  
/* To be used inside methods for getting the element comparison function.
   This macro could be redefined when the comparison function is an
   instance variable or is fixed.
   I'm wondering if I should put _comparison_function back as an instance 
   variable in Collection. */
#define COMPARISON_FUNCTION [self comparisonFunction]

/* Use this for comparing elements in your implementation. */
#define COMPARE_ELEMENTS(ELT1, ELT2) \
  ((*COMPARISON_FUNCTION)(ELT1, ELT2))

#define ELEMENTS_EQUAL(ELT1, ELT2) \
  (COMPARE_ELEMENTS(ELT1, ELT2) == 0)

#define ENCODING_IS_OBJECT(ENCODING) \
  ((*(ENCODING) == _C_ID) || (*(ENCODING) == _C_CLASS))

/* To be used inside a method for determining if the contents  are objects */
#define CONTAINS_OBJECTS \
  (ENCODING_IS_OBJECT([self contentType]))

/* Used inside a method for sending "-retain" if necessary */
#define RETAIN_ELT(ELT) \
  if (CONTAINS_OBJECTS) [ELT.id_u retain]

/* Used inside a method for sending "-release" if necessary */
#define RELEASE_ELT(ELT) \
  if (CONTAINS_OBJECTS) [ELT.id_u release]

/* Used inside a method for sending "-autorelease" if necessary */
#define AUTORELEASE_ELT(ELT) \
  ({if (CONTAINS_OBJECTS) ((elt)[ELT.id_u autorelease]) else ELT;})


/* Error Handling */

#define RETURN_BY_CALLING_EXCEPTION_FUNCTION(FUNC) \
return (*FUNC)(__builtin_apply_args())


/* To be used inside a method for making sure the contents are objects.
   typeof(DEFAULT_ERROR_RETURN) must be the same type as the method
   returns. */
#define CHECK_CONTAINS_OBJECTS_ERROR() \
({if (!(CONTAINS_OBJECTS)) \
{ \
  [self error:"in %s, requires object contents", sel_get_name(_cmd)]; \
}})

/* To be used inside a method whenever a particular element isn't found */
#define ELEMENT_NOT_FOUND_ERROR(AN_ELEMENT) \
([self error:"in %s, element not found.", sel_get_name(_cmd)])

/* To be used inside a method whenever there is no element matching the 
   needed criteria */
#define NO_ELEMENT_FOUND_ERROR() \
([self error:"in %s, no element found.", sel_get_name(_cmd)])

#endif /* __CollectionPrivate_h_INCLUDE_GNU */
