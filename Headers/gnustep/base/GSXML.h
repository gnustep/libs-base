/** Interface for XML parsing classes

   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Michael Pakhantsov  <mishel@berest.dp.ua> on behalf of
   Brainstorm computer solutions.

   Date: Jule 2000
   
   Integrated by Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: September 2000

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

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>

#ifndef	STRICT_MACOS_X
#ifndef	STRICT_OPENSTEP

@class GSXMLAttribute;
@class GSXMLDocument;
@class GSXMLNamespace;
@class GSXMLNode;
@class GSSAXHandler;


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
- (GSXMLDocument*) document;
- (GSXMLAttribute*) firstAttribute;
- (GSXMLNode*) firstChild;
- (GSXMLNode*) firstChildElement;
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
- (NSMutableDictionary*) propertiesAsDictionaryWithKeyTransformationSel:
  (SEL)keyTransformSel;
- (void) setObject: (NSString*)value forKey:(NSString*)key;
- (int) type;
- (NSString*) typeDescription;

@end

@interface GSXMLAttribute : GSXMLNode
- (NSString*) value;
@end

@interface GSXMLParser : NSObject
{
   id             src;                  /* source for parsing   */
   void          *lib;                  /* parser context       */
   GSSAXHandler  *saxHandler;
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
- (BOOL) parse;
- (BOOL) parse: (NSData*)data;
- (BOOL) substituteEntities: (BOOL)yesno;

@end

@interface GSHTMLParser : GSXMLParser
{
}
@end

@interface GSSAXHandler : NSObject
{
  void		*lib;	// xmlSAXHandlerPtr
  GSXMLParser	*parser;
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
- (void) cdataBlock: (NSString*)value;
- (void) comment: (NSString*) value;
- (void) elementDecl: (NSString*)name
		type: (int)type;
- (void) endDocument;
- (void) endElement: (NSString*)elementName;
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
- (void) unparsedEntityDecl: (NSString*)name
		     public: (NSString*)publicId
		     system: (NSString*)systemId
	       notationName: (NSString*)notation;
- (void) warning: (NSString*)e;
- (void) warning: (NSString*)e
       colNumber: (int)colNumber
      lineNumber: (int)lineNumber;

@end

@interface GSHTMLSAXHandler : GSSAXHandler
@end

#endif	/* STRICT_MACOS_X */
#endif	/* STRICT_OPENSTEP */

#endif /* __GSXML_H__ */

