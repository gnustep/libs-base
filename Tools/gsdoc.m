
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

/*
 Before doing anything else - you need to install the Gnome xml parser library!

 I build gsdoc using the 2.0.0 release of the parser.

 You can find out how to get this from http://www.xmlsoft.org

 Once you have installed the xml parser library, you can build gsdoc
 and install it.

 Run gsdoc giving it the name of a gsdoc file as an argument, and it will
 produce an html output file.

 This is an alpha release of the software - please send fixes and improvements
 to rfm@gnu.org

 Volunteers to write gsdoc->info or gsdoc->TeX or any other translators are
 very welcome.
 */

/*
Parameters:
	--makeRefs=ReferencesFileName
			With this option, gsdoc reads gsdoc files and create ReferencesFileName.gsdocrefs files which can be used as --refs to make links between elements

	--projectName=TheProjectName
			Set the project name to "TheProjectName"
			It is used fo index titles,...

	--refs=ARefFile (or --refs=ARefDirectory)
			Use ARefFile.gsdocrefs (or files whith extensions .gsdocrefs in ARefDirectory directory) as references files.
			It's enable to make links bettwen documentations

	--makeIndex=MyIndexFileName
			Create an index of the parsed files and save it as MyIndexName.gsdoc
			You have to set --makeIndexTemplate option

    --makeIndexTemplate=MyIndexTemplateFileName
			The file used as index template for makeIndex option

	--define-XXX=YYY
			Used to define a constant named XXX with value YYY
			in .gsdoc file, all [[infoDictionary.XXX]] texts are replaced with YYY

	 --verbose=X
	 		Level of traces from 0 to ...

	 --location=file://usr/doc/gnustep/MyProject (or --location=http://www.gnustep.org/gnustep/MyProject)
	 		Location of the installed documentation (it helps to make kinks between projects)

	 file1 file2
	 		.gsdoc files
*/

#include <Foundation/Foundation.h>

#if	HAVE_LIBXML

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <libxml/parser.h>

NSString* PathExtension_GSDocRefs=@"gsdocrefs";
NSString* PathExtension_GSDoc=@"gsdoc";
int verbose=0;
NSString* location=nil;

//--------------------------------------------------------------------
// In text, replace keys from variables with their values
// variables is like something like this
// {
//		"[[key1]]" = "value1";
//		"[[key2]]" = "value2";
// };
NSString* TextByReplacingVariablesInText(NSString* text,NSDictionary* variables)
{  
  NSEnumerator* variablesEnum = [variables keyEnumerator];
  id key=nil; 
  while ((key = [variablesEnum nextObject]))
	{
	  id value=[variables objectForKey:key];
	  text=[text stringByReplacingString:key
				 withString:[value description]];
	};
  return text;
};

// ====================================================================
// GSDocParser
@interface	GSDocParser : NSObject
{
  NSString		*baseName;
  NSString		*currName;
  NSString		*fileName;
  NSString		*nextName;	//"Next" Link filename
  NSString		*prevName;	//"Previous" Link filename
  NSString		*upName;	//"Up" Link filename
  NSString		*styleSheetURL;	// Style sheet
  NSMutableDictionary	*indexes;
  NSUserDefaults	*defs;
  NSFileManager		*mgr;
  xmlDocPtr		doc;
}
- (NSString*) getProp: (const char*)name fromNode: (xmlNodePtr)node;
- (NSMutableDictionary*) indexForType: (NSString*)type;
- (id) initWithFileName: (NSString*)name;
- (NSString*) parseText: (xmlNodePtr)node;
- (NSString*) parseText: (xmlNodePtr)node end: (xmlNodePtr*)endNode;
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

// ====================================================================
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
  DESTROY(styleSheetURL);
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
  if (attr == 0 || attr->children == 0)
    {
      return nil;
    }
  return [self parseText: attr->children];
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
  if ((self=[self init]))
	{
	  xmlNodePtr	cur;
	  extern int	xmlDoValidityCheckingDefaultValue;
	  xmlExternalEntityLoader	ldr;
	  NSString			*s;
	  NSFileManager			*m;

	  xmlDoValidityCheckingDefaultValue = 1;
	  ldr = xmlGetExternalEntityLoader();
	  if (ldr != (xmlExternalEntityLoader)loader)
		{
		  xmlSetExternalEntityLoader((xmlExternalEntityLoader)loader);
		}

	  /*
   * Ensure we have a valid file name.
   */
	  s = [name pathExtension];
	  m = [NSFileManager defaultManager];
	  if ([m fileExistsAtPath: name] == NO && [s length] == 0)
		{
		  s = [name stringByAppendingPathExtension:PathExtension_GSDoc];
		  if ([m fileExistsAtPath: s] == NO)
			{
			  NSLog(@"No such document - %@", name);
			  [self dealloc];
			  return nil;
			}
		  name = s;
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
	  cur = doc->children;
	  if (cur == NULL)
		{
		  NSLog(@"empty document - %@", fileName);
		  [self dealloc];
		  return nil;
		}
	  cur = cur->next;

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
	  nextName = RETAIN([self getProp: "next" fromNode: cur]);	// get the "next" link
	  prevName = RETAIN([self getProp: "prev" fromNode: cur]);	// get the "prev" link
	  upName = RETAIN([self getProp: "up" fromNode: cur]);		// get the "up" link
	  styleSheetURL = RETAIN([self getProp: "stylesheeturl" fromNode: cur]);//Get the style sheet if any
	  defs = RETAIN([NSUserDefaults standardUserDefaults]);
	  s = [defs stringForKey: @"BaseName"];
	  if (s != nil)
		{
		  ASSIGN(baseName, s);
		}
	  currName = [baseName copy];
  
	  indexes = [NSMutableDictionary new];
	};
  return self;
}

- (NSString*) parseText: (xmlNodePtr)node
{
  xmlNodePtr	endNode;
  NSString	*result;

  result = [self parseText: node end: &endNode];
  if (endNode != 0)
    {
      NSLog(@"Unexpected node type in text node - %d", endNode->type);
      result = nil;
    }
  return result;
}

- (NSString*) parseText: (xmlNodePtr)node end: (xmlNodePtr*)endNode
{
  return nil;
}

@end



// ====================================================================
@interface	GSDocHtml : GSDocParser
{
  NSMutableDictionary	*refToFile;
  NSMutableArray	*contents;
  NSMutableArray	*footnotes;
  unsigned		labelIndex;
  unsigned		footnoteIndex;
  unsigned		contentsIndex;
  NSMutableDictionary* fileReferences;			// References for the current file (constructed when parsing this file)
  NSMutableDictionary* generalReferences;		// General References (coming from documentations References)
  NSMutableDictionary* variablesDictionary;		// "User Variables"
  NSString*     currentClassName;				// Currently Parsed Class Name if any
  NSString*     currentCategoryName;			// Currently Parsed Category Name if any
  NSString*     currentProtocolName;			// Currently Parsed Protocol Name if any
  BOOL writeFlag;								// YES if we'll write the result
}
- (id)init;
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
- (NSString*) parseVariable: (xmlNodePtr)node;
- (NSString*) parseIVariable: (xmlNodePtr)node;
- (NSString*) parseConstant: (xmlNodePtr)node;
- (NSString*) parseMacro: (xmlNodePtr)node;
- (NSString*) parseMethod: (xmlNodePtr)node;
- (NSArray*) parseStandards: (xmlNodePtr)node;
- (NSString*) parseText: (xmlNodePtr)node end: (xmlNodePtr*)endNode;
- (void) setEntry: (NSString*)entry
withExternalCompleteRef: (NSString*)externalCompleteRef
  withExternalRef: (NSString*)externalRef
		  withRef: (NSString*)ref
    inIndexOfType: (NSString*)type;
-(NSArray*)contents;
-(NSDictionary*)fileReferences;
-(void)setGeneralReferences:(NSDictionary*)dict;
-(void)setVariablesDictionary:(NSDictionary*)dict;
-(NSString*)linkedTypeWithType:(NSString*)type;
-(NSString*)linkedClassWithClass:(NSString*)class_;
-(NSDictionary*)findSymbolForKey:(NSString*)key_;
-(NSString*)linkForSymbol:(NSDictionary*)symbol
				 withText:(NSString*)text;
-(void)setWriteFlag:(BOOL)flag;
@end

// ====================================================================
@implementation	GSDocHtml

- (id)init
{
  if ((self=[super init]))
	{
	  writeFlag=YES;
	};
  return self;
};

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
  DESTROY(fileReferences);
  DESTROY(generalReferences);
  DESTROY(variablesDictionary);
  DESTROY(currentClassName);
  DESTROY(currentCategoryName);
  DESTROY(currentProtocolName);
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
  node = node->children;
  if (node != 0 && strcmp(node->name, "email") == 0)
    {
      email = [self getProp: "email" fromNode: node];
      ename = [self parseText: node->children];
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
    || strcmp(node->name, "jclass") == 0
    || strcmp(node->name, "category") == 0
    || strcmp(node->name, "protocol") == 0
    || strcmp(node->name, "function") == 0
    || strcmp(node->name, "macro") == 0
    || strcmp(node->name, "type") == 0
    || strcmp(node->name, "variable") == 0
    || strcmp(node->name, "ivariable") == 0
    || strcmp(node->name, "constant") == 0)
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
      NSString	*elem = [self parseText: node->children];

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

  node = node->children;
  /*
   * Parse the front (unnumbered chapters) storing the html for each
   * chapter as a separate string in the 'front' array.
   */
  if (node != 0 && strcmp(node->name, "front") == 0)
    {
      xmlNodePtr	f = node->children;

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
      node = node->children;

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
  NSString* nodeId=nil;
  NSMutableDictionary	*dict;
  NSMutableArray	*subs;

  nodeId=[self getProp: "id" fromNode: node];
  ref = nodeId;
  if (ref == nil)
    {
      ref = [NSString stringWithFormat: @"cont-%u", contentsIndex++];
    }

  node = node->children;
  if (node == 0 || strcmp(node->name, "heading") != 0)
    {
      NSLog(@"%s without heading", type);
      return nil;
    }
  head = [self parseText: node->children];
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

  if (nodeId)
	{
	  [self setEntry:head
			withExternalCompleteRef:[NSString stringWithFormat:@"%@##%@",currName,head]
			withExternalRef:head
			withRef: ref
			inIndexOfType:[NSString stringWithCString:type]];
	};

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

  if ((strcmp(node->name, "class") == 0)
    || (strcmp(node->name, "jclass") == 0))
    {
      NSString	*className = [self getProp: "name" fromNode: node];
      NSString	*superName = [self getProp: "super" fromNode: node];
      NSString	*ref = [self getProp: "id" fromNode: node];
      NSString	*declared = nil;
      NSString	*desc = nil;
      NSMutableArray	*conform = [NSMutableArray array];
      NSMutableArray	*ivariables = [NSMutableArray array];//Instance Variables
      NSMutableArray	*factoryMethods = [NSMutableArray array]; //Factory Methods
      NSMutableArray	*instanceMethods = [NSMutableArray array]; // Instance Methods
      NSMutableArray	*standards = [NSMutableArray array]; // Standards

      if (className == nil)
	{
	  NSLog(@"Missing class name");
	  return nil;
	}
      if (ref == nil)
	{
	  ref = className;
	}
	  // We're working on "className"
	  ASSIGN(currentClassName,className);

      /*
       * Clear the methods index so it will contain only values from this class.
       */
      [[self indexForType: @"method"] removeAllObjects];

      node = node->children;
      if (node != 0 && strcmp(node->name, "declared") == 0)
	{
	  declared = [self parseText: node->children];
	  node = node->next;
	}

      while (node != 0 && strcmp(node->name, "conform") == 0)
	{
	  NSString	*s = [self parseText: node->children];

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

      while (node != 0 && strcmp(node->name, "ivariable") == 0)
	{
	  NSString	*s = [self parseIVariable:node];
	  if (s != nil)
	    {
	      [ivariables addObject: s];
	    }
	  node = node->next;
	}

      while (node != 0 && ((strcmp(node->name, "method") == 0)
	|| (strcmp(node->name, "jmethod") == 0)))
	{
	  // Is It a factory method ?
	  BOOL factoryMethod=[[self getProp: "factory" fromNode: node] boolValue];
	  NSString	*s = [self parseMethod: node];

	  if (s != nil)
	    {
		  if (factoryMethod)
			[factoryMethods addObject: s];
		  else
			[instanceMethods addObject: s];
	    }
	  node = node->next;
	}

      while (node != 0 && strcmp(node->name, "standard") == 0)
	{
	  NSString	*s = [self parseText: node->children];

	  if (s != nil)
	    {
	      [standards addObject: s];
	    }
	  node = node->next;
	}

      [self setEntry: className
			withExternalCompleteRef:className
			withExternalRef:className
			withRef: ref
			inIndexOfType: @"class"];
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

	  [text appendString: @"<h2>Instance Variables</h2>\r\n"];
      [self appendIndex: @"ivariable" toString:text];

	  [text appendString: @"<h2>Methods</h2>\r\n"];
      [self appendIndex: @"method" toString: text];

      if ([ivariables count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr><h2>Instance Variables</h2>\r\n"];
	  for (i = 0; i < [ivariables count]; i++)
	    {
	      [text appendString: [ivariables objectAtIndex: i]];
	    }
	}

      if ([factoryMethods count] > 0)
	{
	  unsigned	i;
	  [text appendString: @"<hr><h2>Class Methods</h2>\r\n"];
	  for (i = 0; i < [factoryMethods count]; i++)
		{
		  [text appendString: [factoryMethods objectAtIndex: i]];
		};
	};

      if ([instanceMethods count] > 0)
	{
	  unsigned	i;
	  [text appendString: @"<hr><h2>Instances Methods</h2>\r\n"];
	  for (i = 0; i < [instanceMethods count]; i++)
		{
		  [text appendString: [instanceMethods objectAtIndex: i]];
		};
	};

	  // We've finished working on "className"
	  ASSIGN(currentClassName,nil);
      return text;
    }
  else if (strcmp(node->name, "category") == 0)
    {
      NSString	*className = [self getProp: "class" fromNode: node];
      NSString	*catName = [self getProp: "name" fromNode: node];
      NSString	*ref = [self getProp: "id" fromNode: node];
      NSString	*declared = nil;
      NSString	*desc = nil;
      NSMutableArray	*factoryMethods = [NSMutableArray array];
      NSMutableArray	*instanceMethods = [NSMutableArray array];
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

	  // We works on a category
	  ASSIGN(currentCategoryName,([NSString stringWithFormat: @"%@(%@)",className,catName]));
      /*
       * Clear the methods index so it will contain only values from this class.
       */
      [[self indexForType: @"method"] removeAllObjects];

      node = node->children;
      if (node != 0 && strcmp(node->name, "declared") == 0)
	{
	  declared = [self parseText: node->children];
	  node = node->next;
	}
      if (node != 0 && strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	  node = node->next;
	}

      while (node != 0 && strcmp(node->name, "method") == 0)
	{
	  BOOL factoryMethod=[[self getProp: "factory" fromNode: node] boolValue];
	  NSString	*s = [self parseMethod: node];

	  if (s != nil)
	    {
		  if (factoryMethod)
			[factoryMethods addObject: s];
		  else
			[instanceMethods addObject: s];
	    }
	  node = node->next;
	}

      while (node != 0 && strcmp(node->name, "standard") == 0)
	{
	  NSString	*s = [self parseText: node->children];

	  if (s != nil)
	    {
	      [standards addObject: s];
	    }
	  node = node->next;
	}

      [self setEntry: name
			withExternalCompleteRef:[NSString stringWithFormat:@"%@(%@)",className,catName]
			withExternalRef:[NSString stringWithFormat:@"%@(%@)",className,catName]
			withRef:ref
			inIndexOfType: @"category"];

      [text appendFormat: @"<h2>%@ <a name=\"%@\">(%@)</a></h2>\r\n",
			[self linkedClassWithClass:className],
			ref,
			catName];
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

	  [text appendString: @"<h2>Methods</h2>\r\n"];
      [self appendIndex: @"method" toString: text];

      if ([factoryMethods count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr><h2>Class Methods</h2>\r\n"];
	  for (i = 0; i < [factoryMethods count]; i++)
	    {
	      [text appendString: [factoryMethods objectAtIndex: i]];
	    }
	}

      if ([instanceMethods count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr><h2>Instances Methods</h2>\r\n"];
	  for (i = 0; i < [instanceMethods count]; i++)
	    {
	      [text appendString: [instanceMethods objectAtIndex: i]];
	    }
	}
	  // We've finished working on this category
	  ASSIGN(currentCategoryName,nil);
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

	  // Works on "protName"
	  ASSIGN(currentProtocolName,protName);
      /*
       * Clear the methods index so it will contain only values from this class.
       */
      [[self indexForType: @"method"] removeAllObjects];

      node = node->children;
      if (node != 0 && strcmp(node->name, "declared") == 0)
	{
	  declared = [self parseText: node->children];
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
	  NSString	*s = [self parseText: node->children];

	  if (s != nil)
	    {
	      [standards addObject: s];
	    }
	  node = node->next;
	}

      [self setEntry: protName
			withExternalCompleteRef:protName
			withExternalRef:protName
			withRef: ref
			inIndexOfType: @"protocol"];
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

	  // Finished working on "protName"
	  ASSIGN(currentProtocolName,nil);
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
      node = node->children;
      if (node != 0 && strcmp(node->name, "typespec") == 0)
	{
	  spec = [self parseText: node->children];
	  node = node->next;
	}
      if (spec == nil)
	{
	  NSLog(@"Missing type specification");
	  return nil;
	}

      if (node != 0 && strcmp(node->name, "declared") == 0)
	{
	  declared = [self parseText: node->children];
	  node = node->next;
	}

      if (node != 0 && strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	  node = node->next;
	}

      while (node != 0 && strcmp(node->name, "standard") == 0)
	{
	  NSString	*s = [self parseText: node->children];

	  if (s != nil)
	    {
	      [standards addObject: s];
	    }
	  node = node->next;
	}

      [self setEntry: typeName 
			withExternalCompleteRef:typeName
			withExternalRef:typeName
			withRef: ref inIndexOfType: @"type"];
      [text appendFormat: @"<h3><a name=\"%@\">%@</a></h3>\r\n",
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
	  [text appendFormat: @"\r\n%@\r\n<hr>\r\n", desc];
	}

      return text;
    }
  else if (strcmp(node->name, "variable") == 0)
    {
	  return [self parseVariable:node];
    }
  else if (strcmp(node->name, "constant") == 0)
    {
	  return [self parseConstant:node];
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

  node = node->children;
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
	  NSString	*elem = [self parseText: node->children];

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
	  xmlNodePtr	old = node;

	  [text appendString: [self parseText: node end: &node]];
	  /*
	   * If we found text, the node will have been advanced, but if
	   * it failed we need to advance ourselves.
           */
	  if (node == old)
	    node = node->next;
	  continue;
	}

      node = node->next;
    }
  return text;
}

- (NSString*) parseDocument
{
  xmlNodePtr	cur = doc->children->next->children;
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

  // Don't write result if !writeFlag
  if (writeFlag && [defs boolForKey: @"Monolithic"] == YES)
    {
	  // Replace "UserVariables" in text
	  text=TextByReplacingVariablesInText(text,variablesDictionary);

	  // Write the result
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
  NSString		*elem = [self parseText: node->children];
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
      [self setEntry: @"example"
			withExternalCompleteRef:nil
			withExternalRef:nil
			withRef: ref
			inIndexOfType: @"label"];
      [text appendFormat: @"<a name=\"%@\">example</a>\r\n", ref];
    }
  else
    {
      [self setEntry: cap
			withExternalCompleteRef:nil
			withExternalRef:nil
			withRef:ref
			inIndexOfType: @"label"];
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
  //Avoid ((xxx))
  else if ([type hasPrefix:@"("] && [type hasSuffix:@")"])
	type =[[type stringWithoutPrefix:@"("] stringWithoutSuffix:@")"];
  type=[self linkedTypeWithType:type];

  node = node->children;
  while (node != 0 && strcmp(node->name, "arg") == 0)
    {
      NSString	*arg = [self parseText: node->children];
      NSString	*typ = [self getProp: "type" fromNode: node];

      if (arg == nil)
		return nil;

      if ([args length] > 1)
		{
		  [args appendString: @", "];
		}

      if (typ != nil)
		{
		  //Avoid ((xxx))
		  if ([typ hasPrefix:@"("] && [typ hasSuffix:@")"])
			typ =[[typ stringWithoutPrefix:@"("] stringWithoutSuffix:@")"];
		  typ=[self linkedTypeWithType:typ];
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
      declared = [self parseText: node->children];
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
  [self setEntry: name
		withExternalCompleteRef:name
		withExternalRef:name
		withRef: ref
		inIndexOfType: @"function"];
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

  node = node->children;

  if (node == 0 || strcmp(node->name, "title") != 0
    || (title = [self parseText: node->children]) == nil)
    {
      NSLog(@"head without title");
      return nil;
    }
  [text appendFormat: @"<head>\r\n<title>%@</title>\r\n", title];

      NSLog(@"currName=%@",currName);
  [self setEntry:title
		withExternalCompleteRef:currName
		withExternalRef:currName
		withRef: currName
		inIndexOfType:@"file"];

  if ([styleSheetURL length]>0)
	  [text appendFormat: @"<link rel=stylesheet type=\"text/css\" href=\"%@\">\r\n",styleSheetURL];

  [text appendString: @"</head>\r\n"];
  [text appendString: @"<body>\r\n"];
  if ([prevName length]>0)
    {
	  //Avoid empty link
	  NSString* test=TextByReplacingVariablesInText(prevName,variablesDictionary);
	  if ([test length]>0)
		{
		  if ([[prevName pathExtension] isEqual: @"html"] == YES)
			[text appendFormat: @"<a href=\"%@\">[Previous]</a>\n", prevName];
		  else
			[text appendFormat: @"<a href=\"%@.html\">[Previous]</a>\n", prevName];
		};
    }
  if ([upName length]>0)
    {
	  NSString* test=TextByReplacingVariablesInText(upName,variablesDictionary);
	  if ([test length]>0)
		{
		  if ([[upName pathExtension] isEqual: @"html"] == YES)
			[text appendFormat: @"<a href=\"%@\">[Up]</a>\n", upName];
		  else
			[text appendFormat: @"<a href=\"%@.html\">[Up]</a>\n", upName];
		};
    }
  if ([nextName length]>0)
    {
	  //Avoid empty link
	  NSString* test=TextByReplacingVariablesInText(nextName,variablesDictionary);
	  if ([test length]>0)
		{
		  if ([[nextName pathExtension] isEqual: @"html"] == YES)
			[text appendFormat: @"<a href=\"%@\">[Next]</a>\n", nextName];
		  else
			[text appendFormat: @"<a href=\"%@.html\">[Next]</a>\n", nextName];
		};
    };

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
      version = [self parseText: node->children];
      node = node->next;
      [text appendFormat: @"<p>Version: %@</p>\r\n", version];
    }

  if (node != 0 && strcmp(node->name, "date") == 0)
    {
      date = [self parseText: node->children];
      node = node->next;
      [text appendFormat: @"<p>Date: %@</p>\r\n", date];
    }

  if (node != 0 && strcmp(node->name, "abstract") == 0)
    {
      abstract = [self parseText: node->children];
      node = node->next;
      [text appendFormat: @"<blockquote>%@</blockquote>\r\n", abstract];
    }

  if (node != 0 && strcmp(node->name, "copy") == 0)
    {
      copyright = [self parseText: node->children];
      node = node->next;
      [text appendFormat: @"<p>Copyright: %@</p>\r\n", copyright];
    }

  return text;
}

- (NSString*) parseItem: (xmlNodePtr)node
{
  node = node->children;

  if (strcmp(node->name, "class") == 0
    || strcmp(node->name, "category") == 0
    || strcmp(node->name, "protocol") == 0
    || strcmp(node->name, "function") == 0
    || strcmp(node->name, "macro") == 0
    || strcmp(node->name, "type") == 0
    || strcmp(node->name, "variable") == 0
    || strcmp(node->name, "ivariable") == 0
    || strcmp(node->name, "constant") == 0)
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
      NSString	*elem = [self parseText: node->children];

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
      node = node->children;
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
      node = node->children;
      while (node != 0 && strcmp(node->name, "item") == 0)
	{
  NSDebugMLog(@"parseList node=%p node->name=%s node->content=%s",node, node ? node->name : NULL,node ? node->content : NULL);//MG
	  [text appendFormat: @"<li>%@\r\n", [self parseItem: node]];
	  node = node->next;
	}
      [text appendString: @"</ol>\r\n"];
    }
  else if (strcmp(node->name, "deflist") == 0)
    {
      [text appendString: @"<dl>\r\n"];
      node = node->children;
      while (node != 0)
	{
	  if (strcmp(node->name, "term") == 0)
	    {
	      [text appendFormat: @"<dt>%@\r\n",
		[self parseText: node->children]];
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
      node = node->children;
      while (node != 0)
	{
	  if (strcmp(node->name, "question") == 0)
	    {
	      [text appendFormat: @"<dt>%@\r\n",
		[self parseText: node->children]];
	      node = node->next;
	    }

	  if (node == 0 || strcmp(node->name, "answer") != 0)
	    {
	      NSLog(@"term without desc");
	      return nil;
	    }
	  [text appendFormat: @"<dt>%@\r\n", [self parseBlock: node->children]];
	  node = node->next;
	}
      [text appendString: @"</dl>\r\n"];
    }
  return text;
}

// Parse Variable, IVariable or constant
- (NSString*) parseVariable: (xmlNodePtr)variableNode
				 orConstant: (xmlNodePtr)constantNode
					 ofType:(NSString*)type_
{
  xmlNodePtr node=(variableNode ? variableNode : constantNode);
  NSMutableString	*text = [NSMutableString string];
  NSString	*name = [self getProp: "name" fromNode: node];
  NSString	*type = variableNode ? [self getProp: "type" fromNode: node] : nil;
  NSString	*posttype = variableNode ? [self getProp: "posttype" fromNode: node] : nil;
  NSString	*value = [self getProp: "value" fromNode: node];
  NSString	*role = [self getProp: "role" fromNode: node];
  NSString	*ref = [self getProp: "id" fromNode: node];
  NSString	*declared = nil;
  NSString	*desc = nil;
  NSMutableArray	*standards = [NSMutableArray array];
  NSString  *completeRefName=nil;//MG

  if (name == nil)
	{
	  NSLog(@"Missing variable/constant name");
	  return nil;
	}

  if (variableNode!=NULL && type == nil)
	{
	  NSLog(@"Missing variable type");
	  return nil;
	}
  
  if (ref == nil)
	{
	  ref = name;
	}
  node = node->children;

  if (node != 0 && strcmp(node->name, "declared") == 0)
	{
	  declared = [self parseText: node->children];
	  node = node->next;
	}

  if (node != 0 && strcmp(node->name, "desc") == 0)
	{
	  desc = [self parseDesc: node];
	  node = node->next;
	}

  while (node != 0 && strcmp(node->name, "standard") == 0)
	{
	  NSString	*s = [self parseText: node->children];
	  
	  if (s != nil)
	    {
	      [standards addObject: s];
	    }
	  node = node->next;
	}

  if (currentClassName)
	completeRefName=[NSString stringWithFormat:@"%@::%@",currentClassName,name];
  else
	completeRefName=name;

  [self setEntry: name
		withExternalCompleteRef:completeRefName
		withExternalRef:name
		withRef: ref
		inIndexOfType:type_];

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
	  [text appendFormat: @"%@ <b>%@</b>%@<br>\r\n", type ? type : @"", name, (posttype ? posttype : @"")];//MG
	}
  else
	{
	  [text appendFormat: @"%@ <b>%@</b>%@ = %@<br>\r\n", type ? type : @"", name, (posttype ? posttype : @""), value];//MG
	}
  
  if (desc != nil)
	{
	  [text appendFormat: @"\r\n%@\r\n", desc];
	}
  
  return text;
}

//Parse Variable
- (NSString*) parseVariable: (xmlNodePtr)node
{
  return [self parseVariable:node
			   orConstant:NULL
			   ofType:@"variable"];
};

//Parse Instance Variable
- (NSString*) parseIVariable: (xmlNodePtr)node
{
  return [self parseVariable:node
			   orConstant:NULL
			   ofType:@"ivariable"];
};

// Parse Constant
- (NSString*) parseConstant: (xmlNodePtr)node
{
  return [self parseVariable:NULL
			   orConstant:node
			   ofType:@"constant"];
};

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

  node = node->children;
  while (node != 0 && strcmp(node->name, "arg") == 0)
    {
      NSString	*arg = [self parseText: node->children];
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
      declared = [self parseText: node->children];
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
  [self setEntry: name
		withExternalCompleteRef:name
		withExternalRef:name
		withRef: ref
		inIndexOfType: @"macro"];
  [text appendFormat: @"<h3><a name=\"%@\">%@</a></h3>\r\n", ref, name];
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
  BOOL		factory = [[self getProp: "factory" fromNode: node] boolValue];
  BOOL		desInit = [[self getProp: "init" fromNode: node] boolValue];
  NSMutableString	*lText = [NSMutableString string];
  NSMutableString	*sText = [NSMutableString string];
  BOOL		isJava = (strcmp(node->name, "jmethod") == 0);
  NSString	*desc = nil;
  NSArray	*standards = nil;
  NSString  *methodBlockName=nil;
  NSString  *methodCompleteBlockName=nil;

  if (currentClassName)
	{
	  methodBlockName=currentClassName;
	  methodCompleteBlockName=currentClassName;
	}
  else if (currentCategoryName)
	{
	  methodBlockName=currentClassName;
	  methodCompleteBlockName=currentCategoryName;
	}
  else if (currentProtocolName)
	{
	  methodBlockName=currentProtocolName;
	  methodCompleteBlockName=currentProtocolName;
	}
  else	
	{
	  methodBlockName=@"unknown";
	  methodCompleteBlockName=methodBlockName;
	};

  if (ref == nil)
    {
      ref = [NSString stringWithFormat: @"method-%u",
	labelIndex++];
    }
  if (isJava)
    {
      NSMutableString	*decl = [NSMutableString string];
      NSMutableString	*args = [NSMutableString stringWithString: @"("];
      NSString		*name = [self getProp: "name" fromNode: node];

      if (factory)
	{
	  [decl appendString: @"static "];
	}
      if (type == nil)
		type = @"Object";
	  //Avoid ((xxx))
	  else if ([type hasPrefix:@"("] && [type hasSuffix:@")"])
		type =[[type stringWithoutPrefix:@"("] stringWithoutSuffix:@")"];
	  type=[self linkedTypeWithType:type];
      [decl appendString: type];
      [decl appendString: @" "];

      node = node->children;

      while (node != 0 && strcmp(node->name, "arg") == 0)
	{
	  NSString	*arg = [self parseText: node->children];
	  NSString	*typ = [self getProp: "type" fromNode: node];

	  if (arg == nil) break;
	  if ([args length] > 1)
	    {
	      [args appendString: @", "];
	    }
	  if (typ != nil)
	    {
		  //Avoid ((xxx))
		  if ([typ hasPrefix:@"("] && [typ hasSuffix:@")"])
			typ =[[typ stringWithoutPrefix:@"("] stringWithoutSuffix:@")"];
		  typ=[self linkedTypeWithType:typ];
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

      [lText appendString: decl];
      [lText appendString: @"<b>"];
      [lText appendString: name];
      [lText appendString: @"</b>"];
      [lText appendString: args];
      [sText appendString: decl];
      [sText appendString: name];
      [sText appendString: args];
    }
  else
    {
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
	  //Avoid ((xxx))
	  else if ([type hasPrefix:@"("] && [type hasSuffix:@")"])
		type =[[type stringWithoutPrefix:@"("] stringWithoutSuffix:@")"];
	  type=[self linkedTypeWithType:type];

      [lText appendString: type];
      [lText appendString: @")"];

      node = node->children;
      while (node != 0 && strcmp(node->name, "sel") == 0)
	{
	  NSString	*sel = [self parseText: node->children];

	  if (sel == nil) return nil;
	  [sText appendString: sel];
	  [lText appendFormat: @" <b>%@</b>", sel];
	  node = node->next;
	  if (node != 0 && strcmp(node->name, "arg") == 0)
	    {
	      NSString	*arg = [self parseText: node->children];
	      NSString	*typ = [self getProp: "type" fromNode: node];

	      if (arg == nil)
			return nil;
	      if (typ != nil)
			{
			  //Avoid ((xxx))
			  if ([typ hasPrefix:@"("] && [typ hasSuffix:@")"])
				typ =[[typ stringWithoutPrefix:@"("] stringWithoutSuffix:@")"];
			  typ=[self linkedTypeWithType:typ];
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
    }

  if (node != 0 && strcmp(node->name, "desc") == 0)
    {
      desc = [self parseDesc: node];
      node = node->next;
    }

  if (node != 0)
    {
      standards = [self parseStandards: node];
    }

  if (isJava)
    {
      [self setEntry: sText
			withExternalCompleteRef:[NSString stringWithFormat:@"%@::%@",methodCompleteBlockName,sText]
			withExternalRef:[NSString stringWithFormat:@"%@::%@",methodBlockName,sText]
			withRef: ref
			inIndexOfType: @"method"];
    }
  else
    {
      if (factory)
	{
	  NSString	*s = [@"+" stringByAppendingString: sText];
	  [self setEntry: s
			withExternalCompleteRef:[NSString stringWithFormat:@"+%@::%@",methodCompleteBlockName,sText]
			withExternalRef:[NSString stringWithFormat:@"+%@::%@",methodBlockName,sText]
			withRef: ref
			inIndexOfType: @"method"];
	}
      else
	{
	  NSString	*s = [@"-" stringByAppendingString: sText];
	  [self setEntry: s
			withExternalCompleteRef:[NSString stringWithFormat:@"-%@::%@",methodCompleteBlockName,sText]
			withExternalRef:[NSString stringWithFormat:@"-%@::%@",methodBlockName,sText]
			withRef: ref
			inIndexOfType: @"method"];
	}
    }
  [text appendFormat: @"<h3><a name=\"%@\">%@</a></h3>\r\n", ref, sText];
  if (desInit)
    {
      [text appendString: @"<b>This is the designated initialiser</b><br>\r\n"];
    }
  [text appendFormat: @"%@;<br>\r\n", lText];
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
  if ([standards count] > 0)
    {
      unsigned	i;

      [text appendString: @"Standards:"];
      for (i = 0; i < [standards count]; i++)
	{
	  [text appendString: @" "];
	  [text appendString: [standards objectAtIndex: i]];
	}
      [text appendString: @"<br>\r\n"];
    }

  if (desc != nil)
    {
      [text appendString: desc];
    }
  [text appendString: @"\r\n<hr>\r\n"];

  return text;
}

- (NSArray*) parseStandards: (xmlNodePtr)node
{
  if (node != 0)
    {
      if (strcmp(node->name, "standards") == 0)
	{
	  NSMutableArray	*a = [NSMutableArray array];

	  node = node->children;
	  while (node != 0 && node->name != 0)
	    {
	      [a addObject: [NSString stringWithCString: node->name]];
	      node = node->next;
	    }
	  return a;
	}
      else
	{
	  NSLog(@"Unexpected node in method definition - %s", node->name);
	}
    }
  return nil;
}

- (NSString*) parseText: (xmlNodePtr)node end: (xmlNodePtr*)endNode
{
  NSMutableString	*text = [NSMutableString string];

  *endNode = node;
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
	    if (strcmp(node->name, "br") == 0)
	      {
		[text appendString: @"<br>"];
	      }
	    else if (strcmp(node->name, "code") == 0
	      || strcmp(node->name, "em") == 0
	      || strcmp(node->name, "file") == 0
	      || strcmp(node->name, "site") == 0
	      || strcmp(node->name, "strong") == 0
	      || strcmp(node->name, "var") == 0)
	      {
		NSString	*elem = [self parseText: node->children];

		[text appendFormat: @"<%s>%@</%s>",
		  node->name, elem, node->name];
	      }
	    else if (strcmp(node->name, "entry") == 0
	      || strcmp(node->name, "label") == 0)
	      {
		NSString		*elem;
		NSString		*ref;

		elem = [self parseText: node->children];
		ref = [self getProp: "id" fromNode: node];
		if (ref == nil)
		  {
		    ref = [NSString stringWithFormat: @"label-%u",
		      labelIndex++];
		  }

		[self setEntry: elem
			  withExternalCompleteRef:[NSString stringWithFormat:@"%@::%@",@"***unknown",elem]
			  withExternalRef:[NSString stringWithFormat:@"%@::%@",@"***unknown",elem]
			  withRef: ref
			  inIndexOfType: @"label"];

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

		elem = [self parseText: node->children];
		ref = [NSString stringWithFormat: @"foot-%u",
		  [footnotes count]];

		[self setEntry: elem
			  withExternalCompleteRef:[NSString stringWithFormat:@"%@::%@",@"***unknown",elem]
			  withExternalRef:[NSString stringWithFormat:@"%@::%@",@"***unknown",elem]
			  withRef: ref
			  inIndexOfType: @"footnote"];

		[footnotes addObject: elem];
		[text appendFormat: @" %@ ",
		  [self addLink: ref withText: @"see footnote"]];
	      }
	    else if (strcmp(node->name, "ref") == 0)
	      {
		NSString	*elem = [self parseText: node->children];
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
		NSString	*elem = [self parseText: node->children];
		NSString	*ref = [self getProp: "url" fromNode: node];

		if ([elem length] == 0)
		  elem = ref;
		[text appendFormat: @"<a href=\"%@\">%@</a>", ref, elem];
	      }
	    else
	      {
		return text;
	      }
	    break;

	  default:
	    return text; 
	}
      node = node->next;
      *endNode = node;
    }
  return text;
}

- (void) setEntry: (NSString*)entry
withExternalCompleteRef:(NSString*)externalCompleteRef
  withExternalRef: (NSString*)externalRef
		  withRef: (NSString*)ref
    inIndexOfType: (NSString*)type
{
  NSMutableDictionary	*index = [self indexForType: type];
  NSAssert(entry,@"No entry");
  NSAssert(ref,@"No ref");
  [index setObject: entry forKey: ref];
  [refToFile setObject: currName forKey: ref];

  if (externalCompleteRef && externalRef)
  {
	NSMutableDictionary* thisEntry=nil;
	thisEntry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									   entry, @"title",
									 externalRef, @"ref",
									 externalCompleteRef,@"completeRef",
									 ref, @"fragment",
									 type, @"type",
									 currName, @"fileName",
									 nil];
	if (!fileReferences)
	  {
		fileReferences=[NSMutableDictionary new];
	  };
	[fileReferences setObject:thisEntry 
					forKey:externalCompleteRef];
  };
};

-(NSArray*)contents
{
  return contents;
};

-(NSDictionary*)fileReferences
{
  return fileReferences;
};

-(void)setGeneralReferences:(NSDictionary*)dict
{
  ASSIGN(generalReferences,dict);
};

-(void)setVariablesDictionary:(NSDictionary*)dict
{
  DESTROY(variablesDictionary);
  variablesDictionary=[dict mutableCopy];
};

-(NSString*)linkedClassWithClass:(NSString*)class_
{
  //TODO
  return [self linkedTypeWithType:class_];
};

//Return a link for type (something like: <A HREF="TheFile.html#fragment">TheType</A>)
-(NSString*)linkedTypeWithType:(NSString*)type
{
  NSString* linked=nil;
  NSRange foundRange=[type rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]];
  if (foundRange.length>0)
	{
	  NSString* goodType=nil;
	  NSDictionary* symbol=nil;
	  NSRange goodRange=NSMakeRange(foundRange.location,1);
	  while (foundRange.length>0 && foundRange.location+foundRange.length<[type length])
		{
		  foundRange=[type rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]
						   options:0
						   range:NSMakeRange(foundRange.location+1,1)];
		  if (foundRange.length>0)
			goodRange.length++;
		};
	  goodType=[type substringWithRange:goodRange];
	  symbol=[self findSymbolForKey:goodType];
	  if (symbol)
		{
		  linked=[self linkForSymbol:symbol
					   withText:goodType];
		  if (goodRange.location>0)
			{
			  linked=[NSString stringWithFormat:@"%@%@",
							   [type substringWithRange:NSMakeRange(0,goodRange.location-1)],
							   linked];
			};
		  if (goodRange.location+goodRange.length<[type length])
			{
			  linked=[NSString stringWithFormat:@"%@%@",
							   linked,
							   [type substringWithRange:NSMakeRange(goodRange.location+goodRange.length,
																	[type length]-(goodRange.location+goodRange.length))]];
			};
		};
	};
  if (!linked)
	linked=type;
  return linked;
};


//Return the symbol for key
-(NSDictionary*)findSymbolForKey:(NSString*)key_
{
  NSDictionary* symbol=nil;
  symbol=[generalReferences objectForKey:key_];
  return symbol;
};


//Return a link for symbol with label text
-(NSString*)linkForSymbol:(NSDictionary*)symbol
				 withText:(NSString*)text
{
  NSString* symbolLocation=[[symbol objectForKey:@"projectInfo"] objectForKey:@"location"];  
  NSString* common=nil;
  NSString* prefix=@"";
  if (location)
	{
	  //Equal: no prefix
	  if (![location isEqual:symbolLocation])
		{
		  common=[symbolLocation commonPrefixWithString:location
								 options:0];
		  if ([common length]>0)
			{
			  NSString* tmp=[location stringWithoutPrefix:common];
			  NSString* previous=nil;
			  symbolLocation=[symbolLocation stringWithoutPrefix:common];
			  while([tmp length]>0 && ![tmp isEqual:previous])
				{
				  previous=tmp;
				  tmp=[tmp stringByDeletingLastPathComponent];
				  symbolLocation=[@".." stringByAppendingPathComponent:symbolLocation];
				};
			};
		  prefix=symbolLocation;
		};
	}
  else
	// No Project Location==> take symbol location
	prefix=symbolLocation;
  return [NSString stringWithFormat:@"<A HREF=\"%@#%@\">%@</A>",
				   [prefix stringByAppendingPathComponent:[symbol objectForKey:@"fileName"]],
				   [symbol objectForKey:@"fragment"],
				   text];
};

-(void)setWriteFlag:(BOOL)flag
{
  writeFlag=flag;
};

@end


//--------------------------------------------------------------------
//Return a dictionary of sybols classified by types
//
// symbols:
// {
//	  	"NSString" = { type = "class"; ...};
//		"NSArray" = { type = "class"; ... };
// };
//
// Return:
// {
//		class = {
//					"NSString" = { ...};
//					"NSArray" = { ... };
//				};
//		function = {
//						...
//				};
// ...
// };
NSDictionary* SymbolsReferencesByType(NSDictionary* symbols)
{
  NSMutableDictionary* symbolsByType=[[NSMutableDictionary new] autorelease];
  NSEnumerator* symbolsEnumerator = [symbols keyEnumerator];
  id symbolKey=nil;          
  while ((symbolKey = [symbolsEnumerator nextObject]))
	{
	  NSDictionary* symbol=[symbols objectForKey:symbolKey];
	  id symbolType=[symbol objectForKey:@"type"];
	  NSMutableDictionary* typeDict=[symbolsByType objectForKey:symbolType];
	  NSCAssert1(symbolType,@"No symbol type in symbol %@",symbol);
	  if (!typeDict)
		{
		  typeDict=[[NSMutableDictionary new] autorelease];
		  [symbolsByType setObject:typeDict
						 forKey:symbolType];
		};
	  [typeDict setObject:symbol
				forKey:symbolKey];
	};			  
  return symbolsByType;
};

//--------------------------------------------------------------------
// Return files list of files in symbols
//
// symbols:
// {
//	  	"NSString" = { fileName = "NSString.gsdoc"; ...};
//		"NSArray" = { fileName = "NSArray.gsdoc"; ... };
// }
//
// Return:
// ( NSString.gsdoc, NSArray.gsdoc, ... )
NSArray* FilesFromSymbols(NSDictionary* symbols)
{
  NSArray* sortedFiles=nil;
  NSMutableArray* files=[[NSMutableArray new] autorelease];
  NSEnumerator* symbolsEnumerator = [symbols keyEnumerator];
  id symbolKey=nil;          
  while ((symbolKey = [symbolsEnumerator nextObject]))
	{
	  NSDictionary* symbol=[symbols objectForKey:symbolKey];
	  id file=[symbol objectForKey:@"fileName"];
	  if (![files containsObject:file])
		[files addObject:file];	  
	};
  sortedFiles=[files sortedArrayUsingSelector:@selector(compare:)];
  return sortedFiles;
};

//--------------------------------------------------------------------
// Return list of files found in dir (deep search) which have extension extension
NSArray* FilesInPathWithExtension(NSString* dir,NSString* extension)
{
  NSMutableArray* files=[NSMutableArray array];
  NSString *file=nil;
  NSFileManager* fm=[NSFileManager defaultManager];
  NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:dir];  
  while ((file = [enumerator nextObject]))
	{
	  BOOL isDirectory=NO;
	  if ([fm fileExistsAtPath:file isDirectory:&isDirectory] && !isDirectory && [[file pathExtension] isEqualToString:extension])
		[files addObject:file];
	};
  return files;
};

void AddSymbolsToReferencesWithProjectInfo(NSDictionary* symbols,NSMutableDictionary* references,NSDictionary* projectInfo)
{
  NSEnumerator* symbolsEnumerator = [symbols keyEnumerator];			  
  id symbolKey=nil;          
  while ((symbolKey = [symbolsEnumerator nextObject]))
	{					  
	  NSDictionary* symbol=[symbols objectForKey:symbolKey];
	  NSMutableDictionary* symbolNew=[NSMutableDictionary dictionaryWithDictionary:symbol];
	  if (verbose>=4)
		{
		  NSLog(@"Project %@ Processing reference %@",
				[projectInfo objectForKey:@"projectName"],
				symbolKey);
		};
	  [symbolNew setObject:projectInfo forKey:@"projectInfo"];
	  NSCAssert(symbolKey,@"No symbolKey");
	  [references setObject:symbolNew forKey:symbolKey];
	  NSCAssert1([symbolNew objectForKey:@"ref"],@"No ref for symbol %@",symbolKey);
	  [references setObject:symbolNew forKey:[symbolNew objectForKey:@"ref"]];
	};
};

//--------------------------------------------------------------------
int main(int argc, char **argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSProcessInfo		*proc;
  NSArray		*args;
  unsigned		i;
  NSUserDefaults	*defs;
  NSString* makeRefsFileName=nil;	// makeRefs file name
  NSString* projectName=nil;		// project Name
  NSMutableArray* files=nil;		// Files to parse
  NSMutableArray* references=nil;	// Array of References files/directories
  NSMutableDictionary* generalReferences=nil;	// References (information coming from references files/directories)
  NSMutableDictionary* projectReferences=nil;	// Project References (references founds by parsing files)
  NSString* makeIndexFileName=nil;				// makeIndex file name
  NSString* makeIndexTemplateFileName=nil;		// makeIndex template file name
  NSMutableDictionary* infoDictionary=nil;		// user info
  NSDictionary* variablesDictionary=nil;		// variables dictionary
  NSMutableDictionary* projectInfo=nil;			// Information On Project
  BOOL goOn=YES;

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  pool = [NSAutoreleasePool new];
  defs = [NSUserDefaults standardUserDefaults];
  [defs registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
										 @"Yes", @"Monolithic",
									   nil]];

  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      NSLog(@"unable to get process information!");
	  goOn=NO;
    };

  if (goOn)
	{
	  args = [proc arguments];

	  // First, process arguments
	  for (i=1;goOn && i<[args count];i++)
		{
		  NSString* arg = [args objectAtIndex: i];
		  // is this an option ?
		  if ([arg hasPrefix:@"--"])
			{
			  NSString* argWithoutPrefix=[arg stringWithoutPrefix:@"--"];
			  NSString* key=nil;
			  NSString* value=nil;
			  NSArray* parts=[argWithoutPrefix componentsSeparatedByString:@"="];
			  key=[parts objectAtIndex:0];
			  if ([parts count]>1)
				value=[[parts subarrayWithRange:NSMakeRange(1,[parts count]-1)] componentsJoinedByString:@"="];

			  // makeRefs option
			  if ([key isEqualToString:@"makeRefs"])
				{
				  makeRefsFileName=value;
				  if (makeRefsFileName)
					{
					  if (![[makeRefsFileName pathExtension] isEqual:PathExtension_GSDocRefs])
						makeRefsFileName=[makeRefsFileName stringByAppendingPathExtension:PathExtension_GSDocRefs];
					}
				  else
					makeRefsFileName=@"";
				}
			  // projectName option
			  else if ([key isEqualToString:@"projectName"])
				{
				  projectName=value;
				  NSCAssert([projectName length],@"No project name");
				}
			  // refs option
			  else if ([key isEqualToString:@"refs"])
				{
				  if (!references)
					references=[[NSMutableArray new] autorelease];
				  NSCAssert([value length],@"No index");
				  [references addObject:value];
				}
			  // makeIndex option
			  else if ([key isEqualToString:@"makeIndex"])
				{
				  makeIndexFileName=value;
				  if (!makeIndexFileName)
					makeIndexFileName=@"index";
				  if (![[makeIndexFileName pathExtension] isEqual:PathExtension_GSDoc])
						makeIndexFileName=[makeIndexFileName stringByAppendingPathExtension:PathExtension_GSDoc];
				}
			  // makeIndexTemplate option
			  else if ([key isEqualToString:@"makeIndexTemplate"])
				{
				  makeIndexTemplateFileName=value;
				  NSCAssert([makeIndexTemplateFileName length],@"No makeIndexTemplate filename");
				}
			  // Verbose
			  else if ([key hasPrefix:@"verbose"])
				{
				  NSCAssert1(value,@"No value for %@",key);
				  verbose=[value intValue];
				  NSLog(@"Verbose=%d %@",verbose,value);
				}
			  // Location
			  else if ([key hasPrefix:@"location"])
				{
				  NSCAssert1(value,@"No value for %@",key);
				  location=value;
				}
			  // define option
			  else if ([key hasPrefix:@"define-"])
				{
				  if (!infoDictionary)
					infoDictionary=[NSMutableDictionary dictionary];
				  NSCAssert1(value,@"No value for %@",key);
				  [infoDictionary setObject:value
								  forKey:[key stringWithoutPrefix:@"define-"]];
				}
			  // unknown option
			  else
				{
				  NSLog(@"Unknown option %@",arg);
				  goOn=NO;
				};
			}
		  // file to parse
		  else
			{
			  if (!files)
				files=[NSMutableArray array];
			  [files addObject:arg];
			};
		};
	};

  //Default Values
  if (goOn)
	{
	  if (!projectName)
		projectName=@"unknown";

	  if ([makeRefsFileName length]==0)
		  makeRefsFileName=[projectName stringByAppendingPathExtension:PathExtension_GSDocRefs];
	};

  // Verify option compatibilities
  if (goOn)
	{
	};

  // Construct project references
  if (goOn)
	{
	  projectReferences=[[NSMutableDictionary new] autorelease];
	  [projectReferences setObject:[[NSMutableDictionary new] autorelease] forKey:@"symbols"];
	  projectInfo=[NSMutableDictionary dictionaryWithObjectsAndKeys:
										 projectName, @"projectName",
									   nil];
	  if (location)
		[projectInfo setObject:location
					 forKey:@"location"];
	};

  // Process references (construct a dictionary of all references)
  if (goOn)
	{
	  generalReferences=[[NSMutableDictionary new] autorelease];
	  if ([references count]>0)
		{
		  NSFileManager* fileManager=[NSFileManager defaultManager];
		  for (i=0;goOn && i<[references count];i++)
			{
			  NSString* file = [references objectAtIndex: i];
			  BOOL isDirectory=NO;
			  if (![fileManager fileExistsAtPath:file isDirectory:&isDirectory])
				{
				  NSLog(@"Index File %@ doesn't exist",file);				  
				}
			  else
				{
				  if (isDirectory)
					{
					  NSArray* tmpReferences=FilesInPathWithExtension(file,PathExtension_GSDocRefs);
					  if (verbose>=3)
						{
						  NSLog(@"Processing references directory %@",file);
						};
					  [references addObjectsFromArray:tmpReferences];
					}
				  else
					{
					  NSDictionary* generalIndexTmp=nil;
					  if (verbose>=2)
						{
						  NSLog(@"Processing references file %@",file);
						};
					  generalIndexTmp=[NSDictionary dictionaryWithContentsOfFile:file];				
					  if (!generalIndexTmp)
						{
						  NSLog(@"File %@ isn't a dictionary",file);
						  goOn=NO;
						}
					  else
						{
						  NSDictionary* fileProjectInfo=[generalIndexTmp objectForKey:@"project"];
						  NSDictionary* symbols=[generalIndexTmp objectForKey:@"symbols"];
						  NSCAssert1(fileProjectInfo,@"No Project Info in %@",file);
						  NSCAssert1(symbols,@"No symbols %@",file);
						  AddSymbolsToReferencesWithProjectInfo(symbols,generalReferences,fileProjectInfo);
						};
					};
				};
			};
		};
	};
	  //Variables
  if (goOn)
	{		  
	  NSMutableDictionary* variablesMutableDictionary=[NSMutableDictionary dictionary];
	  NSEnumerator* enumer = [infoDictionary keyEnumerator];
	  id key=nil;          
	  while ((key = [enumer nextObject]))
		{
		  id value=[infoDictionary objectForKey:key];
		  [variablesMutableDictionary setObject:value
									  forKey:[NSString stringWithFormat:@"[[infoDictionary.%@]]",key]];
		};			  
	  [variablesMutableDictionary setObject:[NSCalendarDate calendarDate]
								  forKey:@"[[timestampString]]"];
	  if (makeIndexFileName)
		{
		  [variablesMutableDictionary setObject:makeIndexFileName
									  forKey:@"[[indexFileName]]"];
		  [variablesMutableDictionary setObject:[makeIndexFileName stringByDeletingPathExtension]
									  forKey:@"[[indexBaseFileName]]"];
		};
	  if (projectName)
		[variablesMutableDictionary setObject:projectName
									forKey:@"[[projectName]]"];
	  variablesDictionary=[[variablesMutableDictionary copy] autorelease];

	  if (verbose>=3)
		{
		  NSEnumerator* enumer = [variablesDictionary keyEnumerator];
		  id key=nil;          
		  while ((key = [enumer nextObject]))
			{
			  NSLog(@"Variables: %@=%@",
					key,
					[variablesDictionary objectForKey:key]);
			};		  
		};
	};

  // Find Files to parse
  if (goOn)
	{
	  if ([files count]<1)
		{
		  NSLog(@"No file names given to parse.");
		  goOn=NO;
		}
	  else
		{
		  NSFileManager* fileManager=[NSFileManager defaultManager];
		  NSMutableArray* tmpNewFiles=[NSMutableArray array];
		  for (i=0;goOn && i<[files count];i++)
			{
			  NSString* file = [files objectAtIndex: i];
			  BOOL isDirectory=NO;
			  if (![fileManager fileExistsAtPath:file isDirectory:&isDirectory])
				{
				  NSLog(@"File %@ doesn't exist",file);				  
				  goOn=NO;
				}
			  else
				{
				  if (isDirectory)
					{
					  NSArray* tmpFiles=FilesInPathWithExtension(file,PathExtension_GSDoc);
					  [tmpNewFiles addObjectsFromArray:tmpFiles];
					}
				  else
					{
					  [tmpNewFiles addObject:file];
					};
				};
			};
		  files=tmpNewFiles;
		};
	};

  if (goOn)
	{
	  int pass=0;
	  //1st pass: don't write file, just parse them and construct project references
	  //2nd pass: parse and write files
	  for (pass=0;goOn && pass<=2;pass++)
		{
		  for (i=0;goOn && i<[files count];i++)
			{
			  NSString* file = [files objectAtIndex: i];
			  if ([file isEqual:makeIndexFileName])//Don't process generated index file
				{
				  if (verbose>=1)
					{
					  NSLog(@"Ignoring Index File %@ (Process it later)",file);
					};
				}
			  else
				{
				  if (verbose>=1)
					{
					  NSLog(@"Processing %@",file);
					};
				  NS_DURING
					{
					  GSDocHtml	*p=nil;			  
					  p = [GSDocHtml alloc];
					  p = [p initWithFileName: file];
					  if (p != nil)
						{
						  NSString* previousFile=((i>0) ? [files objectAtIndex:i-1] : @"");
						  NSString* nextFile=(((i+1)<[files count]) ? [files objectAtIndex:i+1] : @"");
						  NSMutableDictionary* variablesMutableDictionary=nil;
						  NSString	*result = nil;
						  [p setGeneralReferences:generalReferences];
						  variablesMutableDictionary=[variablesDictionary mutableCopy];
						  [variablesMutableDictionary setObject:[previousFile stringByDeletingPathExtension]
													  forKey:@"[[prev]]"];
						  [variablesMutableDictionary setObject:[nextFile stringByDeletingPathExtension]
													  forKey:@"[[next]]"];
						  if (makeIndexFileName)
							[variablesMutableDictionary setObject:[makeIndexFileName stringByDeletingPathExtension]
														forKey:@"[[up]]"];
						  [p setVariablesDictionary:variablesMutableDictionary];
						  [p setWriteFlag:(pass==1)];
						  result=[p parseDocument];				  
						  if (result == nil)
							{
							  NSLog(@"Error parsing %@", file);
							  goOn=NO;
							}
						  else
							{
							  if (verbose>=1)
								{
								  NSLog(@"Parsed %@ - OK", file);
								};
							  [[projectReferences objectForKey:@"symbols"]addEntriesFromDictionary:[p fileReferences]];
							  AddSymbolsToReferencesWithProjectInfo([p fileReferences],generalReferences,projectInfo);
							};
						  RELEASE(p);
						}
					}
				  NS_HANDLER
					{
					  NSLog(@"Parsing '%@' - %@", file, [localException reason]);
					  goOn=NO;
					}
				  NS_ENDHANDLER
					}
			};
		};
	};

  // Process Project References to generate Project Reference File
  if (goOn)
	{
	  if (makeRefsFileName)
		{
		  [projectReferences setObject:projectInfo forKey:@"project"];
		  if (verbose>=1)
			{
			  NSLog(@"Writing References File %@",makeRefsFileName);
			};
		  if (![projectReferences writeToFile:makeRefsFileName
								  atomically:YES])
			{
			  NSLog(@"Error creating %@",makeRefsFileName);
			  goOn=NO;
			};
		};
	};

  // Process Project References to generate Index File
  if (goOn)
	{
	  if (makeIndexFileName)
		{
		  NSString* textTemplate=[NSString stringWithContentsOfFile:makeIndexTemplateFileName];
		  NSMutableString* textStart=[NSMutableString string];
		  NSMutableString* textChapters=[NSMutableString string];
		  NSMutableString* textClasses=[NSMutableString string];
		  NSMutableString* textCategories=[NSMutableString string];
		  NSMutableString* textProtocols=[NSMutableString string];
		  NSMutableString* textFunctions=[NSMutableString string];
		  NSMutableString* textTypes=[NSMutableString string];
		  NSMutableString* textConstants=[NSMutableString string];
		  NSMutableString* textVariables=[NSMutableString string];
		  NSMutableString* textOthers=[NSMutableString string];
		  NSMutableString* textFiles=[NSMutableString string];
		  NSMutableString* textStop=[NSMutableString string];
		  NSMutableString* text=nil;
		  NSMutableDictionary* variablesMutableDictionary=nil;
		  NSString* typeTitle=nil;
		  NSString* finalText=nil;
		  NSDictionary* symbolsByType=SymbolsReferencesByType([projectReferences objectForKey:@"symbols"]);
		  NSString* firstFileName=nil;
		  NSEnumerator* typesEnumerator = [symbolsByType keyEnumerator];
		  id typeKey=nil;    
		  if (verbose>=1)
			{
			  NSLog(@"Making Index");
			};
		  [textStart appendFormat:@"<chapter>\n<heading>%@</heading>\n",projectName];
		  while ((typeKey = [typesEnumerator nextObject]))
			{
			  if (verbose>=2)
				{
				  NSLog(@"Making Index for type %@",typeKey);
				};
			  text=nil;
			  if ([typeKey isEqual:@"ivariable"])
				{
				  text=nil;
				  typeTitle=@"Instance Variables";
				}
			  else if ([typeKey isEqual:@"method"])
				{
				  text=nil;
				  typeTitle=@"Methods";
				}
			  else if ([typeKey isEqual:@"file"])
				{
				  text=textFiles;
				  typeTitle=@"Files";
				}
			  else if ([typeKey isEqual:@"chapter"])
				{
				  text=textChapters;
				  typeTitle=@"Chapters";
				}
			  else if ([typeKey isEqual:@"section"])
				{
				  text=nil;
				  typeTitle=@"Section";
				}
			  else if ([typeKey isEqual:@"ubsect"])
				{
				  text=nil;
				  typeTitle=@"Subsections";
				}
			  else if ([typeKey isEqual:@"class"] || [typeKey isEqual:@"jclass"])
				{
				  text=textClasses;
				  typeTitle=@"Classes";
				}
			  else if ([typeKey isEqual:@"protocol"])
				{
				  text=textProtocols;
				  typeTitle=@"Protocols";
				}
			  else if ([typeKey isEqual:@"category"])
				{
				  text=textProtocols;
				  typeTitle=@"Categories";
				}
			  else if ([typeKey isEqual:@"function"])
				{
				  text=textFunctions;
				  typeTitle=@"Functions";
				}
			  else if ([typeKey isEqual:@"macro"])
				{
				  text=textFunctions;
				  typeTitle=@"Macros";
				}
			  else if ([typeKey isEqual:@"constant"])
				{
				  text=textConstants;
				  typeTitle=@"Constants";
				}
			  else if ([typeKey isEqual:@"variable"])
				{
				  text=textVariables;
				  typeTitle=@"Global Variables";
				}
			  else
				{
				  text=textOthers;
				  typeTitle=@"Others";
				};
			  if (text)
				{
				  NSArray* symbolKeys = nil;
				  NSEnumerator* symbolsEnumerator=nil;
				  id symbolKey=nil;
				  NSDictionary* typeDict=[symbolsByType objectForKey:typeKey];
				  [text appendFormat:@"<section>\n<heading>%@</heading>\n<list>\n",typeTitle];
				  symbolKeys = [typeDict keysSortedByValueUsingSelector: @selector(compare:)];
				  symbolsEnumerator = [symbolKeys objectEnumerator];
				  while ((symbolKey = [symbolsEnumerator nextObject]))
					{
					  NSDictionary* symbol=[typeDict objectForKey:symbolKey];
					  if (text==textFiles && !firstFileName)
						firstFileName=[symbol objectForKey:@"fileName"];
					  if (verbose>=4)
						{
						  NSLog(@"Making Index for symbol %@",[symbol objectForKey:@"title"]);
						};
					  [text appendFormat:@"<item><uref url=\"%@#%@\">%@</uref></item>\n",
							[symbol objectForKey:@"fileName"],
							[symbol objectForKey:@"fragment"],
							[symbol objectForKey:@"title"]];
					};
				  [text appendString:@"</list>\n</section>\n"];
				};
			};		  
		  [textStop appendString:@"</chapter>\n"];
		  finalText=[NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n",
							  textStart,
							  textChapters,
							  textClasses,
							  textCategories,
							  textProtocols,
							  textFunctions,
							  textTypes,
							  textConstants,
							  textVariables,
							  textOthers,
							  textFiles,
							  textStop];
		  variablesMutableDictionary=[variablesDictionary mutableCopy];
		  [variablesMutableDictionary setObject:finalText
									  forKey:@"[[content]]"];
		  [variablesMutableDictionary setObject:[firstFileName stringByDeletingPathExtension]
									  forKey:@"[[next]]"];
		  finalText=TextByReplacingVariablesInText(textTemplate,variablesMutableDictionary);
		  if (verbose>=1)
			{
			  NSLog(@"Writing Index %@",makeIndexFileName);
			};
		  if (![finalText writeToFile:makeIndexFileName
						  atomically: YES])
			{
			  NSLog(@"Error creating %@",makeIndexFileName);
			  goOn=NO;
			};
		};
	};

  // Finally, parse index
  if (goOn)
	{
	  if (makeIndexFileName)
		{
		  if (verbose>=1)
			{
			  NSLog(@"Processing %@",makeIndexFileName);
			};
		  NS_DURING
			{
			  GSDocHtml	*p=nil;			  
			  p = [GSDocHtml alloc];
			  p = [p initWithFileName:makeIndexFileName];
			  if (p != nil)
				{
				  NSString	*result = nil;
				  [p setVariablesDictionary:variablesDictionary];
				  result=[p parseDocument];				  
				  if (result == nil)
					{
					  NSLog(@"Error parsing %@",makeIndexFileName);
					  goOn=NO;
					}
				  else
					{
					  if (verbose>=1)
						{
						  NSLog(@"Parsed %@ - OK",makeIndexFileName);
						};
					};
				  RELEASE(p);
				}
			}
		  NS_HANDLER
			{
			  NSLog(@"Parsing '%@' - %@",makeIndexFileName, [localException reason]);
			  goOn=NO;
			}
		  NS_ENDHANDLER;
		}
	};
  [pool release];
  return (goOn ? 0 : 1);
};

#else
int
main()
{
  NSLog(@"No libxml available");
  return 0;
}
#endif

