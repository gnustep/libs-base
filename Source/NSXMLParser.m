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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   */

#include "config.h"
#include <Foundation/NSArray.h>
#include <Foundation/NSError.h>
#include <Foundation/NSException.h>
#include <Foundation/NSXMLParser.h>
#include <Foundation/NSData.h>
#include <Foundation/NSObjCRuntime.h>

NSString* const NSXMLParserErrorDomain = @"NSXMLParserErrorDomain";

#ifdef	HAVE_LIBXML

#include <Additions/GNUstepBase/GSXML.h>

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

#else

@implementation NSString (NSXMLParser)

- (NSString *) _stringByExpandingXMLEntities
{
  NSMutableString *t=[NSMutableString stringWithString: self];
  [t replaceOccurrencesOfString: @"&" withString: @"&amp;" options: 0 range: NSMakeRange(0, [t length])];  // must be first!
  [t replaceOccurrencesOfString: @"<" withString: @"&lt;" options: 0 range: NSMakeRange(0, [t length])];
  [t replaceOccurrencesOfString: @">" withString: @"&gt;" options: 0 range: NSMakeRange(0, [t length])];
  [t replaceOccurrencesOfString: @"\"" withString: @"&quot;" options: 0 range: NSMakeRange(0, [t length])];
  [t replaceOccurrencesOfString: @"'" withString: @"&apos;" options: 0 range: NSMakeRange(0, [t length])];
  return t;
}

@end

static NSString *UTF8STR(const void *ptr, int len)
{
  NSString	*s;

  s = [[NSString alloc] initWithBytes: ptr
			       length: len
			     encoding: NSUTF8StringEncoding];
  if (s == nil)
    NSLog(@"could not convert to UTF8 string! bytes=%08x len=%d", ptr, len);
  return AUTORELEASE(s);
}

typedef struct NSXMLParserIvarsType
{
  NSMutableArray *tagPath;		// hierarchy of tags
  NSData *data;
  NSError *error;
  const unsigned char *cp;		// character pointer
  const unsigned char *cend;		// end of data
  int line;				// current line (counts from 0)
  int column;				// current column (counts from 0)
  BOOL abort;				// abort parse loop
  BOOL shouldProcessNamespaces;
  BOOL shouldReportNamespacePrefixes;
  BOOL shouldResolveExternalEntities;
  BOOL acceptHTML;			// be lazy with bad tag nesting
} NSXMLParserIvars;

@implementation NSXMLParser

#define	this		((NSXMLParserIvars*)_parser)
#define	_del	((id)_handler)

- (void) abortParsing
{
  this->abort = YES;
}

- (int) columnNumber
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
      NSZoneFree([self zone], this);
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
	  _parser = NSZoneMalloc([self zone], sizeof(NSXMLParserIvars));
	  memset(_parser, '\0', sizeof(NSXMLParserIvars));
	  this->data = [data copy];
	  this->tagPath = [[NSMutableArray alloc] init];
	  this->cp = [this->data bytes];
	  this->cend = this->cp + [this->data length];
	}
    }
  return self;
}

- (int) lineNumber
{
  return this->line;
}

- (void) setDelegate: (id)delegate
{
  _handler = delegate;
}

- (NSError *) parserError
{
  return this->error;
}

- (NSArray *) _tagPath
{
  return this->tagPath;
}

#define cget() ((this->cp < this->cend)?(this->column++, *this->cp++): -1)

- (BOOL) _parseError: (NSString *)message
{
#if 0
  NSLog(@"XML parseError: %@", message);
#endif
  NSError *err = nil;

  ASSIGN(this->error, err);
  this->abort = YES;  // break look
  if ([_del respondsToSelector: @selector(parser:parseErrorOccurred:)])
    [_del parser: self parseErrorOccurred: this->error];  // pass error
  return NO;
}

- (void) _processTag: (NSString *)tag
	       isEnd: (BOOL)flag
      withAttributes: (NSDictionary *)attributes
{
  if (this->acceptHTML)
    tag = [tag lowercaseString];  // not case sensitive
  if (!flag)
    {
      if ([tag isEqualToString: @"?xml"])
	{
#if 0
NSLog(@"parserDidStartDocument: ");
#endif
	  if ([_del respondsToSelector: @selector(parserDidStartDocument:)])
	    [_del parserDidStartDocument: self];
	  return;
	}
      if ([tag hasPrefix: @"?"])
	{
#if 0
NSLog(@"_processTag <%@%@ %@>", flag?@"/": @"", tag, attributes);
#endif
	  // parser: foundProcessingInstructionWithTarget: data: 
	  return;
	}
      if ([tag isEqualToString: @"!DOCTYPE"])
	{
#if 0
NSLog(@"_processTag <%@%@ %@>", flag?@"/": @"", tag, attributes);
#endif
	  return;
	}
      if ([tag isEqualToString: @"!ENTITY"])
	{
#if 0
NSLog(@"_processTag <%@%@ %@>", flag?@"/": @"", tag, attributes);
#endif
	  return;
	}
      if ([tag isEqualToString: @"!CDATA"])
	{
  // pass through as NSData
	// parser: foundCDATA:   
#if 0
NSLog(@"_processTag <%@%@ %@>", flag?@"/": @"", tag, attributes);
#endif
	return;
	}
      [this->tagPath addObject: tag];  // push on stack
      if ([_del respondsToSelector:
      @selector(parser:didStartElement:namespaceURI:qualifiedName:attributes:)])
	[_del parser: self
	  didStartElement: tag
	  namespaceURI: nil
	  qualifiedName: nil
	  attributes: attributes];
    }
  else
    {
// closing tag
      if (this->acceptHTML)
	{
	  // lazily close any missing tags on stack
	  while ([this->tagPath count] > 0
	    && ![[this->tagPath lastObject] isEqualToString: tag])
	    {
	      if ([_del respondsToSelector:
		@selector(parser:didEndElement:namespaceURI:qualifiedName:)])
		[_del parser: self
		  didEndElement: [this->tagPath lastObject]
		  namespaceURI: nil
		  qualifiedName: nil];
	      [this->tagPath removeLastObject];  // pop from stack
	    }
	  if ([this->tagPath count] == 0)
	    return;  // ignore closing tag without matching open...
	}
      else if (![[this->tagPath lastObject] isEqualToString: tag])
	{
	  [self _parseError: [NSString stringWithFormat:
	    @"tag nesting error (</%@> expected, </%@> found)",
	    [this->tagPath lastObject], tag]];
	  return;
	}
      if ([_del respondsToSelector:
	@selector(parser:didEndElement:namespaceURI:qualifiedName:)])
	[_del parser: self
	  didEndElement: tag
	  namespaceURI: nil
	  qualifiedName: nil];
	[this->tagPath removeLastObject];  // pop from stack
    }
}

- (NSString *) _entity
{
// parse &xxx; sequence
  int c;
  const unsigned char *ep = this->cp;  // should be position behind &
  int len;
  unsigned int val;
  NSString *entity;

  do {
    c = cget();
  } while (c != EOF && c != '<' && c != ';');

  if (c != ';')
    return nil; // invalid sequence - end of file or missing ; before next tag
  len = this->cp - ep - 1;
  if (*ep == '#')
    {
// &#ddd; or &#xhh;
      // !!! ep+1 is not 0-terminated - but by ;!!
    if (sscanf((char *)ep+1, "x%x;", &val))
      return [NSString stringWithFormat: @"%C", val];  // &#xhh; hex value
    else if (sscanf((char *)ep+1, "%d;", &val))
      return [NSString stringWithFormat: @"%C", val];  // &ddd; decimal value
    }
  else
    {
// the five predefined entities
    if (len == 3 && strncmp((char *)ep, "amp", len) == 0)
      return @"&";
    if (len == 2 && strncmp((char *)ep, "lt", len) == 0)
      return @"<";
    if (len == 2 && strncmp((char *)ep, "gt", len) == 0)
      return @">";
    if (len == 4 && strncmp((char *)ep, "quot", len) == 0)
      return @"\"";
    if (len == 4 && strncmp((char *)ep, "apos", len) == 0)
      return @"'";
    }
  entity = UTF8STR(ep, len);
#if 1
  NSLog(@"NSXMLParser: unrecognized entity: &%@;", entity);
#endif
//  entity=[entitiesTable objectForKey: entity];  // look up string in entity translation table
  if (!entity)
    entity=@"&??;";  // unknown entity
  return entity;
}

- (NSString *) _qarg
{
// get argument (might be quoted)
  const unsigned char *ap = --this->cp;  // argument start pointer
  int c = cget();  // refetch first character

#if 0
  NSLog(@"_qarg: %02x %c", c, isprint(c)?c: ' ');
#endif
  if (c == '\"')
    {
// quoted argument
      do {
        c = cget();
        if (c == EOF)
          return nil;  // unterminated!
      } while (c != '\"');
    return UTF8STR(ap + 1, this->cp - ap - 2);
    }
  if (c == '\'')
    {
// apostrophed argument
    do {
      c = cget();
      if (c == EOF)
        return nil;  // unterminated!
    } while (c != '\'');
    return UTF8STR(ap + 1, this->cp - ap - 2);
    }
  if (!this->acceptHTML)
    ;  // strict XML requires quoting (?)
  while (!isspace(c) && c != '>' && c != '/' && c != '?' && c != '=' &&c != EOF)
    c = cget();
  this->cp--;  // go back to terminating character
  return UTF8STR(ap, this->cp - ap);
}

- (BOOL) parse
{
// read XML (or HTML) file
  const unsigned char *vp = this->cp;  // value pointer
  int c;

  if (!this->acceptHTML
    && (this->cend - this->cp < 6
      || strncmp((char *)this->cp, "<?xml ", 6) != 0))
    {
      // not a valid XML document start
      return [self _parseError: @"missing <?xml > preamble"];
    }
  c = cget();  // get first character
  while (!this->abort)
    {
// parse next element
#if 0
    NSLog(@"_nextelement %02x %c", c, isprint(c)?c: ' ');
#endif
    switch(c)
      {
      case '\r': 
        this->column = 0;
        break;
      case '\n': 
        this->line++;
        this->column = 0;
      case EOF: 
      case '<': 
      case '&': 
        {
// push out any characters that have been collected so far
        if (this->cp - vp > 1)
          {
          // check for whitespace only - might set/reset a flag to indicate so
          if ([_del respondsToSelector: @selector(parser: foundCharacters: )])
            [_del parser: self foundCharacters: UTF8STR(vp, this->cp - vp - 1)];
          vp = this->cp;
          }
        }
      }
    switch(c)
      {
      default: 
        c = cget();  // just collect until we push out (again)
        continue;
      case EOF:   // end of file
        {
          if ([this->tagPath count] != 0)
            {
            if (!this->acceptHTML)
              return [self _parseError: @"unexpected end of file"];  // strict XML nesting error
            while ([this->tagPath count] > 0)
              {
// lazily close all open tags
              if ([_del respondsToSelector: @selector(parser: didEndElement: namespaceURI: qualifiedName: )])
                [_del parser: self didEndElement: [this->tagPath lastObject] namespaceURI: nil qualifiedName: nil];
              [this->tagPath removeLastObject];  // pop from stack
              }
            }
#if 0
          NSLog(@"parserDidEndDocument: ");
#endif
          
          if ([_del respondsToSelector: @selector(parserDidEndDocument: )])
            [_del parserDidEndDocument: self];
          return YES;
        }
      case '&': 
        {
// escape entity begins
          NSString *entity=[self _entity];
          if (!entity)
            return [self _parseError: @"empty entity name"];
          if ([_del respondsToSelector: @selector(parser: foundCharacters: )])
            [_del parser: self foundCharacters: entity];
          vp = this->cp;  // next value sequence starts here
          c = cget();  // first character behind ;
          continue;
        }
      case '<': 
        {
// tag begins
          NSString *tag;
          NSMutableDictionary *parameters;
          NSString *arg;
          const unsigned char *tp = this->cp;  // tag pointer
          if (this->cp < this->cend-3 && strncmp((char *)this->cp, "!--", 3) == 0)
            {
// start of comment skip all characters until "-->"
            this->cp+=3;
            while (this->cp < this->cend-3 && strncmp((char *)this->cp, "-->", 3) != 0)
              this->cp++;  // search
            // if _del responds to parser: foundComment: 
            // convert to string (tp+4 ... cp)
            this->cp+=3;    // might go beyond cend but does not care
            vp = this->cp;    // value might continue
            c = cget();  // get first character behind comment
            continue;
            }
          c = cget(); // get first character of tag
          if (c == '/')
            c = cget(); // closing tag </tag begins
          else if (c == '?')
            {
// special tag <?tag begins
            c = cget();  // include in tag string
          //  NSLog(@"special tag <? found");
            // FIXME: this->should process this tag in a special way so that e.g. <?php any PHP script ?> is read as a single tag!
            // to do this properly, we need a notion of comments and quoted string constants...
            }
          while (!isspace(c) && c != '>' && (c != '/')  && (c != '?'))
            c = cget(); // scan tag until we find a delimiting character
          if (*tp == '/')
            tag = UTF8STR(tp + 1, this->cp - tp - 2);  // don't include / and delimiting character
          else
            tag = UTF8STR(tp, this->cp - tp - 1);  // don't include delimiting character
#if 0
          NSLog(@"tag=%@ - %02x %c", tag, c, isprint(c)?c: ' ');
#endif
          parameters=[NSMutableDictionary dictionaryWithCapacity: 5];
          while (c != EOF)
            {
// collect arguments
            if (c == '/' && *tp != '/')
              {
// appears to be a />
              c = cget();
              if (c != '>')
                return [self _parseError: @"<tag/ is missing the >"];
              [self _processTag: tag isEnd: NO withAttributes: parameters];  // opening tag
              [self _processTag: tag isEnd: YES withAttributes: nil];    // closing tag
              break; // done
              }
            if (c == '?' && *tp == '?')
              {
// appears to be a ?>
              c = cget();
              if (c != '>')
                return [self _parseError: @"<?tag ...? is missing the >"];
              // process
              [self _processTag: tag isEnd: NO withAttributes: parameters];  // single <?tag ...?>
              break; // done
              }
            while (isspace(c))  // this->should also allow for line break and tab
              c = cget();
            if (c == '>')
              {
              [self _processTag: tag isEnd: (*tp=='/') withAttributes: parameters];  // handle tag
              break;
              }
            arg=[self _qarg];  // get next argument (eats up to /, ?, >, =, space)
#if 0
            NSLog(@"arg=%@", arg);
#endif
            if (!this->acceptHTML && [arg length] == 0)
              return [self _parseError: @"empty attribute name"];
            c = cget();  // get delimiting character
            if (c == '=')
              {
// explicit assignment
              c = cget();  // skip =
              [parameters setObject: [self _qarg] forKey: arg];
              c = cget();  // get character behind qarg value
              }
            else  // implicit
              [parameters setObject: @"" forKey: arg];
            }
          vp = this->cp;    // prepare for next value
          c = cget();  // skip > and fetch next character
        }
      }
    }
  return [self _parseError: @"this->aborted"];  // this->aborted
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
  this->shouldProcessNamespaces = aFlag;
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

#endif

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

