/** Interface for MIME parsing classes

   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald  <rfm@gnu.org>

   Date: October 2000
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   AutogsdocSource: Additions/GSMime.m
*/

#ifndef __GSMime_h_GNUSTEP_BASE_INCLUDE
#define __GSMime_h_GNUSTEP_BASE_INCLUDE
#import <GNUstepBase/GSVersionMacros.h>

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

#ifdef NeXT_Foundation_LIBRARY
#import <Foundation/Foundation.h>
#else
#import	<Foundation/NSObject.h>
#import	<Foundation/NSString.h>
#import	<Foundation/NSMapTable.h>
#endif

#if	defined(__cplusplus)
extern "C" {
#endif

@class	NSArray;
@class	NSMutableArray;
@class	NSData;
@class	NSMutableData;
@class	NSDictionary;
@class	NSMutableDictionary;
@class	NSScanner;

/*
 * A trivial class for mantaining state while decoding/encoding data.
 * Each encoding type requires its own subclass.
 */
@interface	GSMimeCodingContext : NSObject
{
  BOOL		atEnd;	/* Flag to say that data has ended.	*/
}
- (BOOL) atEnd;
- (BOOL) decodeData: (const void*)sData
             length: (NSUInteger)length
	   intoData: (NSMutableData*)dData;
- (void) setAtEnd: (BOOL)flag;
@end

@interface      GSMimeHeader : NSObject <NSCopying>
{
#if	GS_EXPOSE(GSMimeHeader)
  NSString              *name;
  NSString              *value;
  NSMutableDictionary   *objects;
  NSMutableDictionary	*params;
  void			*_unused;
#endif
}
+ (NSString*) makeQuoted: (NSString*)v always: (BOOL)flag;
+ (NSString*) makeToken: (NSString*)t preservingCase: (BOOL)preserve;
+ (NSString*) makeToken: (NSString*)t;
- (id) copyWithZone: (NSZone*)z;
- (NSString*) fullValue;
- (id) initWithName: (NSString*)n
	      value: (NSString*)v;
- (id) initWithName: (NSString*)n
	      value: (NSString*)v
	 parameters: (NSDictionary*)p;
- (NSString*) name;
- (NSString*) namePreservingCase: (BOOL)preserve;
- (id) objectForKey: (NSString*)k;
- (NSDictionary*) objects;
- (NSString*) parameterForKey: (NSString*)k;
- (NSDictionary*) parameters;
- (NSDictionary*) parametersPreservingCase: (BOOL)preserve;
- (NSMutableData*) rawMimeData;
- (NSMutableData*) rawMimeDataPreservingCase: (BOOL)preserve;
- (void) setName: (NSString*)s;
- (void) setObject: (id)o  forKey: (NSString*)k;
- (void) setParameter: (NSString*)v forKey: (NSString*)k;
- (void) setParameters: (NSDictionary*)d;
- (void) setValue: (NSString*)s;
- (NSString*) text;
- (NSString*) value;
@end


@interface	GSMimeDocument : NSObject <NSCopying>
{
#if	GS_EXPOSE(GSMimeDocument)
  NSMutableArray	*headers;
  id			content;
  void			*_unused;
#endif
}

+ (NSString*) charsetFromEncoding: (NSStringEncoding)enc;

/**
 * Decode the source data from base64 encoding and return the result.<br />
 * The source data is expected to be ASCII text and may be multiple
 * lines or a line of any length (decoding is very tolerant).
 */
+ (NSData*) decodeBase64: (NSData*)source;
+ (NSString*) decodeBase64String: (NSString*)source;
+ (GSMimeDocument*) documentWithContent: (id)newContent
				   type: (NSString*)type
				   name: (NSString*)name;
/**
 * Encode the source data to base64 encoding and return the result.<br />
 * The resulting data is ASCII text and contains only the base64 encoded
 * values with no line breaks or extraneous data.  This is base64 encoded
 * data in it's general format as mandated in RFC 3548.  If the data is
 * to be used as part of a MIME document body, line breaks must be
 * introduced at 76 byte intervals (GSMime does this when automatically
 * encoding data for you).  If the data is to be used in a PEM document
 * line breaks must be introduced at 74 byte intervals.
 */
+ (NSData*) encodeBase64: (NSData*)source;
+ (NSString*) encodeBase64String: (NSString*)source;
+ (NSStringEncoding) encodingFromCharset: (NSString*)charset;

- (void) addContent: (id)newContent;
- (void) addHeader: (GSMimeHeader*)info;
- (GSMimeHeader*) addHeader: (NSString*)name
                      value: (NSString*)value
		 parameters: (NSDictionary*)parameters;
- (NSArray*) allHeaders;
- (id) content;
- (id) contentByID: (NSString*)key;
- (id) contentByLocation: (NSString*)key;
- (id) contentByName: (NSString*)key;
- (id) copyWithZone: (NSZone*)z;
- (NSString*) contentFile;
- (NSString*) contentID;
- (NSString*) contentLocation;
- (NSString*) contentName;
- (NSString*) contentSubtype;
- (NSString*) contentType;
- (NSArray*) contentsByName: (NSString*)key;
- (void) convertToBase64;
- (void) convertToBinary;
- (NSData*) convertToData;
- (NSString*) convertToText;
- (void) deleteContent: (GSMimeDocument*)aPart;
- (void) deleteHeader: (GSMimeHeader*)aHeader;
- (void) deleteHeaderNamed: (NSString*)name;
- (GSMimeHeader*) headerNamed: (NSString*)name;
- (NSArray*) headersNamed: (NSString*)name;
- (NSString*) makeBoundary;
- (GSMimeHeader*) makeContentID;
- (GSMimeHeader*) makeHeader: (NSString*)name
                       value: (NSString*)value
		  parameters: (NSDictionary*)parameters;
- (GSMimeHeader*) makeMessageID;
- (NSMutableData*) rawMimeData;
- (NSMutableData*) rawMimeData: (BOOL)isOuter;
- (void) setContent: (id)newContent;
- (void) setContent: (id)newContent
	       type: (NSString*)type;
- (void) setContent: (id)newContent
	       type: (NSString*)type
	       name: (NSString*)name;
- (void) setContentType: (NSString*)newType;
- (void) setHeader: (GSMimeHeader*)info;
- (GSMimeHeader*) setHeader: (NSString*)name
                      value: (NSString*)value
		 parameters: (NSDictionary*)parameters;

@end

@interface	GSMimeParser : NSObject
{
#if	GS_EXPOSE(GSMimeParser)
  NSMutableData		*data;
  unsigned char		*bytes;
  unsigned		dataEnd;
  unsigned		sectionStart;
  unsigned		lineStart;
  unsigned		lineEnd;
  unsigned		input;
  unsigned		expect;
  unsigned		rawBodyLength;
  struct {
    unsigned int	inBody:1;
    unsigned int	isHttp:1;
    unsigned int	complete:1;
    unsigned int	hadErrors:1;
    unsigned int	buggyQuotes:1;
    unsigned int	wantEndOfLine:1;
    unsigned int	excessData:1;
    unsigned int	headersOnly:1;
  } flags;
  NSData		*boundary;	// Also overloaded to hold excess
  GSMimeDocument	*document;
  GSMimeParser		*child;
  GSMimeCodingContext	*context;
  NSStringEncoding	_defaultEncoding;
  void			*_unused;
#endif
}

+ (GSMimeDocument*) documentFromData: (NSData*)mimeData;
+ (GSMimeParser*) mimeParser;

- (GSMimeCodingContext*) contextFor: (GSMimeHeader*)info;
- (NSData*) data;
- (BOOL) decodeData: (NSData*)sData
	  fromRange: (NSRange)aRange
	   intoData: (NSMutableData*)dData
	withContext: (GSMimeCodingContext*)con;
- (NSData*) excess;
- (void) expectNoHeaders;
- (BOOL) isComplete;
- (BOOL) isHttp;
- (BOOL) isInBody;
- (BOOL) isInHeaders;
- (GSMimeDocument*) mimeDocument;
- (BOOL) parse: (NSData*)d;
- (BOOL) parseHeaders: (NSData*)d remaining: (NSData**)body;
- (BOOL) parseHeader: (NSString*)aHeader;
- (BOOL) scanHeaderBody: (NSScanner*)scanner into: (GSMimeHeader*)info;
- (NSString*) scanName: (NSScanner*)scanner;
- (BOOL) scanPastSpace: (NSScanner*)scanner;
- (NSString*) scanSpecial: (NSScanner*)scanner;
- (NSString*) scanToken: (NSScanner*)scanner;
- (void) setBuggyQuotes: (BOOL)flag;
- (void) setDefaultCharset: (NSString*)aName;
- (void) setHeadersOnly;
- (void) setIsHttp;
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* OS_API_VERSION(GS_API_NONE,GS_API_NONE) */

#endif	/* __GSMime_h_GNUSTEP_BASE_INCLUDE */
