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
#define	EXPOSE_NSXMLDTD_IVARS	1
#define	EXPOSE_NSXMLDTDNode_IVARS	1
#define	EXPOSE_NSXMLDocument_IVARS	1
#define	EXPOSE_NSXMLElement_IVARS	1
#define	EXPOSE_NSXMLNode_IVARS	1
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
