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

#define GSInternal              NSXMLNodeInternal
#import "NSXMLPrivate.h"
#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLNode)

#if defined(HAVE_LIBXML)

int countAttributes(xmlNodePtr node)
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

BOOL isEqualAttr(const xmlAttrPtr attrA, const xmlAttrPtr attrB)
{
  xmlChar* contentA;
  xmlChar* contentB;
  const xmlChar* nameA;
  const xmlChar* nameB;

  // what has to be the same for two attributes to be equal -- just their values??
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
#ifdef __MINGW32__
          free(contentA);
          free(contentB);
#else
          xmlFree(contentA);
          xmlFree(contentB);
#endif
	  return YES;
	}
#ifdef __MINGW32__
      free(contentA);
      free(contentB);
#else
      xmlFree(contentA);
      xmlFree(contentB);
#endif
      return NO;
    }
  
  return NO;
}

xmlAttrPtr findAttrWithName(xmlNodePtr node, const xmlChar* targetName)
{
  xmlAttrPtr attr = node->properties;

  // find an attr in node with the given name, and return it, else NULL
  while ((attr != NULL) && xmlStrcmp(attr->name, targetName) != 0) 
    {
      attr = attr->next;
    }

  return attr;
}


BOOL isEqualAttributes(xmlNodePtr nodeA, xmlNodePtr nodeB)
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

BOOL isEqualNode(xmlNodePtr nodeA, xmlNodePtr nodeB)
{
  if (nodeA == nodeB)
    return YES;

  if (nodeA->type != nodeB->type)
    return NO;
  
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
#ifdef __MINGW32__
          free(contentA);
          free(contentB);
#else
          xmlFree(contentA);
          xmlFree(contentB);
#endif
	  return NO;
	}
#ifdef __MINGW32__
      free(contentA);
      free(contentB);
#else
      xmlFree(contentA);
      xmlFree(contentB);
#endif
    }
  
  return YES;
}

BOOL isEqualTree(xmlNodePtr nodeA, xmlNodePtr nodeB)
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

// Private methods to manage libxml pointers...
@interface NSXMLNode (Private)
- (void *) _node;
- (void) _setNode: (void *)_anode;
+ (NSXMLNode *) _objectForNode: (xmlNodePtr)node;
- (void) _addSubNode: (NSXMLNode *)subNode;
- (void) _removeSubNode: (NSXMLNode *)subNode;
- (id) _initWithNode: (xmlNodePtr)node kind: (NSXMLNodeKind)kind;
- (xmlNodePtr) _childNodeAtIndex: (NSUInteger)index;
- (void) _insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index;
- (void) _updateExternalRetains;
- (void) _invalidate;
@end

@implementation NSXMLNode (Private)
- (void *) _node
{
  return internal->node;
}

- (void) _setNode: (void *)_anode
{
  if (_anode)
    ((xmlNodePtr)_anode)->_private = self;
  internal->node = _anode;
}

+ (NSXMLNode *) _objectForNode: (xmlNodePtr)node
{
  NSXMLNode *result = nil;
  
  if (node)
    {
      result = node->_private;
      if (result == nil)
	{
          Class cls;
          NSXMLNodeKind kind;
          xmlElementType type = node->type;

	  switch (type)
	    {
	    case XML_DOCUMENT_NODE:
              cls = [NSXMLDocument class];
              kind = NSXMLDocumentKind;
	      break;
	    case XML_ELEMENT_NODE: 
              cls = [NSXMLElement class];
              kind = NSXMLElementKind;
	      break;
	    case XML_TEXT_NODE: 
              cls = [NSXMLNode class];
              kind = NSXMLTextKind;
	      break;
	    case XML_PI_NODE: 
              cls = [NSXMLNode class];
              kind = NSXMLProcessingInstructionKind;
	      break;
	    case XML_COMMENT_NODE: 
              cls = [NSXMLNode class];
              kind = NSXMLCommentKind;
	      break;
	    case XML_ATTRIBUTE_NODE: 
              cls = [NSXMLNode class];
              kind = NSXMLAttributeKind;
	      break;
	    default: 
	      NSLog(@"ERROR: _objectForNode: called with a node of type %d", type);
              return nil;
	      break;
	    }
          if ((node->doc != NULL) && ((xmlNodePtr)(node->doc) != node))
            {
              NSXMLDocument *doc;
              
              doc = (NSXMLDocument*)[self _objectForNode: (xmlNodePtr)node->doc];
              if (doc != nil)
                {
                  cls = [[doc class] replacementClassForClass: cls];
                }
            }

          result = [[cls alloc] _initWithNode: node kind: kind];
	  AUTORELEASE(result);
	  if (node->parent)
            {
	      NSXMLNode *parent = [self _objectForNode: node->parent];
	      [parent _addSubNode: result];
            }
	}
    }
  
  return result;
}

- (int) _externalRetains
{
  return internal->externalRetains;
}

- (int) verifyExternalRetains 
{
  int extraRetains = ([self retainCount] > 1 ? 1 : 0);  // start with 1 or 0 for ourself
  int index;
  for (index = 0; index < [internal->subNodes count]; index++)
    extraRetains += [[internal->subNodes objectAtIndex: index] _externalRetains];
  return extraRetains;
}

- (void) _updateExternalRetains
{
  xmlNodePtr pnode = (MY_NODE ? MY_NODE->parent : NULL);
  NSXMLNode *parent = (NSXMLNode *)(pnode ? pnode->_private : nil);
  int oldCount = internal->externalRetains;
  int extraRetains = ([self retainCount] > 1 ? 1 : 0);  // start with 1 or 0 for ourself
  int index;
  for (index = 0; index < [internal->subNodes count]; index++)
    extraRetains += [[internal->subNodes objectAtIndex: index] _externalRetains];
  internal->externalRetains = extraRetains;
  if (extraRetains != oldCount)
    {
      if (parent)
	[parent _updateExternalRetains]; // tell our parent (if any) since our count has changed
      else
	{ // we're the root node of this tree, so retain or release ourself as needed
	  if (oldCount == 0 && extraRetains > 0)
	    {
	      [super retain];
	      internal->retainedSelf++;
//NSLog(@"RETAINED SELF %@ (%d)", self, internal->retainedSelf);
	    }
	  else if (oldCount > 0 && extraRetains == 0 && internal->retainedSelf)
	    {
	      internal->retainedSelf--;
//NSLog(@"RELEASED SELF %@ (%d)", self, internal->retainedSelf);
	      [super release];
	    }
	}
    }
  else
    {
      if (!parent)
	{
	  if (extraRetains > 0 && internal->retainedSelf == 0)
	    {
	      [super retain];
	      internal->retainedSelf++;
//NSLog(@"RETAINED SELF AFTER STATUS CHANGED %@ (%d)", self, internal->retainedSelf);
	    }
	  else if (extraRetains == 0 && internal->retainedSelf > 0)
	    {
	      internal->retainedSelf--;
//NSLog(@"RELEASED SELF AFTER STATUS CHANGED %@ (%d)", self, internal->retainedSelf);
	      [super release];
	    }
	}
    }
}

- (void) _passExternalRetainsTo: (NSXMLNode *)parent
{
  // this object just became a subNode, so pass knowledge of external retains up the line
  if (internal->externalRetains > 0)
    {
//NSLog(@"_passExternalRetainsTo: %@ (%d,%d) from %@ Start: (%d,%d)", parent, [parent _externalRetains], [parent verifyExternalRetains], self, internal->externalRetains, [self verifyExternalRetains]);
//      if ([self retainCount] == 2)
//	{
//	  internal->externalRetains--;
//NSLog(@"RELEASING TRICKY EXTRA RETAIN WHILE ADDING TO PARENT in %@ now: %d", self, internal->externalRetains);
//	}
      //[self _updateExternalRetains];
      if (internal->retainedSelf)
	{
      [super release]; // we're no longer the root of our branch, so stop retaining ourself
	      internal->retainedSelf--;
//NSLog(@"RELEASED SELF %@ (%d) in _passExternal...", self, internal->retainedSelf);
	}
      [parent _updateExternalRetains];
//NSLog(@"DID _passExternalRetainsTo: %@ (%d,%d) from %@ End: (%d,%d)", parent, [parent _externalRetains], [parent verifyExternalRetains], self, internal->externalRetains, [self verifyExternalRetains]);
   }
}

- (void) _removeExternalRetainsFrom: (NSXMLNode *)parent
{
  // this object is no longer a subNode, so pass removal of external retains up the line
  if (internal->externalRetains > 0)
    {
//NSLog(@"_removeExternalRetainsTo: %@ from %@ Start: %d", parent, self, internal->externalRetains);
///      [parent releaseExternalRetain: internal->externalRetains];
	  if ([self retainCount] == 1)
	    {
	      internal->externalRetains++;
//NSLog(@"ADDED TRICKY EXTRA COUNT WHILE REMOVING FROM PARENT in %@ now: %d subNodes(low): %d", self, internal->externalRetains, [self verifyExternalRetains]);
	    }

      [super retain]; // becoming detached, so retain ourself as the new root of our branch
      internal->retainedSelf++;
//NSLog(@"RETAINED SELF %@ (%d) in _removeExternal...", self, internal->retainedSelf);
      [parent _updateExternalRetains];
    }
}

- (void) _addSubNode: (NSXMLNode *)subNode
{
  if (!internal->subNodes)
    internal->subNodes = [[NSMutableArray alloc] init];
  if ([internal->subNodes indexOfObjectIdenticalTo: subNode] == NSNotFound)
    {
      [internal->subNodes addObject: subNode];
      [subNode _passExternalRetainsTo: self];
    }
}

- (void) _removeSubNode: (NSXMLNode *)subNode
{
  [subNode retain]; // retain temporarily so we can safely remove from our subNodes list first
  [internal->subNodes removeObjectIdenticalTo: subNode];
  [subNode _removeExternalRetainsFrom: self];
  [subNode release]; // release temporary hold
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
  xmlNodePtr node = (xmlNodePtr)(internal->node);
  xmlNodePtr children = node->children;
  if (!children)
    return NULL; // the Cocoa docs say it returns nil if there are no children

  for (children = node->children; children != NULL && count != index; children = children->next)
    {
      count++;
    }

  if (count != index)
    [NSException raise: NSRangeException format: @"child index too large"];

  return children;
}

- (void) _insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index
{
  // this private method provides the common insertion implementation used by NSXMLElement and NSXMLDocument
  
  // Get all of the nodes...
  xmlNodePtr parentNode = MY_NODE; // we are the parent
  xmlNodePtr childNode = ((xmlNodePtr)[child _node]);
  xmlNodePtr curNode = [self _childNodeAtIndex: index];
  BOOL mergeTextNodes = NO; // is there a defined option for this?

  if (mergeTextNodes || childNode->type == XML_ATTRIBUTE_NODE)
    {
      // this uses the built-in libxml functions which merge adjacent text nodes
      xmlNodePtr addedNode = NULL;
      //curNode = ((xmlNodePtr)[cur _node]);

      if (curNode == NULL) //(0 == childCount || index == childCount)
        {
          addedNode = xmlAddChild(parentNode, childNode);
        }
      else //if (index < childCount)
        {
          addedNode = xmlAddPrevSibling(curNode, childNode);
        }
      if (addedNode != childNode)
        {
          [child _setNode: NULL];
          child = [NSXMLNode _objectForNode: addedNode];
        }
    }
  else
    {
      // here we avoid merging adjacent text nodes by linking the new node in "by hand"
      childNode->parent = parentNode;
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
	      // in this case, this is the new "first child", so update our parent to point to it
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

void clearPrivatePointers(xmlNodePtr aNode)
{
  if (!aNode)
    return;
  aNode->_private = NULL;
  clearPrivatePointers(aNode->children);
  clearPrivatePointers(aNode->next);
  if (aNode->type == XML_ELEMENT_NODE)
    clearPrivatePointers((xmlNodePtr)(aNode->properties));
}

int register_namespaces(xmlXPathContextPtr xpathCtx, 
			const xmlChar* nsList) 
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
#ifdef __MINGW32__
          free(nsListDup);
#else
          xmlFree(nsListDup);
#endif
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
          NSLog(@"Error: unable to register NS with prefix=\"%s\" and href=\"%s\"",
                prefix, href);
#ifdef __MINGW32__
          free(nsListDup);
#else
          xmlFree(nsListDup);
#endif
          return -1;	
        }
    }
  
#ifdef __MINGW32__
  free(nsListDup);
#else
  xmlFree(nsListDup);
#endif
  return 0;
}

NSArray *execute_xpath(NSXMLNode *xmlNode,
		       NSString *xpath_exp,
		       NSString *nmspaces)
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
  return [self notImplemented: _cmd];	// FIXME ... generate from libxml
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
  xmlNodePtr node = MY_NODE;

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
      xmlNodePtr node = (xmlNodePtr)(internal->node);
      
      if (node->children == NULL)
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
  id c = [[self class] allocWithZone: zone];
  xmlNodePtr newNode = xmlCopyNode([self _node], 1); // make a deep copy
  clearPrivatePointers(newNode);

  //c = [c initWithKind: internal->kind options: internal->options];
  //[c _setNode: newNode];
  c = [c _initWithNode: newNode kind: internal->kind];

  

//  [c setName: [self name]];
//  [c setURI: [self URI]];
//  [c setObjectValue: [self objectValue]];
//  [c setStringValue: [self stringValue]];

  return c;
}

- (NSString*) description
{
  return [NSString stringWithFormat:@"<%@ %@ %d>%@\n",
                   NSStringFromClass([self class]),
                   [self name], [self kind], [self stringValue]];
}

- (id) retain
{
  [super retain]; // do this first
  if ([self retainCount] == 2)
    {
      [self _updateExternalRetains];
    }
  return self;
}

- (void) release
{
  if ([self retainCount] == 2)
    {
      [super release];
      [self _updateExternalRetains];
    }
  else
    [super release];
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      xmlNodePtr node = (xmlNodePtr)(internal->node);
      [internal->URI release];
      [internal->objectValue release];
      [internal->subNodes release];
      if (node)
	node->_private = NULL;
      if (node && node->parent == NULL)
	{
	  if (node->type == XML_DOCUMENT_NODE)
	    xmlFreeDoc((xmlDocPtr)node);
	  else
	    xmlFreeNode(node);  // the top level node frees the entire tree
	}
      GS_DESTROY_INTERNAL(NSXMLNode);
    }
  [super dealloc];
}

- (void) detach
{
  xmlNodePtr node = (xmlNodePtr)(internal->node);
  if (node)
    {
      xmlNodePtr parentNode = node->parent;
      NSXMLNode *parent = (parentNode ? parentNode->_private : nil); // get our parent object if it exists
      xmlUnlinkNode(node); // separate our node from its parent and siblings
      if (parent)
	{
          int extraRetains = 0;
	  // transfer extra retains of this branch from our parent to ourself
	  extraRetains = internal->externalRetains; //[self verifyExternalRetains];
	  if (extraRetains)
	    {
///	      [parent releaseExternalRetain: extraRetains];
	  if ([self retainCount] == 1)
	    {
	      internal->externalRetains++;
//NSLog(@"ADDED TRICKY EXTRA COUNT WHILE DETACHING in %@ now: %d subNodes(low): %d", self, internal->externalRetains, [self verifyExternalRetains]);
	    }
	      [super retain]; //[self recordExternalRetain: extraRetains];
	      internal->retainedSelf++;
//NSLog(@"RETAINED SELF %@ (%d) in detach", self, internal->retainedSelf);
	    }
	  [parent _removeSubNode: self];
	}
//NSLog(@"DETACHED %@ from %@ and transferred extra retains: %d", self, parent, extraRetains);
    }
}

- (NSUInteger) hash
{
  return [[self name] hash];
}

- (NSUInteger) index
{
  int count = 0;
  xmlNodePtr node = (xmlNodePtr)(internal->node);
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

  if (nil == (self = [super init]))
    {
      return nil;
    }

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
      
    case NSXMLEntityDeclarationKind: 
    case NSXMLElementDeclarationKind: 
    case NSXMLNotationDeclarationKind: 
      theSubclass = [NSXMLDTDNode class];
      break;

    case NSXMLAttributeDeclarationKind: 
      [self release];
      return nil;
      break;
      
    case NSXMLProcessingInstructionKind: 
    case NSXMLCommentKind: 
    case NSXMLTextKind: 
    case NSXMLNamespaceKind: 
    case NSXMLAttributeKind: 
      break;

    default: 
      kind = NSXMLInvalidKind;
      theSubclass = [NSXMLNode class];
      break;
    }

  /*
   * Check whether we are already initializing an instance of the given
   * subclass. If we are not, release ourselves and allocate a subclass instance
   * instead.
   */
  if (NO == [self isKindOfClass: theSubclass])
    {
      [self release];
      return [[theSubclass alloc] initWithKind: kind
				       options: theOptions];
    }

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

  /* Create holder for internal instance variables if needed.
   */
  [self _createInternal];

  /* Create libxml object to go with it...
   */
  [self _setNode: node];

  /* If we are initializing for the correct class, we can actually perform
   * initializations: 
   */
  internal->kind = kind;
  internal->options = theOptions;
  return self;
}

- (BOOL) isEqual: (id)other
{
  if ([self kind] != [other kind])
    {
      return NO;
    }
  return isEqualTree(MY_NODE,(xmlNodePtr)[other _node]);
}

- (NSXMLNodeKind) kind
{
  return internal->kind;
}

- (NSUInteger) level
{
  NSUInteger level = 0;
  xmlNodePtr tmp = MY_NODE->parent;

  while (tmp != NULL)
    {
      level++;
      tmp = tmp->parent;
    }
  return level;
}

- (NSString*) localName
{
  return [[self class] localNameForName: [self name]];
}

- (NSString*) name
{
  if (NSXMLInvalidKind == internal->kind)
    {
      return nil;
    }
  return StringFromXMLStringPtr(MY_NODE->name);
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
  return [NSXMLNode _objectForNode: MY_NODE->next];
}

- (id) objectValue
{
  return internal->objectValue;
}

- (NSXMLNode*) parent
{
  return [NSXMLNode _objectForNode: MY_NODE->parent];
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
  return [NSXMLNode _objectForNode: MY_NODE->prev];
}

- (NSXMLDocument*) rootDocument
{
  return (NSXMLDocument *)[NSXMLNode _objectForNode: (xmlNodePtr)(MY_NODE->doc)];
}

- (NSString*) stringValue
{
  xmlNodePtr node = MY_NODE;
  xmlChar *content = xmlNodeGetContent(node);
  NSString *result = nil;

  /*
  if (node->type == XML_ATTRIBUTE_NODE ||
      node->type == XML_ELEMENT_NODE)
    {
      node = node->children;
    }
  */

  result = StringFromXMLStringPtr(content);
#ifdef __MINGW32__
  free(content);
#else
  xmlFree(content);
#endif

  return result;
}

- (void) setObjectValue: (id)value
{
  if (nil == value)
    {
      ASSIGN(internal->objectValue, [NSString stringWithString: @""]);
      return;
    }
  ASSIGN(internal->objectValue, value);
}

- (void) setName: (NSString *)name
{
  if (NSXMLInvalidKind != internal->kind)
    {
      xmlNodePtr node = MY_NODE;
      xmlNodeSetName(node, XMLSTRING(name));
    }
}

- (void) setStringValue: (NSString*)string
{
  [self setStringValue: string resolvingEntities: NO];
}

- (void) setStringValue: (NSString*)string resolvingEntities: (BOOL)resolve
{
  xmlNodePtr node = MY_NODE;

  if (nil == string)
    {
      // string value may not be nil
      string = @"";
    }
  if (resolve == NO)
    {
      xmlNodeSetContent(node, XMLSTRING(string));
    }
  else
    {
      // need to actually resolve entities...
      // is this the right functionality??
      xmlChar *newstr = xmlEncodeSpecialChars(node->doc, XMLSTRING(string));
      xmlNodeSetContent(node, newstr);
      xmlMemFree(newstr);
    }
}

- (void) setURI: (NSString*)URI
{
  if (NSXMLInvalidKind != internal->kind)
    {
      ASSIGNCOPY(internal->URI, URI);
    }
}

- (NSString*) URI
{
  if (NSXMLInvalidKind == internal->kind)
    {
      return nil;
    }
  return internal->URI;	// FIXME ... fetch from libxml
}

- (NSString*) XMLString
{
  return [self XMLStringWithOptions: NSXMLNodeOptionsNone];
}

- (NSString*) XMLStringWithOptions: (NSUInteger)options
{
  NSString     *string = nil;
  xmlNodePtr   node = (xmlNodePtr)[self _node];
  xmlChar      *buf = NULL;
  xmlDocPtr    doc = node->doc;
  xmlBufferPtr buffer = xmlBufferCreate(); //NULL;
  int error = 0;
  int len = 0;

  error = xmlNodeDump(buffer, doc, node, 1, 1);
  if (-1 == error)
    {
      xmlBufferFree(buffer);
      return nil;
    }
  buf = buffer->content;
  len = buffer->use;
  string = StringFromXMLString(buf,len);
  xmlBufferFree(buffer);

  return string;
}

- (NSString*) XPath
{
  xmlNodePtr node = MY_NODE;
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
  return [self notImplemented: _cmd];
}
@end

#endif
