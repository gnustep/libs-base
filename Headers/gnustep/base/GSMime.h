
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

#include	<Foundation/NSObject.h>

@class	NSArray;
@class	NSMutableArray;
@class	NSData;
@class	NSMutableData;
@class	NSDictionary;
@class	NSMutableDictionary;
@class	NSScanner;
@class	NSString;
@class	NSMutableString;

/*
 * A trivial class for mantaining state while decoding/encoding data.
 * Each encoding type requires its own subclass.
 */
@interface	GSMimeCodingContext : NSObject
{
  BOOL		atEnd;	/* Flag to say that data has ended.	*/
}
- (BOOL) atEnd;
- (void) setAtEnd: (BOOL)flag;
@end

@interface	GSMimeDocument : NSObject
{
  NSMutableArray	*headers;
  id			content;
}

+ (GSMimeDocument*) mimeDocument;

- (BOOL) addHeader: (NSDictionary*)headerInfo;
- (NSArray*) allHeaders;
- (id) content;
- (void) deleteHeader: (NSString*)rawHeader;
- (void) deleteHeaderNamed: (NSString*)aName;
- (NSDictionary*) headerNamed: (NSString*)name;
- (NSArray*) headersNamed: (NSString*)name;
- (BOOL) setContent: (id)newContent;
- (BOOL) setHeader: (NSDictionary*)headerInfo;

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
  BOOL			complete;
  NSData		*boundary;
  GSMimeDocument	*document;
  GSMimeParser		*child;
  GSMimeCodingContext	*context;
}

+ (GSMimeParser*) mimeParser;

- (GSMimeCodingContext*) contextFor: (NSDictionary*)headerInfo;
- (NSData*) data;
- (BOOL) decodeData: (NSData*)sData
	  fromRange: (NSRange)aRange
	   intoData: (NSMutableData*)dData
	withContext: (GSMimeCodingContext*)ctxt;
- (GSMimeDocument*) document;
- (BOOL) isComplete;
- (BOOL) isInBody;
- (BOOL) isInHeaders;
- (BOOL) parse: (NSData*)input;
- (BOOL) parseHeader: (NSString*)aRawHeader;
- (BOOL) parsedHeaders;
- (BOOL) scanHeader: (NSScanner*)aScanner
	      named: (NSString*)headerName
	       inTo: (NSMutableDictionary*)info;
- (BOOL) scanPastSpace: (NSScanner*)aScanner;
- (NSString*) scanSpecial: (NSScanner*)aScanner;
- (NSString*) scanToken: (NSScanner*)aScanner;

@end

#endif
