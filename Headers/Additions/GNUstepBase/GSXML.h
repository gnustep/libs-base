/** Interface for XML parsing classes

   Copyright (C) 2000-2005 Free Software Foundation, Inc.

   Written by:  Michael Pakhantsov  <mishel@berest.dp.ua> on behalf of
   Brainstorm computer solutions.

   Date: Jule 2000

   Integrated by Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: September 2000
   GSXPath by Nicola Pero <nicola@brainstorm.co.uk>

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

   AutogsdocSource: Additions/GSXML.m

*/

#ifndef __GSXML_H__
#define __GSXML_H__

#ifndef NeXT_Foundation_LIBRARY
#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef	STRICT_MACOS_X
#ifndef	STRICT_OPENSTEP

@class GSXMLAttribute;
@class GSXMLDocument;
@class GSXMLNamespace;
@class GSXMLNode;
@class GSSAXHandler;

/**
 * Convenience methods for managing XML escape sequences in an NSString.
 */
@interface	NSString (GSXML)
/**
 * Convert XML special characters in the receiver (like '&amp;' and '&quot;')
 * to their escaped equivalents, and return the escaped string.
 */
- (NSString*) stringByEscapingXML;
/**
 * Convert XML escape sequences (like '&amp;'amp; and '&amp;quot;')
 * to their unescaped equivalents, and return the unescaped string.
 */
- (NSString*) stringByUnescapingXML;
@end

@interface GSXMLDocument : NSObject <NSCopying>
{
  void	*lib;	// pointer to xmllib pointer of xmlDoc struct
  BOOL	_ownsLib;
  id	_parent;
}
+ (GSXMLDocument*) documentWithVersion: (NSString*)version;

- (NSString*) description;
- (NSString*) encoding;

- (void*) lib;

- (GSXMLNode*) makeNodeWithNamespace: (GSXMLNamespace*)ns
				name: (NSString*)name
			     content: (NSString*)content;

- (GSXMLNode*) root;
- (GSXMLNode*) setRoot: (GSXMLNode*)node;

- (NSString*) version;

- (BOOL) writeToFile: (NSString*)filename atomically: (BOOL)useAuxilliaryFile;
- (BOOL) writeToURL: (NSURL*)url atomically: (BOOL)useAuxilliaryFile;

@end



@interface GSXMLNamespace : NSObject <NSCopying>
{
  void	*lib;          /* pointer to struct xmlNs in the gnome xmllib */
  id	_parent;
}

+ (NSString*) descriptionFromType: (int)type;
+ (int) typeFromDescription: (NSString*)desc;

- (NSString*) href;

- (void*) lib;
- (GSXMLNamespace*) next;
- (NSString*) prefix;
- (int) type;
- (NSString*) typeDescription;

@end

/* XML Node */

@interface GSXMLNode : NSObject <NSCopying>
{
  void  *lib;      /* pointer to struct xmlNode from libxml */
  id	_parent;
}

+ (NSString*) descriptionFromType: (int)type;
+ (int) typeFromDescription: (NSString*)desc;

- (NSDictionary*) attributes;
- (NSString*) content;
- (NSString*) description;
- (GSXMLDocument*) document;
- (NSString*) escapedContent;
- (GSXMLAttribute*) firstAttribute;
- (GSXMLNode*) firstChild;
- (GSXMLNode*) firstChildElement;
- (BOOL) isElement;
- (BOOL) isText;
- (void*) lib;
- (GSXMLAttribute*) makeAttributeWithName: (NSString*)name
				    value: (NSString*)value;
- (GSXMLNode*) makeChildWithNamespace: (GSXMLNamespace*)ns
				 name: (NSString*)name
			      content: (NSString*)content;
- (GSXMLNode*) makeComment: (NSString*)content;
- (GSXMLNamespace*) makeNamespaceHref: (NSString*)href
			       prefix: (NSString*)prefix;
- (GSXMLNode*) makePI: (NSString*)name
	      content: (NSString*)content;
- (GSXMLNode*) makeText: (NSString*)content;
- (NSString*) name;
- (GSXMLNamespace*) namespace;
- (GSXMLNamespace*) namespaceDefinitions;
- (GSXMLNode*) next;
- (GSXMLNode*) nextElement;
- (NSString*) objectForKey: (NSString*)key;
- (GSXMLNode*) parent;
- (GSXMLNode*) previous;
- (GSXMLNode*) previousElement;
- (NSMutableDictionary*) propertiesAsDictionaryWithKeyTransformationSel:
  (SEL)keyTransformSel;
- (void) setObject: (NSString*)value forKey:(NSString*)key;
- (int) type;
- (NSString*) typeDescription;
- (void) setNamespace: (GSXMLNamespace *)space;

@end

@interface GSXMLAttribute : GSXMLNode
- (NSString*) value;
@end

@interface GSXMLParser : NSObject
{
   id			src;		/* source for parsing	*/
   void			*lib;		/* parser context	*/
   GSSAXHandler		*saxHandler;	/* handler for parsing	*/
   NSMutableString	*messages;	/* append messages here	*/
}
+ (NSString*) loadEntity: (NSString*)publicId at: (NSString*)location;
+ (GSXMLParser*) parser;
+ (GSXMLParser*) parserWithContentsOfFile: (NSString*)path;
+ (GSXMLParser*) parserWithContentsOfURL: (NSURL*)url;
+ (GSXMLParser*) parserWithData: (NSData*)data;
+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler;
+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
		   withContentsOfFile: (NSString*)path;
+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
		    withContentsOfURL: (NSURL*)url;
+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
			     withData: (NSData*)data;
+ (NSString*) xmlEncodingStringForStringEncoding: (NSStringEncoding)encoding;

- (void) abortParsing;
- (int) columnNumber;
- (GSXMLDocument*) document;
- (BOOL) doValidityChecking: (BOOL)yesno;
- (int) errNo;
- (BOOL) getWarnings: (BOOL)yesno;
- (id) initWithSAXHandler: (GSSAXHandler*)handler;
- (id) initWithSAXHandler: (GSSAXHandler*)handler
       withContentsOfFile: (NSString*)path;
- (id) initWithSAXHandler: (GSSAXHandler*)handler
	withContentsOfURL: (NSURL*)url;
- (id) initWithSAXHandler: (GSSAXHandler*)handler
		 withData: (NSData*)data;

- (BOOL) keepBlanks: (BOOL)yesno;
- (int) lineNumber;
- (NSString*) messages;
- (BOOL) parse;
- (BOOL) parse: (NSData*)data;
- (NSString*) publicID;
- (void) saveMessages: (BOOL)yesno;
- (BOOL) substituteEntities: (BOOL)yesno;
- (NSString*) systemID;

@end

@interface GSHTMLParser : GSXMLParser
{
}
@end

@interface GSSAXHandler : NSObject
{
  void		*lib;	// xmlSAXHandlerPtr
  GSXMLParser	*parser;
@protected
  BOOL		isHtmlHandler;
}
+ (GSSAXHandler*) handler;
- (void*) lib;
- (GSXMLParser*) parser;

/* callbacks ... */
- (void) attribute: (NSString*)name
	     value: (NSString*)value;
- (void) attributeDecl: (NSString*)nameElement
                  name: (NSString*)name
                  type: (int)type
          typeDefValue: (int)defType
          defaultValue: (NSString*)value;
- (void) characters: (NSString*)name;
- (void) cdataBlock: (NSData*)value;
- (void) comment: (NSString*) value;
- (void) elementDecl: (NSString*)name
		type: (int)type;
- (void) endDocument;
- (void) endElement: (NSString*)elementName;
- (void) endElement: (NSString*)elementName
             prefix: (NSString*)prefix
	       href: (NSString*)href;
- (void) entityDecl: (NSString*)name
               type: (int)type
             public: (NSString*)publicId
             system: (NSString*)systemId
            content: (NSString*)content;
- (void) error: (NSString*)e;
- (void) error: (NSString*)e
     colNumber: (int)colNumber
    lineNumber: (int)lineNumber;
- (BOOL) externalSubset: (NSString*)name
             externalID: (NSString*)externalID
               systemID: (NSString*)systemID;
- (void) fatalError: (NSString*)e;
- (void) fatalError: (NSString*)e
          colNumber: (int)colNumber
         lineNumber: (int)lineNumber;
- (void*) getEntity: (NSString*)name;
- (void*) getParameterEntity: (NSString*)name;
- (void) globalNamespace: (NSString*)name
		    href: (NSString*)href
		  prefix: (NSString*)prefix;
- (int) hasExternalSubset;
- (int) hasInternalSubset;
- (void) ignoreWhitespace: (NSString*)ch;
- (BOOL) internalSubset: (NSString*)name
             externalID: (NSString*)externalID
               systemID: (NSString*)systemID;
- (int) isStandalone;
- (NSString*) loadEntity: (NSString*)publicId
		      at: (NSString*)location;
- (void) namespaceDecl: (NSString*)name
		  href: (NSString*)href
		prefix: (NSString*)prefix;
- (void) notationDecl: (NSString*)name
	       public: (NSString*)publicId
	       system: (NSString*)systemId;
- (void) processInstruction: (NSString*)targetName
		       data: (NSString*)PIdata;
- (void) reference: (NSString*)name;
- (void) startDocument;
- (void) startElement: (NSString*)elementName
           attributes: (NSMutableDictionary*)elementAttributes;
- (void) startElement: (NSString*)elementName
	       prefix: (NSString*)prefix
		 href: (NSString*)href
           attributes: (NSMutableDictionary*)elementAttributes;
- (void) unparsedEntityDecl: (NSString*)name
		     public: (NSString*)publicId
		     system: (NSString*)systemId
	       notationName: (NSString*)notation;
- (void) warning: (NSString*)e;
- (void) warning: (NSString*)e
       colNumber: (int)colNumber
      lineNumber: (int)lineNumber;

@end

@interface GSTreeSAXHandler : GSSAXHandler
@end

@interface GSHTMLSAXHandler : GSSAXHandler
@end

@class GSXPathObject;

/*
 * Using this library class is trivial.  Get your GSXMLDocument.  Create
 * a GSXPathContext for it.
 *
 * GSXPathContext *p = [[GSXPathContext alloc] initWithDocument: document];
 *
 * Then, you can use it to evaluate XPath expressions:
 *
 * GSXPathString *result = [p evaluateExpression: @"string(/body/text())"];
 * NSLog (@"Got %@", [result stringValue]);
 *
 */
@interface GSXPathContext : NSObject
{
  void		*_lib;		// xmlXPathContext
  GSXMLDocument *_document;
}
- (id) initWithDocument: (GSXMLDocument*)d;
- (GSXPathObject*) evaluateExpression: (NSString*)XPathExpression;
@end

/** XPath queries return a GSXPathObject.  GSXPathObject in itself is
 * an abstract class; there are four types of completely different
 * GSXPathObject types, listed below.  I'm afraid you need to check
 * the returned type of each GSXPath query to make sure it's what you
 * meant it to be.
 */
@interface GSXPathObject : NSObject
{
  void		*_lib;		// xmlXPathObject
  GSXPathContext *_context;
}
@end

/**
 * For XPath queries returning true/false.
 */
@interface GSXPathBoolean : GSXPathObject
- (BOOL) booleanValue;
@end

/**
 * For XPath queries returning a number.
 */
@interface GSXPathNumber : GSXPathObject
- (double) doubleValue;
@end

/**
 * For XPath queries returning a string.
 */
@interface GSXPathString : GSXPathObject
- (NSString *) stringValue;
@end

/**
 * For XPath queries returning a node set.
 */
@interface GSXPathNodeSet : GSXPathObject
- (unsigned int) count;
- (unsigned int) length;

/** Please note that index starts from 0.  */
- (GSXMLNode *) nodeAtIndex: (unsigned)index;
@end

@interface GSXMLDocument (XSLT)
+ (GSXMLDocument*) xsltTransformFile: (NSString*)xmlFile
                          stylesheet: (NSString*)xsltStylesheet
		              params: (NSDictionary*)params;
			
+ (GSXMLDocument*) xsltTransformFile: (NSString*)xmlFile
                          stylesheet: (NSString*)xsltStylesheet;
			
+ (GSXMLDocument*) xsltTransformXml: (NSData*)xmlData
                         stylesheet: (NSData*)xsltStylesheet
		             params: (NSDictionary*)params;
			
+ (GSXMLDocument*) xsltTransformXml: (NSData*)xmlData
                         stylesheet: (NSData*)xsltStylesheet;
			
- (GSXMLDocument*) xsltTransform: (GSXMLDocument*)xsltStylesheet
                          params: (NSDictionary*)params;
			
- (GSXMLDocument*) xsltTransform: (GSXMLDocument*)xsltStylesheet;
@end



#include	<Foundation/NSURLHandle.h>

@class	NSArray;
@class	NSDictionary;
@class	NSTimer;
@class	GSXMLNode;
@class	GSXMLRPC;

/**
 * <p>The GSXMLRPC class provides methods for constructing and parsing
 * XMLRPC method call and response documents ... so that calls may
 * be constructed of standard objects.
 * </p>
 * <p>The correspondence between XMLRPC values and Objective-C objects
 * is as follows -
 * </p>
 * <list>
 *   <item><strong>i4</strong> (or <em>int</em>) is an [NSNumber] other
 *   than a real/float or boolean.</item>
 *   <item><strong>boolean</strong> is an [NSNumber] created as a BOOL.</item>
 *   <item><strong>string</strong> is an [NSString] object.</item>
 *   <item><strong>double</strong> is an [NSNumber] created as a float or
 *   double.</item>
 *   <item><strong>dateTime.iso8601</strong> is an [NSDate] object.</item>
 *   <item><strong>base64</strong> is an [NSData] object.</item>
 *   <item><strong>array</strong> is an [NSArray] object.</item>
 *   <item><strong>struct</strong> is an [NSDictionary] object.</item>
 * </list>
 * <p>If you attempt to use any other type of object in the construction
 * of an XMLRPC document, the [NSObject-description] method of that
 * object will be used to create a striong, and the resulting object
 * will be encoded as an XMLRPC <em>string</em> element.
 * </p>
 * <p>In particular, the names of members in a <em>struct</em> must be strings,
 * so if you provide an [NSDictionary] object to represent a <em>struct</em>
 * the keys of the dictionary will be converted to strings if necessary.
 * </p>
 * <p>The class also provides a method for making a synchronous XMLRPC
 * method call (with timeout), or an asynchronous call in which the
 * call completion is handled by a delegate.
 * </p>
 */
@interface	GSXMLRPC : NSObject <NSURLHandleClient>
{
@private
#ifdef GNUSTEP
  NSURLHandle		*handle;
#else
  NSString *connectionURL;
  NSURLConnection *connection;
  NSMutableData *response;
#endif
  NSTimer		*timer;
  id			result;
  id			delegate;	// Not retained.
}

/**
 * Given a method name and an array of parameters, this method constructs
 * the XML document for the corresponding XMLRPC call and returns the
 * document as a string.<br />
 * The params array may be empty or nil if there are no parameters to be
 * passed.<br />
 * The method returns nil if passed an invalid method name (a method name
 * may contain any of the ascii alphanumeric characters and underscore,
 * fullstop, colon, or slash).<br />
 * This method is used internally when sending an XMLRPC method call to
 * a remote system, but you can also call it yourself.
 */
- (NSString*) buildMethodCall: (NSString*)method 
                       params: (NSArray*)params;

/**
 * Constructs an XML document for an XMLRPC fault response with the
 * specified code and string.  The resulting document is returned
 * as a string.<br />
 * This method is intended for use by applications acting as XMLRPC servers.
 */
- (NSString*) buildResponseWithFaultCode: (int)code andString: (NSString*)s;

/**
 * Builds an XMLRPC response with the specified array of parameters and
 * returns the document as a string.<br />
 * The params array may be empty or nil if there are no parameters to be
 * returned (an empty params element will be created).<br />
 * This method is intended for use by applications acting as XMLRPC servers.
 */
- (NSString*) buildResponseWithParams: (NSArray*)params;

/**
 * Returns the delegate previously set by the -setDelegate: method.<br />
 * The delegate handles completion of asynchronous method calls to the
 * URL specified when the receiver was initialised (if any).
 */
- (id) delegate;

/**
 * Initialise the receiver to make XMLRPC calls to the specified URL.<br />
 * This method just calls -initWithURL:certificate:privateKey:password:
 * with nil arguments for the SSL credentials.
 */
- (id) initWithURL: (NSString*)url;

/** <init />
 * Initialise the receiver to make XMLRPC calls to the specified url
 * and (optionally) with the specified SSL parameters.<br />
 * The url argument may be nil, in which case the receiver will be
 * unable to make XMLRPC calls, but can be used to parse incoming
 * requests and build responses.<br />
 * If the SSL credentials are non-nil, connections to the remote server
 * will be authenticated using the supplied certificate so that the
 * remote system knows who is contacting it.
 */
- (id) initWithURL: (NSString*)url
       certificate: (NSString*)cert
        privateKey: (NSString*)pKey
	  password: (NSString*)pwd;

/**
 * Calls -sendMethodCall:params:timeout: and waits for the response.<br />
 * Returns the response parameters (an array),
 * the response fault (a dictionary),
 * or a failure reason (a string).
 */
- (id) makeMethodCall: (NSString*)method
	       params: (NSArray*)params
	      timeout: (int)seconds;

/**
 * Parses XML data containing an XMLRPC method call.<br />
 * Returns the name of the method call.<br />
 * Empties, and then places the method parameters (if any)
 * in the params argument.<br />
 * NB. Any containers (arrays or dictionaries) in the parsed parameters
 * will be mutable, so you can modify this data structure as you like.<br />
 * Raises an exception if parsing fails.<br />
 * This method is intended for the use of XMLRPC server applications.
 */
- (NSString*) parseMethod: (NSData*)request
		   params: (NSMutableArray*)params;

/**
 * Parses XML data containing an XMLRPC method response.<br />
 * Returns nil for succes, the fault dictionary on failure.<br />
 * Places the response parameters (if any) in the params argument.<br />
 * NB. Any containers (arrays or dictionaries) in the parsed parameters
 * will be mutable, so you can modify this data structure as you like.<br />
 * Raises an exception if parsing fails.<br />
 * Used internally when making a method call to a remote server.
 */
- (NSDictionary*) parseResponse: (NSData*)response
			 params: (NSMutableArray*)params;

/**
 * Returns the result of the last method call, or nil if there has been
 * no method call or one is in progress.<br />
 * The result may be one of -
 * <list>
 *   <item>A mutable array ... the parameters of a success response.</item>
 *   <item>A dictionary ... containing a fault response.</item>
 *   <item>A string ... describing a low-level failure (eg. timeout).</item>
 * </list>
 * NB. Any containers (arrays or dictionaries) in the parsed parameters
 * of a success response will be mutable, so you can modify this data
 * structure as you like.
 */
- (id) result;

/**
 * Send an asynchronous XMLRPC method call with the specified timeout.<br />
 * A delegate should have been set to handle the result of this call,
 * but if one was not set the state of the asynchronous call may be polled
 * by calling the -result method, which will return nil as long as the
 * call has not completed.<br />
 * The call may be cancelled by calling the -timeout: method<br />
 * This method returns YES if the call was started,
 * NO if it could not be started
 * (eg because another call is in progress or because of bad arguments).<br />
 * NB. For the asynchronous operation to proceed, the current [NSRunLoop]
 * must be run.
 */
- (BOOL) sendMethodCall: (NSString*)method
		 params: (NSArray*)params
		timeout: (int)seconds;

/**
 * Specify whether to perform mdebug trace on I/O
 */
- (void) setDebug: (BOOL)flag;

/**
 * Sets the delegate object which will receive callbacks when an XMLRPC
 * call completes.<br />
 * NB. this delegate is <em>not</em> retained, and should be removed
 * before it is deallocated (call -setDelegate: again with a nil argument
 * to remove the delegate).
 */
- (void) setDelegate: (id)aDelegate;

/**
 * Handles timeouts, passing information to delegate ... you don't need to
 * call this method, but you <em>may</em> call it in order to cancel an
 * asynchronous request as if it had timed out.
 */
- (void) timeout: (NSTimer*)t;

#ifdef GNUSTEP
/** Allows GSXMLRPC to act as a client of NSURLHandle. Internal use only. */
- (void) URLHandle: (NSURLHandle*)sender
  resourceDataDidBecomeAvailable: (NSData*)newData;
/** Allows GSXMLRPC to act as a client of NSURLHandle. Internal use only. */
- (void) URLHandle: (NSURLHandle*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason;
/** Allows GSXMLRPC to act as a client of NSURLHandle. Internal use only. */
- (void) URLHandleResourceDidBeginLoading: (NSURLHandle*)sender;
/** Allows GSXMLRPC to act as a client of NSURLHandle. Internal use only. */
- (void) URLHandleResourceDidCancelLoading: (NSURLHandle*)sender;
/** Allows GSXMLRPC to act as a client of NSURLHandle. Internal use only. */
- (void) URLHandleResourceDidFinishLoading: (NSURLHandle*)sender;
#endif

@end

/**
 * Delegates should implement this method in order to be informed of
 * the success or failure of an XMLRPC method call which was initiated
 * by the -sendMethodCall:params:timeout: method.<br />
 */
@interface	GSXMLRPC (Delegate)
/**
 * Called by the sender when an XMLRPC method call completes (either success
 * or failure). 
 * The delegate may then call the -result method to retrieve the result of
 * the method call from the sender.
 */
- (void) completedXMLRPC: (GSXMLRPC*)sender;
@end


#endif	/* STRICT_MACOS_X */
#endif	/* STRICT_OPENSTEP */

#endif /* __GSXML_H__ */

