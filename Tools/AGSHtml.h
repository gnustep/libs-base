#ifndef	_INCLUDED_AGSHTML_H
#define	_INCLUDED_AGSHTML_H
/** 

   <title>AGSHtml ... a class to output html for a gsdoc file</title>
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

#include        "AGSIndex.h"

@interface AGSHtml : NSObject
{
  AGSIndex		*localRefs;
  AGSIndex		*globalRefs;
  NSMutableString	*indent;
  NSString		*base;	// Not retained
  NSString		*unit;	// Not retained
  NSString		*heading;	// Not retained
  NSString		*nextFile;	// Not retained
  NSString		*prevFile;	// Not retained
  NSString		*upFile;	// Not retained
}
- (void) decIndent;
- (void) incIndent;
- (NSString*) outputDocument: (GSXMLNode*)node;
- (void) outputNode: (GSXMLNode*)node to: (NSMutableString*)buf;
- (GSXMLNode*) outputBlock: (GSXMLNode*)node
			to: (NSMutableString*)buf
		    inPara: (BOOL)flag;
- (GSXMLNode*) outputList: (GSXMLNode*)node to: (NSMutableString*)buf;
- (GSXMLNode*) outputText: (GSXMLNode*)node to: (NSMutableString*)buf;
- (void) outputUnit: (GSXMLNode*)node to: (NSMutableString*)buf;
- (void) setGlobalRefs: (AGSIndex*)r;
- (void) setLocalRefs: (AGSIndex*)r;
@end
#endif
