
/* Interface for XML parsing classes

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
*/

#ifndef __GSXML_H__
#define __GSXML_H__

#define GSXML_DEBUG 1
//#undef  GSXML_DEBUG

#include <libxml/tree.h>
#include <libxml/entities.h>

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>

@class GSXMLAttribute;
@class GSXMLDocument;
@class GSXMLHandler;
@class GSXMLNamespace;
@class GSXMLNode;
@class GSSAXHandler;

typedef xmlElementType 		GSXMLElementType;
typedef xmlEntityType  		GSXMLEntityType;
typedef xmlAttributeType 	GSXMLAttributeType;
typedef xmlElementTypeVal 	GSXMLElementTypeVal;
typedef xmlNsType		GSXMLNamespaceType;

#ifdef GSXML_DEBUG
#define DP(message) printf("DEBUG: %s\n", message)
#define TEST_ALLOC_ALL  printf("test allocation\n%s", GSDebugAllocationListAll())
#define TEST_ALLOC(msg)  printf(" %s test allocation list\n%s", msg, GSDebugAllocationList(YES))
#endif




@interface GSXMLDocument : NSObject
{
    void *lib;            // pointer to xmllib pointer of xmlDoc struct
    BOOL native;
}
+ (GSXMLDocument*) documentWithVersion: (NSString*)version;
+ (GSXMLDocument*) documentFrom: (void*)data;

- (id) initWithVersion: (NSString*)version;
- (id) initFrom: (void*)data;

- (void*) lib;

- (GSXMLNode*) root;
- (GSXMLNode*) setRoot: (GSXMLNode*)node;

- (GSXMLNode*) makeNodeWithNamespace: (GSXMLNamespace*)ns
				name: (NSString*)name
			     content: (NSString*)content;

- (NSString*) version;
- (NSString*) encoding;

- (void) save: (NSString*) filename;

@end



@interface GSXMLNamespace : NSObject
{
   void *lib;          /* pointer to struct xmlNs in the gnome xmllib */
   BOOL native;
}

+ (GSXMLNamespace*) namespaceWithNode: (GSXMLNode*)node
				 href: (NSString*)href
			       prefix: (NSString*)prefix;
+ (GSXMLNamespace*) namespaceFrom: (void*)data;

- (id) initWithNode: (GSXMLNode*)node
	       href: (NSString*)href
	     prefix: (NSString*)prefix;
- (id) initFrom: (void*)data;

- (NSString*) href;
- (void*) lib;
- (GSXMLNamespace*) next;
- (NSString*) prefix;
- (GSXMLNamespaceType) type;

@end

/* XML Node */

@interface GSXMLNode : NSObject
{
  void  *lib;      /* pointer to struct xmlNode from libxml */
  BOOL  native;
}
+ (GSXMLNode*) nodeWithNamespace: (GSXMLNamespace*)ns name: (NSString*)name;
+ (GSXMLNode*) nodeFrom: (void*) data;

- (id) initWithNamespace: (GSXMLNamespace*)ns name: (NSString*)name;
- (id) initFrom: (void*) data;

- (GSXMLNode*) children;
- (NSString*) content;
- (GSXMLDocument*) doc;
- (void*) lib;
- (NSString*) name;
- (GSXMLNode*) next;
- (GSXMLNamespace*) ns;
- (GSXMLNamespace*) nsDef;  /* namespace definitions on this node */
- (GSXMLNode*) parent;
- (GSXMLNode*) prev;
- (GSXMLAttribute*) properties;
- (NSMutableDictionary*) propertiesAsDictionary;
- (GSXMLElementType) type;

- (GSXMLNode*) makeChildWithNamespace: (GSXMLNamespace*)ns
				 name: (NSString*)name
			      content: (NSString*)content;
- (GSXMLNode*) makeComment: (NSString*)content;
- (GSXMLNode*) makePI: (NSString*)name
	      content: (NSString*)content;
- (GSXMLAttribute*) setProp: (NSString*)name
		      value: (NSString*)value;

@end

/* Attribute */

@interface GSXMLAttribute : GSXMLNode
{
}
+ (GSXMLAttribute*) attributeWithNode: (GSXMLNode*)node
				 name: (NSString*)name
				value: (NSString*)value;
+ (GSXMLAttribute*) attributeFrom: (void*)data;

- (id) initWithNode: (GSXMLNode*)node
	       name: (NSString*)name
	      value: (NSString*)value;
- (id) initFrom: (void*)data;

- (NSString*) name;
- (GSXMLAttribute*) next;
- (GSXMLAttribute*) prev;
- (GSXMLAttributeType) type;
- (NSString*) value;

@end


@interface GSXMLParser : NSObject
{
   id             src;                  /* source for parsing   */
   void          *lib;                  /* parser context       */
   GSSAXHandler  *saxHandler;
}
+ (GSXMLParser*) parser: (id)source;
+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
			       source: (id) source;

- (id) initWithSAXHandler: (GSSAXHandler*)handler source: (id)source;

- (GSXMLDocument*) doc;
- (BOOL) parse;

- (BOOL) doValidityChecking: (BOOL)yesno;
- (int) errNo;
- (BOOL) getWarnings: (BOOL)yesno;
- (BOOL) keepBlanks: (BOOL)yesno;
- (void) setExternalEntityLoader: (void*)function;
- (BOOL) substituteEntities: (BOOL)yesno;

@end


@interface GSSAXHandler : NSObject
{
  void *lib;
  BOOL native;
}
+ (GSSAXHandler*) handler;
- (void*) lib;
@end

@interface GSSAXHandler (Callbacks)

- (void) startDocument;
- (void) endDocument;

- (void) isStandalone;

- (void) startElement: (NSString*)elementName
           attributes: (NSMutableDictionary*)elementAttributes;
- (void) endElement: (NSString*)elementName;
- (void) attribute: (NSString*)name
	     value: (NSString*)value;
- (void) characters: (NSString*)name
	     length: (int)len;
- (void) ignoreWhitespace: (NSString*)ch
		   length: (int)len;
- (void) processInstruction: (NSString*)targetName
		       data: (NSString*)PIdata;
- (void) comment: (NSString*) value;
- (void) cdataBlock: (NSString*)value
	     length: (int)len;


- (void) hasInternalSubset;
- (void) internalSubset: (NSString*)name
             externalID: (NSString*)externalID
               systemID: (NSString*)systemID;
- (void) hasExternalSubset;
- (void) resolveEntity: (NSString*)publicId
	      systemID: (NSString*)systemID;
- (void) getEntity: (NSString*)name;
- (void) getParameterEntity: (NSString*)name;

- (void) namespaceDecl: (NSString*)name
		  href: (NSString*)href
		prefix: (NSString*)prefix;
- (void) notationDecl: (NSString*)name
	       public: (NSString*)publicId
	       system: (NSString*)systemId;
- (void) entityDecl: (NSString*)name
               type: (int)type
             public: (NSString*)publicId
             system: (NSString*)systemId
            content: (NSString*)content;
- (void) attributeDecl: (NSString*)nameElement
                  name: (NSString*)name
                  type: (int)type
          typeDefValue: (int)defType
          defaultValue: (NSString*)value;
- (void) elementDecl: (NSString*)name
		type: (int)type;
- (void) unparsedEntityDecl: (NSString*)name
		     public: (NSString*)publicId
		     system: (NSString*)systemId
	       notationName: (NSString*)notation;
- (void) reference: (NSString*)name;

- (void) globalNamespace: (NSString*)name
		    href: (NSString*)href
		  prefix: (NSString*)prefix;


- (void) warning: (NSString*)e;
- (void) error: (NSString*)e;
- (void) fatalError: (NSString*)e;

@end

#endif __GSXML_H__

