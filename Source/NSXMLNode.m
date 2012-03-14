/* Implementation for NSXMLNode for GNUStep
   Copyright (C) 2008 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Created: September 2008

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#import "common.h"

#define GSInternal	NSXMLNodeInternal
#define	GS_XMLNODETYPE	xmlNode

#import "NSXMLPrivate.h"
#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLNode)

#if defined(HAVE_LIBXML)

static int
countAttributes(xmlNodePtr node)
{
  int count = 0;
  xmlAttrPtr attr = node->properties;

  while (attr) 
    {
      count++;
      attr = attr->next;
    }

  return count;
}

static BOOL
isEqualAttr(const xmlAttrPtr attrA, const xmlAttrPtr attrB)
{
  xmlChar	*contentA;
  xmlChar	*contentB;
  const xmlChar	*nameA;
  const xmlChar	*nameB;

  /* what has to be the same for two attributes to be equal --
   * just their values??
   */
  if (attrB == attrA)
    {
      return YES;
    }

  if (attrA == NULL || attrB == NULL)
    {
      return NO;
    }

  nameA = attrA->name;
  nameB = attrB->name;

  if (xmlStrcmp(nameA, nameB) == 0)
    {
      // get the content...
      contentA = xmlNodeGetContent((const xmlNodePtr)attrA);
      contentB = xmlNodeGetContent((const xmlNodePtr)attrB);

      if (xmlStrcmp(contentA, contentB) == 0)
	{
          xmlFree(contentA);
          xmlFree(contentB);
	  return YES;
	}
      xmlFree(contentA);
      xmlFree(contentB);
      return NO;
    }
  
  return NO;
}

static xmlAttrPtr
findAttrWithName(xmlNodePtr node, const xmlChar* targetName)
{
  xmlAttrPtr attr = node->properties;

  // find an attr in node with the given name, and return it, else NULL
  while ((attr != NULL) && xmlStrcmp(attr->name, targetName) != 0) 
    {
      attr = attr->next;
    }

  return attr;
}


static BOOL
isEqualAttributes(xmlNodePtr nodeA, xmlNodePtr nodeB)
{
  xmlAttrPtr attrA = NULL;

  if (countAttributes(nodeA) != countAttributes(nodeB))
    return NO;
  
  attrA = nodeA->properties;
  while (attrA)
    {
      xmlAttrPtr attrB = findAttrWithName(nodeB, attrA->name);
      if (!isEqualAttr(attrA, attrB))
	{
	  return NO;
	}
      attrA = attrA->next;
    }

  return YES;
}

static BOOL
isEqualNode(xmlNodePtr nodeA, xmlNodePtr nodeB)
{
  if (nodeA == nodeB)
    return YES;

  if (nodeA->type != nodeB->type)
    return NO;
  
  if (nodeA->type == XML_NAMESPACE_DECL) 
    {
      xmlNsPtr nsA = (xmlNsPtr)nodeA;
      xmlNsPtr nsB = (xmlNsPtr)nodeB;
      
      if (xmlStrcmp(nsA->href, nsB->href) != 0)
	{
	  return NO;
	}
      if (xmlStrcmp(nsA->prefix, nsB->prefix) != 0)
	{
	  return NO;
	}
      
      return YES;
    }

  if (xmlStrcmp(nodeA->name, nodeB->name) != 0)
    return NO;
  
  if (nodeA->type == XML_ELEMENT_NODE) 
    {
      xmlChar *contentA = NULL;
      xmlChar *contentB = NULL;

      if (!isEqualAttributes(nodeA, nodeB))
	{
	  return NO;
	}

      // Get the value of any text node underneath the current element.
      contentA = xmlNodeGetContent((const xmlNodePtr)nodeA);
      contentB = xmlNodeGetContent((const xmlNodePtr)nodeB);
      if (xmlStrcmp(contentA, contentB) != 0)
	{
          xmlFree(contentA);
          xmlFree(contentB);
	  return NO;
	}
      xmlFree(contentA);
      xmlFree(contentB);
    }
  // FIXME: Handle more node types
  
  return YES;
}

static BOOL
isEqualTree(xmlNodePtr nodeA, xmlNodePtr nodeB)
{
  xmlNodePtr childA;
  xmlNodePtr childB;

  if (nodeA == nodeB)
    {
      return YES;
    }
  
  if (nodeA == NULL || nodeB == NULL)
    {
      return NO;
    }
  
  if (!isEqualNode(nodeA, nodeB))
    {
      return NO;
    }
  
  if (nodeA->type == XML_NAMESPACE_DECL) 
    {
      return YES;
    }

  // Check children
  childA = nodeA->children;
  childB = nodeB->children;
  while (isEqualTree(childA, childB))
    {
      if (childA == NULL)
        {
          return YES;
        }
      else
        {
          childA = childA->next;
          childB = childB->next;
        }
    }
  
  return NO;
}

/* FIXME ... the libxml2 data structure representing a namespace has a
 * completely different layout from that of almost all other nodes, so
 * the generic xmlNode code won't work and we need to check the type
 * in every method we use!
 */
@implementation NSXMLNode (Private)
- (void *) _node
{
  return internal->node;
}

- (void) _setNode: (void *)_anode
{
  DESTROY(internal->subNodes);
  internal->node = _anode;
  if (internal->node != NULL)
    {
      if (internal->node->type == XML_NAMESPACE_DECL)
        {
          ((xmlNsPtr)(internal->node))->_private = self;
        }
      else
        {
          internal->node->_private = self;
        }
    }
}

+ (NSXMLNode *) _objectForNode: (xmlNodePtr)node
{
  NSXMLNode *result = nil;
  
  if (node)
    {
      if (node->type == XML_NAMESPACE_DECL)
        {
          result = ((xmlNs *)node)->_private;
        }
      else
        {
          result = node->_private;
        }
      if (result == nil)
	{
          Class cls;
          NSXMLNodeKind kind;
          xmlElementType type = node->type;
          xmlDoc *docNode;
          NSXMLDocument *doc = nil;
          
	  switch (type)
	    {
	      case XML_DOCUMENT_NODE:
              case XML_HTML_DOCUMENT_NODE:
		cls = [NSXMLDocument class];
		kind = NSXMLDocumentKind;
		break;
	      case XML_ELEMENT_NODE: 
		cls = [NSXMLElement class];
		kind = NSXMLElementKind;
		break;
	      case XML_DTD_NODE:
		cls = [NSXMLDTD class];
		kind = NSXMLDTDKind;
		break;
	      case XML_ATTRIBUTE_DECL: 
		cls = [NSXMLDTDNode class];
		kind = NSXMLAttributeDeclarationKind;
		break;
	      case XML_ELEMENT_DECL: 
		cls = [NSXMLDTDNode class];
		kind = NSXMLElementDeclarationKind;
		break;
	      case XML_ENTITY_DECL: 
		cls = [NSXMLDTDNode class];
		kind = NSXMLEntityDeclarationKind;
		break;
	      case XML_NOTATION_NODE: 
		cls = [NSXMLDTDNode class];
		kind = NSXMLNotationDeclarationKind;
		break;
	      case XML_ATTRIBUTE_NODE: 
		cls = [NSXMLNode class];
		kind = NSXMLAttributeKind;
		break;
	      case XML_CDATA_SECTION_NODE:
		cls = [NSXMLNode class];
		kind = NSXMLTextKind;
                // FIXME: Should set option
		break;
	      case XML_COMMENT_NODE: 
		cls = [NSXMLNode class];
		kind = NSXMLCommentKind;
		break;
	      case XML_NAMESPACE_DECL: 
		cls = [NSXMLNode class];
		kind = NSXMLNamespaceKind;
		break;
	      case XML_PI_NODE: 
		cls = [NSXMLNode class];
		kind = NSXMLProcessingInstructionKind;
		break;
	      case XML_TEXT_NODE: 
		cls = [NSXMLNode class];
		kind = NSXMLTextKind;
		break;
	      default: 
		NSLog(@"ERROR: _objectForNode: called with a node of type %d",
		  type);
		return nil;
		break;
	    }
          if (node->type == XML_NAMESPACE_DECL)
            {
              docNode = NULL;
            }
          else
            {
              docNode = node->doc;
            }

          if ((docNode != NULL) && ((xmlNodePtr)docNode != node))
            {
              doc = (NSXMLDocument*)[self _objectForNode: (xmlNodePtr)docNode];
              if (doc != nil)
                {
                  cls = [[doc class] replacementClassForClass: cls];
                }
            }

          result = [[cls alloc] _initWithNode: node kind: kind];
	  AUTORELEASE(result);
          if (node->type == XML_NAMESPACE_DECL)
            {
              [doc _addSubNode: result];
            }
          else
            {
              if (node->parent)
                {
                  NSXMLNode *parent = [self _objectForNode: node->parent];
                  [parent _addSubNode: result];
                }
            }
	}
    }
  
  return result;
}

- (void) _addSubNode: (NSXMLNode *)subNode
{
  if (!internal->subNodes)
    internal->subNodes = [[NSMutableArray alloc] init];
  if ([internal->subNodes indexOfObjectIdenticalTo: subNode] == NSNotFound)
    {
      [internal->subNodes addObject: subNode];
    }
}

- (void) _removeSubNode: (NSXMLNode *)subNode
{
  // retain temporarily so we can safely remove from our subNodes list first
  [subNode retain]; 
  [internal->subNodes removeObjectIdenticalTo: subNode];
  // release temporary hold. Apple seems to do an autorelease here.
  [subNode autorelease];
}

- (void) _createInternal
{
  GS_CREATE_INTERNAL(NSXMLNode);
}

- (id) _initWithNode: (xmlNodePtr)node kind: (NSXMLNodeKind)kind
{
  if ((self = [super init]))
    {
      [self _createInternal];
      [self _setNode: node];
      internal->kind = kind;
    }
  return self;
}

- (xmlNodePtr) _childNodeAtIndex: (NSUInteger)index
{
  NSUInteger count = 0;
  xmlNodePtr node = internal->node;
  xmlNodePtr children;

  if (node->type == XML_NAMESPACE_DECL)
    return NULL;

  children = node->children;
  if (!children)
    return NULL; // the Cocoa docs say it returns nil if there are no children

  while (children != NULL && count++ < index)
    {
      children = children->next;
    }

  if (count < index)
    [NSException raise: NSRangeException format: @"child index too large"];

  return children;
}

- (void) _insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index
{
  /* this private method provides the common insertion
   * implementation used by NSXMLElement and NSXMLDocument
   */
  
  // Get all of the nodes...
  xmlNodePtr parentNode = internal->node; // we are the parent
  xmlNodePtr childNode = (xmlNodePtr)[child _node];
  xmlNodePtr curNode = [self _childNodeAtIndex: index];
  BOOL mergeTextNodes = NO; // is there a defined option for this?

  if (mergeTextNodes || childNode->type == XML_ATTRIBUTE_NODE)
    {
      // this uses the built-in libxml functions which merge adjacent text nodes
      xmlNodePtr addedNode = NULL;

      if (curNode == NULL)
        {
          addedNode = xmlAddChild(parentNode, childNode);
        }
      else
        {
          addedNode = xmlAddPrevSibling(curNode, childNode);
        }
      if (addedNode != childNode)
        {
          [child _setNode: NULL];
          child = [NSXMLNode _objectForNode: addedNode];
        }
    }
  else if (childNode->type == XML_NAMESPACE_DECL)
    {
      // FIXME
    }
  else
    {
      /* here we avoid merging adjacent text nodes by linking
       * the new node in "by hand"
       */
      childNode->parent = parentNode;
      xmlSetTreeDoc(childNode, parentNode->doc);
      if (curNode)
	{
	  // insert childNode before an existing node curNode
	  xmlNodePtr prevNode = curNode->prev;
	  curNode->prev = childNode;
	  childNode->next = curNode;
	  if (prevNode)
	    {
	      childNode->prev = prevNode;
	      prevNode->next = childNode;
	    }
	  else
	    {
	      /* in this case, this is the new "first child",
	       * so update our parent to point to it
	       */
	      parentNode->children = childNode;
	    }
	}
      else
	{
	  // not inserting before an existing node... add as new "last child"
	  xmlNodePtr formerLastChild = parentNode->last;
	  if (formerLastChild)
	    {
	      formerLastChild->next = childNode;
	      childNode->prev = formerLastChild;
	      parentNode->last = childNode;
	    }
	  else
	    {
	      // no former children -- this is the first
	      parentNode->children = childNode;
	      parentNode->last = childNode;
	    }
	}
    }

  [self _addSubNode: child];
}

- (void) _invalidate
{
  internal->kind = NSXMLInvalidKind;
  [self _setNode: NULL];
}

@end

static void
clearPrivatePointers(xmlNodePtr aNode)
{
  if (!aNode)
    return;

  if (aNode->type == XML_NAMESPACE_DECL)
    {
      xmlNsPtr	ns = (xmlNsPtr)aNode;

      ns->_private = NULL;
      clearPrivatePointers((xmlNodePtr)ns->next);
      return;
    }

  aNode->_private = NULL;
  clearPrivatePointers(aNode->children);
  clearPrivatePointers(aNode->next);
  if (aNode->type == XML_ELEMENT_NODE)
    {
      clearPrivatePointers((xmlNodePtr)(aNode->properties));
    }
  // FIXME: Handle more node types
}

static int
register_namespaces(xmlXPathContextPtr xpathCtx, const xmlChar* nsList) 
{
  xmlChar* nsListDup;
  xmlChar* prefix;
  xmlChar* href;
  xmlChar* next;
  
  assert(xpathCtx);
  assert(nsList);
  
  nsListDup = xmlStrdup(nsList);
  if (nsListDup == NULL)
    {
      NSLog(@"Error: unable to strdup namespaces list");
      return -1;	
    }
  
  next = nsListDup; 
  while (next != NULL)
    {
      /* skip spaces */
      while ((*next) == ' ') next++;
      if ((*next) == '\0') break;
      
      /* find prefix */
      prefix = next;
      next = (xmlChar*)xmlStrchr(next, '=');
      if (next == NULL)
        {
          NSLog(@"Error: invalid namespaces list format");
          xmlFree(nsListDup);
          return -1;	
        }
      *(next++) = '\0';	
    
      /* find href */
      href = next;
      next = (xmlChar*)xmlStrchr(next, ' ');
      if (next != NULL)
        {
          *(next++) = '\0';	
        }
    
      /* do register namespace */
      if (xmlXPathRegisterNs(xpathCtx, prefix, href) != 0)
        {
          NSLog(@"Error: unable to register NS with prefix=\"%s\""
	    @" and href=\"%s\"", prefix, href);
          xmlFree(nsListDup);
          return -1;	
        }
    }
  
  xmlFree(nsListDup);
  return 0;
}

static NSArray *
execute_xpath(NSXMLNode *xmlNode, NSString *xpath_exp, NSString *nmspaces)
{
  xmlNodePtr node = [xmlNode _node];
  xmlDocPtr doc = node->doc;
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: 10];
  xmlChar* xpathExpr = (xmlChar *)XMLSTRING(xpath_exp); 
  xmlChar* nsList = (xmlChar *)XMLSTRING(nmspaces);
  xmlXPathContextPtr xpathCtx =  NULL; 
  xmlXPathObjectPtr xpathObj = NULL; 
  xmlNodeSetPtr nodeset = NULL;
  xmlNodePtr cur = NULL;
  int i = 0; 

  assert(xpathExpr);
  
  /* Create xpath evaluation context */
  xpathCtx = xmlXPathNewContext(doc);
  if (!xpathCtx) 
    {
      NSLog(@"Error: unable to create new XPath context.");
      return nil;
    }
    
  /* Register namespaces from list (if any) */
  if ((nsList != NULL) && (register_namespaces(xpathCtx, nsList) < 0)) 
    {
      NSLog(@"Error: failed to register namespaces list \"%s\"", nsList);
      xmlXPathFreeContext(xpathCtx); 
      return nil;
    }

  if (![xpath_exp hasPrefix: @"/"])
    {
      // provide a context for relative paths
      xpathCtx->node = node;
    }

  /* Evaluate xpath expression */
  xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
  if (xpathObj == NULL) 
    {
      NSLog(@"Error: unable to evaluate xpath expression \"%s\"", xpathExpr);
      xmlXPathFreeContext(xpathCtx);
      return nil;
    }
  
  /* results */
  nodeset = xpathObj->nodesetval;
/*
  if (nodeset == NULL || nodeset->nodeNr == 0)
    {
      xpathObj = xmlXPathEval(xpathExpr, xpathCtx);
      if (xpathObj != NULL)
        nodeset = xpathObj->nodesetval;
      if (nodeset)
        NSLog(@"Succeeded in evaluating as a path, using xmlXPathEval");
    }
*/
  if (nodeset)
    {
      /* Collect results */
      for (i = 0; i < nodeset->nodeNr; i++)
	{
	  id obj = nil;
	  cur = nodeset->nodeTab[i];
	  obj = [NSXMLNode _objectForNode: cur];
	  if (obj)
	    {
	      [result addObject: obj];
	    }
	} 
    }

  /* Cleanup */
  xmlXPathFreeObject(xpathObj);
  xmlXPathFreeContext(xpathCtx); 

  return result;
}

@implementation NSXMLNode

+ (void) initialize
{
  xmlCheckVersion(LIBXML_VERSION);
  // Protect against libxml2 not being correctly set up on Windows.
  // See: http://www.linuxquestions.org/questions/programming-9/%5Bsolved%5Dusing-libxml2-on-mingw-xmlfree-crashes-839802/
  if (!xmlFree)
    {
      xmlMemGet(&xmlFree, &xmlMalloc, &xmlRealloc, NULL);
    }
}

+ (id) attributeWithName: (NSString*)name
	     stringValue: (NSString*)stringValue
{
  NSXMLNode *n;

  n = [[[self alloc] initWithKind: NSXMLAttributeKind] autorelease];
  [n setStringValue: stringValue];
  [n setName: name];
  
  return n;
}

+ (id) attributeWithName: (NSString*)name
		     URI: (NSString*)URI
	     stringValue: (NSString*)stringValue
{
  NSXMLNode *n;
  
  n = [[[self alloc] initWithKind: NSXMLAttributeKind] autorelease];
  [n setURI: URI];
  [n setStringValue: stringValue];
  [n setName: name];
  
  return n;
}

+ (id) commentWithStringValue: (NSString*)stringValue
{
  NSXMLNode *n;

  n = [[[self alloc] initWithKind: NSXMLCommentKind] autorelease];
  [n setStringValue: stringValue];

  return n;
}

+ (id) DTDNodeWithXMLString: (NSString*)string
{
  NSXMLNode *n;

  n = [[[NSXMLDTDNode alloc] initWithXMLString: string] autorelease];

  return n;
}

+ (id) document
{
  NSXMLNode *n;

  n = [[[NSXMLDocument alloc] initWithKind: NSXMLDocumentKind] autorelease];
  return n;
}

+ (id) documentWithRootElement: (NSXMLElement*)element
{
  NSXMLDocument	*d;

  d = [[[NSXMLDocument alloc] initWithRootElement: element] autorelease];
  return d;
}

+ (id) elementWithName: (NSString*)name
{
  NSXMLNode *n;

  n = [[[NSXMLElement alloc] initWithName: name] autorelease];
  return n;
}

+ (id) elementWithName: (NSString*)name
	      children: (NSArray*)children
	    attributes: (NSArray*)attributes
{
  NSXMLElement *e = [self elementWithName: name];

  [e insertChildren: children atIndex: 0];
  [e setAttributes: attributes];
  return e;
}

+ (id) elementWithName: (NSString*)name
		   URI: (NSString*)URI
{
  NSXMLNode *n;

  n = [[[NSXMLElement alloc] initWithName: name URI: URI] autorelease];
  return n;
}

+ (id) elementWithName: (NSString*)name
	   stringValue: (NSString*)string
{
  NSXMLElement *e;
  
  e = [[NSXMLElement alloc] initWithName: name stringValue: string];
  return e;
}

+ (NSString*) localNameForName: (NSString*)name
{
  const xmlChar *xmlName = XMLSTRING(name); 
  xmlChar *prefix = NULL;
  xmlChar *localName;

  if (NULL == xmlName)
    return nil;

  localName = xmlSplitQName2(xmlName, &prefix);
  return StringFromXMLStringPtr(localName);
}

+ (id) namespaceWithName: (NSString*)name
	     stringValue: (NSString*)stringValue
{
  NSXMLNode *n;

  n = [[[self alloc] initWithKind: NSXMLNamespaceKind] autorelease];
  [n setName: name];
  [n setStringValue: stringValue];
  return n;
}

+ (NSXMLNode*) predefinedNamespaceForPrefix: (NSString*)name
{
  // FIXME: We should cache these instances
  if ([name isEqualToString: @"xml"])
    {
      return [self namespaceWithName: @"xml"
        stringValue: @"http: //www.w3.org/XML/1998/namespace"];
    }
  if ([name isEqualToString: @"xs"])
    {
      return [self namespaceWithName: @"xs"
        stringValue: @"http: //www.w3.org/2001/XMLSchema"];
    }
  if ([name isEqualToString: @"xsi"])
    {
      return [self namespaceWithName: @"xsi"
        stringValue: @"http: //www.w3.org/2001/XMLSchema-instance"];
    }
  if ([name isEqualToString: @"fn"])
    {
      return [self namespaceWithName: @"fn"
        stringValue: @"http: //www.w3.org/2003/11/xpath-functions"];
    }
  if ([name isEqualToString: @"local"])
    {
      return [self namespaceWithName: @"local"
        stringValue: @"http: //www.w3.org/2003/11/xpath-local-functions"];
    }
  
  return nil;
}

+ (NSString*) prefixForName: (NSString*)name
{
  const xmlChar *xmlName = XMLSTRING(name); 
  xmlChar *prefix = NULL;

  if (NULL == xmlName)
    return nil;

  xmlSplitQName2(xmlName, &prefix);

  if (NULL == prefix)
    {
      return @"";
    }
  else
    {
      return StringFromXMLStringPtr(prefix);
    }
}

+ (id) processingInstructionWithName: (NSString*)name
			 stringValue: (NSString*)stringValue
{
  NSXMLNode *n;

  n = [[[self alloc] initWithKind: NSXMLProcessingInstructionKind] autorelease];
  [n setStringValue: stringValue];
  [n setName: name];
  return n;
}

+ (id) textWithStringValue: (NSString*)stringValue
{
  NSXMLNode *n;

  n = [[[self alloc] initWithKind: NSXMLTextKind] autorelease];
  [n setStringValue: stringValue];
  return n;
}

- (NSString*) canonicalXMLStringPreservingComments: (BOOL)comments
{
  // FIXME ... generate from libxml
  return [self XMLStringWithOptions: NSXMLNodePreserveWhitespace];
}

- (NSXMLNode*) childAtIndex: (NSUInteger)index
{
  xmlNodePtr childNode = [self _childNodeAtIndex: index];
  return [NSXMLNode _objectForNode: childNode];
}

- (NSUInteger) childCount
{
  NSUInteger count = 0;
  xmlNodePtr children = NULL;
  xmlNodePtr node = internal->node;

  if (!node)
    {
      return 0;
    }

  if (node->type == XML_NAMESPACE_DECL)
    {
      return 0;
    }

  for (children = node->children; children; children = children->next)
    {
      count++;
    }

  return count;
}

- (NSArray*) children
{
  NSMutableArray *childrenArray = nil;

  if (NSXMLInvalidKind == internal->kind)
    {
      return nil;
    }
  else
    {
      xmlNodePtr children = NULL;
      xmlNodePtr node = internal->node;
      
      if ((node == NULL) ||
          (node->type == XML_NAMESPACE_DECL) ||
          (node->children == NULL))
	{
	  return nil;
	}

      childrenArray = [NSMutableArray array];
      for (children = node->children; children; children = children->next)
	{
	  NSXMLNode *n = [NSXMLNode _objectForNode: children];
	  [childrenArray addObject: n];
	}
    }
  return childrenArray;
}

- (id) copyWithZone: (NSZone*)zone
{
  NSXMLNode *c = [[self class] allocWithZone: zone];
  xmlNodePtr newNode = xmlCopyNode([self _node], 2); // make a deep copy
  clearPrivatePointers(newNode);

  c = [c _initWithNode: newNode kind: internal->kind];

  GSIVar(c, options) = internal->options;
  if (nil != internal->objectValue)
    {
      /*
        Only copy the objectValue when externally set.
        The problem here are nodes created by parsing XML.
        There the stringValue may be set, but the objectValue isn't.
        This should rather be solved by creating a suitable objectValue,
        when the node gets instantiated.
      */
      [c setObjectValue: internal->objectValue];
    }
  [c setURI: [self URI]];
//  [c setName: [self name]];
//  [c setStringValue: [self stringValue]];

  return c;
}

- (NSString*) description
{
  return [NSString stringWithFormat:@"<%@ %@ %d>%@\n",
    NSStringFromClass([self class]),
    [self name], [self kind], [self XMLString]];
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      xmlNodePtr node = internal->node;
      NSArray *subNodes = [internal->subNodes copy];
      NSEnumerator *enumerator = [subNodes objectEnumerator];
      NSXMLNode *subNode;

      while ((subNode = [enumerator nextObject]) != nil)
        {
          [subNode detach];
        }
      [subNodes release];

      [internal->URI release];
      [internal->objectValue release];
      [internal->subNodes release];
      if (node)
        {
          if (node->type == XML_NAMESPACE_DECL)
            {
              ((xmlNsPtr)node)->_private = NULL;
              xmlFreeNode(node);
            }
          else
            {
              node->_private = NULL;
              if (node->parent == NULL)
                {
                  // the top level node frees the entire tree
                  if (node->type == XML_DOCUMENT_NODE)
                    xmlFreeDoc((xmlDocPtr)node);
                  else
                    xmlFreeNode(node);
                }
            }
        }
      GS_DESTROY_INTERNAL(NSXMLNode);
    }
  [super dealloc];
}

- (void) detach
{
  xmlNodePtr node = internal->node;

  if (node)
    {
      NSXMLNode *parent = [self parent];

      if (node->type == XML_NAMESPACE_DECL)
        {
          // FIXME
        }
      else
        {
          // separate our node from its parent and siblings
          xmlUnlinkNode(node);
          xmlSetTreeDoc(node, NULL);
        }

      if (parent)
	{
	  [parent _removeSubNode: self];
	}
    }
}

- (NSUInteger) hash
{
  return [[self name] hash];
}

- (NSUInteger) index
{
  xmlNodePtr node = internal->node;
  int count = 0;

  if (node->type == XML_NAMESPACE_DECL)
    {
      // FIXME: Could try to go to document an loop over the namespaces
      return 0;
    }

  while ((node = node->prev))
    {
      count++; // count our earlier sibling nodes
    }

  return count;
}

- (id) init
{
  return [self initWithKind: NSXMLInvalidKind];
}

- (id) initWithKind: (NSXMLNodeKind) kind
{
  return [self initWithKind: kind options: 0];
}

- (id) initWithKind: (NSXMLNodeKind)kind options: (NSUInteger)theOptions
{
  Class theSubclass = [NSXMLNode class];
  void *node = NULL;

  /*
   * We find the correct subclass for specific node kinds: 
   */
  switch (kind)
    {
      case NSXMLDocumentKind: 
	theSubclass = [NSXMLDocument class];
	break;
	  
      case NSXMLInvalidKind: 
	theSubclass = [NSXMLNode class];
	break; 

      case NSXMLElementKind: 
	theSubclass = [NSXMLElement class];
	break;
	
      case NSXMLDTDKind: 
	theSubclass = [NSXMLDTD class];
	break;
	
      case NSXMLElementDeclarationKind: 
      case NSXMLEntityDeclarationKind: 
      case NSXMLNotationDeclarationKind: 
	theSubclass = [NSXMLDTDNode class];
	break;

      case NSXMLNamespaceKind: 
	theSubclass = [NSXMLNode class];
	break;

      case NSXMLAttributeKind: 
      case NSXMLCommentKind: 
      case NSXMLProcessingInstructionKind: 
      case NSXMLTextKind: 
	break;

      case NSXMLAttributeDeclarationKind: 
	[self release];
	return nil;
	
      default: 
	kind = NSXMLInvalidKind;
	theSubclass = [NSXMLNode class];
	break;
    }

  /*
   * Check whether we are already initializing an instance of the given
   * subclass. If we are not, release ourselves and allocate a subclass
   * instance instead.
   */
  if (NO == [self isKindOfClass: theSubclass])
    {
      [self release];
      return [[theSubclass alloc] initWithKind: kind
				       options: theOptions];
    }

  /* If we are initializing for the correct class, we can actually perform
   * initializations: 
   */
  switch (kind)
    {
      case NSXMLDocumentKind: 
	node = xmlNewDoc((xmlChar *)"1.0");
	break;
	  
      case NSXMLInvalidKind: 
      case NSXMLElementKind: 
	node = xmlNewNode(NULL,(xmlChar *)"");
	break;
	
      case NSXMLDTDKind: 
	node = xmlNewDtd(NULL, (xmlChar *)"", (xmlChar *)"",(xmlChar *)"");
	break;
	
      case NSXMLEntityDeclarationKind: 
      case NSXMLElementDeclarationKind: 
      case NSXMLNotationDeclarationKind: 
	node = xmlNewNode(NULL, (xmlChar *)"");
	break;

      case NSXMLProcessingInstructionKind: 
	node = xmlNewPI((xmlChar *)"", (xmlChar *)"");
	break;

      case NSXMLCommentKind: 
	node = xmlNewComment((xmlChar *)"");
	break;

      case NSXMLTextKind: 
	node = xmlNewText((xmlChar *)"");
	break;

      case NSXMLNamespaceKind: 
	node = xmlNewNs(NULL,(xmlChar *)"",(xmlChar *)"");
	break;

      case NSXMLAttributeKind: 
	node = xmlNewProp(NULL,(xmlChar *)"",(xmlChar *)"");
	break;

      default: 
	break;
    }

  if (nil == (self = [self _initWithNode: node kind: kind]))
    {
      return nil;
    }

  internal->options = theOptions;
  return self;
}

- (BOOL) isEqual: (id)other
{
  if ([self kind] != [other kind])
    {
      return NO;
    }
  /*
  NSLog(@"self %@ other %@", self, other);
  NSLog(@"s sV '%@' oV '%@', other sV '%@' oV '%@'", [self stringValue], [self objectValue],
        [other stringValue], [other objectValue]);
  */
  return isEqualTree(internal->node, (xmlNodePtr)[other _node]);
}

- (NSXMLNodeKind) kind
{
  return internal->kind;
}

- (NSUInteger) level
{
  NSXMLNode *parent = [self parent];
  
  if (nil == parent)
    {
      return 0;
    }
  else
    {
      return [parent level] + 1;
    }
}

- (NSString*) localName
{
  return [[self class] localNameForName: [self name]];
}

- (NSString*) name
{
  xmlNodePtr node = internal->node;

  if (NSXMLInvalidKind == internal->kind)
    {
      return nil;
    }

  if (node->type == XML_NAMESPACE_DECL)
    {
      return StringFromXMLStringPtr(((xmlNs *)node)->prefix);
    }
  else
    {
      return StringFromXMLStringPtr(node->name);
    }
}

- (NSXMLNode*) _nodeFollowingInNaturalDirection: (BOOL)forward
{
  NSXMLNode *ancestor = self;
  NSXMLNode *candidate = nil;
  NSXMLNodeKind kind;

  /* Node walking is a depth-first thingy. Hence, we consider children first: */
  if (0 != [self childCount])
    {
      NSUInteger theIndex = 0;
      if (NO == forward)
	{
	  theIndex = [self childCount] - 1;
	}
      candidate = [[self children] objectAtIndex: theIndex];
    }

  /* If there are no children, we move on to siblings: */
  /* If there are no siblings left for the receiver, we recurse down to the root
   * of the tree until we find an ancestor with further siblings: */
  while ((nil == candidate) && (nil != ancestor))
    {
      if (forward)
	{
	  candidate = [ancestor nextSibling];
	}
      else
	{
	  candidate = [ancestor previousSibling];
	}
      ancestor = [ancestor parent];
    }

  /* No children, no next siblings, no next siblings for any ancestor: We are
   * the last node */
  if (nil == candidate)
    {
      return nil;
    }

  /* Sanity check: Namespace and attribute nodes are skipped: */
  kind = [candidate kind];
  if ((NSXMLAttributeKind == kind) || (NSXMLNamespaceKind == kind))
    {
      return [candidate _nodeFollowingInNaturalDirection: forward];
    }
  return candidate;
}

- (NSXMLNode*) nextNode
{
  return [self _nodeFollowingInNaturalDirection: YES];
}

- (NSXMLNode*) nextSibling
{
  return [NSXMLNode _objectForNode: internal->node->next];
}

- (id) objectValue
{
  return internal->objectValue;
}

- (NSXMLNode*) parent
{
  xmlNodePtr parent = NULL;
  xmlNodePtr node = internal->node;

  if (NULL == node)
    {
      return nil;
    }
  if (XML_NAMESPACE_DECL == node->type)
    {
      return nil;
    }

  parent = node->parent;
  return [NSXMLNode _objectForNode: parent];
}

- (NSString*) prefix
{
  return [[self class] prefixForName: [self name]];
}

- (NSXMLNode*) previousNode
{
  return [self _nodeFollowingInNaturalDirection: NO];
}

- (NSXMLNode*) previousSibling
{
  return [NSXMLNode _objectForNode: internal->node->prev];
}

- (NSXMLDocument*) rootDocument
{
  return
    (NSXMLDocument *)[NSXMLNode _objectForNode: (xmlNodePtr)(internal->node->doc)];
}

- (NSString*) stringValue
{
  xmlNodePtr node = internal->node;
  xmlChar *content = xmlNodeGetContent(node);
  NSString *result = nil;

  if (NULL != content)
    {
      result = StringFromXMLStringPtr(content);
      xmlFree(content);
    }
  else
    {
      result = @"";
    }

  return result;
}

- (void) setObjectValue: (id)value
{
  NSString *stringValue;

  // FIXME: Use correct formatter here
  stringValue = [value description];
  [self setStringValue: stringValue];

  ASSIGN(internal->objectValue, value);
}

- (void) setName: (NSString *)name
{
  xmlNodePtr node = internal->node;

  if (NSXMLInvalidKind == internal->kind)
    {
      return;
    }
  
  if (node->type == XML_NAMESPACE_DECL)
    {
      xmlNsPtr ns = (xmlNsPtr)node;

      if (ns->prefix != NULL)
        {
          xmlFree((xmlChar *)ns->prefix);
        }
      ns->prefix = XMLStringCopy(name);
    }
  else
    {
      xmlNodeSetName(node, XMLSTRING(name));
    }
}

- (void) setStringValue: (NSString*)string
{
  [self setStringValue: string resolvingEntities: NO];
}

- (void) setStringValue: (NSString*)string resolvingEntities: (BOOL)resolve
{
  xmlNodePtr node = internal->node;

  if (node->type == XML_NAMESPACE_DECL)
    {
      xmlNsPtr ns = (xmlNsPtr)node;
      if (ns->href != NULL)
        {
          xmlFree((xmlChar *)ns->href);
        }
      ns->href = XMLStringCopy(string);
    }
  else
    {
      if (resolve == NO)
        {
          xmlNodeSetContent(node, XMLSTRING(string));
        }
      else
        {
          // need to actually resolve entities...
          // is this the right functionality?? xmlEncodeSpecialChars()
          xmlChar *newstr = xmlEncodeEntitiesReentrant(node->doc, XMLSTRING(string));
          xmlNodeSetContent(node, newstr);
          xmlMemFree(newstr);
        }
    }
  ASSIGN(internal->objectValue, string);
}

- (void) setURI: (NSString*)URI
{
  if (NSXMLInvalidKind == internal->kind)
    {
      return;
    }
  ASSIGNCOPY(internal->URI, URI);
  //xmlNodeSetBase(internal->node, XMLSTRING(URI));
}

- (NSString*) URI
{
  if (NSXMLInvalidKind == internal->kind)
    {
      return nil;
    }
  return internal->URI;
  //return StringFromXMLStringPtr(xmlNodeGetBase(NULL, internal->node));
}

- (NSString*) XMLString
{
  return [self XMLStringWithOptions: NSXMLNodeOptionsNone];
}

- (NSString*) XMLStringWithOptions: (NSUInteger)options
{
  NSString     *string = nil;
  xmlChar      *buf = NULL;
  xmlBufferPtr buffer;
  int error = 0;
  int len = 0;
  xmlSaveCtxtPtr ctxt;
  int xmlOptions = 0;

  buffer = xmlBufferCreate();

  // XML_SAVE_XHTML XML_SAVE_AS_HTML XML_SAVE_NO_DECL XML_SAVE_NO_XHTML
  xmlOptions |= XML_SAVE_AS_XML;
  if (options & NSXMLNodePreserveWhitespace)
    {
      xmlOptions |= XML_SAVE_WSNONSIG;
    }
  if (options & NSXMLNodeCompactEmptyElement)
    {
      xmlOptions |= XML_SAVE_NO_EMPTY;
    }
  if (options & NSXMLNodePrettyPrint)
    {
      xmlOptions |= XML_SAVE_FORMAT;
    }
  
  ctxt = xmlSaveToBuffer(buffer, "utf-8", xmlOptions);
  xmlSaveTree(ctxt, internal->node);
  error = xmlSaveClose(ctxt);
  if (-1 == error)
    {
      xmlBufferFree(buffer);
      return nil;
    }
  buf = buffer->content;
  len = buffer->use;
  string = StringFromXMLString(buf, len);
  xmlBufferFree(buffer);

  return string;
}

- (NSString*) XPath
{
  xmlNodePtr node = internal->node;
  return StringFromXMLStringPtr(xmlGetNodePath(node));
}

- (NSArray*) nodesForXPath: (NSString*)anxpath error: (NSError**)error
{
  if (error != NULL)
    {
      *error = NULL;
    }
  return execute_xpath(self, anxpath, NULL);
}

 - (NSArray*) objectsForXQuery: (NSString*)xquery
		     constants: (NSDictionary*)constants
		         error: (NSError**)error
{
  return [self notImplemented: _cmd];
}

- (NSArray*) objectsForXQuery: (NSString*)xquery error: (NSError**)error
{
  return [self objectsForXQuery: xquery
                      constants: nil
                          error: error];
}
@end

#endif
