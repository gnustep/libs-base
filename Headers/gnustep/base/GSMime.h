
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

   AutogsdocSource: Additions/GSMime.m
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

@interface      GSMimeHeader : NSObject
{
  NSString              *name;
  NSString              *value;
  NSMutableDictionary   *objects;
  NSMutableDictionary   *params;
}
+ (NSString*) makeQuoted: (NSString*)v;
+ (NSString*) makeToken: (NSString*)t;
- (id) initWithName: (NSString*)n
	      value: (NSString*)v
	 parameters: (NSDictionary*)p;
- (NSString*) name;
- (id) objectForKey: (NSString*)k;
- (NSDictionary*) objects;
- (NSString*) parameterForKey: (NSString*)k;
- (NSDictionary*) parameters;
- (void) setName: (NSString*)s;
- (void) setObject: (id)o  forKey: (NSString*)k;
- (void) setParameter: (NSString*)v forKey: (NSString*)k;
- (void) setParameters: (NSDictionary*)d;
- (void) setValue: (NSString*)s;
- (NSString*) text;
- (NSString*) value;
@end


@interface	GSMimeDocument : NSObject
{
  NSMutableArray	*headers;
  id			content;
}

+ (GSMimeDocument*) mimeDocument;

- (BOOL) addContent: (id)newContent;
- (BOOL) addHeader: (GSMimeHeader*)info;
- (NSArray*) allHeaders;
- (id) content;
- (id) contentByID: (NSString*)key;
- (id) contentByName: (NSString*)key;
- (NSString*) contentFile;
- (NSString*) contentID;
- (NSString*) contentName;
- (NSString*) contentSubType;
- (NSString*) contentType;
- (void) deleteHeader: (GSMimeHeader*)aHeader;
- (void) deleteHeaderNamed: (NSString*)name;
- (GSMimeHeader*) headerNamed: (NSString*)name;
- (NSArray*) headersNamed: (NSString*)name;
- (GSMimeHeader*) makeContentID;
- (BOOL) setContent: (id)newContent;
- (BOOL) setContent: (id)newContent
	       type: (NSString*)type
	    subType: (NSString*)subType
	       name: (NSString*)name;
- (BOOL) setHeader: (GSMimeHeader*)info;

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
  unsigned		expect;
  unsigned		rawBodyLength;
  BOOL			inBody;
  BOOL			isHttp;
  BOOL			complete;
  NSData		*boundary;
  GSMimeDocument	*document;
  GSMimeParser		*child;
  GSMimeCodingContext	*context;
}

+ (GSMimeDocument*) documentFromData: (NSData*)mimeData;
+ (GSMimeParser*) mimeParser;

- (GSMimeCodingContext*) contextFor: (GSMimeHeader*)info;
- (NSData*) data;
- (BOOL) decodeData: (NSData*)sData
	  fromRange: (NSRange)aRange
	   intoData: (NSMutableData*)dData
	withContext: (GSMimeCodingContext*)con;
- (void) expectNoHeaders;
- (BOOL) isComplete;
- (BOOL) isHttp;
- (BOOL) isInBody;
- (BOOL) isInHeaders;
- (GSMimeDocument*) mimeDocument;
- (BOOL) parse: (NSData*)d;
- (BOOL) parseHeader: (NSString*)aHeader;
- (BOOL) scanHeaderBody: (NSScanner*)scanner into: (GSMimeHeader*)info;
- (BOOL) scanPastSpace: (NSScanner*)scanner;
- (NSString*) scanSpecial: (NSScanner*)scanner;
- (NSString*) scanToken: (NSScanner*)scanner;
- (void) setIsHttp;
@end

#endif
