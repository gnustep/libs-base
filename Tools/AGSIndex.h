#ifndef	_INCLUDED_AGSINDEX_H
#define	_INCLUDED_AGSINDEX_H
/** 

   <title>AGSIndex ... a class to create references for a gsdoc file</title>
   Copyright <copy>(C) 2001 Free Software Foundation, Inc.</copy>

   Written by:  <author name="Richard Frith-Macdonald">
   <email>richard@brainstorm.co.uk</email></author>
   Created: October 2001

   This file is part of the GNUstep Project

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   You should have received a copy of the GNU General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

   */

#include        <Foundation/GSXML.h>

@interface AGSIndex : NSObject
{
  NSMutableDictionary	*refs;
  NSString		*base;	// Not retained
  NSString		*unit;	// Not retained
}
- (void) makeRefs: (GSXMLNode*)node;
- (void) mergeRefs: (NSDictionary*)more;
- (NSMutableDictionary*) refs;
- (void) setGlobalRef: (NSString*)ref type: (NSString*)type;
- (void) setUnitRef: (NSString*)ref type: (NSString*)type;
@end
#endif
