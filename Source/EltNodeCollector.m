/* Implementation for Objective-C EltNodeCollector collection object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

   This file is part of the GNU Objective C Class Library.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

/* This is class works in conjunction with all classes that require
   content objects conforming to some <...Comprising> protocol
   i.e. LinkedList, BinaryTree,  RBTree, etc.
   It provides a interface for holding non-object elt's.
*/

/* I should override a few more methods to increase efficiency. */

#include <objects/EltNodeCollector.h>
#include <objects/IndexedCollectionPrivate.h>
#include <objects/LinkedListEltNode.h>
#include <objects/Coder.h>

#define DEFAULT_ELT_NODE_CLASS LinkedListEltNode
#define DEFAULT_NODE_COLLECTOR_CLASS LinkedList

@implementation EltNodeCollector

+ initialize
{
  if (self == [EltNodeCollector class])
    [self setVersion:0];	/* beta release */
  return self;
}

+ defaultEltNodeClass
{
  return [DEFAULT_ELT_NODE_CLASS class];
}

+ defaultNodeCollectorClass
{
  return [DEFAULT_NODE_COLLECTOR_CLASS class];
}

// INITIALIZING AND FREEING;

/* This is the designated initializer of this class */
- initWithType: (const char *)contentEncoding
    nodeCollector: aCollector
    nodeClass: aNodeClass
{
  [super initWithType:contentEncoding];
  _comparison_function = elt_get_comparison_function(contentEncoding);
  // This actually checks that instances conformTo: ??? ;
  /*
  if (![aNodeClass conformsTo:@protocol(EltHolding)])
    [self error:"in %s, 2nd arg, %s, does not conform to @protocol(%s)",
	  sel_get_name(_cmd), [nodeClass name], [@protocol(EltHolding) name]];
	  */
  _node_class = aNodeClass;
  /* We could check to make sure that any objects already in aCollector
     conform to @protocol(EltHolding) and that their encoding matches
     contentEncoding. */
  _contents_collector = aCollector;
  return self;
}

// remove this;
/*
- initWithType: (const char *)contentEncoding
    nodeClass: aNodeClass
{
  return [self initWithType:contentEncoding
	       nodeCollector:[[[_node_class nodeCollectorClass] alloc] init]
	       nodeClass:aNodeClass];
}
*/

/* Archiving must mimic the above designated initializer */

- (void) _encodeCollectionWithCoder: (Coder*)aCoder
{
  const char *encoding = [self contentType];

  [super _encodeCollectionWithCoder:aCoder];
  [aCoder encodeValueOfType:@encode(char*) at:&encoding
	  withName:"EltNodeCollector Content Type Encoding"];
  [aCoder encodeValueOfType:"#" at:&_node_class
	  withName:"EltNodeCollector Content Node Class"];
}

+ _newCollectionWithCoder: (Coder*) aCoder
{
  EltNodeCollector *n;
  char *encoding;

  n = [super _newCollectionWithCoder:aCoder];
  [aCoder decodeValueOfType:@encode(char*) at:&encoding withName:NULL];
  n->_comparison_function = elt_get_comparison_function(encoding);
  [aCoder decodeValueOfType:"#" at:&(n->_node_class) withName:NULL];
  n->_contents_collector = nil;
  return n;
}

- (void) _encodeContentsWithCoder: (Coder*)aCoder
{
  [aCoder encodeObject:_contents_collector 
	  withName:"EltNodeCollector Contents Collector"];
}

- (void) _decodeContentsWithCoder: (Coder*)aCoder
{
  [aCoder decodeObjectAt:&_contents_collector withName:NULL];
}

/* Old-style archiving */

- _writeInit: (TypedStream*)aStream
{
  const char *encoding = [self contentType];

  [super _writeInit:aStream];
  objc_write_type(aStream, @encode(char*), &encoding);
  objc_write_type(aStream, "#", &_node_class);
  return self;
}

- _readInit: (TypedStream*)aStream
{
  char *encoding;

  [super _readInit:aStream];
  objc_read_type(aStream, @encode(char*), &encoding);
  _comparison_function = elt_get_comparison_function(encoding);
  objc_read_type(aStream, "#", &_node_class);
  _contents_collector = nil;	/* taken care of in _readContents: */
  return self;
}

- _writeContents: (TypedStream*)aStream
{
  objc_write_object(aStream, _contents_collector);
  return self;
}

- _readContents: (TypedStream*)aStream
{
  objc_read_object(aStream, &_contents_collector);
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  EltNodeCollector *copy = [super emptyCopy];
  copy->_contents_collector = [_contents_collector emptyCopy];
  return copy;
}

/* This must work without sending any messages to content objects */
- empty
{
  [_contents_collector empty];
  return self;
}

/* Override designated initializer for superclass */
- initWithType: (const char *)contentEncoding
{
  return [self initWithType:contentEncoding
	       nodeCollector:[[self class] defaultNodeCollectorClass]
	       nodeClass:[[self class] defaultEltNodeClass]];
}

- free
{
  [[_contents_collector freeObjects] free];
  return [super free];
}


// DETERMINING CLASS OF AUTOCREATED NODES;
- eltNodeClass
{
  return _node_class;
}

// GETTING THE UNDERLYING COLLECTOR;
- contentsCollector
{
  return _contents_collector;
}

// ADDING;

- makeEltNodeWithElement: (elt)newElement
{
  return [[[self eltNodeClass] alloc]
	  initElement:newElement
	  encoding:[self contentType]];
}

- insertElement: (elt)newElement atIndex: (unsigned)index
{
  unsigned count = [_contents_collector count];
  CHECK_INDEX_RANGE_ERROR(index, count+1);
  if (index == count)
    [_contents_collector 
     appendElement:[self makeEltNodeWithElement:newElement]];
  else
    [_contents_collector 
     insertElement:[self makeEltNodeWithElement:newElement]
     before:[_contents_collector elementAtIndex:index]];
  return self;
}

- insertElement: (elt)newElement before: (elt)oldElement
{
  id node = [self eltNodeWithElement:oldElement];
  if (!node)
    ELEMENT_NOT_FOUND_ERROR(oldElement);
  [_contents_collector 
   insertElement:[self makeEltNodeWithElement:newElement]
   before:node];
  return self;
}

- insertElement: (elt)newElement after: (elt)oldElement
{
  id node = [self eltNodeWithElement:oldElement];
  if (!node)
    ELEMENT_NOT_FOUND_ERROR(oldElement);
  [_contents_collector 
   insertElement:[self makeEltNodeWithElement:newElement]
   after:node];
  return self;
}

- appendElement: (elt)newElement
{
  [_contents_collector
   appendElement:[self makeEltNodeWithElement:newElement]];
  return self;
}

- prependElement: (elt)newElement
{
  [_contents_collector
   prependElement:[self makeEltNodeWithElement:newElement]];
  return self;
}

- addElement: (elt)newElement
{
  [_contents_collector
   addElement:[self makeEltNodeWithElement:newElement]];
  return self;
}

// REMOVING SWAPING AND REPLACING;

- swapAtIndeces: (unsigned)index1 : (unsigned)index2;
{
  CHECK_INDEX_RANGE_ERROR(index1, [_contents_collector count]);
  CHECK_INDEX_RANGE_ERROR(index2, [_contents_collector count]);
  [_contents_collector
   swapAtIndeces:index1 :index2];
  return self;
}

- (elt) removeElementAtIndex: (unsigned)index
{
  id node;
  elt ret;

  CHECK_INDEX_RANGE_ERROR(index, [_contents_collector count]);
  node = [_contents_collector removeElementAtIndex:index].id_u;
  ret = [node elementData];
  [node free];
  return ret;
}

- (elt) removeElement: (elt)oldElement
{
  id aNode = [self eltNodeWithElement:oldElement];
  elt ret;

  if (!aNode)
    return ELEMENT_NOT_FOUND_ERROR(oldElement);
  ret = [aNode elementData];
  [_contents_collector removeElement:aNode];
  [aNode free];
  return ret;
}

- (elt) removeFirstElement
{
  id aNode = [_contents_collector firstElement].id_u;
  elt ret;

  if (!aNode)
    return NO_ELEMENT_FOUND_ERROR();
  ret = [aNode elementData];
  [_contents_collector removeElement:aNode];
  [aNode free];
  return ret;
}

- (elt) removeLastElement
{
  id aNode = [_contents_collector lastElement].id_u;
  elt ret;

  if (!aNode)
    return NO_ELEMENT_FOUND_ERROR();
  ret = [aNode elementData];
  [_contents_collector removeElement:aNode];
  [aNode free];
  return ret;
}

- (elt) replaceElement: (elt)oldElement with: (elt)newElement
{
  id aNode = [self eltNodeWithElement:oldElement];
  elt ret;

  if (!aNode)
    return ELEMENT_NOT_FOUND_ERROR(oldElement);
  ret = [aNode elementData];
  [_contents_collector replaceElement:aNode 
		       with:[self makeEltNodeWithElement:newElement]];
  [aNode free];
  return ret;
}

- (elt) replaceElementAtIndex: (unsigned)index with: (elt)newElement
{
  elt ret;
  elt oldNode;

  CHECK_INDEX_RANGE_ERROR(index, [_contents_collector count]);
  oldNode = [_contents_collector 
	     replaceElementAtIndex:index
	     with:[self makeEltNodeWithElement:newElement]];
  ret = [oldNode.id_u elementData];
  [oldNode.id_u free];
  return ret;
}

// GETTING ELEMENTS BY INDEX;

- (elt) elementAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, [_contents_collector count]);
  return [[_contents_collector elementAtIndex:index].id_u elementData];
}

// TESTING;

- eltNodeWithElement: (elt)anElement
{
  int (*cf)(elt,elt) = [self comparisonFunction];
  elt err_ret;
  elt err(arglist_t argFrame)
    {
      return err_ret;
    }
  BOOL test(elt node)
    {
       if (!((*cf)([node.id_u elementData], anElement)))
	 return YES;
       else
	 return NO;
     }
  err_ret.id_u = nil;
  return [_contents_collector detectElementByCalling:test
			      ifNoneCall:err].id_u;
}

- (unsigned) count
{
  return [_contents_collector count];
}


// ENUMERATING;

- (BOOL) getNextElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  elt node;
  BOOL flag;

  flag = [_contents_collector getNextElement:&node withEnumState:enumState];
  if (flag)
    *anElementPtr = [node.id_u elementData];
  return flag;
}

- (void*) newEnumState
{
  return [_contents_collector newEnumState];
}

- freeEnumState: (void**)enumState
{
  [_contents_collector freeEnumState:enumState];
  return self;
}

- (BOOL) getPrevElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  elt node;
  BOOL flag;

  flag = [_contents_collector getPrevElement:&node withEnumState:enumState];
  if (flag)
    *anElementPtr = [node.id_u elementData];
  return flag;
}

- withElementsCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag
{
  void doIt(elt node)
    {
      (*aFunc)([node.id_u elementData]);
    }
  [_contents_collector withElementsCall:doIt whileTrue:flag];
  return self;
}

- withElementsInReverseCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag
{
  void doIt(elt node)
    {
      (*aFunc)([node.id_u elementData]);
    }
  [_contents_collector withElementsInReverseCall:doIt whileTrue:flag];
  return self;
}

- (const char *) contentType
{
  return elt_get_encoding(_comparison_function);
}

- (int(*)(elt,elt)) comparisonFunction
{
  return _comparison_function;
}

@end

