
/* Interface for MIME parsing classes

   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard frith-Macdonald  <rfm@gnu.org>

   Date: October 2000
   
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
*/

#ifndef __GSMIME_H__
#define __GSMIME_H__

#include	<Foundation/NSArray.h>
#include	<Foundation/NSData.h>
#include	<Foundation/NSDictionary.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSScanner.h>

@interface	GSMimeDocument : NSObject
{
  NSMutableArray	*headers;
  id			content;
  NSData		*boundary;
}

+ (GSMimeDocument*) mimeDocument;

- (BOOL) addHeader: (NSString*)aHeader;
- (NSData*) boundary;
- (id) content;
- (void) deleteHeader: (NSString*)aHeader;
- (void) deleteHeaderNamed: (NSString*)aName;
- (NSArray*) infoForAllHeaders;
- (NSDictionary*) infoForHeaderNamed: (NSString*)name;
- (NSArray*) infoForHeadersNamed: (NSString*)name;
- (BOOL) parseHeader: (NSScanner*)aScanner
	       named: (NSString*)name
		inTo: (NSMutableDictionary*)info;
- (BOOL) setContent: (id)newContent;
- (BOOL) setHeader: (NSString*)aHeader;

@end

@interface	GSMimeParser : NSObject
{
  NSMutableData		*data;
  unsigned char		*bytes;
  unsigned		dataEnd;
  unsigned		sectionStart;
  unsigned		lineStart;
  unsigned		lineEnd;
  unsigned		input;
  BOOL			inBody;
  GSMimeDocument	*document;
}

+ (GSMimeParser*) mimeParser;

- (GSMimeDocument*) document;
- (BOOL) parse: (NSData*)input;
- (BOOL) parsedHeaders;

@end

#endif
