/* Implementation for GSXMLDocument for GNUstep xmlparser

   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by: Michael Pakhantsov  <mishel@berest.dp.ua> on behalf of
   Brainstorm computer solutions.
   Date: Jule 2000
   
   Integration by Richard Frith-Macdonald <richard@brainstorm.co.uk>
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

#include <libxml/parser.h>
#include <libxml/parserInternals.h>
#include <libxml/SAX.h>
#include <libxml/HTMLparser.h>

#include <Foundation/GSXML.h>
#include <Foundation/NSData.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSException.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSFileManager.h>

extern int xmlDoValidityCheckingDefaultValue;
extern int xmlGetWarningsDefaultValue;

/*
 * optimization
 *
 */
static Class NSString_class;
static IMP usImp;
static SEL usSel;

inline static NSString*
UTF8Str(const char *bytes)
{
  return (*usImp)(NSString_class, usSel, bytes);
}

inline static NSString*
UTF8StrLen(const char *bytes, unsigned length)
{
  char		*buf = NSZoneMalloc(NSDefaultMallocZone(), length+1);
  NSString	*str;

  memcpy(buf, bytes, length);
  buf[length] = '\0';
  str = UTF8Str(buf);
  NSZoneFree(NSDefaultMallocZone(), buf);
  return str;
}

static BOOL cacheDone = NO;

static void
setupCache()
{
  if (cacheDone == NO)
    {
      cacheDone = YES;
      NSString_class = [NSString class];
      usSel = @selector(stringWithUTF8String:);
      usImp = [NSString_class methodForSelector: usSel];
    }
}

static xmlParserInputPtr
loadEntityFunction(const char *url, const char *eid, xmlParserCtxtPtr *ctxt);


/* Internal interfaces */
@interface GSXMLParser (Private)
- (BOOL) _initLibXML;
- (void) _parseChunk: (NSData*)data;
@end

@interface GSSAXHandler (Private)
- (BOOL) _initLibXML;
- (void) _setParser: (GSXMLParser*)value;
@end


@implementation GSXMLDocument : NSObject

+ (void) initialize
{
  if (cacheDone == NO)
    setupCache();
}

+ (GSXMLDocument*) documentWithVersion: (NSString*)version
{
  return AUTORELEASE([[self alloc] initWithVersion: version]);
}

- (id) initWithVersion: (NSString*)version
{
  void	*data = xmlNewDoc([version cString]);

  if (data == 0)
    {
      NSLog(@"Can't create GSXMLDocument object");
      DESTROY(self);
    }
  else if ((self = [self initFrom: data]) != nil)
    {
      native = YES;
    }
  return self;
}

+ (GSXMLDocument*) documentFrom: (void*)data
{
  return AUTORELEASE([[self alloc] initFrom: data]);
}

- (id) initFrom: (void*)data
{
  self = [super init];
  if (self != nil)
    {
     if (data == NULL)
        {
          NSLog(@"GSXMLDocument - no data for initialization");
	  RELEASE(self);
          return nil;
        }
     lib = data;
     native = NO;
    }
  else
    {
      NSLog(@"Can't create GSXMLDocument object");
      return nil;
    }
  return self;
}

- (id) init
{
  NSLog(@"GSXMLDocument: calling -init is not legal");
  RELEASE(self);
  return nil;
}

- (GSXMLNode*) root
{
  return [GSXMLNode nodeFrom: xmlDocGetRootElement(lib)];
}

- (GSXMLNode*) setRoot: (GSXMLNode*)node
{
  void  *nodeLib = [node lib];
  void  *oldRoot = xmlDocSetRootElement(lib, nodeLib);
  return oldRoot == NULL ? nil : [GSXMLNode nodeFrom: nodeLib];
}

- (NSString*) version
{
  return [NSString_class stringWithCString: ((xmlDocPtr)(lib))->version];
}

- (NSString*) encoding
{
  return [NSString_class stringWithCString: ((xmlDocPtr)(lib))->encoding];
}

- (void) dealloc
{
  if ((native) && lib != NULL)
    {
      xmlFreeDoc(lib);
    }
  [super dealloc];
}

- (void*) lib
{
  return lib;
}

- (unsigned) hash
{
  return (unsigned)lib;
}

- (BOOL) isEqualTo: (id)other
{
  if ([other isKindOfClass: [self class]] == YES
    && [other lib] == lib)
    return YES;
  else
    return NO;
}


- (GSXMLNode*) makeNodeWithNamespace: (GSXMLNamespace*)ns
				name: (NSString*)name
			     content: (NSString*)content;
{
  return [GSXMLNode nodeFrom: 
    xmlNewDocNode(lib, [ns lib], [name cString], [content cString])];
}

- (void) save: (NSString*) filename
{
  xmlSaveFile([filename cString], lib);
}

@end

@implementation GSXMLNamespace : NSObject

+ (void) initialize
{
  if (cacheDone == NO)
    setupCache();
}

/* This is the initializer of this class */
+ (GSXMLNamespace*) namespaceWithNode: (GSXMLNode*)node
				 href: (NSString*)href
			       prefix: (NSString*)prefix
{
  return AUTORELEASE([[self alloc] initWithNode: node
					   href: href
				 	 prefix: prefix]);
}

- (id) initWithNode: (GSXMLNode*)node
	       href: (NSString*)href
	     prefix: (NSString*)prefix
{
  void	*data;

  if (node != nil)
    {
      data = xmlNewNs((xmlNodePtr)[node lib], [href cString], [prefix cString]);
      if (data == NULL)
        {
          NSLog(@"Can't create GSXMLNamespace object");
	  RELEASE(self);
          return nil;
        }
      self = [self initFrom: data];
    }
  else
    {
      data = xmlNewNs(NULL, [href cString], [prefix cString]);
      if (data == NULL)
        {
          NSLog(@"Can't create GSXMLNamespace object");
	  RELEASE(self);
          return nil;
        }
      self = [self initFrom: data];
      if (self != nil)
	{
	  native = YES;
	}
    }
  return self;
}

+ (GSXMLNamespace*) namespaceFrom: (void*)data
{
  return AUTORELEASE([[self alloc] initFrom: data]);
}

- (id) initFrom: (void*)data
{
  self = [super init];
  if (self != nil)
    {
     if (data == NULL)
        {
          NSLog(@"GSXMLNamespace - no data for initialization");
          return nil;
        }
      else
        {
          lib = data;
          native = NO;
        }
    }
  return self;
}

- (id) init
{
  NSLog(@"GSXMLNamespace: calling -init is not legal");
  RELEASE(self);
  return nil;
}

/* return pointer to xmlNs struct */
- (void*) lib
{
  return lib;
}

- (void) dealloc
{
  if (native == YES && lib != NULL)
    {
      xmlFreeNs(lib);
      lib = NULL;
    }
  [super dealloc];
}

/* return the namespace prefix  */
- (NSString*) prefix
{
  return UTF8Str(((xmlNsPtr)(lib))->prefix);
}

/* the namespace reference */
- (NSString*) href
{
  return UTF8Str(((xmlNsPtr)(lib))->href);
}

/* type of namespace */
- (GSXMLNamespaceType) type
{
  return (GSXMLNamespaceType)((xmlNsPtr)(lib))->type;
}

- (GSXMLNamespace*) next
{
  if (((xmlNsPtr)(lib))->next != NULL)
    {
      return [GSXMLNamespace namespaceFrom: ((xmlNsPtr)(lib))->next];
    }
  else
    {
      return nil;
    }
}

- (unsigned) hash
{
  return (unsigned)lib;
}

- (BOOL) isEqualTo: (id)other
{
  if ([other isKindOfClass: [self class]] == YES && [other lib] == lib)
    return YES;
  else
    return NO;
}

@end

/* Internal interface for GSXMLNamespace */
@interface GSXMLNamespace (internal)
- (void) native: (BOOL)value;
@end

@implementation GSXMLNamespace (Internal)
- (void) native: (BOOL)value
{
  native = value;
}
@end

@implementation GSXMLNode: NSObject

static NSMapTable	*nodeNames = 0;

+ (void) initialize
{
  if (self == [GSXMLNode class])
    {
      if (cacheDone == NO)
	setupCache();
      nodeNames = NSCreateMapTable(NSIntMapKeyCallBacks,
	NSNonRetainedObjectMapValueCallBacks, 0);
      NSMapInsert(nodeNames,
	(void*)XML_ELEMENT_NODE, (void*)@"XML_ELEMENT_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_ATTRIBUTE_NODE, (void*)@"XML_ATTRIBUTE_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_TEXT_NODE, (void*)@"XML_TEXT_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_CDATA_SECTION_NODE, (void*)@"XML_CDATA_SECTION_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_ENTITY_REF_NODE, (void*)@"XML_ENTITY_REF_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_ENTITY_NODE, (void*)@"XML_ENTITY_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_PI_NODE, (void*)@"XML_PI_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_COMMENT_NODE, (void*)@"XML_COMMENT_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_DOCUMENT_NODE, (void*)@"XML_DOCUMENT_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_DOCUMENT_TYPE_NODE, (void*)@"XML_DOCUMENT_TYPE_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_DOCUMENT_FRAG_NODE, (void*)@"XML_DOCUMENT_FRAG_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_NOTATION_NODE, (void*)@"XML_NOTATION_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_HTML_DOCUMENT_NODE, (void*)@"XML_HTML_DOCUMENT_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_DTD_NODE, (void*)@"XML_DTD_NODE");
      NSMapInsert(nodeNames,
	(void*)XML_ELEMENT_DECL, (void*)@"XML_ELEMENT_DECL");
      NSMapInsert(nodeNames,
	(void*)XML_ATTRIBUTE_DECL, (void*)@"XML_ATTRIBUTE_DECL");
      NSMapInsert(nodeNames,
	(void*)XML_ENTITY_DECL, (void*)@"XML_ENTITY_DECL");
    }
}

+ (GSXMLNode*) nodeWithNamespace: (GSXMLNamespace*) ns name: (NSString*) name
{
  return AUTORELEASE([[self alloc] initWithNamespace: ns name: name]);
}

- (id) initWithNamespace: (GSXMLNamespace*) ns name: (NSString*) name
{
  self = [super init];
  if (self != nil)
    {
      if (ns != nil)
        {
          [ns native: NO];
          lib = xmlNewNode((xmlNsPtr)[ns lib], [name cString]);
        }
      else
        {
          lib = xmlNewNode(NULL, [name cString]);
        }
      if (lib == NULL)
        {
          NSLog(@"Can't create GSXMLNode object");
          return nil;
        }

      native = YES;
    }
  return self;
}

- (void) dealloc
{
  if (native == YES && lib != NULL)
    {
      xmlFreeNode(lib);
    }
  [super dealloc];

}

+ (GSXMLNode*) nodeFrom: (void*)data
{
  return AUTORELEASE([[self alloc] initFrom: data]);
}

- (id) initFrom: (void*)data
{
  self = [super init];
  if (self != nil)
    {
     if (data == NULL)
        {
          NSLog(@"GSXMLNode - no data for initialization");
          return nil;
        }
     lib = data;
     native = NO;
    }
  return self;
}

- (void*) lib
{
  return lib;
}

- (NSString*) content
{
  if (((xmlNodePtr)lib)->content != NULL)
    {
      return UTF8Str(((xmlNodePtr)lib)->content);
    }
  else
    {
      return nil;
    }
}

- (NSString*) name
{
  if (lib != NULL)
    {
      return UTF8Str(((xmlNodePtr)lib)->name);
    }
  else
    {
      return nil;
    }
}

- (GSXMLNamespace*) ns
{
  if (((xmlNodePtr)(lib))->ns != NULL)
    {
      return [GSXMLNamespace namespaceFrom: ((xmlNodePtr)(lib))->ns];
    }
  else
    {
      return nil;
    }
}

- (GSXMLNamespace*) nsDef
{
  if (((xmlNodePtr)lib)->nsDef != NULL)
    {
      return [GSXMLNamespace namespaceFrom: ((xmlNodePtr)lib)->nsDef];
    }
  else
    {
      return nil;
    }
}

- (NSMutableDictionary*) propertiesAsDictionary
{
  return [self propertiesAsDictionaryWithKeyTransformationSel:NULL];
};

- (NSMutableDictionary*) propertiesAsDictionaryWithKeyTransformationSel:(SEL)keyTransformSel
{
  xmlAttrPtr		prop;
  NSMutableDictionary	*d = [NSMutableDictionary dictionary];

  prop = ((xmlNodePtr)(lib))->properties;

  while (prop != NULL)
    {
      const void	*name = prop->name;
      NSString*key=UTF8Str(name);
      if (keyTransformSel)
        key=[key performSelector:keyTransformSel];

      if (prop->children != NULL)
	{
	   const void	*content = prop->children->content;

	   [d setObject: UTF8Str(content) forKey: key];
	}
      else
	{
	   [d setObject: @"" forKey: key];
	}
      prop = prop->next;
  }

  return d;
}

- (GSXMLElementType) type
{
  return (GSXMLElementType)((xmlNodePtr)(lib))->type;
}

- (NSString*) typeDescription
{
  NSString	*desc = (NSString*)NSMapGet(nodeNames, (void*)[self type]);

  if (desc == nil)
    {
      desc = @"Unknown node type";
    }
  return desc;
}

- (GSXMLNode*) properties
{
  if (((xmlNodePtr)(lib))->properties != NULL)
    {
      return [GSXMLAttribute attributeFrom: ((xmlNodePtr)(lib))->properties];
    }
  else
    {
      return nil;
    }
}

- (GSXMLDocument*) doc
{
  if (((xmlNodePtr)(lib))->doc != NULL)
    {
      return [GSXMLDocument documentFrom: ((xmlNodePtr)(lib))->doc];
    }
  else
    {
      return nil;
    }
}

- (GSXMLNode*) children
{
  if (((xmlNodePtr)(lib))->children != NULL)
    {
      return [GSXMLNode nodeFrom: ((xmlNodePtr)(lib))->children];
    }
  else
    {
      return nil;
    }
}

- (GSXMLNode*) parent
{
  if (((xmlNodePtr)(lib))->parent != NULL)
    {
      return [GSXMLNode nodeFrom: ((xmlNodePtr)(lib))->parent];
    }
  else
    {
      return nil;
    }
}

- (GSXMLNode*) next
{
  if (((xmlNodePtr)(lib))->next != NULL)
    {
      return [GSXMLNode nodeFrom: ((xmlNodePtr)(lib))->next];
    }
  else
    {
      return nil;
    }
}

- (GSXMLNode*) prev
{
  if (((xmlNodePtr)(lib))->prev != NULL)
    {
      return [GSXMLNode nodeFrom: ((xmlNodePtr)(lib))->prev];
    }
  else
    {
      return nil;
    }
}

- (GSXMLNode*) makeChildWithNamespace: (GSXMLNamespace*)ns
				 name: (NSString*)name
			      content: (NSString*)content;
{
  return [GSXMLNode nodeFrom: 
    xmlNewChild(lib, [ns lib], [name cString], [content cString])];
}

- (GSXMLAttribute*) setProp: (NSString*)name value: (NSString*)value
{
  return [GSXMLAttribute attributeFrom: 
    xmlSetProp(lib, [name cString], [value cString])];
}


- (GSXMLNode*) makeComment: (NSString*)content
{
  return [GSXMLNode nodeFrom: xmlAddChild((xmlNodePtr)lib, xmlNewComment([content cString]))];
}

- (GSXMLNode*) makePI: (NSString*)name content: (NSString*)content
{
  return [GSXMLNode nodeFrom: 
    xmlAddChild((xmlNodePtr)lib, xmlNewPI([name cString], [content cString]))];
}

- (unsigned) hash
{
  return (unsigned)lib;
}

- (BOOL) isEqualTo: (id)other
{
  if ([other isKindOfClass: [self class]] == YES
    && [other lib] == lib)
    return YES;
  else
    return NO;
}

@end



/*
 *
 * GSXMLAttribure
 *
 */


@implementation GSXMLAttribute : GSXMLNode

+ (void) initialize
{
  if (cacheDone == NO)
    setupCache();
}

- (GSXMLAttributeType) type
{
  return (GSXMLAttributeType)((xmlAttrPtr)(lib))->atype;
}

- (void*) lib
{
  return lib;
}

+ (GSXMLAttribute*) attributeWithNode: (GSXMLNode*)node
				 name: (NSString*)name
				value: (NSString*)value;
{
  return AUTORELEASE([[self alloc] initWithNode: node name: name value: value]);
}

- (id) initWithNode: (GSXMLNode*)node
	       name: (NSString*)name
	      value: (NSString*)value;
{
  self = [super init];
  lib = xmlNewProp((xmlNodePtr)[node lib], [name cString], [value cString]);
  return self;
}

+ (GSXMLAttribute*) attributeFrom: (void*)data
{
  return AUTORELEASE([[self alloc] initFrom: data]);
}

- (id) initFrom: (void*)data
{
  self = [super init];
  if (self != nil)
    {
     if (data == NULL)
        {
          NSLog(@"GSXMLAttribute - no data for initalization");
          return nil;
        }
     lib = data;
    }
  return self;
}

- (id) init
{
  NSLog(@"GSXMLNode: calling -init is not legal");
  RELEASE(self);
  return nil;
}

- (void) dealloc
{
  if ((native) && lib != NULL)
    {
      xmlFreeProp(lib);
    }
  [super dealloc];
}

- (NSString*) name
{
  return[NSString_class stringWithCString: ((xmlAttrPtr)(lib))->name];
}


- (NSString*) value
{
  if (((xmlNodePtr)lib)->children != NULL
    && ((xmlNodePtr)lib)->children->content != NULL)
    {
      return UTF8Str(((xmlNodePtr)(lib))->children->content);
    }
  return nil;
}


- (GSXMLAttribute*) next
{
  if (((xmlAttrPtr)(lib))->next != NULL)
    {
      return [GSXMLAttribute attributeFrom: ((xmlAttrPtr)(lib))->next];
    }
  else
    {
      return nil;
    }
}

- (GSXMLAttribute*) prev
{
  if (((xmlAttrPtr)(lib))->prev != NULL)
    {
      return [GSXMLAttribute attributeFrom: ((xmlAttrPtr)(lib))->prev];
    }
  else
    {
      return nil;
    }
}

@end


@implementation GSXMLParser : NSObject

static NSString	*endMarker = @"At end of incremental parse";

+ (void) initialize
{
  if (cacheDone == NO)
    setupCache();
  xmlSetExternalEntityLoader((xmlExternalEntityLoader)loadEntityFunction);
}

+ (GSXMLParser*) parser
{
  return AUTORELEASE([[self alloc] initWithSAXHandler: nil]);
}

+ (GSXMLParser*) parserWithContentsOfFile: (NSString*)path
{
  return AUTORELEASE([[self alloc] initWithSAXHandler: nil
				   withContentsOfFile: path]);
}

+ (GSXMLParser*) parserWithContentsOfURL: (NSURL*)url
{
  return AUTORELEASE([[self alloc] initWithSAXHandler: nil
				    withContentsOfURL: url]);
}

+ (GSXMLParser*) parserWithData: (NSData*)data
{
  return AUTORELEASE([[self alloc] initWithSAXHandler: nil
					     withData: data]);
}

+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
{
  return AUTORELEASE([[self alloc] initWithSAXHandler: handler]);
}

+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
		   withContentsOfFile: (NSString*)path
{
  return AUTORELEASE([[self alloc] initWithSAXHandler: handler
				   withContentsOfFile: path]);
}

+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
		    withContentsOfURL: (NSURL*)url
{
  return AUTORELEASE([[self alloc] initWithSAXHandler: handler
				    withContentsOfURL: url]);
}

+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
			     withData: (NSData*)data
{
  return AUTORELEASE([[self alloc] initWithSAXHandler: handler
					     withData: data]);
}

+ (NSString*) xmlEncodingStringForStringEncoding: (NSStringEncoding)encoding
{
  NSString	*xmlEncodingString = nil;

  switch (encoding)
    {
      case NSUnicodeStringEncoding:
	NSLog(@"NSUnicodeStringEncoding not supported for XML");//??
	break;
      case NSNEXTSTEPStringEncoding:
	NSLog(@"NSNEXTSTEPStringEncoding not supported for XML");//??
	break;
      case NSJapaneseEUCStringEncoding:
	xmlEncodingString = @"EUC-JP";
	break;
      case NSShiftJISStringEncoding:
	xmlEncodingString = @"Shift-JIS";
	break;
      case NSISO2022JPStringEncoding:
	xmlEncodingString = @"ISO-2022-JP";
	break;
      case NSUTF8StringEncoding:
	xmlEncodingString = @"UTF-8";
	break;
      case NSWindowsCP1251StringEncoding:
	NSLog(@"NSWindowsCP1251StringEncoding not supported for XML");//??
	break;
      case NSWindowsCP1252StringEncoding:
	NSLog(@"NSWindowsCP1252StringEncoding not supported for XML");//??
	break;
      case NSWindowsCP1253StringEncoding:
	NSLog(@"NSWindowsCP1253StringEncoding not supported for XML");//??
	break;
      case NSWindowsCP1254StringEncoding:
	NSLog(@"NSWindowsCP1254StringEncoding not supported for XML");//??
	break;
      case NSWindowsCP1250StringEncoding:
	NSLog(@"NSWindowsCP1250StringEncoding not supported for XML");//??
	break;
      case NSISOLatin1StringEncoding:
	xmlEncodingString = @"ISO-8859-1";
	break;
      case NSISOLatin2StringEncoding:
	xmlEncodingString = @"ISO-8859-2";
	break;
      case NSSymbolStringEncoding:
	NSLog(@"NSSymbolStringEncoding not supported for XML");//??
	break;
      case NSCyrillicStringEncoding:
	NSLog(@"NSCyrillicStringEncoding not supported for XML");//??
	break;
      case NSNonLossyASCIIStringEncoding:
      case NSASCIIStringEncoding:
      case GSUndefinedEncoding:
      default:
	xmlEncodingString = nil;
	break;
    }
  return xmlEncodingString;
}

- (id) initWithSAXHandler: (GSSAXHandler*)handler
{
  if (handler != nil && [handler isKindOfClass: [GSSAXHandler class]] == NO)
    {
      NSLog(@"Bad GSSAXHandler object passed to GSXMLParser initialiser");
      RELEASE(self);
      return nil;
    }
  saxHandler = RETAIN(handler);
  [saxHandler _setParser: self];
  if ([self _initLibXML] == NO)
    {
      RELEASE(self);
      return nil;
    }
  return self;
}

- (id) initWithSAXHandler: (GSSAXHandler*)handler
       withContentsOfFile: (NSString*)path
{
  self = [self initWithSAXHandler: handler];
  if (self != nil)
    {
      if (path == nil || [path isKindOfClass: [NSString class]] == NO)
        {
          NSLog(@"Bad file path passed to initialize GSXMLParser");
	  RELEASE(self);
	  return nil;
        }
      src = [path copy];
    }
  return self;
}

- (id) initWithSAXHandler: (GSSAXHandler*)handler
	withContentsOfURL: (NSURL*)url
{
  self = [self initWithSAXHandler: handler];
  if (self != nil)
    {
      if (url == nil || [url isKindOfClass: [NSURL class]] == NO)
        {
          NSLog(@"Bad NSURL passed to initialize GSXMLParser");
	  RELEASE(self);
	  return nil;
        }
      src = [url copy];
    }
  return self;
}

- (id) initWithSAXHandler: (GSSAXHandler*)handler
		 withData: (NSData*)data
{
  self = [self initWithSAXHandler: handler];
  if (self != nil)
    {
      if (data == nil || [data isKindOfClass: [NSData class]] == NO)
        {
          NSLog(@"Bad NSData passed to initialize GSXMLParser");
	  RELEASE(self);
	  return nil;
        }
      src = [data copy];
    }
  return self;
}

- (BOOL) parse
{
  id	tmp;

  if (src == endMarker)
    {
      NSLog(@"GSXMLParser -parse called on object that is already parsed");
      return NO;
    }
  if (src == nil)
    {
      NSLog(@"GSXMLParser -parse called on object with no source");
      return NO;
    }

  if ([src isKindOfClass: [NSData class]])
    {
    }
  else if ([src isKindOfClass: NSString_class])
    {
      NSData	*data = [NSData dataWithContentsOfFile: src];

      if (data == nil)
	{
	  NSLog(@"File to parse (%@) is not readable", src);
          return NO;
	}
      ASSIGN(src, data);
    }
  else if ([src isKindOfClass: [NSURL class]])
    {
      NSData	*data = [src resourceDataUsingCache: YES];

      if (data == nil)
	{
	  NSLog(@"URL to parse (%@) is not readable", src);
          return NO;
	}
      ASSIGN(src, data);
    }
  else
    {
       NSLog(@"source for [-parse] must be NSString, NSData or NSURL type");
       return NO;
    }

  tmp = RETAIN(src);
  ASSIGN(src, endMarker);
  [self _parseChunk: tmp];
  [self _parseChunk: nil];
  RELEASE(tmp);

  if (((xmlParserCtxtPtr)lib)->wellFormed)
    return YES;
  else
    return NO;
}

- (BOOL) parse: (NSData*)data
{
  if (src == endMarker)
    {
      NSLog(@"GSXMLParser -parse: called on object that is fully parsed");
      return NO;
    }
  if (src != nil)
    {
       NSLog(@"XMLParser -parse: called for parser not initialised with nil");
       return NO;
    }

  if (data == nil || [data length] == 0)
    {
      /*
       * At end of incremental parse.
       */
      if (lib != NULL)
	{
	  xmlParseChunk(lib, 0, 0, 1);
	  src = endMarker;
	  if (((xmlParserCtxtPtr)lib)->wellFormed)
	    return YES;
	  else
	    return NO;
	}
      else
	{
	  NSLog(@"GSXMLParser -parse: terminated with no data");
	  return NO;
	}
    }
  else
    {
      [self _parseChunk: data];
      return YES;
    }
}

- (GSXMLDocument*) doc
{
  return [GSXMLDocument documentFrom: ((xmlParserCtxtPtr)lib)->myDoc];
}

- (void) dealloc
{
  RELEASE(src);
  RELEASE(saxHandler);
  if (lib != NULL)
    {
      xmlFreeDoc(((xmlParserCtxtPtr)lib)->myDoc);
      xmlFreeParserCtxt(lib);
    }
  [super dealloc];
}


- (BOOL) substituteEntities: (BOOL)yesno
{
  BOOL	result = ((xmlParserCtxtPtr)lib)->replaceEntities ? YES : NO;

  ((xmlParserCtxtPtr)lib)->replaceEntities = (yesno == YES) ? 1 : 0;
  return result;
}

- (BOOL) keepBlanks: (BOOL)yesno
{
  BOOL	result = ((xmlParserCtxtPtr)lib)->keepBlanks ? YES : NO;

  ((xmlParserCtxtPtr)lib)->keepBlanks = (yesno == YES) ? 1 : 0;
  return result;
}

- (BOOL) doValidityChecking: (BOOL)yesno
{
  BOOL	result = ((xmlParserCtxtPtr)lib)->validate ? YES : NO;

  ((xmlParserCtxtPtr)lib)->validate = (yesno == YES) ? 1 : 0;
  return result;
}

- (BOOL) getWarnings: (BOOL)yesno
{
  return !(xmlGetWarningsDefaultValue = yesno);
}

- (int) errNo
{
  return ((xmlParserCtxtPtr)lib)->errNo;
}


/*
 * Private methods - internal use only.
 */

- (BOOL) _initLibXML
{
  lib = (void*)xmlCreatePushParserCtxt([saxHandler lib], NULL, 0, 0, ".");  
  if (lib == NULL)
    {
      NSLog(@"Failed to create libxml parser context");
      return NO;
    }
  else
    {
      /*
       * Put saxHandler address in _private member, so we can retrieve 
       * the GSXMLHandler to use in our SAX C Functions.
       */
      ((xmlParserCtxtPtr)lib)->_private=saxHandler;
    }
  return YES;
}

- (void) _parseChunk: (NSData*)data
{
  // nil data allowed
  xmlParseChunk(lib, [data bytes], [data length], 0);
}

@end

@implementation GSHTMLParser

- (BOOL) _initLibXML
{
  lib = (void*)htmlCreatePushParserCtxt([saxHandler lib], NULL, 0, 0, ".",
    XML_CHAR_ENCODING_NONE);
  if (lib == NULL)
    {
      NSLog(@"Failed to create libxml parser context");
      return NO;
    }
  else
    {
      /*
       * Put saxHandler address in _private member, so we can retrieve 
       * the GSXMLHandler to use in our SAX C Functions.
       */
      ((htmlParserCtxtPtr)lib)->_private = saxHandler;
    }
  return YES;
}

- (void) _parseChunk: (NSData*)data
{
  htmlParseChunk(lib, [data bytes], [data length], 0);
}

@end

@implementation GSSAXHandler : NSObject

+ (void) initialize
{
  if (cacheDone == NO)
    setupCache();
}

/*
 * The context is a xmlParserCtxtPtr or htmlParserCtxtPtr.
 * Its _private member contains the address of our Sax Handler Object.
 * We can use a (xmlParserCtxtPtr) cast because xmlParserCtxt and
 * htmlParserCtxt are the same structure (and will remain, cf libxml author).
 */
#define	HANDLER	(GSSAXHandler*)(((xmlParserCtxtPtr)ctx)->_private)

static xmlParserInputPtr
loadEntityFunction(const char *url, const char *eid, xmlParserCtxtPtr *ctx)
{
  extern xmlParserInputPtr	xmlNewInputFromFile();
  NSString			*file;
  xmlParserInputPtr		ret = 0;
  NSString			*entityId;
  NSString			*location ;
  NSArray			*components;
  NSMutableString		*local;
  unsigned			count;
  unsigned			index;

  NSCAssert(ctx, @"No Context");
  if (eid == 0 || url == 0)
    return 0;

  entityId = UTF8Str(eid);
  location = UTF8Str(url);
  components = [location pathComponents];
  local = [NSMutableString string];

  /*
   * Build a local filename by replacing path separator characters with
   * something else.
   */
  count = [components count];
  if (count > 0)
    {
      count--;
      for (index = 0; index < count; index++)
	{
	  [local appendString: [components objectAtIndex: index]];
	  [local appendString: @"_"];
	}
      [local appendString: [components objectAtIndex: index]];
    }

  /*
   * Now ask the SAXHandler callback for the name of a local file
   */
  file = [HANDLER loadEntity: entityId at: location];

  if (file == nil)
    {
      /*
       * Special case - GNUstep DTDs - should be installed in the GNUstep
       * system bundle - so we look for them there.
       */
      if ([entityId hasPrefix: @"-//GNUstep//DTD "] == YES)
	{
	  NSCharacterSet	*ws = [NSCharacterSet whitespaceCharacterSet];
	  NSMutableString	*name;
	  NSString		*found;
	  unsigned		len;
	  NSRange		r;

	  /*
	   * Extract the relevent DTD name
	   */
	  name = AUTORELEASE([entityId mutableCopy]);
	  r = NSMakeRange(0, 16);
	  [name deleteCharactersInRange: r];
	  len = [name length];
	  r = [name rangeOfString: @"/" options: NSLiteralSearch];
	  if (r.length > 0)
	    {
	      r.length = len - r.location;
	      [name deleteCharactersInRange: r];
	      len = [name length];
	    }

	  /*
	   * Convert dots to underscores.
	   */
	  r = [name rangeOfString: @"." options: NSLiteralSearch];
	  while (r.length > 0)
	    {
	      [name replaceCharactersInRange: r withString: @"_"];
	      r.location++;
	      r.length = len - r.location;
	      r = [name rangeOfString: @"."
			     options: NSLiteralSearch
			       range: r];
	    }

	  /*
	   * Convert whitespace to hyphens.
	   */
	  r = [name rangeOfCharacterFromSet: ws options: NSLiteralSearch];
	  while (r.length > 0)
	    {
	      [name replaceCharactersInRange: r withString: @"-"];
	      r.location++;
	      r.length = len - r.location;
	      r = [name rangeOfCharacterFromSet: ws
				       options: NSLiteralSearch
					 range: r];
	    }

	  found = [NSBundle pathForGNUstepResource: name
					    ofType: @"dtd"
				       inDirectory: @"DTDs"];
	  if (found == nil)
	    {
	      NSLog(@"unable to find GNUstep DTD - '%@' for '%s'", name, eid);
	    }
	  else
	    {
	      file = found;
	    }
	}

      /*
       * DTD not found - so we look for it in standard locations.
       */
      if (file == nil)
	{
	  file = [[NSBundle mainBundle] pathForResource: local
						 ofType: @""
					    inDirectory: @"DTDs"];
	  if (file == nil)
	    {
	      file = [NSBundle pathForGNUstepResource: local
					       ofType: @""
					  inDirectory: @"DTDs"];
	    }
	}
    }

  if ([file length] > 0)
    {
      ret = xmlNewInputFromFile(ctx, [file fileSystemRepresentation]);
    }
  return ret;
}

static void
startDocumentFunction(void *ctx)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER startDocument];
}

static void
endDocumentFunction(void *ctx)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER endDocument];
}

static int
isStandaloneFunction(void *ctx)
{
  NSCAssert(ctx,@"No Context");
  return [HANDLER isStandalone];
}

static int
hasInternalSubsetFunction(void *ctx)
{
  int	has;

  NSCAssert(ctx,@"No Context");
  has = [HANDLER hasInternalSubset];
  if (has < 0)
    has = (*xmlDefaultSAXHandler.hasInternalSubset)(ctx);
  return has;
}

static int
hasExternalSubsetFunction(void *ctx)
{
  int	has;

  NSCAssert(ctx,@"No Context");
  has = [HANDLER hasExternalSubset];
  if (has < 0)
    has = (*xmlDefaultSAXHandler.hasExternalSubset)(ctx);
  return has;
}

static void
internalSubsetFunction(void *ctx, const char *name,
  const xmlChar *ExternalID, const xmlChar *SystemID)
{
  NSCAssert(ctx,@"No Context");
  if ([HANDLER internalSubset: UTF8Str(name)
		   externalID: UTF8Str(ExternalID)
		     systemID: UTF8Str(SystemID)] == NO)
    (*xmlDefaultSAXHandler.internalSubset)(ctx, name, ExternalID, SystemID);
}

static void
externalSubsetFunction(void *ctx, const char *name,
  const xmlChar *ExternalID, const xmlChar *SystemID)
{
  NSCAssert(ctx,@"No Context");
  if ([HANDLER externalSubset: UTF8Str(name)
		   externalID: UTF8Str(ExternalID)
		     systemID: UTF8Str(SystemID)] == NO)
    (*xmlDefaultSAXHandler.externalSubset)(ctx, name, ExternalID, SystemID);
}

static xmlEntityPtr
getEntityFunction(void *ctx, const char *name)
{
  NSCAssert(ctx,@"No Context");
  return [HANDLER getEntity: UTF8Str(name)];
}

static xmlEntityPtr
getParameterEntityFunction(void *ctx, const char *name)
{
  NSCAssert(ctx,@"No Context");
  return [HANDLER getParameterEntity: UTF8Str(name)];
}

static void
entityDeclFunction(void *ctx, const char *name, int type,
  const char *publicId, const char *systemId, char *content)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER entityDecl: UTF8Str(name)
		 type: type
	       public: UTF8Str(publicId)
	       system: UTF8Str(systemId)
	      content: UTF8Str(content)];
}

static void
attributeDeclFunction(void *ctx, const char *elem, const char *name,
  int type, int def, const char *defaultValue, xmlEnumerationPtr tree)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER attributeDecl: UTF8Str(elem)
		    name: UTF8Str(name)
		    type: type
	    typeDefValue: def
	    defaultValue: UTF8Str(defaultValue)];
}

static void
elementDeclFunction(void *ctx, const char *name, int type,
  xmlElementContentPtr content)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER elementDecl: UTF8Str(name)
		  type: type];

}

static void
notationDeclFunction(void *ctx, const char *name,
  const char *publicId, const char *systemId)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER notationDecl: UTF8Str(name)
		 public: UTF8Str(publicId)
		 system: UTF8Str(systemId)];
}

static void
unparsedEntityDeclFunction(void *ctx, const char *name,
  const char *publicId, const char *systemId, const char *notationName)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER unparsedEntityDecl: UTF8Str(name)
		       public: UTF8Str(publicId)
		       system: UTF8Str(systemId)
		 notationName: UTF8Str(notationName)];
}

static void
startElementFunction(void *ctx, const char *name, const char **atts)
{
  int i;
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSString *key, *obj;
  NSCAssert(ctx,@"No Context");

  if (atts != NULL)
    {
      for (i = 0; (atts[i] != NULL); i++)
	{
	  key = [NSString_class stringWithCString: atts[i++]];
	  obj = [NSString_class stringWithCString: atts[i]];
	  [dict setObject: obj forKey: key];
	}
    }
  [HANDLER startElement: UTF8Str(name)
	     attributes: dict];
}

static void
endElementFunction(void *ctx, const char *name)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER endElement: UTF8Str(name)];
}

static void
charactersFunction(void *ctx, const char *ch, int len)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER characters: UTF8StrLen(ch, len)];
}

static void
referenceFunction(void *ctx, const char *name)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER reference: UTF8Str(name)];
}

static void
ignorableWhitespaceFunction(void *ctx, const char *ch, int len)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER ignoreWhitespace: UTF8StrLen(ch, len)];
}

static void
processInstructionFunction(void *ctx, const char *target,  const char *data)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER processInstruction: UTF8Str(target)
			 data: UTF8Str(data)];
}

static void
cdataBlockFunction(void *ctx, const char *value, int len)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER cdataBlock: UTF8StrLen(value, len)];
}

static void
commentFunction(void *ctx, const char *value)
{
  NSCAssert(ctx,@"No Context");
  [HANDLER comment: UTF8Str(value)];
}

static void
warningFunction(void *ctx, const char *msg, ...)
{
  char allMsg[2048];
  va_list args;

  va_start(args, msg);
  vsprintf(allMsg, msg, args);
  va_end(args);

  NSCAssert(ctx,@"No Context");
  [HANDLER warning: UTF8Str(allMsg)];
}

static void
errorFunction(void *ctx, const char *msg, ...)
{
  char allMsg[2048];
  va_list args;

  va_start(args, msg);
  vsprintf(allMsg, msg, args);
  va_end(args);
  NSCAssert(ctx,@"No Context");
  [HANDLER error: UTF8Str(allMsg)];
}

static void
fatalErrorFunction(void *ctx, const char *msg, ...)
{
  char allMsg[2048];
  va_list args;

  va_start(args, msg);
  vsprintf(allMsg, msg, args);
  va_end(args);
  NSCAssert(ctx, @"No Context");
  [HANDLER fatalError: UTF8Str(allMsg)];
}

#undef	HANDLER

+ (GSSAXHandler*) handler
{
  return AUTORELEASE([[self alloc] init]);
}

- (id) init
{
  NSAssert(lib == 0, @"Already created lib");
  self = [super init];
  if (self != nil)
    {
      if ([self _initLibXML] == NO)
        {
          NSLog(@"GSSAXHandler: out of memory\n");
	  RELEASE(self);
	  return nil;
        }
    }
  return self;
}

- (void*) lib
{
  return lib;
}

- (GSXMLParser*) parser
{
  return parser;
}

- (void) dealloc
{
  if (parser == nil && lib != NULL)
    {
      free(lib);
    }
  [super dealloc];
}

- (void) startDocument
{

}

- (void) endDocument
{
}

- (void) startElement: (NSString*)elementName
	   attributes: (NSMutableDictionary*)elementAttributes;
{
}

- (void) endElement: (NSString*) elementName
{
}

- (void) attribute: (NSString*) name value: (NSString*)value
{
}

- (void) characters: (NSString*) name
{
}

- (void) ignoreWhitespace: (NSString*) ch
{
}

- (void) processInstruction: (NSString*)targetName data: (NSString*)PIdata
{
}

- (void) comment: (NSString*) value
{
}

- (void) cdataBlock: (NSString*)value
{
}

- (NSString*) loadEntity: (NSString*)publicId
		      at: (NSString*)location
{
  return nil;
}

- (void) namespaceDecl: (NSString*)name
		  href: (NSString*)href
		prefix: (NSString*)prefix
{
}

- (void) notationDecl: (NSString*)name
	       public: (NSString*)publicId
	       system: (NSString*)systemId
{
}

- (void) entityDecl: (NSString*)name
	       type: (int)type
	     public: (NSString*)publicId
	     system: (NSString*)systemId
	    content: (NSString*)content
{
}

- (void) attributeDecl: (NSString*)nameElement
	 nameAttribute: (NSString*)name
	    entityType: (int)type
	  typeDefValue: (int)defType
	  defaultValue: (NSString*)value
{
}

- (void) elementDecl: (NSString*)name
		type: (int)type
{
}

- (void) unparsedEntityDecl: (NSString*)name
	       publicEntity: (NSString*)publicId
	       systemEntity: (NSString*)systemId
	       notationName: (NSString*)notation
{
}

- (void) reference: (NSString*) name
{
}

- (void) globalNamespace: (NSString*)name
		    href: (NSString*)href
		  prefix: (NSString*)prefix
{
}

- (void) warning: (NSString*)e
{
}

- (void) error: (NSString*)e
{
}

- (void) fatalError: (NSString*)e
{
}

- (int) hasInternalSubset
{
  return 0;
}

- (BOOL) internalSubset: (NSString*)name
	     externalID: (NSString*)externalID
	       systemID: (NSString*)systemID
{
  return NO;
}

- (int) hasExternalSubset
{
  return 0;
}

- (BOOL) externalSubset: (NSString*)name
	     externalID: (NSString*)externalID
		ystemID: (NSString*)systemID
{
  return NO;
}

- (void*) getEntity: (NSString*)name
{
  return 0;
}

/*
 * Private methods - internal use only.
 */
- (BOOL) _initLibXML
{
  lib = (xmlSAXHandler*)malloc(sizeof(xmlSAXHandler));
  if (lib == NULL)
    return NO;
  else
    {
      memcpy(lib, &xmlDefaultSAXHandler, sizeof(htmlSAXHandler));

#define	LIB	((xmlSAXHandlerPtr)lib)
      LIB->internalSubset         = (void*) internalSubsetFunction;
      LIB->externalSubset         = (void*) externalSubsetFunction;
      LIB->isStandalone           = (void*) isStandaloneFunction;
      LIB->hasInternalSubset      = (void*) hasInternalSubsetFunction;
      LIB->hasExternalSubset      = (void*) hasExternalSubsetFunction;
      LIB->getEntity              = (void*) getEntityFunction;
      LIB->entityDecl             = (void*) entityDeclFunction;
      LIB->notationDecl           = (void*) notationDeclFunction;
      LIB->attributeDecl          = (void*) attributeDeclFunction;
      LIB->elementDecl            = (void*) elementDeclFunction;
      LIB->unparsedEntityDecl     = (void*) unparsedEntityDeclFunction;
      LIB->startDocument          = (void*) startDocumentFunction;
      LIB->endDocument            = (void*) endDocumentFunction;
      LIB->startElement           = (void*) startElementFunction;
      LIB->endElement             = (void*) endElementFunction;
      LIB->reference              = (void*) referenceFunction;
      LIB->characters             = (void*) charactersFunction;
      LIB->ignorableWhitespace    = (void*) ignorableWhitespaceFunction;
      LIB->processingInstruction  = (void*) processInstructionFunction;
      LIB->comment                = (void*) commentFunction;
      LIB->warning                = (void*) warningFunction;
      LIB->error                  = (void*) errorFunction;
      LIB->fatalError             = (void*) fatalErrorFunction;
      LIB->getParameterEntity     = (void*) getParameterEntityFunction;
      LIB->cdataBlock             = (void*) cdataBlockFunction;
#undef	LIB
      return YES;
    }
}

- (void) _setParser: (GSXMLParser*)value
{
  parser = value;
}
@end

@implementation GSHTMLSAXHandler
- (BOOL) _initLibXML
{
  lib = (xmlSAXHandler*)malloc(sizeof(htmlSAXHandler));
  if (lib == NULL)
    return NO;
  else
    {
      memcpy(lib, &xmlDefaultSAXHandler, sizeof(htmlSAXHandler));

#define	LIB	((htmlSAXHandlerPtr)lib)
      LIB->internalSubset         = (void*) internalSubsetFunction;
      LIB->externalSubset         = (void*) externalSubsetFunction;
      LIB->isStandalone           = (void*) isStandaloneFunction;
      LIB->hasInternalSubset      = (void*) hasInternalSubsetFunction;
      LIB->hasExternalSubset      = (void*) hasExternalSubsetFunction;
      LIB->getEntity              = (void*) getEntityFunction;
      LIB->entityDecl             = (void*) entityDeclFunction;
      LIB->notationDecl           = (void*) notationDeclFunction;
      LIB->attributeDecl          = (void*) attributeDeclFunction;
      LIB->elementDecl            = (void*) elementDeclFunction;
      LIB->unparsedEntityDecl     = (void*) unparsedEntityDeclFunction;
      LIB->startDocument          = (void*) startDocumentFunction;
      LIB->endDocument            = (void*) endDocumentFunction;
      LIB->startElement           = (void*) startElementFunction;
      LIB->endElement             = (void*) endElementFunction;
      LIB->reference              = (void*) referenceFunction;
      LIB->characters             = (void*) charactersFunction;
      LIB->ignorableWhitespace    = (void*) ignorableWhitespaceFunction;
      LIB->processingInstruction  = (void*) processInstructionFunction;
      LIB->comment                = (void*) commentFunction;
      LIB->warning                = (void*) warningFunction;
      LIB->error                  = (void*) errorFunction;
      LIB->fatalError             = (void*) fatalErrorFunction;
      LIB->getParameterEntity     = (void*) getParameterEntityFunction;
      LIB->cdataBlock             = (void*) cdataBlockFunction;
#undef	LIB
      return YES;
    }
}
@end
