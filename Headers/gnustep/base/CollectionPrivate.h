/* Collection definitions for the use of subclass implementations only
   Copyright (C) 1993,1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

   This file is part of the Gnustep Base Library.

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

#ifndef __CollectionPrivate_h_GNUSTEP_BASE_INCLUDE
#define __CollectionPrivate_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>

@interface ConstantCollection (ArchivingHelpers)
/* These methods should never be called except in order, and inside 
   -encodeWithCoder: and -decodeWithCoder: */
- (void) _encodeCollectionWithCoder: (id <Encoding>)aCoder;
- _initCollectionWithCoder: (id <Decoding>)aCoder;
- (void) _encodeContentsWithCoder: (id <Encoding>)aCoder;
- (void) _decodeContentsWithCoder: (id <Decoding>)aCoder;
@end

@interface ConstantCollection (DeallocationHelpers)

/* Empty the internals of a collection after the contents have
   already been released. */
- (void) _collectionEmpty;

- (void) _collectionReleaseContents;

/* Deallocate the internals of a collection after the contents 
   have already been released. */
- (void) _collectionDealloc;

@end

#endif /* __CollectionPrivate_h_GNUSTEP_BASE_INCLUDE */
