/** Implementation for GSXMLDocument for GNUstep xmlparser

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

#include <config.h>

#ifdef	HAVE_LIBXML

#include <Foundation/GSXML.h>
#include <Foundation/NSData.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSException.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSFileManager.h>

/* libxml headers */
#include <tree.h>
#include <entities.h>
#include <parser.h>
#include <parserInternals.h>
#include <SAX.h>
#include <HTMLparser.h>
#include <xmlmemory.h>

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

@interface GSXMLNamespace (GSPrivate)
- (void) _native: (BOOL)value;
@end

@interface GSXMLNode (GSPrivate)
- (void) _native: (BOOL)value;
@end

@interface GSXMLParser (Private)
- (BOOL) _initLibXML;
- (void) _parseChunk: (NSData*)data;
@end

@interface GSSAXHandler (Private)
- (BOOL) _initLibXML;
- (void) _setParser: (GSXMLParser*)value;
@end


@implementation GSXMLDocument : NSObject

/**
 * Return document created using raw libxml data.
 * The resulting document does not 'own' the data, and will not free it.
 */
+ (GSXMLDocument*) documentFrom: (void*)data
{
  return AUTORELEASE([[self alloc] initFrom: data]);
}

/**
 * Create a new document with the specified version.
 */
+ (GSXMLDocument*) documentWithVersion: (NSString*)version
{
  return AUTORELEASE([[self alloc] initWithVersion: version]);
}

+ (void) initialize
{
  if (cacheDone == NO)
    setupCache();
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

- (void) dealloc
{
  if ((native) && lib != NULL)
    {
      xmlFreeDoc(lib);
    }
  [super dealloc];
}

/**
 * Returns a string representation of the document or nil if the
 * document does not have reasonable contents.
 */
- (NSString*) description
{
  NSString	*string = nil;
  xmlChar	*buf = NULL;
  int		length;

  xmlDocDumpMemory(lib, &buf, &length);

  if (buf != 0 && length > 0)
    {
      string = [NSString_class stringWithCString: buf length: length];
      xmlFree(buf);
    }
  return string;
}

- (id) init
{
  NSLog(@"GSXMLDocument: calling -init is not legal");
  RELEASE(self);
  return nil;
}

/**
 * Initialise a new document object using raw libxml data.
 * The resulting document does not 'own' the data, and will not free it.
 */
- (id) initFrom: (void*)data
{
  self = [super init];
  if (self != nil)
    {
      if (data == NULL)
        {
          NSLog(@"%@ - no data for initialization",
	    NSStringFromClass([self class]));
	  DESTROY(self);
          return nil;
        }
      lib = data;
      native = NO;
    }
  return self;
}

/**
 * Initialise a new document with the specified version.<br />
 * Generates the raw data and passes it to -initFrom: to
 * perform basic initialisation, then takes ownership of
 * of the underlying data so it will be freed when this
 * object is deallocated.
 */
- (id) initWithVersion: (NSString*)version
{
  void	*data = xmlNewDoc([version lossyCString]);

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

/**
 * Returns the root node of the document.
 */
- (GSXMLNode*) root
{
  return [GSXMLNode nodeFrom: xmlDocGetRootElement(lib)];
}

/**
 * Sets the root node of the document.  This takes ownership of the
 * underlying data in the supplied node.
 */
- (GSXMLNode*) setRoot: (GSXMLNode*)node
{
  void  *nodeLib = [node lib];
  void  *oldRoot = xmlDocSetRootElement(lib, nodeLib);

  [node _native: NO];
  return oldRoot == NULL ? nil : [GSXMLNode nodeFrom: nodeLib];
}

/**
 * Returns the version string for this document.
 */
- (NSString*) version
{
  return [NSString_class stringWithCString: ((xmlDocPtr)(lib))->version];
}

/**
 * Returns the name of the encoding for this document.
 */
- (NSString*) encoding
{
  return [NSString_class stringWithCString: ((xmlDocPtr)(lib))->encoding];
}

/**
 * Returns a pointer to the raw libxml data used by this document.
 */
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
			     content: (NSString*)content
{
  return [GSXMLNode nodeFrom: 
    xmlNewDocNode(lib, [ns lib], [name lossyCString],
    [content lossyCString])];
}

/**
 * Saves the document to filename.
 */
- (void) save: (NSString*)filename
{
  xmlSaveFile([filename lossyCString], lib);
}

/**
 * Returns a string representation of the document.
 */
- (NSString*) stringValue
{
  NSString	*string = nil;
  xmlChar	*buf = NULL;
  int		length;

  xmlDocDumpMemory(lib, &buf, &length);

  if (buf != 0 && length > 0)
    {
      string = [NSString_class stringWithCString: buf length: length];
      xmlFree(buf);
    }

  return string;
}

- (BOOL) writeToFile: (NSString*)filename atomically: (BOOL)useAuxilliaryFile
{
  NSString	*s = [self description];

  if (s == nil)
    {
      return NO;
    }
  return [s writeToFile: filename atomically: useAuxilliaryFile];
}

- (BOOL) writeToURL: (NSURL*)url atomically: (BOOL)useAuxilliaryFile
{
  NSString	*s = [self description];

  if (s == nil)
    {
      return NO;
    }
  return [s writeToURL: url atomically: useAuxilliaryFile];
}

@end

@implementation GSXMLNamespace : NSObject

static NSMapTable	*nsNames = 0;

+ (void) initialize
{
  if (self == [GSXMLNamespace class])
    {
      if (cacheDone == NO)
	setupCache();
      nsNames = NSCreateMapTable(NSIntMapKeyCallBacks,
	NSNonRetainedObjectMapValueCallBacks, 0);
      NSMapInsert(nsNames,
	(void*)XML_LOCAL_NAMESPACE, (void*)@"XML_LOCAL_NAMESPACE");
    }
}

+ (int) typeFromDescription: (NSString*)desc
{
  NSMapEnumerator	enumerator;
  NSString		*val;
  int			key;

  enumerator = NSEnumerateMapTable(nsNames);
  while (NSNextMapEnumeratorPair(&enumerator, (void**)&key, (void**)&val))
    {
      if ([desc isEqual: val] == YES)
	{
	  return key;
	}
    }
  return -1;
}

+ (NSString*) descriptionFromType: (int)type
{
  NSString	*desc = (NSString*)NSMapGet(nsNames, (void*)[self type]);

  return desc;
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

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

/**
 * Initialise a new document object using raw libxml data.
 * The resulting document does not 'own' the data, and will not free it.
 */
- (id) initFrom: (void*)data
{
  self = [super init];
  if (self != nil)
    {
      if (data == NULL)
        {
          NSLog(@"%@ - no data for initialization",
	    NSStringFromClass([self class]));
	  DESTROY(self);
          return nil;
        }
      lib = data;
      native = NO;
    }
  return self;
}

- (id) initWithNode: (GSXMLNode*)node
	       href: (NSString*)href
	     prefix: (NSString*)prefix
{
  void	*data;

  if (node != nil)
    {
      data = xmlNewNs((xmlNodePtr)[node lib], [href lossyCString],
	[prefix lossyCString]);
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
      data = xmlNewNs(NULL, [href lossyCString], [prefix lossyCString]);
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
- (int) type
{
  return (int)((xmlNsPtr)(lib))->type;
}

- (NSString*) typeDescription
{
  NSString	*desc = (NSString*)NSMapGet(nsNames, (void*)[self type]);

  if (desc == nil)
    {
      desc = @"Unknown namespace type";
    }
  return desc;
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


@implementation GSXMLNamespace (GSPrivate)
- (void) _native: (BOOL)value
{
  NSAssert(native != value, NSInternalInconsistencyException);
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

+ (int) typeFromDescription: (NSString*)desc
{
  NSMapEnumerator	enumerator;
  NSString		*val;
  int			key;

  enumerator = NSEnumerateMapTable(nodeNames);
  while (NSNextMapEnumeratorPair(&enumerator, (void**)&key, (void**)&val))
    {
      if ([desc isEqual: val] == YES)
	{
	  return key;
	}
    }
  return -1;
}

+ (NSString*) descriptionFromType: (int)type
{
  NSString	*desc = (NSString*)NSMapGet(nodeNames, (void*)[self type]);

  return desc;
}

+ (GSXMLNode*) nodeWithNamespace: (GSXMLNamespace*) ns name: (NSString*) name
{
  return AUTORELEASE([[self alloc] initWithNamespace: ns name: name]);
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

- (id) initWithNamespace: (GSXMLNamespace*) ns name: (NSString*) name
{
  self = [super init];
  if (self != nil)
    {
      if (ns != nil)
        {
          [ns _native: NO];
          lib = xmlNewNode((xmlNsPtr)[ns lib], [name lossyCString]);
        }
      else
        {
          lib = xmlNewNode(NULL, [name lossyCString]);
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
          NSLog(@"%@ - no data for initialization",
	    NSStringFromClass([self class]));
	  DESTROY(self);
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
  if (lib != NULL && ((xmlNodePtr)lib)->content!=NULL)
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
  if (lib != NULL && ((xmlNodePtr)lib)->name!=NULL)
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
  if (lib != NULL && ((xmlNodePtr)(lib))->ns != NULL)
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
  if (lib != NULL && ((xmlNodePtr)lib)->nsDef != NULL)
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
  return [self propertiesAsDictionaryWithKeyTransformationSel: NULL];
}

- (NSMutableDictionary*) propertiesAsDictionaryWithKeyTransformationSel:
  (SEL)keyTransformSel
{
  xmlAttrPtr		prop;
  NSMutableDictionary	*d = [NSMutableDictionary dictionary];

  prop = ((xmlNodePtr)(lib))->properties;

  while (prop != NULL)
    {
      const void	*name = prop->name;
      NSString		*key = UTF8Str(name);

      if (keyTransformSel != 0)
	{
	  key = [key performSelector: keyTransformSel];
	}
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

- (int) type
{
  return (int)((xmlNodePtr)(lib))->type;
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
			      content: (NSString*)content
{
  return [GSXMLNode nodeFrom: 
    xmlNewChild(lib, [ns lib], [name lossyCString], [content lossyCString])];
}

- (GSXMLAttribute*) setProp: (NSString*)name value: (NSString*)value
{
  return [GSXMLAttribute attributeFrom: 
    xmlSetProp(lib, [name lossyCString], [value lossyCString])];
}


- (GSXMLNode*) makeComment: (NSString*)content
{
  return [GSXMLNode nodeFrom: xmlAddChild((xmlNodePtr)lib,
    xmlNewComment([content lossyCString]))];
}

- (GSXMLNode*) makePI: (NSString*)name content: (NSString*)content
{
  return [GSXMLNode nodeFrom: 
    xmlAddChild((xmlNodePtr)lib, xmlNewPI([name lossyCString],
    [content lossyCString]))];
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

@implementation GSXMLNode (GSPrivate)
- (void) _native: (BOOL)value
{
  NSAssert(native != value, NSInternalInconsistencyException);
  native = value;
}
@end



@implementation GSXMLAttribute : GSXMLNode

static NSMapTable	*attrNames = 0;

/**
 * Create attribute from underlying libxml data ... you probably don't need
 * to use this yourself.
 */
+ (GSXMLAttribute*) attributeFrom: (void*)data
{
  return AUTORELEASE([[self alloc] initFrom: data]);
}

/**
 * Create a new property carried by a node.
 */
+ (GSXMLAttribute*) attributeWithNode: (GSXMLNode*)node
				 name: (NSString*)name
				value: (NSString*)value
{
  return AUTORELEASE([[self alloc] initWithNode: node name: name value: value]);
}

/**
 * Return the string constant value for the attribute
 * type given.
 */
+ (NSString*) descriptionFromType: (int)type
{
  NSString	*desc = (NSString*)NSMapGet(attrNames, (void*)[self type]);

  return desc;
}

+ (void) initialize
{
  if (self == [GSXMLAttribute class])
    {
      if (cacheDone == NO)
	setupCache();
      attrNames = NSCreateMapTable(NSIntMapKeyCallBacks,
	NSNonRetainedObjectMapValueCallBacks, 0);
      NSMapInsert(attrNames,
	(void*)XML_ATTRIBUTE_CDATA, (void*)@"XML_ATTRIBUTE_CDATA");
      NSMapInsert(attrNames,
	(void*)XML_ATTRIBUTE_ID, (void*)@"XML_ATTRIBUTE_ID");
      NSMapInsert(attrNames,
	(void*)XML_ATTRIBUTE_IDREF, (void*)@"XML_ATTRIBUTE_IDREF");
      NSMapInsert(attrNames,
	(void*)XML_ATTRIBUTE_IDREFS, (void*)@"XML_ATTRIBUTE_IDREFS");
      NSMapInsert(attrNames,
	(void*)XML_ATTRIBUTE_ENTITY, (void*)@"XML_ATTRIBUTE_ENTITY");
      NSMapInsert(attrNames,
	(void*)XML_ATTRIBUTE_ENTITIES, (void*)@"XML_ATTRIBUTE_ENTITIES");
      NSMapInsert(attrNames,
	(void*)XML_ATTRIBUTE_NMTOKEN, (void*)@"XML_ATTRIBUTE_NMTOKEN");
      NSMapInsert(attrNames,
	(void*)XML_ATTRIBUTE_NMTOKENS, (void*)@"XML_ATTRIBUTE_NMTOKENS");
      NSMapInsert(attrNames,
	(void*)XML_ATTRIBUTE_ENUMERATION, (void*)@"XML_ATTRIBUTE_ENUMERATION");
      NSMapInsert(attrNames,
	(void*)XML_ATTRIBUTE_NOTATION, (void*)@"XML_ATTRIBUTE_NOTATION");
    }
}

/**
 * <p>
 *   Return the numeric constant value for the attribute
 *   type named.  This method is inefficient, so the returned
 *   value should be saved for re-use later.  The possible
 *   values are -
 * </p>
 * <list>
 *   <item>XML_ATTRIBUTE_CDATA</item>
 *   <item>XML_ATTRIBUTE_ID</item>
 *   <item>XML_ATTRIBUTE_IDREF	</item>
 *   <item>XML_ATTRIBUTE_IDREFS</item>
 *   <item>XML_ATTRIBUTE_ENTITY</item>
 *   <item>XML_ATTRIBUTE_ENTITIES</item>
 *   <item>XML_ATTRIBUTE_NMTOKEN</item>
 *   <item>XML_ATTRIBUTE_NMTOKENS</item>
 *   <item>XML_ATTRIBUTE_ENUMERATION</item>
 *   <item>XML_ATTRIBUTE_NOTATION</item>
 * </list>
 */
+ (int) typeFromDescription: (NSString*)desc
{
  NSMapEnumerator	enumerator;
  NSString		*val;
  int			key;

  enumerator = NSEnumerateMapTable(attrNames);
  while (NSNextMapEnumeratorPair(&enumerator, (void**)&key, (void**)&val))
    {
      if ([desc isEqual: val] == YES)
	{
	  return key;
	}
    }
  return -1;
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

- (id) init
{
  NSLog(@"GSXMLNode: calling -init is not legal");
  RELEASE(self);
  return nil;
}

/**
 * Generates the raw data for an attribute node and calls -initFrom:
 * to initialise this instance.
 */
- (id) initWithNode: (GSXMLNode*)node
	       name: (NSString*)name
	      value: (NSString*)value
{
  void	*data = (void*)xmlNewProp((xmlNodePtr)[node lib], [name lossyCString],
      [value lossyCString]);

  self = [self initFrom: data];
  if (self != nil)
    {
      native = YES;
    }
  return self;
}

/**
 * Returns underlying raw data associated with this node.
 */
- (void*) lib
{
  return lib;
}

- (NSString*) name
{
  return[NSString_class stringWithCString: ((xmlAttrPtr)(lib))->name];
}

- (GSXMLNamespace*) ns
{
  return [GSXMLNamespace namespaceFrom: ((xmlAttrPtr)(lib))->ns];
}

- (int) type
{
  return (int)((xmlAttrPtr)(lib))->atype;
}

- (NSString*) typeDescription
{
  NSString	*desc = (NSString*)NSMapGet(attrNames, (void*)[self type]);

  if (desc == nil)
    {
      desc = @"Unknown attribute type";
    }
  return desc;
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

+ (NSString*) loadEntity: (NSString*)publicId
		      at: (NSString*)location
{
  return nil;
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
      case NSISOCyrillicStringEncoding:
	NSLog(@"NSISOCyrillicStringEncoding not supported for XML");//??
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
  int	oldVal;
  int	newVal = (yesno == YES) ? 1 : 0;

  xmlGetFeature((xmlParserCtxtPtr)lib, "substitute entities", (void*)&oldVal);
  xmlSetFeature((xmlParserCtxtPtr)lib, "substitute entities", (void*)&newVal);
  return (oldVal == 1) ? YES : NO;
}

- (BOOL) keepBlanks: (BOOL)yesno
{
  int	oldVal;
  int	newVal = (yesno == YES) ? 1 : 0;

  xmlGetFeature((xmlParserCtxtPtr)lib, "keep blanks", (void*)&oldVal);
  xmlSetFeature((xmlParserCtxtPtr)lib, "keep blanks", (void*)&newVal);
  return (oldVal == 1) ? YES : NO;
}

- (BOOL) doValidityChecking: (BOOL)yesno
{
  int	oldVal;
  int	newVal = (yesno == YES) ? 1 : 0;

  xmlGetFeature((xmlParserCtxtPtr)lib, "validate", (void*)&oldVal);
  xmlSetFeature((xmlParserCtxtPtr)lib, "validate", (void*)&newVal);
  return (oldVal == 1) ? YES : NO;
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

/**
 * <p>XML SAX Handler.</p>
 * <p>
 *   GSSAXHandler is a callback-based interface to the XML parser
 *   that operates in a similar (though not identical) manner to
 *   SAX.
 * </p>
 * <p>
 *    Each GSSAXHandler object is associated with a GSXMLParser
 *    object.  As parsing progresses, the mathods of the GSSAXHandler
 *    are invoked by the parser, so the handler is able to deal
 *    with the elements and entities being parsed.
 *  </p>
 *  <p>
 *    The callback methods in the GSSAXHandler class do nothing - it
 *    is intended that you subclass GSSAXHandler and override them.
 *  </p>
 */
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
  NSString			*location;
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
      file = [GSXMLParser loadEntity: entityId at: location];
    }

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
  else
    {
      NSLog(@"don't know how to load entity '%s' id '%s'", url, eid);
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
  int lineNumber=-1;
  int colNumber=-1;

  va_start(args, msg);
  vsprintf(allMsg, msg, args);
  va_end(args);

  NSCAssert(ctx,@"No Context");
  lineNumber=getLineNumber(ctx);
  colNumber=getColumnNumber(ctx);
  [HANDLER warning: UTF8Str(allMsg)
           colNumber:colNumber
           lineNumber:lineNumber];
}

static void
errorFunction(void *ctx, const char *msg, ...)
{
  char allMsg[2048];
  va_list args;
  int lineNumber=-1;
  int colNumber=-1;

  va_start(args, msg);
  vsprintf(allMsg, msg, args);
  va_end(args);
  NSCAssert(ctx,@"No Context");
  lineNumber=getLineNumber(ctx);
  colNumber=getColumnNumber(ctx);
  [HANDLER error: UTF8Str(allMsg)
           colNumber:colNumber
           lineNumber:lineNumber];
}

static void
fatalErrorFunction(void *ctx, const char *msg, ...)
{
  char allMsg[2048];
  va_list args;
  int lineNumber=-1;
  int colNumber=-1;

  va_start(args, msg);
  vsprintf(allMsg, msg, args);
  va_end(args);
  NSCAssert(ctx, @"No Context");
  lineNumber=getLineNumber(ctx);
  colNumber=getColumnNumber(ctx);
  [HANDLER fatalError: UTF8Str(allMsg)           
           colNumber:colNumber
           lineNumber:lineNumber];
}

#undef	HANDLER

/**
 * Create a new SAX handler.
 */
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

/**
 * Return pointer to xmlSAXHandler structure.
 */
- (void*) lib
{
  return lib;
}

/**
 * Return the parser object with which this handler is
 * associated.  This may occasionally be useful.
 */
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

/**
 * Called when the document starts being processed.
 */
- (void) startDocument
{
}

/**
 * Called when the document end has been detected.
 */
- (void) endDocument
{
}

/**
 * Called to detemrine if the document is standalone.
 */
- (int) isStandalone
{
  return 1;
}

/**
 * Called when an opening tag has been processed.
 */
- (void) startElement: (NSString*)elementName
	   attributes: (NSMutableDictionary*)elementAttributes
{
}

/**
 * Called when a closing tag has been processed.
 */
- (void) endElement: (NSString*) elementName
{
}

/**
 * Handle an attribute that has been read by the parser.
 */
- (void) attribute: (NSString*) name value: (NSString*)value
{
}

/**
 * Receiving some chars from the parser.
 */
- (void) characters: (NSString*) name
{
}

/**
 * Receiving some ignorable whitespaces from the parser.
 */
- (void) ignoreWhitespace: (NSString*) ch
{
}

/**
 * A processing instruction has been parsed.
 */
- (void) processInstruction: (NSString*)targetName data: (NSString*)PIdata
{
}

/**
 * A comment has been parsed.
 */
- (void) comment: (NSString*) value
{
}

/**
 * Called when a pcdata block has been parsed.
 */
- (void) cdataBlock: (NSString*)value
{
}

/**
 * Called to return the filenmae from which an entity should be loaded.
 */
- (NSString*) loadEntity: (NSString*)publicId
		      at: (NSString*)location
{
  return nil;
}

/**
 * An old global namespace has been parsed.
 */
- (void) namespaceDecl: (NSString*)name
		  href: (NSString*)href
		prefix: (NSString*)prefix
{
}

/**
 * What to do when a notation declaration has been parsed.
 */
- (void) notationDecl: (NSString*)name
	       public: (NSString*)publicId
	       system: (NSString*)systemId
{
}

/**
 * An entity definition has been parsed.
 */
- (void) entityDecl: (NSString*)name
	       type: (int)type
	     public: (NSString*)publicId
	     system: (NSString*)systemId
	    content: (NSString*)content
{
}

/**
 * An attribute definition has been parsed.
 */
- (void) attributeDecl: (NSString*)nameElement
	 nameAttribute: (NSString*)name
	    entityType: (int)type
	  typeDefValue: (int)defType
	  defaultValue: (NSString*)value
{
}

/**
 * An element definition has been parsed.
 */
- (void) elementDecl: (NSString*)name
		type: (int)type
{
}

/**
 * What to do when an unparsed entity declaration is parsed.
 */
- (void) unparsedEntityDecl: (NSString*)name
	       publicEntity: (NSString*)publicId
	       systemEntity: (NSString*)systemId
	       notationName: (NSString*)notation
{
}

/**
 * Called when an entity reference is detected.
 */
- (void) reference: (NSString*) name
{
}

/**
 * An old global namespace has been parsed.
 */
- (void) globalNamespace: (NSString*)name
		    href: (NSString*)href
		  prefix: (NSString*)prefix
{
}

/**
 * Called when a warning message needs to be output.
 */
- (void) warning: (NSString*)e
{
}

/**
 * Called when an error message needs to be output.
 */
- (void) error: (NSString*)e
{
}

/**
 * Called when a fatal error message needs to be output.
 */
- (void) fatalError: (NSString*)e
{
}

/**
 * Called when a warning message needs to be output.
 */
- (void) warning: (NSString*)e
       colNumber: (int)colNumber
      lineNumber: (int)lineNumber
{
  [self warning:e];
}

/**
 * Called when an error message needs to be output.
 */
- (void) error: (NSString*)e
     colNumber: (int)colNumber
    lineNumber: (int)lineNumber
{
  [self error:e];
}

/**
 * Called when a fatal error message needs to be output.
 */
- (void) fatalError: (NSString*)e
       colNumber: (int)colNumber
      lineNumber: (int)lineNumber
{
  [self fatalError:e];
}

/**
 * Called to find out whether there is an internal subset.
 */
- (int) hasInternalSubset
{
  return 0;
}

/**
 * Called to find out whether there is an internal subset.
 */
- (BOOL) internalSubset: (NSString*)name
	     externalID: (NSString*)externalID
	       systemID: (NSString*)systemID
{
  return NO;
}

/**
 * Called to find out whether there is an external subset.
 */
- (int) hasExternalSubset
{
  return 0;
}

/**
 * Called to find out whether there is an external subset.
 */
- (BOOL) externalSubset: (NSString*)name
	     externalID: (NSString*)externalID
		ystemID: (NSString*)systemID
{
  return NO;
}

/**
 * get an entity by name
 */
- (void*) getEntity: (NSString*)name
{
  return 0;
}

/**
 * get a aparameter entity by name
 */
- (void*) getParameterEntity: (NSString*)name
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

#else

#include	<Foundation/NSObjCRuntime.h>
#include	<Foundation/NSCoder.h>

/*
 * Build dummy implementations of the classes if libxml is not available
 */
@interface GSXMLDummy : NSObject
@end
@interface GSXMLAttribute : GSXMLDummy
@end
@interface GSXMLDocument : GSXMLDummy
@end
@interface GSXMLHandler : GSXMLDummy
@end
@interface GSXMLNamespace : GSXMLDummy
@end
@interface GSXMLNode : GSXMLDummy
@end
@interface GSSAXHandler : GSXMLDummy
@end
@interface GSXMLParser : GSXMLDummy
@end
@implementation GSXMLDummy
+ (id) allocWithZone: (NSZone*)z
{
  NSLog(@"Not built with libxml ... %@ unusable in %@",
    NSStringFromClass(self), NSStringFromSelector(_cmd));
  return nil;
}
- (id) init
{
  NSLog(@"Not built with libxml ... %@ unusable in %@",
    NSStringFromClass([self class]), NSStringFromSelector(_cmd));
  RELEASE(self);
  return nil;
}
- (id) initWithCoder: (NSCoder*)aCoder
{
  NSLog(@"Not built with libxml ... %@ unusable in %@",
    NSStringFromClass([self class]), NSStringFromSelector(_cmd));
  RELEASE(self);
  return nil;
}
@end
@implementation GSXMLAttribute
@end
@implementation GSXMLDocument
@end
@implementation GSXMLHandler
@end
@implementation GSXMLNamespace
@end
@implementation GSXMLNode
@end
@implementation GSSAXHandler
@end
@implementation GSXMLParser
@end
#endif

