/** Implementation for NSXMLParser for GNUStep
   Copyright (C) 2004 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: May 2004

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.

   */

#include <Additions/GNUstepBase/GSXML.h>
#include <Foundation/NSError.h>
#include <Foundation/NSException.h>
#include <Foundation/NSXMLParser.h>
#include <Foundation/NSData.h>
#include <Foundation/NSObjCRuntime.h>
#include <GNUstepBase/GSFunctions.h>

NSString* const NSXMLParserErrorDomain = @"NSXMLParserErrorDomain";

@interface	NSXMLSAXHandler : GSSAXHandler
{
@public
  id		_delegate;
  id		_owner;
  NSError	*_lastError;
  BOOL		_shouldProcessNamespaces;
  BOOL		_shouldReportNamespacePrefixes;
  BOOL		_shouldResolveExternalEntities;
}
- (void) _setOwner: (id)owner;
@end

@implementation	NSXMLSAXHandler

- (void) endDocument
{
  [_delegate parserDidEndDocument: _owner];
}
- (void) startDocument
{
  [_delegate parserDidStartDocument: _owner];
}

- (void) startElement: (NSString*)elementName
	       prefix: (NSString*)prefix
		 href: (NSString*)href
	   attributes: (NSMutableDictionary*)elementAttributes
{
  if (_shouldProcessNamespaces)
    {
      [_delegate parser: _owner
	didStartElement: elementName
	   namespaceURI: href
	  qualifiedName: prefix
	     attributes: elementAttributes];
    }
  else
    {
      [_delegate parser: _owner
	didStartElement: elementName
	   namespaceURI: nil
	  qualifiedName: nil
	     attributes: elementAttributes];
    }
}

- (void) endElement: (NSString*) elementName
	     prefix: (NSString*)prefix
	       href: (NSString*)href
{
  if (_shouldProcessNamespaces)
    {
      [_delegate parser: _owner
	  didEndElement: elementName
	   namespaceURI: href
	  qualifiedName: prefix];
    }
  else
    {
      [_delegate parser: _owner
	  didEndElement: elementName
	   namespaceURI: nil
	  qualifiedName: nil];
    }
}
- (void) attribute: (NSString*) name value: (NSString*)value
{
	// FIXME
}
- (void) characters: (NSString*)string
{
  [_delegate parser: _owner
    foundCharacters: string];
}
- (void) ignoreWhitespace: (NSString*) ch
{
  [_delegate parser: _owner
    foundIgnorableWhitespace: ch];
}
- (void) processInstruction: (NSString*)targetName data: (NSString*)PIdata
{
  [_delegate parser: _owner
    foundProcessingInstructionWithTarget: targetName
    data: PIdata];
}
- (void) comment: (NSString*) value
{
  [_delegate parser: _owner
    foundComment: value];
}
- (void) cdataBlock: (NSData*)value
{
  [_delegate parser: _owner
    foundCDATA: value];
}

/**
 * Called to return the filename from which an entity should be loaded.
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

- (void) notationDecl: (NSString*)name
	       public: (NSString*)publicId
	       system: (NSString*)systemId
{
  [_delegate parser: _owner
    foundNotationDeclarationWithName: name
    publicID: publicId
    systemID: systemId];
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

- (void) attributeDecl: (NSString*)nameElement
		  name: (NSString*)name
		  type: (int)type
	  typeDefValue: (int)defType
	  defaultValue: (NSString*)value
{
  [_delegate parser: _owner
    foundAttributeDeclarationWithName: name
    forElement: nameElement
    type: nil		// FIXME
    defaultValue: value];
}

- (void) elementDecl: (NSString*)name
		type: (int)type
{
  [_delegate parser: _owner
    foundElementDeclarationWithName: name
    model: nil];	// FIXME
}

/**
 * What to do when an unparsed entity declaration is parsed.
 */
- (void) unparsedEntityDecl: (NSString*)name
		     public: (NSString*)publicId
		     system: (NSString*)systemId
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
  GSPrintf(stderr, @"%@", e);
}

- (void) error: (NSString*)e
{
  NSError	*error;
  NSDictionary	*d;

  d = [NSDictionary dictionaryWithObjectsAndKeys:
    e, NSLocalizedDescriptionKey,
    nil];
  error = [NSError errorWithDomain: NSXMLParserErrorDomain
			      code: 0
			  userInfo: d];
  ASSIGN(_lastError, error);
  [_delegate parser: _owner
    parseErrorOccurred: error];
}
- (void) fatalError: (NSString*)e
{
  [self error: e];
}
- (void) warning: (NSString*)e
       colNumber: (int)colNumber
      lineNumber: (int)lineNumber
{
  e = [NSString stringWithFormat: @"at line: %d column: %d ... %@",
    lineNumber, colNumber, e];
  [self warning: e];
}
- (void) error: (NSString*)e
     colNumber: (int)colNumber
    lineNumber: (int)lineNumber
{
  e = [NSString stringWithFormat: @"at line: %d column: %d ... %@",
    lineNumber, colNumber, e];
  [self error: e];
}
- (void) fatalError: (NSString*)e
       colNumber: (int)colNumber
      lineNumber: (int)lineNumber
{
  e = [NSString stringWithFormat: @"at line: %d column: %d ... %@",
    lineNumber, colNumber, e];
  [self fatalError: e];
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
	       systemID: (NSString*)systemID
{
  return NO;
}
- (void*) getEntity: (NSString*)name
{
  return 0;
}
- (void*) getParameterEntity: (NSString*)name
{
  return 0;
}

- (void) _setOwner: (id)owner
{
  ASSIGN(_owner, owner);
}

@end



@implementation NSXMLParser

#define	myParser	((GSXMLParser*)_parser)
#define	myHandler	((NSXMLSAXHandler*)_handler)

- (void) abortParsing
{
  NSDictionary	*d;
  NSString	*e;
  NSError	*error;

  e = @"Parsing aborted";
  d = [NSDictionary dictionaryWithObjectsAndKeys:
    e, NSLocalizedDescriptionKey,
    nil];
  error = [NSError errorWithDomain: NSXMLParserErrorDomain
			      code: 0
			  userInfo: d];
  ASSIGN(myHandler->_lastError, error);
  [myHandler->_delegate parser: myHandler->_owner parseErrorOccurred: error];
  [myParser abortParsing];
}

- (void) dealloc
{
  DESTROY(_parser);
  DESTROY(_handler);
  [super dealloc];
}

- (id) delegate
{
  return myHandler->_delegate;
}

- (id) initWithContentsOfURL: (NSURL*)anURL
{
  NSData	*d = [NSData dataWithContentsOfURL: anURL];

  if (d == nil)
    {
      DESTROY(self);
    }
  else
    {
      self = [self initWithData: d];
    }
  return self;
}

- (id) initWithData: (NSData*)data
{
  _handler = [NSXMLSAXHandler new];
  [myHandler _setOwner: self];
  _parser = [[GSXMLParser alloc] initWithSAXHandler: myHandler withData: data];
  return self;
}

- (BOOL) parse
{
  BOOL	result;

  result = [[myHandler parser] parse];
  return result;
}

- (NSError*) parserError
{
  return nil;	// FIXME
}

- (void) setDelegate: (id)delegate
{
  myHandler->_delegate = delegate;
}

- (void) setShouldProcessNamespaces: (BOOL)aFlag
{
  myHandler->_shouldProcessNamespaces = aFlag;
}

- (void) setShouldReportNamespacePrefixes: (BOOL)aFlag
{
  myHandler->_shouldReportNamespacePrefixes = aFlag;
}

- (void) setShouldResolveExternalEntities: (BOOL)aFlag
{
  myHandler->_shouldResolveExternalEntities = aFlag;
}

- (BOOL) shouldProcessNamespaces
{
  return myHandler->_shouldProcessNamespaces;
}

- (BOOL) shouldReportNamespacePrefixes
{
  return myHandler->_shouldReportNamespacePrefixes;
}

- (BOOL) shouldResolveExternalEntities
{
  return myHandler->_shouldResolveExternalEntities;
}

@end

@implementation NSXMLParser (NSXMLParserLocatorAdditions)
- (int) columnNumber
{
  return [myParser columnNumber];
}

- (int) lineNumber
{
  return [myParser lineNumber];
}

- (NSString*) publicID
{
  return [myParser publicID];
}

- (NSString*) systemID
{
  return [myParser systemID];
}

@end

@implementation NSObject (NSXMLParserDelegateEventAdditions)
- (NSData*) parser: (NSXMLParser*)aParser
  resolveExternalEntityName: (NSString*)aName
  systemID: (NSString*)aSystemID
{
  return nil;
}

- (void) parser: (NSXMLParser*)aParser
  didEndElement: (NSString*)anElementName
  namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
{
}

- (void) parser: (NSXMLParser*)aParser
  didEndMappingPrefix: (NSString*)aPrefix
{
}

- (void) parser: (NSXMLParser*)aParser
  didStartElement: (NSString*)anElementName
  namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
  attributes: (NSDictionary*)anAttributeDict
{
}

- (void) parser: (NSXMLParser*)aParser
  didStartMappingPrefix: (NSString*)aPrefix
  toURI: (NSString*)aNamespaceURI
{
}

- (void) parser: (NSXMLParser*)aParser
  foundAttributeDeclarationWithName: (NSString*)anAttributeName
  forElement: (NSString*)anElementName
  type: (NSString*)aType
  defaultValue: (NSString*)aDefaultValue
{
}

- (void) parser: (NSXMLParser*)aParser
  foundCDATA: (NSData*)aBlock
{
}

- (void) parser: (NSXMLParser*)aParser
  foundCharacters: (NSString*)aString
{
}

- (void) parser: (NSXMLParser*)aParser
  foundComment: (NSString*)aComment
{
}

- (void) parser: (NSXMLParser*)aParser
  foundElementDeclarationWithName: (NSString*)anElementName
  model: (NSString*)aModel
{
}

- (void) parser: (NSXMLParser*)aParser
  foundExternalEntityDeclarationWithName: (NSString*)aName
  publicID: (NSString*)aPublicID
  systemID: (NSString*)aSystemID
{
}

- (void) parser: (NSXMLParser*)aParser
  foundIgnorableWhitespace: (NSString*)aWhitespaceString
{
}

- (void) parser: (NSXMLParser*)aParser
  foundInternalEntityDeclarationWithName: (NSString*)aName
  value: (NSString*)aValue
{
}

- (void) parser: (NSXMLParser*)aParser
  foundNotationDeclarationWithName: (NSString*)aName
  publicID: (NSString*)aPublicID
  systemID: (NSString*)aSystemID
{
}

- (void) parser: (NSXMLParser*)aParser
  foundProcessingInstructionWithTarget: (NSString*)aTarget
  data: (NSString*)aData
{
}

- (void) parser: (NSXMLParser*)aParser
  foundUnparsedEntityDeclarationWithName: (NSString*)aName
  publicID: (NSString*)aPublicID
  systemID: (NSString*)aSystemID
  notationName: (NSString*)aNotationName
{
}

- (void) parser: (NSXMLParser*)aParser
  parseErrorOccurred: (NSError*)anError
{
}

- (void) parser: (NSXMLParser*)aParser
  validationErrorOccurred: (NSError*)anError
{
}

- (void) parserDidEndDocument: (NSXMLParser*)aParser
{
}

- (void) parserDidStartDocument: (NSXMLParser*)aParser
{
}

@end

