/** Implementation for NSXMLParser for GNUStep
   Copyright (C) 2004 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: May 2004

   SloppyParser additions based on code by Nikolaus Schaller

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

   */

#import "common.h"
#define	EXPOSE_NSXMLParser_IVARS	1
#import "Foundation/NSArray.h"
#import "Foundation/NSError.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSXMLParser.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSNull.h"
#import "GNUstepBase/GSStandaloneXMLParser.h"
#import "GNUstepBase/GSMime.h"

@interface GSMimeDocument (internal)
+ (NSString*) charsetForXml: (NSData*)xml;
@end

static  NSNull  *null = nil;

/* We always have the native (sloppy) parser, and can get that behavior
 * by using the GSSloppyXMLParser class.
 * With libxml2 we have a stricter parser (which will break on some OSX
 * property lists) available using GSStrictXMLParser.
 */
@interface      GSSloppyXMLParser : GSStandaloneXMLParser
@end
@implementation GSSloppyXMLParser
- (void) _setAcceptHTML: (BOOL)flag
{
  [self setAcceptHTML: flag];
}
- (NSArray*) _tagPath
{
  return [self tagPath];
}
@end

@interface      GSStrictXMLParser : NSXMLParser
@end


@implementation NSString (NSXMLParser)

- (NSString *) _stringByExpandingXMLEntities
{
  NSMutableString       *t = [NSMutableString stringWithString: self];

  [t replaceOccurrencesOfString: @"&"
                     withString: @"&amp;"
                        options: 0
                          range: NSMakeRange(0, [t length])];  // must be first!
  [t replaceOccurrencesOfString: @"<"
                     withString: @"&lt;"
                        options: 0
                          range: NSMakeRange(0, [t length])];
  [t replaceOccurrencesOfString: @">"
                     withString: @"&gt;"
                        options: 0
                          range: NSMakeRange(0, [t length])];
  [t replaceOccurrencesOfString: @"\""
                     withString: @"&quot;"
                        options: 0
                          range: NSMakeRange(0, [t length])];
  [t replaceOccurrencesOfString: @"'"
                     withString: @"&apos;"
                        options: 0
                          range: NSMakeRange(0, [t length])];
  return t;
}

@end

static inline NSString *
NewUTF8STR(const void *ptr, int len)
{
  NSString	*s;

  s = [[NSString alloc] initWithBytes: ptr
			       length: len
			     encoding: NSUTF8StringEncoding];
  if (s == nil)
    NSLog(@"could not convert to UTF8 string! bytes=%p len=%d", ptr, len);
  return s;
}

@interface GSXMLParserIvars : NSObject
{
@public
  NSMutableArray        *tagPath;	// hierarchy of tags
  NSMutableArray        *namespaces;
  NSMutableDictionary	*defaults;
  NSData                *data;
  NSError               *error;
  const unsigned char	*bytes;
  NSUInteger		cp;		// character position
  NSUInteger		cend;		// end of data
  int line;				// current line (counts from 0)
  int column;				// current column (counts from 0)
  BOOL abort;				// abort parse loop
  BOOL ignorable;			// whitespace is ignorable
  BOOL whitespace;			// had only whitespace in current data
  BOOL shouldProcessNamespaces;
  BOOL shouldReportNamespacePrefixes;
  BOOL shouldResolveExternalEntities;
  BOOL acceptHTML;			// be lazy with bad tag nesting
  BOOL hasStarted;
  BOOL hasElement;
  IMP	didEndElement;
  IMP	didEndMappingPrefix;
  IMP	didStartElement;
  IMP	didStartMappingPrefix;
  IMP	foundCDATA;
  IMP	foundCharacters;
  IMP	foundComment;
  IMP	foundIgnorable;
} 
@end
@implementation	GSXMLParserIvars
- (NSString*) description
{
  return [[super description] stringByAppendingFormat:
    @" shouldProcessNamespaces: %d"
    @" shouldReportNamespacePrefixes: %d"
    @" shouldResolveExternalEntities: %d"
    @" acceptHTML: %d"
    @" hasStarted: %d"
    @" hasElement: %d",
    shouldProcessNamespaces,
    shouldReportNamespacePrefixes,
    shouldResolveExternalEntities,
    acceptHTML,
    hasStarted,
    hasElement];
}
@end

static SEL	didEndElementSel = 0;
static SEL	didEndMappingPrefixSel;
static SEL	didStartElementSel;
static SEL	didStartMappingPrefixSel;
static SEL	foundCDATASel;
static SEL	foundCharactersSel;
static SEL	foundCommentSel;
static SEL	foundIgnorableSel;

@interface	NSXMLParser (Private)
- (NSString *) _newQarg;
@end

@implementation NSXMLParser

#define EXTRA_DEBUG     0

#define _parser (self->_parser)
#define _handler (self->_handler)
#define	this	((GSXMLParserIvars*)_parser)
#define	_del	((id)_handler)

static	Class	sloppy = Nil;
static	Class	strict = Nil;

+ (id) allocWithZone: (NSZone*)z
{
  if (self == [NSXMLParser class])
    {
#if	 defined(HAVE_LIBXML)
      return NSAllocateObject(strict, 0, z);
#else
      return NSAllocateObject(sloppy, 0, z);
#endif
    }
  return NSAllocateObject(self, 0, z);
}

+ (void) initialize
{
  sloppy = [GSSloppyXMLParser class];
  strict = [GSStrictXMLParser class];
  if (null == nil)
    {
      null = RETAIN([NSNull null]);
      RELEASE([NSObject leakAt: &null]);
    }
  if (didEndElementSel == 0)
    {
      didEndElementSel
	= @selector(parser:didEndElement:namespaceURI:qualifiedName:);
      didEndMappingPrefixSel
        = @selector(parser:didEndMappingPrefix:);
      didStartElementSel
= @selector(parser:didStartElement:namespaceURI:qualifiedName:attributes:);
      didStartMappingPrefixSel
	= @selector(parser:didStartMappingPrefix:toURI:);
      foundCDATASel
	= @selector(parser:foundCDATA:);
      foundCharactersSel
	= @selector(parser:foundCharacters:);
      foundCommentSel
	= @selector(parser:foundComment:);
      foundIgnorableSel
	= @selector(parser:foundIgnorableWhitespace:);
    }
}

- (void) abortParsing
{
  this->abort = YES;
}

- (NSInteger) columnNumber
{
  return this->column;
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->data);
      RELEASE(this->error);
      RELEASE(this->tagPath);
      RELEASE(this->namespaces);
      RELEASE(this->defaults);
      RELEASE(this);
      _parser = 0;
      _handler = 0;
    }
  [super dealloc];
}

- (id) delegate
{
  return _del;
}

- (id) initWithContentsOfURL: (NSURL *)anURL
{
  return [self initWithData: [NSData dataWithContentsOfURL: anURL]];
}

#define	addr(x) (this->bytes + (x))

- (id) initWithData: (NSData *)data
{
  if (data == nil)
    {
      DESTROY(self);
    }
  else
    {
      self = [super init];
      if (self)
	{
	  NSStringEncoding	enc;
          NSString		*tmp;

	  _parser = [GSXMLParserIvars new];
	  /* Determine character encoding and convert to utf-8
	   */
	  enc = [GSMimeDocument encodingFromCharset:
	    [GSMimeDocument charsetForXml: data]];
	  if (GSUndefinedEncoding == enc)
	    {
	      enc = NSUTF8StringEncoding;	// Guess at UTF8
	    }

          tmp = [[NSString alloc] initWithData: data encoding: enc];
	  if (nil == tmp)
	    {
	      /* Bad encoding... fall back to latin1, guaranteed to work.
	       */
	      enc = NSISOLatin1StringEncoding;
	      tmp = [[NSString alloc] initWithData: data encoding: enc];
	    }  
	  this->data = RETAIN([tmp dataUsingEncoding: NSUTF8StringEncoding]);
	  RELEASE(tmp);

	  this->tagPath = [[NSMutableArray alloc] init];
	  this->namespaces = [[NSMutableArray alloc] init];
	  this->bytes = [this->data bytes];
	  this->cp = 0;
	  this->cend = [this->data length];
	  /* If the data contained utf-8 with a BOM, we must skip it.
	   */
	  if ((this->cend - this->cp) > 2 && addr(this->cp)[0] == 0xef
	    && addr(this->cp)[1] == 0xbb && addr(this->cp)[2] == 0xbf)
	    {
	      this->cp += 3;	// Skip BOM
	    }
	}
    }
  return self;
}

- (id) initWithStream: (NSInputStream*)stream
{
  RELEASE(self);	// FIXME
  return nil;
}

- (NSInteger) lineNumber
{
  return this->line;
}

- (void) setDelegate: (id)delegate
{
  if (_handler != delegate)
    {
      _handler = delegate;

      if ([_del respondsToSelector: didEndElementSel])
	{
	  this->didEndElement = [_del methodForSelector: didEndElementSel];
	}
      else
	{
	  this->didEndElement = 0;
	}

      if ([_del respondsToSelector: didEndMappingPrefixSel])
	{
	  this->didEndMappingPrefix
	    = [_del methodForSelector: didEndMappingPrefixSel];
	}
      else
	{
	  this->didEndMappingPrefix = 0;
	}

      if ([_del respondsToSelector: didStartElementSel])
	{
	  this->didStartElement = [_del methodForSelector: didStartElementSel];
	}
      else
	{
	  this->didStartElement = 0;
	}

      if ([_del respondsToSelector: didStartMappingPrefixSel])
	{
	  this->didStartMappingPrefix
	    = [_del methodForSelector: didStartMappingPrefixSel];
	}
      else
	{
	  this->didStartMappingPrefix = 0;
	}

      if ([_del respondsToSelector: foundCDATASel])
	{
	  this->foundCDATA
	    = [_del methodForSelector: foundCDATASel];
	}
      else
	{
	  this->foundCDATA = 0;
	}

      if ([_del respondsToSelector: foundCharactersSel])
	{
	  this->foundCharacters
	    = [_del methodForSelector: foundCharactersSel];
	}
      else
	{
	  this->foundCharacters = 0;
	}

      if ([_del respondsToSelector: foundCommentSel])
	{
	  this->foundComment
	    = [_del methodForSelector: foundCommentSel];
	}
      else
	{
	  this->foundComment = 0;
	}

      if ([_del respondsToSelector: foundIgnorableSel])
	{
/* It seems OX reports ignorable whitespace as characters,
 * so we disable this ... FIXME can this really be right?
 */
#if 0
	  this->foundIgnorable
	    = [_del methodForSelector: foundIgnorableSel];
#else
	  this->foundIgnorable = 0;
#endif
	}
      else
	{
	  this->foundIgnorable = 0;
	}
    }
}

- (NSError *) parserError
{
  return this->error;
}

- (BOOL) parse
{
  return NO;	// subclass implementes
}

- (BOOL) acceptsHTML
{
  return this->acceptHTML;
}

- (BOOL) shouldProcessNamespaces
{
  return this->shouldProcessNamespaces;
}

- (BOOL) shouldReportNamespacePrefixes
{
  return this->shouldReportNamespacePrefixes;
}

- (BOOL) shouldResolveExternalEntities
{
  return this->shouldResolveExternalEntities;
}

- (void) setShouldProcessNamespaces: (BOOL)aFlag
{
  this->shouldProcessNamespaces = aFlag;
}

- (void) setShouldReportNamespacePrefixes: (BOOL)aFlag
{
  this->shouldReportNamespacePrefixes = aFlag;
}

- (void) setShouldResolveExternalEntities: (BOOL)aFlag
{
  this->shouldResolveExternalEntities = aFlag;
}

- (void) _setAcceptHTML: (BOOL) flag
{
  this->acceptHTML = flag;
}

- (NSString *) publicID
{
  return [self notImplemented: _cmd];
}

- (NSString *) systemID
{
  return [self notImplemented: _cmd];
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

#if	 defined(HAVE_LIBXML)

#include <GNUstepBase/GSXML.h>

@interface	NSXMLSAXHandler : GSSAXHandler
{
@public
  id		_delegate;      // Not retained
  id		_owner;         // Not retained
  NSError	*_lastError;
  BOOL		_shouldProcessNamespaces;
  BOOL		_shouldReportNamespacePrefixes;
  BOOL		_shouldResolveExternalEntities;
  NSMutableArray        *_namespaces;
}
- (void) _setOwner: (id)owner;
@end

@implementation	NSXMLSAXHandler

+ (void) initialize
{
}

- (void) dealloc
{
  DESTROY(_namespaces);
  DESTROY(_lastError);
  [super dealloc];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _namespaces = [NSMutableArray new];
    }
  return self;
}

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
	   namespaces: (NSMutableDictionary*)elementNamespaces
{
  NSString      *qName = elementName;

  if ([prefix length] > 0)
    {
      qName = [NSString stringWithFormat: @"%@:%@", prefix, qName];
    }

  if (elementAttributes == nil)
    {
      elementAttributes = [NSMutableDictionary dictionary];
    }

  if ([elementNamespaces count] > 0)
    {
      [_namespaces addObject: [elementNamespaces allKeys]];
      if (_shouldReportNamespacePrefixes)
        {
          NSEnumerator  *e = [elementNamespaces keyEnumerator];
          NSString      *k;

          while ((k = [e nextObject]) != nil)
            {
              NSString  *v = [elementNamespaces objectForKey: k];

              [_delegate parser: _owner
                didStartMappingPrefix: k
                toURI: v];
            }
        }
    }
  else
    {
      [_namespaces addObject: null];
    }

  if (_shouldProcessNamespaces)
    {
      [_delegate parser: _owner
	didStartElement: elementName
	   namespaceURI: (nil == href) ? @"" : href
	  qualifiedName: qName
	     attributes: elementAttributes];
    }
  else
    {
      /* When we are not handling namespaces specially, any namespaces
       * should appear as attributes of the element.
       */
      if ([elementNamespaces count] > 0)
        {
          NSEnumerator  *e = [elementNamespaces keyEnumerator];
          NSString      *k;

          while ((k = [e nextObject]) != nil)
            {
              NSString  *v = [elementNamespaces objectForKey: k];

              if ([k length] == 0)
                {
                  [elementAttributes setObject: v forKey: @"xmlns"];
                }
              else
                {
                  k = [@"xmlns:" stringByAppendingString: k];
                  [elementAttributes setObject: v forKey: k];
                }
            }
        }
      [_delegate parser: _owner
	didStartElement: qName
	   namespaceURI: nil
	  qualifiedName: nil
	     attributes: elementAttributes];
    }
}

- (void) endElement: (NSString*)elementName
	     prefix: (NSString*)prefix
	       href: (NSString*)href
{
  NSString      *qName = elementName;

  if ([prefix length] > 0)
    {
      qName = [NSString stringWithFormat: @"%@:%@", prefix, qName];
    }
  if (_shouldProcessNamespaces)
    {
      [_delegate parser: _owner
	  didEndElement: elementName
	   namespaceURI: (nil == href) ? @"" : href
	  qualifiedName: qName];
    }
  else
    {
      [_delegate parser: _owner
	  didEndElement: qName
	   namespaceURI: nil
	  qualifiedName: nil];
    }

  if (_shouldReportNamespacePrefixes)
    {
      id        o = [_namespaces lastObject];

      if (o != (id)null)
        {
          NSEnumerator  *e = [(NSArray*)o objectEnumerator];
          NSString      *k;

          while ((k = [e nextObject]) != nil)
            {
              [_delegate parser: _owner didEndMappingPrefix: k];
            }
        }
    }
  [_namespaces removeLastObject];
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
	       type: (NSInteger)type
	     public: (NSString*)publicId
	     system: (NSString*)systemId
	    content: (NSString*)content
{
}

- (void) attributeDecl: (NSString*)nameElement
		  name: (NSString*)name
		  type: (NSInteger)type
	  typeDefValue: (NSInteger)defType
	  defaultValue: (NSString*)value
{
  [_delegate parser: _owner
    foundAttributeDeclarationWithName: name
    forElement: nameElement
    type: @""		// FIXME
    defaultValue: value];
}

- (void) elementDecl: (NSString*)name
		type: (NSInteger)type
{
  [_delegate parser: _owner
    foundElementDeclarationWithName: name
    model: @""];	// FIXME
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
       colNumber: (NSInteger)colNumber
      lineNumber: (NSInteger)lineNumber
{
  e = [NSString stringWithFormat: @"at line: %d column: %d ... %@",
    (int)lineNumber, (int)colNumber, e];
  [self warning: e];
}
- (void) error: (NSString*)e
     colNumber: (NSInteger)colNumber
    lineNumber: (NSInteger)lineNumber
{
  e = [NSString stringWithFormat: @"at line: %d column: %d ... %@",
    (int)lineNumber, (int)colNumber, e];
  [self error: e];
}
- (void) fatalError: (NSString*)e
          colNumber: (NSInteger)colNumber
         lineNumber: (NSInteger)lineNumber
{
  e = [NSString stringWithFormat: @"at line: %d column: %d ... %@",
    (int)lineNumber, (int)colNumber, e];
  [self fatalError: e];
}
- (NSInteger) hasInternalSubset
{
  return 0;
}
- (BOOL) internalSubset: (NSString*)name
	     externalID: (NSString*)externalID
	       systemID: (NSString*)systemID
{
  return NO;
}
- (NSInteger) hasExternalSubset
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
  _owner = owner;
}

@end



@implementation GSStrictXMLParser

+ (void) initialize
{
  if (null == nil)
    {
      null = RETAIN([NSNull null]);
      RELEASE([NSObject leakAt: &null]);
    }
}

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
  if (nil != (self = [super init]))
    {
      _handler = [NSXMLSAXHandler new];
      [myHandler _setOwner: self];
      _parser = [[GSXMLParser alloc] initWithSAXHandler: myHandler
				      withContentsOfURL: anURL];
      [(GSXMLParser*)_parser substituteEntities: YES];
    }
  return self;
}

- (id) initWithData: (NSData*)data
{
  if (nil != (self = [super init]))
    {
      _handler = [NSXMLSAXHandler new];
      [myHandler _setOwner: self];
      _parser = [[GSXMLParser alloc] initWithSAXHandler: myHandler
					       withData: data];
      [(GSXMLParser*)_parser substituteEntities: YES];
    }
  return self;
}

- (id) initWithStream: (NSInputStream*)stream
{
  if (nil != (self = [super init]))
    {
      _handler = [NSXMLSAXHandler new];
      [myHandler _setOwner: self];
      _parser = [[GSXMLParser alloc] initWithSAXHandler: myHandler
					withInputStream: stream];
      [(GSXMLParser*)_parser substituteEntities: YES];
    }
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
  return (nil == myHandler) ? nil : myHandler->_lastError;
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

- (NSInteger) columnNumber
{
  return [myParser columnNumber];
}

- (NSInteger) lineNumber
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

#else
@implementation GSStrictXMLParser
@end
#endif
