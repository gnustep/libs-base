
/* This tool converts documentation in gsdoc format to another format
   At present (and for the forseeable future), the only format supported
   is HTML.

   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: February 2000

   This file is part of the GNUstep Project

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.
    
   You should have received a copy of the GNU General Public  
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

   */

#include <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "parser.h"


@interface	GSDocParser : NSObject
{
  NSString		*baseName;
  NSString		*currName;
  NSString		*fileName;
  NSString		*nextName;
  NSString		*prevName;
  NSString		*upName;
  NSMutableDictionary	*indexes;
  NSUserDefaults	*defs;
  NSFileManager		*mgr;
  xmlDocPtr		doc;
}
- (NSString*) getProp: (const char*)name fromNode: (xmlNodePtr)node;
- (NSMutableDictionary*) indexForType: (NSString*)type;
- (id) initWithFileName: (NSString*)name;
- (NSString*) parseText: (xmlNodePtr)node;
@end

static xmlParserInputPtr
loader(const char *url, const char* eid, xmlParserCtxtPtr *ctxt)
{
  extern xmlParserInputPtr xmlNewInputFromFile();
  xmlParserInputPtr	ret = 0;

  if (strncmp(eid, "-//GNUstep//DTD ", 16) == 0)
    {
      char	buf[BUFSIZ];
      char	*ptr;
      NSString	*name;
      NSString	*file;

      strcpy(buf, &eid[16]);
      for (ptr = buf; *ptr != '\0' && *ptr != '/'; ptr++)
	{
	  if (*ptr == '.')
	    {
	     *ptr = '_';
	    }
	  else if (isspace(*ptr))
	    {
	      *ptr = '-';
	    }
	}
      *ptr = '\0';
      name = [NSString stringWithCString: buf];
      file = [NSBundle pathForGNUstepResource: name
				       ofType: @"dtd"
				  inDirectory: @"DTDs"];
      if (file == nil)
	{
	  NSLog(@"unable to find GNUstep DTD - '%@' for '%s'", name, eid);
	}
      else
	{
	  ret = xmlNewInputFromFile(ctxt, [file cString]);
	}
    }
  else
    {
      NSLog(@"don't know how to load entity '%s' id '%s'", url, eid);
    }

  return ret;
}

@implementation	GSDocParser

- (void) dealloc
{
  if (doc != 0)
    {
      xmlFreeDoc(doc);
      doc = 0;
    }
  DESTROY(defs);
  DESTROY(indexes);
  DESTROY(baseName);
  DESTROY(nextName);
  DESTROY(prevName);
  DESTROY(upName);
  DESTROY(currName);
  DESTROY(fileName);
  [super dealloc];
}

- (NSString*) getProp: (const char*)name fromNode: (xmlNodePtr)node
{
  xmlAttrPtr	attr = node->properties;

  while (attr != 0 && strcmp(attr->name, name) != 0)
    {
      attr = attr->next;
    }
  if (attr == 0 || attr->val == 0)
    {
      return nil;
    }
  return [self parseText: attr->val];
}

- (NSMutableDictionary*) indexForType: (NSString*)type
{
  NSMutableDictionary	*dict = [indexes objectForKey: type];

  if (dict == nil)
    {
      dict = [NSMutableDictionary new];
      [indexes setObject: dict forKey: type];
      RELEASE(dict);
    }
  return dict;
}

- (id) initWithFileName: (NSString*)name
{
  xmlNodePtr	cur;
  extern int	xmlDoValidityCheckingDefaultValue;
  xmlExternalEntityLoader	ldr;
  NSString			*s;

  xmlDoValidityCheckingDefaultValue = 1;
  ldr = xmlGetExternalEntityLoader();
  if (ldr != (xmlExternalEntityLoader)loader)
    {
      xmlSetExternalEntityLoader((xmlExternalEntityLoader)loader);
    }

  fileName = [name copy];
  /*
   * Build an XML tree from the file.
   */
  doc = xmlParseFile([name cString]);
  if (doc == NULL)
    {
      NSLog(@"unparseable document - %@", fileName);
      [self dealloc];
      return nil;
    }
  /*
   * Check that the document is of the right kind
   */
  cur = doc->root;
  if (cur == NULL)
    {
      NSLog(@"empty document - %@", fileName);
      [self dealloc];
      return nil;
    }

  if (strcmp(cur->name, "gsdoc") != 0)
    {
      NSLog(@"document of the wrong type, root node != gsdoc");
      [self dealloc];
      return nil;
    }

  baseName = [self getProp: "base" fromNode: cur];
  if (baseName == nil)
    {
      baseName = @"gsdoc";
    }
  else
    {
      RETAIN(baseName);
    }
  nextName = RETAIN([self getProp: "next" fromNode: cur]);
  prevName = RETAIN([self getProp: "prev" fromNode: cur]);
  upName = RETAIN([self getProp: "up" fromNode: cur]);
  defs = RETAIN([NSUserDefaults standardUserDefaults]);
  s = [defs stringForKey: @"BaseName"];
  if (s != nil)
    {
      ASSIGN(baseName, s);
    }
  currName = [baseName copy];
  
  indexes = [NSMutableDictionary new];
  return self;
}

- (NSString*) parseText: (xmlNodePtr)node
{
  return nil;
}

@end



@interface	GSDocHtml : GSDocParser
{
  NSMutableDictionary	*refToFile;
  NSMutableArray	*contents;
  NSMutableArray	*footnotes;
  unsigned		labelIndex;
  unsigned		footnoteIndex;
  unsigned		contentsIndex;
}
- (NSString*) addLink: (NSString*)ref withText: (NSString*)text;
- (void) appendContents: (NSArray*)array toString: (NSMutableString*)text;
- (void) appendFootnotesToString: (NSMutableString*)text;
- (void) appendIndex: (NSString*)type toString: (NSMutableString*)text;
- (NSString*) parseAuthor: (xmlNodePtr)node;
- (NSString*) parseBlock: (xmlNodePtr)node;
- (NSString*) parseBody: (xmlNodePtr)node;
- (NSString*) parseChapter: (xmlNodePtr)node contents: (NSMutableArray*)array;
- (NSString*) parseDef: (xmlNodePtr)node;
- (NSString*) parseDesc: (xmlNodePtr)node;
- (NSString*) parseDocument;
- (NSString*) parseEmbed: (xmlNodePtr)node;
- (NSString*) parseExample: (xmlNodePtr)node;
- (NSString*) parseFunction: (xmlNodePtr)node;
- (NSString*) parseHead: (xmlNodePtr)node;
- (NSString*) parseItem: (xmlNodePtr)node;
- (NSString*) parseList: (xmlNodePtr)node;
- (NSString*) parseMacro: (xmlNodePtr)node;
- (NSString*) parseMethod: (xmlNodePtr)node;
- (NSString*) parseText: (xmlNodePtr)node;
- (void) setEntry: (NSString*)entry
	  withRef: (NSString*)ref
    inIndexOfType: (NSString*)type;
@end


@implementation	GSDocHtml

- (NSString*) addLink: (NSString*)ref withText: (NSString*)text
{
  NSString	*file = [refToFile objectForKey: ref];

  if (file == nil)
    {
      return [NSString stringWithFormat: @"<a href=\"#%@\">%@</a>", ref, text];
    }
  else
    {
      return [NSString stringWithFormat: @"<a href=\"%@#%@\">%@</a>",
	file, ref, text];
    }
}

- (void) appendContents: (NSArray*)array toString: (NSMutableString*)text
{
  unsigned	count = [array count];

  if (count > 0)
    {
      unsigned	i;

      [text appendString: @"<ul>\r\n"];
      for (i = 0; i < count; i++)
	{
	  NSDictionary	*dict = [array objectAtIndex: i];
	  NSString	*title = [dict objectForKey: @"Title"];
	  NSString	*ref = [dict objectForKey: @"Ref"];
	  NSArray	*sub = [dict objectForKey: @"Contents"];

	  [text appendFormat: @"<li>%@\r\n",
	    [self addLink: ref withText: title]];
	  [self appendContents: sub toString: text];
	}
      [text appendString: @"</ul>\r\n"];
    }
}

- (void) appendFootnotesToString: (NSMutableString*)text
{
  unsigned	count = [footnotes count];

  if (count > 0)
    {
      unsigned	i;

      [text appendString: @"<h2>Footnotes</h2>\r\n"];
      for (i = 0; i < count; i++)
	{
	  NSString	*note = [footnotes objectAtIndex: i];
	  NSString	*ref = [NSString stringWithFormat: @"foot-%u", i];


	  [text appendFormat: @"<a name=\"%@\">footnote %u</a> -\r\n", ref, i];
	  [text appendString: note];
	  [text appendString: @"<hr>\r\n"];
	}
    }
}

- (void) appendIndex: (NSString*)type toString: (NSMutableString*)text
{
  NSDictionary	*dict = [self indexForType: type];
  NSEnumerator	*enumerator;
  NSArray	*keys;
  NSString	*key;

  keys = [dict keysSortedByValueUsingSelector: @selector(compare:)];
  enumerator = [keys objectEnumerator];
  [text appendString: @"<ul>\r\n"];
  while ((key = [enumerator nextObject]) != nil)
    {
      NSString	*name = [dict objectForKey: key];

      [text appendFormat: @"<li>%@\r\n",
	[self addLink: key withText: name]];
    }
  [text appendString: @"</ul>\r\n"];
}

- (void) dealloc
{
  DESTROY(contents);
  DESTROY(footnotes);
  [super dealloc];
}

- (id) initWithFileName: (NSString*)name
{
  self = [super initWithFileName: name];
  if (self != nil)
    {
      mgr = RETAIN([NSFileManager defaultManager]);
      refToFile = [NSMutableDictionary new];
      contents = [NSMutableArray new];
      footnotes = [NSMutableArray new];
      if ([defs boolForKey: @"Monolithic"] == YES)
	{
	  ASSIGN(currName, [baseName stringByAppendingPathExtension: @"html"]);
	}
      else
	{
	  BOOL	flag = NO;

	  if ([mgr fileExistsAtPath: baseName isDirectory: &flag] == NO)
	    {
	      if ([mgr createDirectoryAtPath: baseName attributes: nil] == NO)
		{
		  NSLog(@"Unable to create directory '%@'", baseName);
		  RELEASE(self);
		  return nil;
		}
	    }
	  else if (flag == NO)
	    {
	      NSLog(@"The file '%@' is not a directory", baseName);
	      RELEASE(self);
	      return nil;
	    }
	  ASSIGN(currName,
	    [baseName stringByAppendingPathComponent: @"index.html"]);
	}    
    }
  return self;
}

- (NSString*) parseAuthor: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*name = [self getProp: "name" fromNode: node];
  NSString		*email = nil;
  NSString		*ename = nil;
  NSString		*url = nil;
  NSString		*desc = nil;

  if (name == nil)
    {
      NSLog(@"Missing or illegal author name");
      return nil;
    }
  node = node->childs;
  if (node != 0 && strcmp(node->name, "email") == 0)
    {
      email = [self getProp: "email" fromNode: node];
      ename = [self parseText: node->childs];
      node = node->next;
    }
  if (node != 0 && strcmp(node->name, "url") == 0)
    {
      url = [self getProp: "url" fromNode: node];
      node = node->next;
    }
  if (node != 0 && strcmp(node->name, "desc") == 0)
    {
      desc = [self parseDesc: node];
      node = node->next;
    }
  
  [text appendString: @"<dt>"];
  if (url == nil)
    {
      [text appendFormat: @"%@\r\n", name];
    }
  else
    {
      [text appendFormat: @"<a href=\"%@\">%@</a>\r\n", url, name];
    }
  if (email != nil)
    {
      if ([ename length] == 0)
	ename = email;
      [text appendFormat: @" (<a href=\"mailto:%@\"><code>%@</code></a>)\r\n",
	email, ename];
    }
  [text appendString: @"<dd>\r\n"];
  if (desc != nil)
    {
      [text appendString: desc];
    }
  return text;
}

- (NSString*) parseBlock: (xmlNodePtr)node
{
  if (node == 0)
    {
      NSLog(@"nul node when expecting block");
      return nil;
    }

  if (strcmp(node->name, "class") == 0
    || strcmp(node->name, "category") == 0
    || strcmp(node->name, "protocol") == 0
    || strcmp(node->name, "function") == 0
    || strcmp(node->name, "macro") == 0
    || strcmp(node->name, "type") == 0
    || strcmp(node->name, "variable") == 0)
    {
      return [self parseDef: node];
    }

  if (strcmp(node->name, "list") == 0
    || strcmp(node->name, "enum") == 0
    || strcmp(node->name, "deflist") == 0
    || strcmp(node->name, "qalist") == 0)
    {
      return [self parseList: node];
    }

  if (strcmp(node->name, "p") == 0)
    {
      NSString	*elem = [self parseText: node->childs];

      if (elem == nil)
	{
	  return nil;
	}
      return [NSString stringWithFormat: @"<p>\r\n%@</p>\r\n", elem];
    }

  if (strcmp(node->name, "example") == 0)
    {
      return [self parseExample: node];
    }

  if (strcmp(node->name, "embed") == 0)
    {
      return [self parseEmbed: node];
    }

  NSLog(@"unknown block type - %s", node->name);
  return nil;
}

- (NSString*) parseBody: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  CREATE_AUTORELEASE_POOL(arp);
  BOOL			needContents = NO;
  NSMutableArray	*back = [NSMutableArray arrayWithCapacity: 2];
  NSMutableArray	*body = [NSMutableArray arrayWithCapacity: 4];
  NSMutableArray	*front = [NSMutableArray arrayWithCapacity: 2];
  NSString		*chapter;
  unsigned		count;
  unsigned		i;

  node = node->childs;
  /*
   * Parse the front (unnumbered chapters) storing the html for each
   * chapter as a separate string in the 'front' array.
   */
  if (node != 0 && strcmp(node->name, "front") == 0)
    {
      xmlNodePtr	f = node->childs;

      if (f != 0 && strcmp(f->name, "contents") == 0)
	{
	  needContents = YES;
	  f = f->next;
	}
      while (f != 0 && strcmp(f->name, "chapter") == 0)
	{
	  chapter = [self parseChapter: f contents: contents];
	  if (chapter == nil)
	    {
	      return nil;
	    }
	  [front addObject: chapter];
	  f = f->next;
	}
      node = node->next;
    }

  /*
   * Parse the main body of the document, storing the html for each
   * chapter as a separate string in the 'body' array.
   */
  while (node != 0 && strcmp(node->name, "chapter") == 0)
    {
      chapter = [self parseChapter: node contents: contents];
      if (chapter == nil)
	{
	  return nil;
	}
      [body addObject: chapter];
      node = node->next;
    }

  /*
   * Parse the back unnumbered part of the document, storing the html for each
   * chapter as a separate string in the 'back' array.
   */
  if (node != 0 && strcmp(node->name, "back") == 0)
    {
      node = node->childs;

      while (node != 0 && strcmp(node->name, "chapter") == 0)
	{
	  chapter = [self parseChapter: node contents: contents];
	  if (chapter == nil)
	    {
	      return nil;
	    }
	  [back addObject: chapter];
	  node = node->next;
	}
    }

  /*
   * Ok - parsed all the chapters of the document, so we have stored the
   * document structure and can output a contents list.
   */
  if (needContents)
    {
      [text appendString: @"<h1>Contents</h1>\r\n"];
      [self appendContents: contents toString: text];
    }
  /*
   *  Now output all the chapters.
   */
  count = [front count];
  for (i = 0; i < count; i++)
    {
      chapter = [front objectAtIndex: i];
      [text appendString: chapter];
    }
  count = [body count];
  for (i = 0; i < count; i++)
    {
      chapter = [body objectAtIndex: i];
      [text appendString: chapter];
    }
  count = [back count];
  for (i = 0; i < count; i++)
    {
      chapter = [back objectAtIndex: i];
      [text appendString: chapter];
    }
  /*
   * Now output any indices requested.
   */
  while (node != 0 && strcmp(node->name, "index") == 0)
    {
      NSString	*type = [self getProp: "type" fromNode: node];

      if (type != nil)
	{
	  [text appendFormat: @"<h1>%@ index</h1>\r\n", type];
	  [self appendIndex: type toString: text];
	}
      node = node->next;
    }
  [self appendFootnotesToString: text];
  [text appendString: @"</body>\r\n"];
  RELEASE(arp);
  return text;
}

- (NSString*) parseChapter: (xmlNodePtr)node contents: (NSMutableArray*)array
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableString	*text = [NSMutableString string];
  const char		*type = node->name;
  const char		*next;
  const char		*h;
  NSString		*head;
  NSString		*ref;
  NSMutableDictionary	*dict;
  NSMutableArray	*subs;

  ref = [self getProp: "id" fromNode: node];
  if (ref == nil)
    {
      ref = [NSString stringWithFormat: @"cont-%u", contentsIndex++];
    }

  node = node->childs;
  if (node == 0 || strcmp(node->name, "heading") != 0)
    {
      NSLog(@"%s without heading", type);
      return nil;
    }
  head = [self parseText: node->childs];
  node = node->next;


  if (strcmp(type, "chapter") == 0)
    {
      next = "section";
      h = "h2";
    }
  else if (strcmp(type, "section") == 0)
    {
      next = "subsect";
      h = "h3";
    }
  else if (strcmp(type, "subsect") == 0)
    {
      next = "subsubsect";
      h = "h4";
    }
  else
    {
      next = "";
      h = "h5";
    }

  /*
   * Build content information and add it to the array at this level.
   */
  subs = [NSMutableArray new];
  dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
	head, @"Title",
	ref, @"Ref",
	subs, @"Contents", nil];
  RELEASE(subs);
  [array addObject: dict];

  /*
   * Put heading in string.
   */
  [text appendFormat: @"<%s><a name=\"%@\">%@</a></%s>\r\n", h, ref, head, h];

  /*
   * Try to parse block data up to the next subsection.
   */
  while (node != 0 && strcmp(node->name, next) != 0)
    {
      NSString	*block = [self parseBlock: node];

      if (block == nil)
	{
	  return nil;
	}
      [text appendString: block];
      node = node->next;
    }

  while (node != 0 && strcmp(node->name, next) == 0)
    {
      NSString	*chapter = [self parseChapter: node contents: subs];

      if (chapter == nil)
	{
	  return nil;
	}
      [text appendString: chapter];
      node = node->next;
    }
  [dict setObject: text forKey: @"Text"];
  RELEASE(arp);
  return text;
}

- (NSString*) parseDef: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];

  if (strcmp(node->name, "class") == 0)
    {
      NSString	*className = [self getProp: "name" fromNode: node];
      NSString	*superName = [self getProp: "super" fromNode: node];
      NSString	*ref = [self getProp: "id" fromNode: node];
      NSString	*declared = nil;
      NSString	*desc = nil;
      NSMutableArray	*conform = [NSMutableArray array];
      NSMutableArray	*methods = [NSMutableArray array];
      NSMutableArray	*standards = [NSMutableArray array];

      if (className == nil)
	{
	  NSLog(@"Missing class name");
	  return nil;
	}
      if (ref == nil)
	{
	  ref = className;
	}

      /*
       * Clear the methods index so it will contain only values from this class.
       */
      [[self indexForType: @"method"] removeAllObjects];

      node = node->childs;
      if (node != 0 && strcmp(node->name, "declared") == 0)
	{
	  declared = [self parseText: node->childs];
	  node = node->next;
	}
      while (node != 0 && strcmp(node->name, "conform") == 0)
	{
	  NSString	*s = [self parseText: node->childs];

	  if (s != nil)
	    {
	      [conform addObject: s];
	    }
	  node = node->next;
	}
      if (node != 0 && strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	  node = node->next;
	}
      while (node != 0 && strcmp(node->name, "method") == 0)
	{
	  NSString	*s = [self parseMethod: node];

	  if (s != nil)
	    {
	      [methods addObject: s];
	    }
	  node = node->next;
	}
      while (node != 0 && strcmp(node->name, "standard") == 0)
	{
	  NSString	*s = [self parseText: node->childs];

	  if (s != nil)
	    {
	      [standards addObject: s];
	    }
	  node = node->next;
	}

      [self setEntry: className withRef: ref inIndexOfType: @"class"];
      [text appendFormat: @"<h2><a name=\"%@\">%@</a></h2>\r\n",
	ref, className];
      if (declared != nil)
	{
	  [text appendFormat: @"<p><b>Declared in:</b> %@</p>\r\n", declared];
	}
      if (superName != nil)
	{
	  [text appendFormat: @"<p><b>Inherits from:</b> %@</p>\r\n",
	    superName];
	}
      if ([conform count] > 0)
	{
	  unsigned	i;

	  [text appendFormat: @"<p><b>Conforms to:</b> %@\r\n",
	    [conform objectAtIndex: 0]];
	  for (i = 1; i < [conform count]; i++)
	    {
	      [text appendFormat: @", %@\r\n", [conform objectAtIndex: i]];
	    }
	  [text appendString: @"</p>\r\n"];
	}
      if ([standards count] > 0)
	{
	  unsigned	i;

	  [text appendFormat: @"<p><b>Standards:</b> %@\r\n",
	    [standards objectAtIndex: 0]];
	  for (i = 1; i < [standards count]; i++)
	    {
	      [text appendFormat: @", %@\r\n", [standards objectAtIndex: i]];
	    }
	  [text appendString: @"</p>\r\n"];
	}

      if (desc != nil)
	{
	  [text appendFormat: @"<hr>\r\n%@\r\n", desc];
	}

      [self appendIndex: @"method" toString: text];

      if ([methods count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr>\r\n"];
	  for (i = 0; i < [methods count]; i++)
	    {
	      [text appendString: [methods objectAtIndex: i]];
	    }
	}
      return text;
    }
  else if (strcmp(node->name, "category") == 0)
    {
      NSString	*className = [self getProp: "class" fromNode: node];
      NSString	*catName = [self getProp: "name" fromNode: node];
      NSString	*ref = [self getProp: "id" fromNode: node];
      NSString	*declared = nil;
      NSString	*desc = nil;
      NSMutableArray	*methods = [NSMutableArray array];
      NSMutableArray	*standards = [NSMutableArray array];
      NSString	*name;

      if (className == nil || catName == nil)
	{
	  NSLog(@"Missing category or class name");
	  return nil;
	}
      name = [NSString stringWithFormat: @"%@ (%@)", catName, className];
      if (ref == nil)
	{
	  ref = name;
	}

      /*
       * Clear the methods index so it will contain only values from this class.
       */
      [[self indexForType: @"method"] removeAllObjects];

      node = node->childs;
      if (node != 0 && strcmp(node->name, "declared") == 0)
	{
	  declared = [self parseText: node->childs];
	  node = node->next;
	}
      if (node != 0 && strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	  node = node->next;
	}
      while (node != 0 && strcmp(node->name, "method") == 0)
	{
	  NSString	*s = [self parseMethod: node];

	  if (s != nil)
	    {
	      [methods addObject: s];
	    }
	  node = node->next;
	}
      while (node != 0 && strcmp(node->name, "standard") == 0)
	{
	  NSString	*s = [self parseText: node->childs];

	  if (s != nil)
	    {
	      [standards addObject: s];
	    }
	  node = node->next;
	}

      [self setEntry: name withRef: ref inIndexOfType: @"category"];
      [text appendFormat: @"<h2><a name=\"%@\">%@</a></h2>\r\n",
	ref, name];
      if (declared != nil)
	{
	  [text appendFormat: @"<p><b>Declared in:</b> %@</p>\r\n", declared];
	}
      if ([standards count] > 0)
	{
	  unsigned	i;

	  [text appendFormat: @"<p><b>Standards:</b> %@\r\n",
	    [standards objectAtIndex: 0]];
	  for (i = 1; i < [standards count]; i++)
	    {
	      [text appendFormat: @", %@\r\n", [standards objectAtIndex: i]];
	    }
	  [text appendString: @"</p>\r\n"];
	}

      if (desc != nil)
	{
	  [text appendFormat: @"<hr>\r\n%@\r\n", desc];
	}

      [self appendIndex: @"method" toString: text];

      if ([methods count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr>\r\n"];
	  for (i = 0; i < [methods count]; i++)
	    {
	      [text appendString: [methods objectAtIndex: i]];
	    }
	}
      return text;
    }
  else if (strcmp(node->name, "protocol") == 0)
    {
      NSString	*protName = [self getProp: "name" fromNode: node];
      NSString	*ref = [self getProp: "id" fromNode: node];
      NSString	*declared = nil;
      NSString	*desc = nil;
      NSMutableArray	*methods = [NSMutableArray array];
      NSMutableArray	*standards = [NSMutableArray array];

      if (protName == nil)
	{
	  NSLog(@"Missing protocol name");
	  return nil;
	}
      if (ref == nil)
	{
	  ref = protName;
	}

      /*
       * Clear the methods index so it will contain only values from this class.
       */
      [[self indexForType: @"method"] removeAllObjects];

      node = node->childs;
      if (node != 0 && strcmp(node->name, "declared") == 0)
	{
	  declared = [self parseText: node->childs];
	  node = node->next;
	}
      if (node != 0 && strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	  node = node->next;
	}
      while (node != 0 && strcmp(node->name, "method") == 0)
	{
	  NSString	*s = [self parseMethod: node];

	  if (s != nil)
	    {
	      [methods addObject: s];
	    }
	  node = node->next;
	}
      while (node != 0 && strcmp(node->name, "standard") == 0)
	{
	  NSString	*s = [self parseText: node->childs];

	  if (s != nil)
	    {
	      [standards addObject: s];
	    }
	  node = node->next;
	}

      [self setEntry: protName withRef: ref inIndexOfType: @"protocol"];
      [text appendFormat: @"<h2><a name=\"%@\">%@</a></h2>\r\n",
	ref, protName];
      if (declared != nil)
	{
	  [text appendFormat: @"<p><b>Declared in:</b> %@</p>\r\n", declared];
	}
      if ([standards count] > 0)
	{
	  unsigned	i;

	  [text appendFormat: @"<p><b>Standards:</b> %@\r\n",
	    [standards objectAtIndex: 0]];
	  for (i = 1; i < [standards count]; i++)
	    {
	      [text appendFormat: @", %@\r\n", [standards objectAtIndex: i]];
	    }
	  [text appendString: @"</p>\r\n"];
	}

      if (desc != nil)
	{
	  [text appendFormat: @"<hr>\r\n%@\r\n", desc];
	}

      [self appendIndex: @"method" toString: text];

      if ([methods count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr>\r\n"];
	  for (i = 0; i < [methods count]; i++)
	    {
	      [text appendString: [methods objectAtIndex: i]];
	    }
	}
      return text;
    }
  else if (strcmp(node->name, "function") == 0)
    {
      return [self parseFunction: node];
    }
  else if (strcmp(node->name, "macro") == 0)
    {
      return [self parseMacro: node];
    }
  else if (strcmp(node->name, "type") == 0)
    {
      NSString	*typeName = [self getProp: "name" fromNode: node];
      NSString	*ref = [self getProp: "id" fromNode: node];
      NSString	*declared = nil;
      NSString	*desc = nil;
      NSString	*spec = nil;
      NSMutableArray	*standards = [NSMutableArray array];

      if (typeName == nil)
	{
	  NSLog(@"Missing type name");
	  return nil;
	}
      if (ref == nil)
	{
	  ref = typeName;
	}
      node = node->childs;
      if (node != 0 && strcmp(node->name, "typespec") == 0)
	{
	  spec = [self parseText: node->childs];
	  node = node->next;
	}
      if (spec == nil)
	{
	  NSLog(@"Missing type specification");
	  return nil;
	}

      if (node != 0 && strcmp(node->name, "declared") == 0)
	{
	  declared = [self parseText: node->childs];
	  node = node->next;
	}
      if (node != 0 && strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	  node = node->next;
	}
      while (node != 0 && strcmp(node->name, "standard") == 0)
	{
	  NSString	*s = [self parseText: node->childs];

	  if (s != nil)
	    {
	      [standards addObject: s];
	    }
	  node = node->next;
	}

      [self setEntry: typeName withRef: ref inIndexOfType: @"type"];
      [text appendFormat: @"<h2><a name=\"%@\">%@</a></h2>\r\n",
	ref, typeName];
      if (declared != nil)
	{
	  [text appendFormat: @"<p><b>Declared in:</b> %@</p>\r\n", declared];
	}
      if ([standards count] > 0)
	{
	  unsigned	i;

	  [text appendFormat: @"<p><b>Standards:</b> %@\r\n",
	    [standards objectAtIndex: 0]];
	  for (i = 1; i < [standards count]; i++)
	    {
	      [text appendFormat: @", %@\r\n", [standards objectAtIndex: i]];
	    }
	  [text appendString: @"</p>\r\n"];
	}

      [text appendFormat: @"<b>typedef</b> %@ %@<br>\r\n", spec, typeName];

      if (desc != nil)
	{
	  [text appendFormat: @"<hr>\r\n%@\r\n", desc];
	}

      return text;
    }
  else if (strcmp(node->name, "variable") == 0)
    {
      NSString	*name = [self getProp: "name" fromNode: node];
      NSString	*type = [self getProp: "type" fromNode: node];
      NSString	*value = [self getProp: "value" fromNode: node];
      NSString	*role = [self getProp: "role" fromNode: node];
      NSString	*ref = [self getProp: "id" fromNode: node];
      NSString	*declared = nil;
      NSString	*desc = nil;
      NSMutableArray	*standards = [NSMutableArray array];

      if (name == nil || type == nil)
	{
	  NSLog(@"Missing variable type or name");
	  return nil;
	}
      if (ref == nil)
	{
	  ref = name;
	}
      node = node->childs;
      if (node != 0 && strcmp(node->name, "declared") == 0)
	{
	  declared = [self parseText: node->childs];
	  node = node->next;
	}
      if (node != 0 && strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	  node = node->next;
	}
      while (node != 0 && strcmp(node->name, "standard") == 0)
	{
	  NSString	*s = [self parseText: node->childs];

	  if (s != nil)
	    {
	      [standards addObject: s];
	    }
	  node = node->next;
	}

      [self setEntry: name withRef: ref inIndexOfType: @"variable"];
      [text appendFormat: @"<h2><a name=\"%@\">%@</a></h2>\r\n", ref, name];
      if (declared != nil)
	{
	  [text appendFormat: @"<p><b>Declared in:</b> %@</p>\r\n", declared];
	}
      if ([standards count] > 0)
	{
	  unsigned	i;

	  [text appendFormat: @"<p><b>Standards:</b> %@\r\n",
	    [standards objectAtIndex: 0]];
	  for (i = 1; i < [standards count]; i++)
	    {
	      [text appendFormat: @", %@\r\n", [standards objectAtIndex: i]];
	    }
	  [text appendString: @"</p>\r\n"];
	}

      if ([role isEqual: @"except"])
	{
	  [text appendString: @"<p>Exception name</p>\r\n"];
	}
      else if ([role isEqual: @"defaults"])
	{
	  [text appendString: @"<p>Defaults system key</p>\r\n"];
	}
      else if ([role isEqual: @"notify"])
	{
	  [text appendString: @"<p>Notification name</p>\r\n"];
	}
      else if ([role isEqual: @"key"])
	{
	  [text appendString: @"<p>Dictionary key</p>\r\n"];
	}

      if (value == nil)
	{
	  [text appendFormat: @"%@ <b>%@</b><br>\r\n", type, name];
	}
      else
	{
	  [text appendFormat: @"%@ <b>%@</b> = %@<br>\r\n", type, name, value];
	}

      if (desc != nil)
	{
	  [text appendFormat: @"<hr>\r\n%@\r\n", desc];
	}

      return text;
    }
  else
    {
      NSLog(@"Definition of unknown type - %s", node->name);
      return nil;
    }
}

- (NSString*) parseDesc: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];

  node = node->childs;
  if (node == 0)
    {
      return @"";
    }
  while (node != 0)
    {
      if (strcmp(node->name, "list") == 0
	|| strcmp(node->name, "enum") == 0
	|| strcmp(node->name, "deflist") == 0
	|| strcmp(node->name, "qalist") == 0)
	{
	  [text appendString: [self parseList: node]];
	}
      else if (strcmp(node->name, "p") == 0)
	{
	  NSString	*elem = [self parseText: node->childs];

	  if (elem != nil)
	    {
	      [text appendFormat:  @"<p>\r\n%@</p>\r\n", elem];
	    }
	}
      else if (strcmp(node->name, "example") == 0)
	{
	  [text appendString: [self parseExample: node]];
	}
      else if (strcmp(node->name, "embed") == 0)
	{
	  [text appendString: [self parseEmbed: node]];
	}
      else
	{
	  [text appendString: [self parseText: node]];
	}

      node = node->next;
    }
  return text;
}

- (NSString*) parseDocument
{
  xmlNodePtr	cur = doc->root->childs;
  NSString	*text;
  NSString	*body;
  NSString	*head;

  if (cur == 0 || strcmp(cur->name, "head") != 0)
    {
      NSLog(@"head missing from document");
      return nil;
    }
  if ((head = [self parseHead: cur]) == nil)
    {
      return nil;
    }
  cur = cur->next;
  if (cur == 0 || strcmp(cur->name, "body") != 0)
    {
      NSLog(@"body missing from document");
      return nil;
    }
  if ((body = [self parseBody: cur]) == nil)
    {
      return nil;
    }

  text = [NSString stringWithFormat: @"<html>%@%@\r\n</html>\r\n", head, body];

  if ([defs boolForKey: @"Monolithic"] == YES)
    {
      [text writeToFile: currName atomically: YES];
    }
  return text;
}

- (NSString*) parseEmbed: (xmlNodePtr)node
{
  return @"An Embed";
}

- (NSString*) parseExample: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*elem = [self parseText: node->childs];
  NSString		*ref = [self getProp: "id" fromNode: node];
  NSString		*cap = [self getProp: "caption" fromNode: node];

  if (ref == nil)
    {
      ref = [NSString stringWithFormat: @"label-%u", labelIndex++];
    }
  if (elem == nil)
    {
      return nil;
    }
  if (cap == nil)
    {
      [self setEntry: @"example" withRef: ref inIndexOfType: @"label"];
      [text appendFormat: @"<a name=\"%@\">example</a>\r\n", ref];
    }
  else
    {
      [self setEntry: cap withRef: ref inIndexOfType: @"label"];
      [text appendFormat: @"<a name=\"%@\">%@</a>\r\n", ref, cap];
    }
  [text appendFormat: @"<pre>\r\n%@\r\n</pre>\r\n", elem];
  return text;
}

- (NSString*) parseFunction: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString	*ref = [self getProp: "id" fromNode: node];
  NSString	*type = [self getProp: "type" fromNode: node];
  NSString	*name = [self getProp: "name" fromNode: node];
  NSString	*desc = nil;
  NSString	*declared = nil;
  NSMutableString	*args = [NSMutableString stringWithString: @"("];

  if (ref == nil)
    {
      ref = [NSString stringWithFormat: @"function-%u", labelIndex++];
    }
  if (type == nil)
    {
      type = @"int";
    }

  node = node->childs;
  while (node != 0 && strcmp(node->name, "arg") == 0)
    {
      NSString	*arg = [self parseText: node->childs];
      NSString	*typ = [self getProp: "type" fromNode: node];

      if (arg == nil) return nil;
      if ([args length] > 1)
	{
	  [args appendString: @", "];
	}
      if (typ != nil)
	{
	  [args appendString: typ];
	  [args appendString: @" "];
	}
      [args appendString: arg];
      node = node->next;
    }
  if (node != 0 && strcmp(node->name, "vararg") == 0)
    {
      if ([args length] > 1)
	{
	  [args appendString: @", ..."];
	}
      else
	{
	  [args appendString: @"..."];
	}
      node = node->next;
    }
  [args appendString: @")"];
  if (node != 0 && strcmp(node->name, "declared") == 0)
    {
      declared = [self parseText: node->childs];
      node = node->next;
    }
  if (node != 0)
    {
      if (strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	}
      else
	{
	  NSLog(@"Unexpected node in function definition - %s", node->name);
	  return nil;
	}
    }
  [self setEntry: name withRef: ref inIndexOfType: @"function"];
  [text appendFormat: @"<h2><a name=\"%@\">%@</a></h2>\r\n", ref, name];
  if (declared != nil)
    {
      [text appendFormat: @"<p><b>Declared in:</b> %@</p>\r\n", declared];
    }
  [text appendFormat: @"<b>Prototype:</b> %@ %@%@<br>\r\n", type, name, args];

  if (desc != nil)
    {
      [text appendString: desc];
    }
  [text appendString: @"\r\n<hr>\r\n"];

  return text;
}

- (NSString*) parseHead: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*abstract;
  NSString		*title;
  NSString		*copyright;
  NSString		*date;
  NSString		*version;
  BOOL			hadAuthor = NO;

  node = node->childs;

  if (node == 0 || strcmp(node->name, "title") != 0
    || (title = [self parseText: node->childs]) == nil)
    {
      NSLog(@"head without title");
      return nil;
    }
  [text appendFormat: @"<head>\r\n<title>%@</title>\r\n", title];

  [text appendString: @"</head>\r\n"];
  [text appendString: @"<body>\r\n"];
  if (prevName != nil)
    [text appendFormat: @"<a href=\"%@\">[Previous]</a>\n", prevName];
  if (upName != nil)
    [text appendFormat: @"<a href=\"%@\">[Up]</a>\n", upName];
  if (nextName != nil)
    [text appendFormat: @"<a href=\"%@\">[Next]</a>\n", nextName];

  [text appendFormat: @"<h1>%@</h1>\r\n", title];

  node = node->next;
  while (node != 0 && strcmp(node->name, "author") == 0)
    {
      NSString	*author = [self parseAuthor: node];

      if (author == nil)
	{
	  return nil;
	}
      if (hadAuthor == NO)
	{
	  hadAuthor = YES;
	  [text appendString: @"<h3>Authors</h3>\r\n<dl>\r\n"];
	}
      [text appendString: author];
      node = node->next;
    }
  if (hadAuthor == YES)
    {
      [text appendString: @"</dl>\r\n"];
    }

  if (node != 0 && strcmp(node->name, "version") == 0)
    {
      version = [self parseText: node->childs];
      node = node->next;
      [text appendFormat: @"<p>Version: %@</p>\r\n", version];
    }

  if (node != 0 && strcmp(node->name, "date") == 0)
    {
      date = [self parseText: node->childs];
      node = node->next;
      [text appendFormat: @"<p>Date: %@</p>\r\n", date];
    }

  if (node != 0 && strcmp(node->name, "abstract") == 0)
    {
      abstract = [self parseText: node->childs];
      node = node->next;
      [text appendFormat: @"<blockquote>%@</blockquote>\r\n", abstract];
    }

  if (node != 0 && strcmp(node->name, "copy") == 0)
    {
      copyright = [self parseText: node->childs];
      node = node->next;
      [text appendFormat: @"<p>Copyright: %@</p>\r\n", copyright];
    }

  return text;
}

- (NSString*) parseItem: (xmlNodePtr)node
{
  node = node->childs;

  if (strcmp(node->name, "class") == 0
    || strcmp(node->name, "category") == 0
    || strcmp(node->name, "protocol") == 0
    || strcmp(node->name, "function") == 0
    || strcmp(node->name, "macro") == 0
    || strcmp(node->name, "type") == 0
    || strcmp(node->name, "variable") == 0)
    {
      return [self parseDef: node];
    }

  if (strcmp(node->name, "list") == 0
    || strcmp(node->name, "enum") == 0
    || strcmp(node->name, "deflist") == 0
    || strcmp(node->name, "qalist") == 0)
    {
      return [self parseList: node];
    }

  if (strcmp(node->name, "p") == 0)
    {
      NSString	*elem = [self parseText: node->childs];

      if (elem == nil)
	{
	  return nil;
	}
      return [NSString stringWithFormat: @"<p>\r\n%@</p>\r\n", elem];
    }

  if (strcmp(node->name, "example") == 0)
    {
      return [self parseExample: node];
    }

  if (strcmp(node->name, "embed") == 0)
    {
      return [self parseEmbed: node];
    }

  return [self parseText: node];
}

- (NSString*) parseList: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];

  if (strcmp(node->name, "list") == 0)
    {
      [text appendString: @"<ul>\r\n"];
      node = node->childs;
      while (node != 0 && strcmp(node->name, "item") == 0)
	{
	  [text appendFormat: @"<li>%@\r\n", [self parseItem: node]];
	  node = node->next;
	}
      [text appendString: @"</ul>\r\n"];
    }
  else if (strcmp(node->name, "enum") == 0)
    {
      [text appendString: @"<ol>\r\n"];
      node = node->childs;
      while (node != 0 && strcmp(node->name, "item") == 0)
	{
	  [text appendFormat: @"<li>%@\r\n", [self parseItem: node]];
	  node = node->next;
	}
      [text appendString: @"</ol>\r\n"];
    }
  else if (strcmp(node->name, "deflist") == 0)
    {
      [text appendString: @"<dl>\r\n"];
      node = node->childs;
      while (node != 0)
	{
	  if (strcmp(node->name, "term") == 0)
	    {
	      [text appendFormat: @"<dt>%@\r\n",
		[self parseText: node->childs]];
	      node = node->next;
	    }
	  if (node == 0 || strcmp(node->name, "desc") != 0)
	    {
	      NSLog(@"term without desc");
	      return nil;
	    }
	  [text appendFormat: @"<dd>%@\r\n", [self parseDesc: node]];
	  node = node->next;
	}
      [text appendString: @"</dl>\r\n"];
    }
  else
    {
      [text appendString: @"<dl>\r\n"];
      node = node->childs;
      while (node != 0)
	{
	  if (strcmp(node->name, "question") == 0)
	    {
	      [text appendFormat: @"<dt>%@\r\n",
		[self parseText: node->childs]];
	      node = node->next;
	    }
	  if (node == 0 || strcmp(node->name, "answer") != 0)
	    {
	      NSLog(@"term without desc");
	      return nil;
	    }
	  [text appendFormat: @"<dt>%@\r\n", [self parseBlock: node->childs]];
	  node = node->next;
	}
      [text appendString: @"</dl>\r\n"];
    }
  return text;
}

- (NSString*) parseMacro: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString	*ref = [self getProp: "id" fromNode: node];
  NSString	*name = [self getProp: "name" fromNode: node];
  NSString	*desc = nil;
  NSString	*declared = nil;
  NSMutableString	*args = [NSMutableString stringWithString: @"("];

  if (ref == nil)
    {
      ref = [NSString stringWithFormat: @"macro-%u", labelIndex++];
    }

  node = node->childs;
  while (node != 0 && strcmp(node->name, "arg") == 0)
    {
      NSString	*arg = [self parseText: node->childs];
      NSString	*typ = [self getProp: "type" fromNode: node];

      if (arg == nil) return nil;
      if ([args length] > 1)
	{
	  [args appendString: @", "];
	}
      if (typ != nil)
	{
	  [args appendString: typ];
	  [args appendString: @" "];
	}
      [args appendString: arg];
      node = node->next;
    }
  if (node != 0 && strcmp(node->name, "vararg") == 0)
    {
      if ([args length] > 1)
	{
	  [args appendString: @", ..."];
	}
      else
	{
	  [args appendString: @"..."];
	}
      node = node->next;
    }
  if ([args length] == 1)
    {
      args = nil;
    }
  else
    {
      [args appendString: @")"];
    }
  if (node != 0 && strcmp(node->name, "declared") == 0)
    {
      declared = [self parseText: node->childs];
      node = node->next;
    }
  if (node != 0)
    {
      if (strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	}
      else
	{
	  NSLog(@"Unexpected node in function definition - %s", node->name);
	  return nil;
	}
    }
  [self setEntry: name withRef: ref inIndexOfType: @"macro"];
  [text appendFormat: @"<h2><a name=\"%@\">%@</a></h2>\r\n", ref, name];
  if (declared != nil)
    {
      [text appendFormat: @"<p><b>Declared in:</b> %@</p>\r\n", declared];
    }
  if (args == nil)
    {
      [text appendFormat: @"<b>Declaration:</b> %@<br>\r\n", name];
    }
  else
    {
      [text appendFormat: @"<b>Declaration:</b> %@%@<br>\r\n", name, args];
    }

  if (desc != nil)
    {
      [text appendString: desc];
    }
  [text appendString: @"\r\n<hr>\r\n"];

  return text;
}

- (NSString*) parseMethod: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString	*ref = [self getProp: "id" fromNode: node];
  NSString	*type = [self getProp: "type" fromNode: node];
  NSString	*over = [self getProp: "override" fromNode: node];
//  NSString	*role = [self getProp: "role" fromNode: node];
  BOOL		factory = [[self getProp: "factory" fromNode: node] boolValue];
  BOOL		desInit = [[self getProp: "init" fromNode: node] boolValue];
  NSMutableString	*lText = [NSMutableString string];
  NSMutableString	*sText = [NSMutableString string];
  NSString	*desc = nil;

  if (ref == nil)
    {
      ref = [NSString stringWithFormat: @"method-%u",
	labelIndex++];
    }
  if (factory)
    {
      [lText appendString: @"+ ("];
    }
  else
    {
      [lText appendString: @"- ("];
    }
  if (type == nil)
    type = @"id";
  [lText appendString: type];
  [lText appendString: @")"];

  node = node->childs;
  while (node != 0 && strcmp(node->name, "sel") == 0)
    {
      NSString	*sel = [self parseText: node->childs];

      if (sel == nil) return nil;
      [sText appendString: sel];
      [lText appendFormat: @" <b>%@</b>", sel];
      node = node->next;
      if (node != 0 && strcmp(node->name, "arg") == 0)
	{
	  NSString	*arg = [self parseText: node->childs];
	  NSString	*typ = [self getProp: "type" fromNode: node];

	  if (arg == nil) return nil;
	  if (typ != nil)
	    {
	      [lText appendFormat: @" (%@)%@", typ, arg];
	    }
	  else
	    {
	      [lText appendString: @" "];
	      [lText appendString: arg];
	    }
	  node = node->next;
	  if (node != 0 && strcmp(node->name, "vararg") == 0)
	    {
	      [lText appendString: @", ..."];
	      node = node->next;
	      break;
	    }
	}
      else
	{
	  break;	/* Just a selector	*/
	}
    }
  if (node != 0)
    {
      if (strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	}
      else
	{
	  NSLog(@"Unexpected node in method definition - %s", node->name);
	  return nil;
	}
    }
  if (factory)
    {
      NSString	*s = [@"+" stringByAppendingString: sText];
      [self setEntry: s withRef: ref inIndexOfType: @"method"];
    }
  else
    {
      NSString	*s = [@"-" stringByAppendingString: sText];
      [self setEntry: s withRef: ref inIndexOfType: @"method"];
    }
  [text appendFormat: @"<h2><a name=\"%@\">%@</a></h2>\r\n", ref, sText];
  if (desInit)
    {
      [text appendString: @"<b>This is the designated initialiser</b><br>\r\n"];
    }
  [text appendFormat: @"%@<br>\r\n", lText];
  if ([over isEqual: @"subclass"])
    {
      [text appendString: @"Your subclass <em>must</em> override this "
	@"abstract method.<br>\r\n"];
    }
  else if ([over isEqual: @"never"])
    {
      [text appendString: @"Your subclass must <em>not</em> override this "
	@"method.<br>\r\n"];
    }

  if (desc != nil)
    {
      [text appendString: desc];
    }
  [text appendString: @"\r\n<hr>\r\n"];

  return text;
}

- (NSString*) parseText: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];

  while (node != 0)
    {
      switch (node->type)
	{
	  case XML_TEXT_NODE:
	    [text appendFormat: @"%s", node->content];
	    break;

	  case XML_ENTITY_REF_NODE:
	    [text appendFormat: @"%s", node->content];
	    break;

	  case XML_ELEMENT_NODE:
	    if (strcmp(node->name, "code") == 0
	      || strcmp(node->name, "em") == 0
	      || strcmp(node->name, "file") == 0
	      || strcmp(node->name, "site") == 0
	      || strcmp(node->name, "strong") == 0
	      || strcmp(node->name, "var") == 0)
	      {
		NSString	*elem = [self parseText: node->childs];

		[text appendFormat: @"<%s>%@</%s>",
		  node->name, elem, node->name];
	      }
	    else if (strcmp(node->name, "entry") == 0
	      || strcmp(node->name, "label") == 0)
	      {
		NSString		*elem;
		NSString		*ref;

		elem = [self parseText: node->childs];
		ref = [self getProp: "id" fromNode: node];
		if (ref == nil)
		  {
		    ref = [NSString stringWithFormat: @"label-%u",
		      labelIndex++];
		  }
		[self setEntry: elem withRef: ref inIndexOfType: @"label"];
		if (strcmp(node->name, "label") == 0)
		  {
		    [text appendFormat: @"<a name=\"%@\">%@</a>", ref, elem];
		  }
		else
		  {
		    [text appendFormat: @"<a name=\"%@\"></a>", ref];
		  }
	      }
	    else if (strcmp(node->name, "footnote") == 0)
	      {
		NSString		*elem;
		NSString		*ref;

		elem = [self parseText: node->childs];
		ref = [NSString stringWithFormat: @"foot-%u",
		  [footnotes count]];
		[self setEntry: elem withRef: ref inIndexOfType: @"footnote"];
		[footnotes addObject: elem];
		[text appendFormat: @" %@ ",
		  [self addLink: ref withText: @"see footnote"]];
	      }
	    else if (strcmp(node->name, "ref") == 0)
	      {
		NSString	*elem = [self parseText: node->childs];
//		NSString	*typ = [self getProp: "type" fromNode: node];
//		NSString	*cls = [self getProp: "class" fromNode: node];
		NSString	*ref = [self getProp: "id" fromNode: node];

		if ([elem length] == 0)
		  {
		    elem = ref;
		  }
		[text appendString: [self addLink: ref withText: elem]];
	      }
	    else if (strcmp(node->name, "uref") == 0)
	      {
		NSString	*elem = [self parseText: node->childs];
		NSString	*ref = [self getProp: "url" fromNode: node];

		if ([elem length] == 0)
		  elem = ref;
		[text appendFormat: @"<a href=\"%@\">%@</a>", ref, elem];
	      }
	    break;

	  default:
	    NSLog(@"Unexpected node type in text node - %d", node->type);
	    return nil; 
	}
      node = node->next;
    }
  return text;
}

- (void) setEntry: (NSString*)entry
	  withRef: (NSString*)ref
    inIndexOfType: (NSString*)type
{
  NSMutableDictionary	*index = [self indexForType: type];

  [index setObject: entry forKey: ref];
  [refToFile setObject: currName forKey: ref];
}

@end


int
main(int argc, char **argv)
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  NSProcessInfo		*proc;
  NSArray		*args;
  unsigned		i;
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];

  [defs registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
    @"Yes", @"Monolithic",
    nil]];

  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      NSLog(@"unable to get process information!");
      [pool release];
      exit(0);
    }

  args = [proc arguments];

  if ([args count] <= 1)
    {
      NSLog(@"No file names given to parse.");
    }
  else
    {
      for (i = 1; i < [args count]; i++)
	{
	  NSString	*file = [args objectAtIndex: i];

	  NS_DURING
	    {
	      GSDocHtml	*p;

	      p = [GSDocHtml alloc];
	      p = [p initWithFileName: file];
	      if (p != nil)
		{
		  NSString	*result = [p parseDocument];

		  if (result == nil)
		    NSLog(@"Error parsing %@", file);
		  else
		    NSLog(@"Parsed %@ - OK", file);
		  RELEASE(p);
		}
	    }
	  NS_HANDLER
	    {
	      NSLog(@"Parsing '%@' - %@", file, [localException reason]);
	    }
	  NS_ENDHANDLER
	}
    }
  [pool release];
  return 0;
}

