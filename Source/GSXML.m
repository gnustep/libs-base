/* Implementation for GSXMLDocument for GNUstep xmlparser

   Written by: Michael Pakhantsov  <mishel@berest.dp.ua>
   Date: Jule 2000
*/

#include <libxml/parser.h>
#include <libxml/parserInternals.h>
#include <libxml/SAX.h>

#include <Foundation/GSXML.h>
#include <Foundation/NSData.h>
#include <Foundation/NSFileManager.h>

extern int xmlDoValidityCheckingDefaultValue;
extern int xmlGetWarningsDefaultValue;

/*
 * optimization
 *
 */
static Class NSString_class;
static IMP csImp;
static SEL csSel = @selector(stringWithCString:);

static BOOL cacheDone = NO;

static void
setupCache()
{
  if (cacheDone == NO)
    {
      cacheDone = YES;
      NSString_class = [NSString class];
      csImp
	= [NSString_class methodForSelector: csSel];
    }
}


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
  return [NSString stringWithCString: ((xmlDocPtr)(lib))->version];
}

- (NSString*) encoding
{
  return [NSString stringWithCString: ((xmlDocPtr)(lib))->encoding];
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


- (GSXMLNode*) makeNode: (GSXMLNamespace*)ns
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
+ (GSXMLNamespace*) namespace: (GSXMLNode*)node
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
  return (*csImp)(NSString_class, csSel, ((xmlNsPtr)(lib))->prefix);
}

/* the namespace reference */
- (NSString*) href
{
  return (*csImp)(NSString_class, csSel, ((xmlNsPtr)(lib))->href);
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

+ (void) initialize
{
  if (cacheDone == NO)
    setupCache();
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
      return (*csImp)(NSString_class, csSel, ((xmlNodePtr)lib)->content);
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
      return (*csImp)(NSString_class, csSel, ((xmlNodePtr)lib)->name);
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
  xmlAttrPtr		prop;
  NSMutableDictionary	*d = [NSMutableDictionary dictionary];

  prop = ((xmlNodePtr)(lib))->properties;

  while (prop != NULL)
    {
      const void	*name = prop->name;

      if (prop->children != NULL)
	{
	   const void	*content = prop->children->content;

	   [d setObject: (*csImp)(NSString_class, csSel, content)
		 forKey: (*csImp)(NSString_class, csSel, name)];
	}
      else
	{
	   [d setObject: nil
		 forKey: (*csImp)(NSString_class, csSel, name)];
	}
      prop = prop->next;
  }

  return d;
}

- (GSXMLElementType) type
{
  return (GSXMLElementType)((xmlNodePtr)(lib))->type;
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

- (GSXMLNode*) makeChild: (GSXMLNamespace*)ns
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

+ (GSXMLAttribute*) attributeFromNode: (GSXMLNode*)node
				 name: (NSString*)name
				value: (NSString*)value;
{
  return AUTORELEASE([[self alloc] initFromNode: node name: name value: value]);
}

- (id) initFromNode: (GSXMLNode*)node
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
  return[NSString stringWithCString: ((xmlAttrPtr)(lib))->name];
}


- (NSString*) value
{
  if (((xmlNodePtr)lib)->children != NULL
    && ((xmlNodePtr)lib)->children->content != NULL)
    {
      return (*csImp)(NSString_class, csSel,
	((xmlNodePtr)(lib))->children->content);
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


/* Internal interface for GSSAXHandler */
@interface GSSAXHandler (internal)
- (void) native: (BOOL)value;
@end

@implementation GSSAXHandler (Internal)
- (void) native: (BOOL)value
{
   native = value;
}
@end


@implementation GSXMLParser : NSObject

+ (void) initialize
{
  if (cacheDone == NO)
    setupCache();
}

+ (GSXMLParser*) parser: (id)source
{
  return AUTORELEASE([[self alloc] initWithSAXHandler: nil source: source]);
}

+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
			       source: (id)source
{
  return AUTORELEASE([[self alloc] initWithSAXHandler: handler source: source]);
}

- (id) initWithSAXHandler: (GSSAXHandler*)handler source: (id)source
{
  self = [super init];

  if (self != nil)
    {
      if ([source isKindOfClass: [NSData class]])
        {
        }
      else if ([source isKindOfClass: [NSString class]])
        {
        }
      else
        {
          NSLog(@"source must be NSString, NSData or NSURL type");
        }
      src = [source copy];
      saxHandler = handler;
    }
  else
    {
     NSLog(@"Can't create GSXMLParser");
    }

  return self;
}

- (BOOL) parse
{
  if (lib != NULL)
    {
      xmlFreeDoc(((xmlParserCtxtPtr)lib)->myDoc);
      xmlClearParserCtxt(lib);
    }
  if ([src isKindOfClass: [NSData class]])
    {
      lib = (void*)xmlCreateMemoryParserCtxt((void*)[src bytes],
	[src length]-1);
      if (lib == NULL)
        {
          NSLog(@"out of memory");
          return NO;
        }
    }
  else if ([src isKindOfClass: [NSString class]])
    {
      NSFileManager	*mgr = [NSFileManager defaultManager];

      if ([mgr isReadableFileAtPath: src] == NO)
	{
	  NSLog(@"File to parse (%@) is not readable", src);
          return NO;
	}
      lib = (void*)xmlCreateFileParserCtxt([src cString]);
      if (lib == NULL)
        {
          NSLog(@"out of memory");
          return NO;
        }
    }
  else
    {
       NSLog(@"source must be NSString, NSData or NSURL type");
       return NO;
    }

  if (saxHandler != nil)
    {
      free(((xmlParserCtxtPtr)lib)->sax);
      ((xmlParserCtxtPtr)lib)->sax = [saxHandler lib];
      ((xmlParserCtxtPtr)lib)->userData = saxHandler;
      [saxHandler native: NO];
    }

  xmlParseDocument(lib);

  if (((xmlParserCtxtPtr)lib)->wellFormed)
    return YES;
  else
    return NO;
}

- (GSXMLDocument*) doc
{
  return [GSXMLDocument documentFrom: ((xmlParserCtxtPtr)lib)->myDoc];
}

- (void) dealloc
{
  RELEASE(src);
  if (lib != NULL)
    {
      xmlFreeDoc(((xmlParserCtxtPtr)lib)->myDoc);
      xmlFreeParserCtxt(lib);
    }
  [super dealloc];
}


- (BOOL) substituteEntities: (BOOL)yesno
{
  return xmlSubstituteEntitiesDefault(yesno);
}

- (BOOL) keepBlanks: (BOOL)yesno
{
  return xmlKeepBlanksDefault(yesno);
}

- (BOOL) doValidityChecking: (BOOL)yesno
{
  return !(xmlDoValidityCheckingDefaultValue = yesno);
}

- (BOOL) getWarnings: (BOOL)yesno
{
  return !(xmlGetWarningsDefaultValue = yesno);
}


- (void) setExternalEntityLoader: (void*)function
{
  xmlSetExternalEntityLoader((xmlExternalEntityLoader)function);
}

- (int) errNo
{
  return ((xmlParserCtxtPtr)lib)->errNo;
}

@end



@implementation GSSAXHandler : NSObject

+ (void) initialize
{
  if (cacheDone == NO)
    setupCache();
}

void startDocumentFunction(void *ctx)
{
  [(GSSAXHandler*)ctx startDocument];
}

void endDocumentFunction(void *ctx)
{
  [(GSSAXHandler*)ctx endDocument];
}

int isStandaloneFunction(void *ctx)
{
  [(GSSAXHandler*)ctx isStandalone];
  return (0);
}


int hasInternalSubsetFunction(void *ctx)
{
  [(GSSAXHandler*)ctx hasInternalSubset];
  return (0);
}

int hasExternalSubsetFunction(void *ctx)
{
  [(GSSAXHandler*)ctx hasExternalSubset];
  return (0);
}

void internalSubsetFunction(void *ctx, const char *name,
	       const xmlChar *ExternalID, const xmlChar *SystemID)
{
  [(GSSAXHandler*)ctx internalSubset: (*csImp)(NSString_class, csSel, name)
                      externalID: (*csImp)(NSString_class, csSel, ExternalID)
                        systemID: (*csImp)(NSString_class, csSel, SystemID)];
}

xmlParserInputPtr resolveEntityFunction(void *ctx, const char *publicId, const char *systemId)
{
    [(GSSAXHandler*)ctx resolveEntity: (*csImp)(NSString_class, csSel, publicId)
                         systemID: (*csImp)(NSString_class, csSel, systemId)];
    return(NULL);
}

xmlEntityPtr getEntityFunction(void *ctx, const char *name)
{
    [(GSSAXHandler*)ctx getEntity: (*csImp)(NSString_class, csSel, name)];
    return(NULL);
}

xmlEntityPtr getParameterEntityFunction(void *ctx, const char *name)
{
    [(GSSAXHandler*)ctx getParameterEntity: (*csImp)(NSString_class, csSel, name)];
    return(NULL);
}


void entityDeclFunction(void *ctx, const char *name, int type,
          const char *publicId, const char *systemId, char *content)
{
  [(GSSAXHandler*)ctx entityDecl: (*csImp)(NSString_class, csSel, name)
                        type: type
                      public: (*csImp)(NSString_class, csSel, publicId)
                      system: (*csImp)(NSString_class, csSel, systemId)
                     content: (*csImp)(NSString_class, csSel, content)];
}

void attributeDeclFunction(void *ctx, const char *elem, const char *name,
              int type, int def, const char *defaultValue,
	      xmlEnumerationPtr tree)
{
  [(GSSAXHandler*)ctx attributeDecl: (*csImp)(NSString_class, csSel, elem)
                            name: (*csImp)(NSString_class, csSel, name)
                            type: type
                    typeDefValue: def
                    defaultValue: (*csImp)(NSString_class, csSel, defaultValue)];
}

void elementDeclFunction(void *ctx, const char *name, int type,
	    xmlElementContentPtr content)
{
  [(GSSAXHandler*)ctx elementDecl: (*csImp)(NSString_class, csSel, name)
                         type: type];

}

void notationDeclFunction(void *ctx, const char *name,
       const char *publicId, const char *systemId)
{
  [(GSSAXHandler*)ctx notationDecl: (*csImp)(NSString_class, csSel, name)
                      public: (*csImp)(NSString_class, csSel, publicId)
                      system: (*csImp)(NSString_class, csSel, systemId)];
}

void unparsedEntityDeclFunction(void *ctx, const char *name,
       const char *publicId, const char *systemId,
       const char *notationName)
{
  [(GSSAXHandler*)ctx unparsedEntityDecl: (*csImp)(NSString_class, csSel, name)
                              public: (*csImp)(NSString_class, csSel, publicId)
                              system: (*csImp)(NSString_class, csSel, systemId)
                              notationName: (*csImp)(NSString_class, csSel, notationName)];
}


void startElementFunction(void *ctx, const char *name, const char **atts)
{
    int i;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSString *key, *obj;

    if (atts != NULL)
      {
        for (i = 0; (atts[i] != NULL); i++)
          {
            key = [NSString stringWithCString: atts[i++]];
            obj = [NSString stringWithCString: atts[i]];
            [dict setObject: obj forKey: key];
          }
      }
    [(GSSAXHandler*)ctx startElement: (*csImp)(NSString_class, csSel, name) attributes: dict];
}

void endElementFunction(void *ctx, const char *name)
{
  [(GSSAXHandler*)ctx endElement: (*csImp)(NSString_class, csSel, name)];
}

void charactersFunction(void *ctx, const char *ch, int len)
{
  [(GSSAXHandler*)ctx characters: [NSString stringWithCString: ch length: len] length: len];
}

void referenceFunction(void *ctx, const char *name)
{
  [(GSSAXHandler*)ctx reference: (*csImp)(NSString_class, csSel, name)];
}

void ignorableWhitespaceFunction(void *ctx, const char *ch, int len)
{
  [(GSSAXHandler*)ctx ignoreWhitespace: (*csImp)(NSString_class, csSel, ch) length: len];
}

void processInstructionFunction(void *ctx, const char *target,  const char *data)
{
  [(GSSAXHandler*)ctx processInstruction: (*csImp)(NSString_class, csSel, target)
                                  data: (*csImp)(NSString_class, csSel, data)];
}

void cdataBlockFunction(void *ctx, const char *value, int len)
{
  [(GSSAXHandler*)ctx cdataBlock: (*csImp)(NSString_class, csSel, value) length: len];
}

void commentFunction(void *ctx, const char *value)
{
  [(GSSAXHandler*)ctx comment: (*csImp)(NSString_class, csSel, value)];
}

void warningFunction(void *ctx, const char *msg, ...)
{
    char allMsg[2048];
    va_list args;

    va_start(args, msg);
    vsprintf(allMsg, msg, args);
    va_end(args);

    [(GSSAXHandler*)ctx warning: (*csImp)(NSString_class, csSel, allMsg)];
}

void errorFunction(void *ctx, const char *msg, ...)
{
    char allMsg[2048];
    va_list args;

    va_start(args, msg);
    vsprintf(allMsg, msg, args);
    va_end(args);
    [(GSSAXHandler*)ctx error: (*csImp)(NSString_class, csSel, allMsg)];

}

void fatalErrorFunction(void *ctx, const char *msg, ...)
{
    char allMsg[2048];
    va_list args;

    va_start(args, msg);
    vsprintf(allMsg, msg, args);
    va_end(args);
    [(GSSAXHandler*)ctx fatalError: (*csImp)(NSString_class, csSel, allMsg)];
}




+ (GSSAXHandler*) handler
{
  return AUTORELEASE([[self alloc] init]);
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
     lib = (xmlSAXHandler*)malloc(sizeof(xmlSAXHandler));
     if (lib == NULL)
        {
          NSLog(@"GSSAXHandler: out of memory\n");
	  RELEASE(self);
	  return nil;
        }
     memset(lib, 0, sizeof(xmlSAXHandler));
     native = YES;

    ((xmlSAXHandlerPtr)lib)->internalSubset         = internalSubsetFunction;
    ((xmlSAXHandlerPtr)lib)->isStandalone           = isStandaloneFunction;
    ((xmlSAXHandlerPtr)lib)->hasInternalSubset      = hasInternalSubsetFunction;
    ((xmlSAXHandlerPtr)lib)->hasExternalSubset      = hasExternalSubsetFunction;
    ((xmlSAXHandlerPtr)lib)->resolveEntity          = resolveEntityFunction;
    ((xmlSAXHandlerPtr)lib)->getEntity              = getEntityFunction;
    ((xmlSAXHandlerPtr)lib)->entityDecl             = entityDeclFunction;
    ((xmlSAXHandlerPtr)lib)->notationDecl           = notationDeclFunction;
    ((xmlSAXHandlerPtr)lib)->attributeDecl          = attributeDeclFunction;
    ((xmlSAXHandlerPtr)lib)->elementDecl            = elementDeclFunction;
    ((xmlSAXHandlerPtr)lib)->unparsedEntityDecl     = unparsedEntityDeclFunction;
    ((xmlSAXHandlerPtr)lib)->startDocument          = startDocumentFunction;
    ((xmlSAXHandlerPtr)lib)->endDocument            = endDocumentFunction;
    ((xmlSAXHandlerPtr)lib)->startElement           = startElementFunction;
    ((xmlSAXHandlerPtr)lib)->endElement             = endElementFunction;
    ((xmlSAXHandlerPtr)lib)->reference              = referenceFunction;
    ((xmlSAXHandlerPtr)lib)->characters             = charactersFunction;
    ((xmlSAXHandlerPtr)lib)->ignorableWhitespace    = ignorableWhitespaceFunction;
    ((xmlSAXHandlerPtr)lib)->processingInstruction  = processInstructionFunction;
    ((xmlSAXHandlerPtr)lib)->comment                = commentFunction;
    ((xmlSAXHandlerPtr)lib)->warning                = warningFunction;
    ((xmlSAXHandlerPtr)lib)->error                  = errorFunction;
    ((xmlSAXHandlerPtr)lib)->fatalError             = fatalErrorFunction;
    ((xmlSAXHandlerPtr)lib)->getParameterEntity     = getParameterEntityFunction;
    ((xmlSAXHandlerPtr)lib)->cdataBlock             = cdataBlockFunction;
    }
  return self;
}

- (void*) lib
{
  return lib;
}

- (void) dealloc
{
  if (native == YES && lib != NULL)
    {
      free(lib);
    }
  [super dealloc];
}

-(void) startDocument
{

}

-(void) endDocument
{
}

-(void) startElement: (NSString*)elementName
          attributes: (NSMutableDictionary*)elementAttributes;
{
}

-(void) endElement: (NSString*) elementName
{
}

-(void) attribute: (NSString*) name value: (NSString*)value
{
}

- (void) characters: (NSString*) name length: (int)len
{
}

- (void) ignoreWhitespace: (NSString*) ch length: (int)len
{
}

- (void) processInstruction: (NSString*)targetName data: (NSString*)PIdata
{
}

-(void) comment: (NSString*) value
{
}

-(void) cdataBlock: (NSString*)value length: (int)len
{

}

-(void) resolveEntity: (NSString*)publicIdEntity systemEntity: (NSString*)systemIdEntity
{

}
-(void) namespaceDecl: (NSString*) name
                 href: (NSString*) href
               prefix: (NSString*) prefix;
{

}
-(void) notationDecl: (NSString*)name public: (NSString*)publicId system: (NSString*)systemId
{

}
-(void) entityDecl: (NSString*) name
        type: (int)       type
      public: (NSString*) publicId
      system: (NSString*) systemId
     content: (NSString*) content;
{

}
-(void) attributeDecl: (NSString*) nameElement
        nameAttribute: (NSString*) name
        entityType:    (int)       type
        typeDefValue:  (int)       defType
        defaultValue:  (NSString*) value;
{

}
-(void) elementDecl: (NSString*) name
        type: (int)       type;
{

}
-(void) unparsedEntityDecl: (NSString*) name
              publicEntity: (NSString*) publicId
              systemEntity: (NSString*) systemId
              notationName: (NSString*) notation;
{

}

-(void) reference: (NSString*) name
{
}

-(void) globalNamespace: (NSString*) name href: (NSString*)href prefix: (NSString*) prefix
{

}
-(void) warning: (NSString*)e
{
}
-(void) error: (NSString*)e
{
}
-(void) fatalError: (NSString*)e
{
}


- (void) hasInternalSubset
{
}
- (void) internalSubset: (NSString*)name
            externalID: (NSString*)externalID
              systemID: (NSString*)systemID;
{
}

-(void) hasExternalSubset
{
}


- (void) getEntity: (NSString*)name
{
}


@end
