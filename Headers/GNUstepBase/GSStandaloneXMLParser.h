/** Interface of a standalone (no libxml2) NSXMLParser for GNUStep
   Copyright (C) 2004-2026 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: May 2004

   StandaloneParser additions based on code by Nikolaus Schaller

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

   */

#ifndef __GSStandaloneXMLParser_h_GNUSTEP_BASE_INCLUDE
#define __GSStandaloneXMLParser_h_GNUSTEP_BASE_INCLUDE
#import <GNUstepBase/GSVersionMacros.h>

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

#import <Foundation/Foundation.h>

#if	defined(__cplusplus)
extern "C" {
#endif

/* We have the native (standalone) parser which does not depend upon
 * (and is not as strict as) libxml2, and can get that behavior
 * by using the GSStandaloneXMLParser class.
 */
GS_EXPORT_CLASS
@interface      GSStandaloneXMLParser : NSXMLParser
{
@private
  void	*_standalone;
}

/** Controls whether the parser accepts HTML (XHMTL) documents.  Turning
 * this on implicitly closes unmatched start elements when any enclosing
 * element is closed (rather than being treated as an error).
 */
- (void) setAcceptHTML: (BOOL)flag;

/** Returns the current parser tag path: an array containing the names of
 * the XML element tags encountered in a nested set of elements.  The first
 * name in the array is the outermost element, the last the innermost.
 */
- (NSArray*) tagPath;
@end


#if     defined(__cplusplus) 
}  
#endif

#endif  /* OS_API_VERSION(GS_API_NONE,GS_API_NONE) */
   
#endif  /* __GSStandaloneXMLParser_h_GNUSTEP_BASE_INCLUDE */

