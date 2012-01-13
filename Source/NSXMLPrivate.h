/* Private header for libxml2 wrapping components
   Copyright (C) 2009 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Created: Februrary 2009

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#ifndef	_INCLUDED_NSXMLPRIVATE_H
#define	_INCLUDED_NSXMLPRIVATE_H

#import "config.h"
#import "GNUstepBase/GSConfig.h"

#define	EXPOSE_NSXMLDTD_IVARS	1
#define	EXPOSE_NSXMLDTDNode_IVARS	1
#define	EXPOSE_NSXMLDocument_IVARS	1
#define	EXPOSE_NSXMLElement_IVARS	1
#define	EXPOSE_NSXMLNode_IVARS	1

/*
 * Macro to cast string to correct type for libxml2
 */
#define	XMLSTRING(X)	((const unsigned char*)[X UTF8String])

inline static unsigned char *XMLStringCopy(NSString *source)
{
  char *xmlstr;
  unsigned int len = [source maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
  if (len == 0)
    return NULL;
  xmlstr = malloc(len);
  [source getCString:xmlstr maxLength:len encoding:NSUTF8StringEncoding];
  return (unsigned char *)xmlstr;
}

inline static NSString*
StringFromXMLStringPtr(const unsigned char *bytes)
{
  NSString	*str;
  unsigned int length;

  if (bytes == NULL)
    return @"";

  length = strlen((char *)bytes);
  str = [[NSString alloc] initWithBytes: bytes
				       length: length
				     encoding: NSUTF8StringEncoding];
  return AUTORELEASE(str);
}

inline static NSString*
StringFromXMLString(const unsigned char *bytes, unsigned length)
{
  NSString	*str;
  
  if (bytes == NULL)
    return @"";

  str = [[NSString alloc] initWithBytes: bytes
				       length: length
				     encoding: NSUTF8StringEncoding];
  return AUTORELEASE(str);
}

#define MY_DOC	((xmlDoc *)internal->node)
#define MY_NODE ((xmlNode *)internal->node)
#define MY_ATTR ((xmlAttr *)internal->node)
#define MY_ELEM ((xmlElement *)internal->node)

/* Instance variables for NSXMLNode.  This macro needs to be defined before
 * the NSXMLNode.h header is imported and before GSInternal.h is imported.
 *
 * Description of internal ivars:
 * - `children': The primary storage for the descendant nodes. We use an NSArray
 *   here until somebody finds out it's not fast enough.
 * - `childCount': For efficiency, we cache the count. This means we need to
 *   update it whenever the children change.
 * - `previousSibling', `nextSibling': Tree walking is a common operation for
 *   XML. [parent->children objectAtIndex: index + 1] would be a
 *   straightforward way to obtain the next sibling of the node, but it hurts
 *   performance quite a bit. So we cache the siblings and update them when the
 *   nodes are changed.
 */
#define GS_NSXMLNode_IVARS \
  void		 *handle; \
  NSUInteger	  kind; \
  NSXMLNode      *parent; \
  NSUInteger      index; \
  id              objectValue; \
  NSString       *URI; \
  NSXMLNode      *previousSibling; \
  NSXMLNode      *nextSibling;\
  NSUInteger      options; \
  void           *node;  \
  NSMutableArray *subNodes; \


/* When using the non-fragile ABI, the instance variables are exposed to the
 * compiler within the class declaration, so we don't need to incorporate
 * superclass variables into the subclass declaration.
 * But with the fragile ABI we need to allocate a single internal structure
 * containing the private variables for both the subclass and the superclass.
 */
#if	GS_NONFRAGILE
#define	SUPERIVARS(X)
#else
#define	SUPERIVARS(X)	X
#endif

/* Instance variables for NSXMLDocument with/without the instance
 * variable 'inherited' from NSXMLNode.
 * This macro needs to be defined before the NSXMLDocument.h header
 * is imported and before GSInternal.h is imported.
 */
#define GS_NSXMLDocument_IVARS SUPERIVARS(GS_NSXMLNode_IVARS) \
  NSXMLDTD     		*docType; \
  NSString     		*MIMEType; \
  NSUInteger   		fidelityMask; \
  NSInteger		contentKind; \


/* Instance variables for NSXMLDTD with/without the instance
 * variable 'inherited' from NSXMLNode.
 * This macro needs to be defined before the NSXMLDTD.h header
 * is imported and before GSInternal.h is imported.
 */
#define GS_NSXMLDTD_IVARS SUPERIVARS(GS_NSXMLNode_IVARS) \
  NSString      *publicID; \
  NSString      *systemID; \
  NSMutableDictionary   *entities; \
  NSMutableDictionary   *elements; \
  NSMutableDictionary   *notations; \
  NSMutableDictionary   *attributes; \
  NSString              *original; \


/* Instance variables for NSXMLDTDNode with/without the instance
 * variable 'inherited' from NSXMLNode.
 * This macro needs to be defined before the NSXMLDTDNode.h header
 * is imported and before GSInternal.h is imported.
 */
#define GS_NSXMLDTDNode_IVARS SUPERIVARS(GS_NSXMLNode_IVARS) \
  NSUInteger	DTDKind; \
  NSString	*notationName; \
  NSString	*publicID; \
  NSString	*systemID; \


/* Instance variables for NSXMLElement with/without the instance
 * variable 'inherited' from NSXMLNode.
 * This macro needs to be defined before the NSXMLElement.h header
 * is imported and before GSInternal.h is imported.
 */
#define GS_NSXMLElement_IVARS SUPERIVARS(GS_NSXMLNode_IVARS)

#import "Foundation/NSArray.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDebug.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSString.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSXMLNode.h"
#import "Foundation/NSXMLDocument.h"
#import "Foundation/NSXMLDTDNode.h"
#import "Foundation/NSXMLDTD.h"
#import "Foundation/NSXMLElement.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

#ifdef	HAVE_LIBXML

/* Avoid problems on systems where the xml headers use 'id'
 */
#define	id	GSXMLID

/* libxml headers */
#include <libxml/tree.h>
#include <libxml/entities.h>
#include <libxml/parser.h>
#include <libxml/parserInternals.h>
#include <libxml/HTMLparser.h>
#include <libxml/xmlmemory.h>
#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>

#ifdef HAVE_LIBXSLT
#include <libxslt/xslt.h>
#include <libxslt/xsltInternals.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>
#endif /* HAVE_LIBXSLT */

#undef	id

#endif /* HAVE_LIBXML */

#endif

