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

 You need at least version 2.0.0 of the parser.

 You can find out how to get this from http: //www.xmlsoft.org

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
	--makeRefs = ReferencesFileName
	With this option, gsdoc reads gsdoc files and creates
	ReferencesFileName.gsdocrefs files which can be used
	as --refs to make links between elements

	--projectName = TheProjectName
	Sets the project name to "TheProjectName"
	It is used for index titles, ...

	--refs = ARefFile (or --refs = ARefDirectory)
	Use ARefFile.gsdocrefs (or files whith extensions .gsdocrefs
	in ARefDirectory directory) as references files.
	It enables you to make links between documentations

	--makeIndex = MyIndexFileName
	Create an index of the parsed files and save it as MyIndexName.gsdoc
	You have to set --makeIndexTemplate option

	--makeIndexTemplate = MyIndexTemplateFileName
	The file used as index template for makeIndex option

	--define-XXX = YYY
	Used to define a constant named XXX with value YYY
	in .gsdoc file, all [[infoDictionary.XXX]] texts are replaced with YYY

	--verbose = X
	Level of traces from 0 to ...

	 --location = file: //usr/doc/gnustep/MyProject
	(or --location = http: //www.gnustep.org/gnustep/MyProject)
	Location of the installed documentation (it helps to make links
	between projects)

	file1 file2
	.gsdoc files
*/

#include <config.h>

#include <Foundation/Foundation.h>

#if	HAVE_LIBXML

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <parser.h>

NSString	*pathExtension_GSDocRefs = @"gsdocrefs";
NSString	*pathExtension_GSDoc = @"gsdoc";
NSString	*pathExtension_HTML = @"html";
int		verbose = 0;
NSString	*location = nil;

/*
 * In text, replace keys from variables with their values
 *variables is like something like this
 * {
 *		"[[key1]]" = "value1";
 *		"[[key2]]" = "value2";
 * }
 */
static NSString *
textByReplacingVariablesInText(NSString *text, NSDictionary *variables)
{
  NSEnumerator	*variablesEnum = [variables keyEnumerator];
  id		key = nil;

  while ((key = [variablesEnum nextObject]) != nil)
    {
      id	value = [[variables objectForKey: key] description];

      text = [text stringByReplacingString: key withString: value];
    }
  return text;
}

/*
 * GSDocParser
 */
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
- (NSString *) getProp: (const char *)name fromNode: (xmlNodePtr)node;
- (NSMutableDictionary *) indexForType: (NSString *)type;
- (id) initWithFileName: (NSString *)name;
- (NSString *) parseText: (xmlNodePtr)node;
- (NSString *) parseText: (xmlNodePtr)node end: (xmlNodePtr *)endNode;
@end

static xmlParserInputPtr
loader(const char *url, const char *eid, xmlParserCtxtPtr *ctxt)
{
  extern xmlParserInputPtr xmlNewInputFromFile();
  xmlParserInputPtr	ret = 0;

  if (url == 0)
    {
      url = "";
    }
  if (eid == 0)
    {
      ret = xmlNewInputFromFile(ctxt, url);
    }
  else if (strncmp(eid, "-//GNUstep//DTD ", 16) == 0)
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
  DESTROY(styleSheetURL);
  DESTROY(currName);
  DESTROY(fileName);
  [super dealloc];
}

- (NSString *) getProp: (const char *)name fromNode: (xmlNodePtr)node
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

- (NSMutableDictionary *) indexForType: (NSString *)type
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

- (id) initWithFileName: (NSString *)name
{
  if ((self = [self init]) != nil)
    {
      xmlNodePtr		cur;
      extern int		xmlDoValidityCheckingDefaultValue;
      xmlExternalEntityLoader	ldr;
      NSString			*s;
      NSFileManager		*m;

      xmlKeepBlanksDefault(0);
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
	  s = [name stringByAppendingPathExtension: pathExtension_GSDoc];
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
	  //baseName = @"gsdoc";
	  ASSIGN(baseName, [fileName stringByDeletingPathExtension]);
	}
      else
	{
	  RETAIN(baseName);
	}
      nextName = RETAIN([self getProp: "next" fromNode: cur]);
      prevName = RETAIN([self getProp: "prev" fromNode: cur]);
      upName = RETAIN([self getProp: "up" fromNode: cur]);
      styleSheetURL = RETAIN([self getProp: "stylesheeturl" fromNode: cur]);
      defs = RETAIN([NSUserDefaults standardUserDefaults]);
      s = [defs stringForKey: @"BaseName"];
      if (s != nil)
	{
	  ASSIGN(baseName, s);
	}
      currName = [baseName copy];

      indexes = [NSMutableDictionary new];
    }
  return self;
}

- (NSString *) parseText: (xmlNodePtr)node
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

- (NSString *) parseText: (xmlNodePtr)node end: (xmlNodePtr *)endNode
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
  NSString		*projectName;
  NSMutableDictionary	*fileReferences;
  NSMutableDictionary	*generalReferences;
  NSMutableDictionary	*variablesDictionary;
  NSString		*currentClassName;
  NSString		*currentCategoryName;
  NSString		*currentProtocolName;
  NSString		*currentEOModel;
  NSString		*currentEOEntity;
  NSString		*currentEORelationship;
  NSString		*currentEORelationshipDestinationEntity;
  NSArray		*typesTypes;
  NSArray		*classesTypes;
  NSArray		*protocolsTypes;
  NSArray		*filesTypes;
  NSArray		*adaptorsTypes;
  NSArray		*EOModelsTypes;
  NSArray		*EOEntitiesTypes;
  NSArray		*EOClassPropertiesTypes;
  NSArray		*EORelationshipsTypes;
  BOOL			writeFlag;
  BOOL			processFileReferencesFlag;
}
- (NSString *) addLink: (NSString *)ref withText: (NSString *)text;
- (void) appendContents: (NSArray *)array toString: (NSMutableString *)text;
- (void) appendFootnotesToString: (NSMutableString *)text;
- (void) appendIndex: (NSString *)type toString: (NSMutableString *)text;
- (NSArray *) contents;
- (NSDictionary *) fileReferences;
- (NSDictionary *) findSymbolForKey: (NSString *)key
			   ofTypes: (NSArray *)types;
- (NSString *) linkForSymbol: (NSDictionary *)symbol
				 withText: (NSString *)text;
- (NSString *) linkForSymbolKey: (NSString *)key
		       ofTypes: (NSArray *)types
		      withText: (NSString *)text;
- (NSString *) linkedItem: (NSString *)item
		 ofTypes: (NSArray *)types;
- (NSString *) parseAuthor: (xmlNodePtr)node;
- (NSString *) parseBlock: (xmlNodePtr)node;
- (NSString *) parseBody: (xmlNodePtr)node;
- (NSString *) parseChapter: (xmlNodePtr)node contents: (NSMutableArray *)array;
- (NSString *) parseDef: (xmlNodePtr)node;
- (NSString *) parseDesc: (xmlNodePtr)node;
- (NSString *) parseDocument;
- (NSString *) parseEmbed: (xmlNodePtr)node;
- (NSString *) parseExample: (xmlNodePtr)node;
- (NSString *) parseFunction: (xmlNodePtr)node;
- (NSString *) parseHead: (xmlNodePtr)node;
- (NSString *) parseItem: (xmlNodePtr)node;
- (NSString *) parseList: (xmlNodePtr)node;
- (NSString *) parseVariable: (xmlNodePtr)node;
- (NSString *) parseIVariable: (xmlNodePtr)node;
- (NSString *) parseConstant: (xmlNodePtr)node;
- (NSString *) parseMacro: (xmlNodePtr)node;
- (NSString *) parseMethod: (xmlNodePtr)node;
- (NSArray *) parseStandards: (xmlNodePtr)node;
- (NSString *) parseText: (xmlNodePtr)node end: (xmlNodePtr *)endNode;
- (NSString *) parseDictionary: (xmlNodePtr)node;
- (NSString *) parseEOModel: (xmlNodePtr)node;
- (NSString *) parseEOEntity: (xmlNodePtr)node;
- (NSString *) parseEOAttribute: (xmlNodePtr)node;
- (NSString *) parseEOAttributeRef: (xmlNodePtr)node;
- (NSString *) parseEORelationship: (xmlNodePtr)node;
- (NSString *) parseEORelationshipComponent: (xmlNodePtr)node;
- (NSString *) parseEOJoin: (xmlNodePtr)node;
- (void) setEntry: (NSString *)entry
  withExternalCompleteRef: (NSString *)externalCompleteRef
	  withExternalRef: (NSString *)externalRef
		  withRef: (NSString *)ref
	    inIndexOfType: (NSString *)type;
- (void) setGeneralReferences: (NSDictionary *)dict;
- (void) setProcessFileReferencesFlag: (BOOL)flag;
- (void) setProjectName: (NSString *)projectName;
- (void) setVariablesDictionary: (NSDictionary *)dict;
- (void) setWriteFlag: (BOOL)flag;
@end

// ====================================================================
@implementation	GSDocHtml

- (id) init
{
  if ((self = [super init]) == nil)
    {
      writeFlag = YES;
      processFileReferencesFlag = YES;
      typesTypes
	= [NSArray arrayWithObjects: @"type", @"class", @"define", nil];
      RETAIN(typesTypes);
      classesTypes = [NSArray arrayWithObjects: @"class", @"define", nil];
      RETAIN(classesTypes);
      protocolsTypes = [NSArray arrayWithObjects: @"protocol", @"define", nil];
      RETAIN(protocolsTypes);
      filesTypes = [NSArray arrayWithObjects: @"file", nil];
      RETAIN(filesTypes);
      adaptorsTypes = [NSArray arrayWithObjects: @"db-adaptor", nil];
      RETAIN(adaptorsTypes);
      EOModelsTypes = [NSArray arrayWithObjects: @"EOModel", nil];
      RETAIN(EOModelsTypes);
      EOEntitiesTypes = [NSArray arrayWithObjects: @"EOEntity", nil];
      RETAIN(EOEntitiesTypes);
      EOClassPropertiesTypes
	= [NSArray arrayWithObjects: @"EOAttribute", @"EORelationship", nil];
      RETAIN(EOClassPropertiesTypes);
      EORelationshipsTypes = [NSArray arrayWithObjects: @"EORelationship", nil];
      RETAIN(EORelationshipsTypes);
    }
  return self;
}

- (NSString *) addLink: (NSString *)ref withText: (NSString *)text
{
  NSString	*file = [refToFile objectForKey: ref];

  if (file == nil)
    {
      return [NSString stringWithFormat: @"<a href =\"#%@\">%@</a>", ref, text];
    }
  else
    {
      return [NSString stringWithFormat: @"<a href =\"%@#%@\">%@</a>",
	file, ref, text];
    }
}

- (void) appendContents: (NSArray *)array toString: (NSMutableString *)text
{
  unsigned	count = [array count];

  if (count> 0)
    {
      unsigned	i;

      [text appendString: @"<ul>\r\n"];
      for (i = 0; i < count; i++)
	{
	  NSDictionary	*dict = [array objectAtIndex: i];
	  NSString	*title = [dict objectForKey: @"Title"];
	  NSString	*ref = [dict objectForKey: @"Ref"];
	  NSArray	*sub = [dict objectForKey: @"Contents"];

	  [text appendFormat: @"<li >%@\r\n",
	    [self addLink: ref withText: title]];
	  [self appendContents: sub toString: text];
	}
      [text appendString: @"</ul>\r\n"];
    }
}

- (void) appendFootnotesToString: (NSMutableString *)text
{
  unsigned	count = [footnotes count];

  if (count> 0)
    {
      unsigned	i;

      [text appendString: @"<h2>Footnotes </h2>\r\n"];
      for (i = 0; i < count; i++)
	{
	  NSString	*note = [footnotes objectAtIndex: i];
	  NSString	*ref = [NSString stringWithFormat: @"foot-%u", i];


	  [text appendFormat:
	    @"<a name =\"%@\">footnote %u </a> -\r\n", ref, i];
	  [text appendString: note];
	  [text appendString: @"<hr>\r\n"];
	}
    }
}

- (void) appendIndex: (NSString *)type toString: (NSMutableString *)text
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

      [text appendFormat: @"<li >%@\r\n",
			[self addLink: key withText: name]];
    }
  [text appendString: @"</ul>\r\n"];
}

- (void) dealloc
{
  DESTROY(contents);
  DESTROY(footnotes);
  DESTROY(projectName);
  DESTROY(fileReferences);
  DESTROY(generalReferences);
  DESTROY(variablesDictionary);
  DESTROY(currentClassName);
  DESTROY(currentCategoryName);
  DESTROY(currentProtocolName);
  DESTROY(currentEOModel);
  DESTROY(currentEOEntity);
  DESTROY(currentEORelationship);
  DESTROY(currentEORelationshipDestinationEntity);
  DESTROY(typesTypes);
  DESTROY(classesTypes);
  DESTROY(protocolsTypes);
  DESTROY(filesTypes);
  DESTROY(adaptorsTypes);
  DESTROY(EOModelsTypes);
  DESTROY(EOEntitiesTypes);
  DESTROY(EOClassPropertiesTypes);
  DESTROY(EORelationshipsTypes);
  [super dealloc];
}

- (id) initWithFileName: (NSString *)name
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
	  ASSIGN(currName,
	    [baseName stringByAppendingPathExtension: pathExtension_HTML]);
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

- (NSString *) parseAuthor: (xmlNodePtr)node
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
  NSDebugMLLog(@"debug", @"Start parsing Author name: %@", name);
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
      [text appendFormat: @"<a href =\"%@\">%@</a>\r\n", url, name];
    }
  if (email != nil)
    {
      if ([ename length] == 0)
	{
	  ename = email;
	}
      [text appendFormat: @" (<a href =\"mailto: %@\"><code>%@</code></a>)\r\n",
	email, ename];
    }
  [text appendString: @"<dd>\r\n"];
  if (desc != nil)
    {
      [text appendString: desc];
    }
  NSDebugMLLog(@"debug", @"Stop parsing Author name: %@", name);
  return text;
}

- (NSString *) parseBlock: (xmlNodePtr)node
{
  if (node == 0)
    {
      NSLog(@"nul node when expecting block");
      return nil;
    }
  NSDebugMLLog(@"debug", @"Start parsing block node->name: %s", node->name);

  if (strcmp(node->name, "class") == 0
    || strcmp(node->name, "jclass") == 0
    || strcmp(node->name, "category") == 0
    || strcmp(node->name, "protocol") == 0
    || strcmp(node->name, "function") == 0
    || strcmp(node->name, "macro") == 0
    || strcmp(node->name, "type") == 0
    || strcmp(node->name, "variable") == 0
    || strcmp(node->name, "ivariable") == 0
    || strcmp(node->name, "constant") == 0
    || strcmp(node->name, "EOModel") == 0
    || strcmp(node->name, "EOEntity") == 0)
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

  if (strcmp(node->name, "dictionary") == 0)
    {
      return [self parseDictionary: node];
    }

  NSLog(@"unknown block type - %s", node->name);
  return nil;
}

- (NSString *) parseBody: (xmlNodePtr)node
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

  NSDebugMLLog(@"debug", @"Start parsing body");

  node = node->children;
  /*
   * Parse the front (unnumbered chapters) storing the html for each
   *chapter as a separate string in the 'front' array.
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
   *chapter as a separate string in the 'body' array.
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
   *chapter as a separate string in the 'back' array.
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
   *document structure and can output a contents list.
   */
  if (needContents)
    {
      [text appendString: @"<h1>Contents </h1>\r\n"];
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
	  [text appendFormat: @"<h1>%@ index </h1>\r\n", type];
	  [self appendIndex: type toString: text];
	}
      node = node->next;
    }
  [self appendFootnotesToString: text];
  [text appendString: @"</body>\r\n"];
  NSDebugMLLog(@"debug", @"Stop parsing body");
  RELEASE(arp);
  return text;
}

- (NSString *) parseChapter: (xmlNodePtr)node contents: (NSMutableArray *)array
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableString	*text = [NSMutableString string];
  const char		*type = node->name;
  const char		*next;
  const char		*h;
  NSString		*head;
  NSString		*ref;
  NSString *nodeId = nil;
  NSMutableDictionary	*dict;
  NSMutableArray	*subs;
  NSDebugMLLog(@"debug", @"Start parsing chapter");

  nodeId = [self getProp: "id" fromNode: node];
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

  if (!nodeId || ([nodeId length] > 0 && ![nodeId isEqual: @"#"]))
    {
      NSString	*ref;

      ref = [NSString stringWithFormat: @"%@##%@##%@",
	projectName, currName, head];
      [self setEntry: head
	withExternalCompleteRef: ref
	withExternalRef: head
	withRef: ref
	inIndexOfType: [NSString stringWithCString: type]];
    }

  /*
   * Build content information and add it to the array at this level.
   */
  subs = [NSMutableArray new];
  dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    head, @"Title", ref, @"Ref", subs, @"Contents", nil];
  RELEASE(subs);
  [array addObject: dict];

  /*
   * Put heading in string.
   */
  [text appendFormat: @"<%s><a name =\"%@\">%@</a></%s>\r\n", h, ref, head, h];

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
  NSDebugMLLog(@"debug", @"Stop parsing chapter");
  RELEASE(arp);
  return text;
}

- (NSString *) parseDef: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];

  NSDebugMLLog(@"debug", @"Start parsing def");

  if ((strcmp(node->name, "class") == 0)
    || (strcmp(node->name, "jclass") == 0))
    {
      NSString		*className = [self getProp: "name" fromNode: node];
      NSString		*superName = [self getProp: "super" fromNode: node];
      NSString		*ref = [self getProp: "id" fromNode: node];
      NSString		*declared = nil;
      NSString		*desc = nil;
      NSMutableArray	*conform = [NSMutableArray array];
      NSMutableArray	*ivariables = [NSMutableArray array];
      NSMutableArray	*factoryMethods = [NSMutableArray array];
      NSMutableArray	*instanceMethods = [NSMutableArray array];
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
      // We're working on "className"
      ASSIGN(currentClassName, className);

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
	  NSString	*s = [self parseIVariable: node];
	  if (s != nil)
	    {
	      [ivariables addObject: s];
	    }
	  node = node->next;
	}

      while (node != 0 && ((strcmp(node->name, "method") == 0)
	|| (strcmp(node->name, "jmethod") == 0)))
	{
	  BOOL		factoryMethod;
	  NSString	*s;

	  factoryMethod = [[self getProp: "factory" fromNode: node] boolValue];
	  s = [self parseMethod: node];

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
	withExternalCompleteRef: className
	withExternalRef: className
	withRef: ref
	inIndexOfType: @"class"];
      [text appendFormat: @"<h2><a name =\"%@\">%@</a></h2>\r\n",
	ref, className];
      if (declared != nil)
	{
	  [text appendFormat: @"<p><b>Declared in: </b> %@</p>\r\n", declared];
	}
      if (superName != nil)
	{
	  [text appendFormat: @"<p><b>Inherits from: </b> %@</p>\r\n",
	    [self linkedItem: superName ofTypes: classesTypes]];
	}
      if ([conform count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<p><b>Conforms to: </b>"];
	  for (i = 0; i < [conform count]; i++)
	    {
	      NSString	*conformItem = [conform objectAtIndex: i];

	      conformItem = [self linkedItem: conformItem
				     ofTypes: protocolsTypes];
	      [text appendFormat: @"%@ %@\r\n", (i > 0 ? @", " : @""),
		conformItem];
	    }
	  [text appendString: @"</p>\r\n"];
	}
      if ([standards count] > 0)
	{
	  unsigned	i;

	  [text appendFormat: @"<p><b>Standards: </b> %@\r\n",
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

      [text appendString: @"<h2>Instance Variables </h2>\r\n"];
      [self appendIndex: @"ivariable" toString: text];

      [text appendString: @"<h2>Methods </h2>\r\n"];
      [self appendIndex: @"method" toString: text];

      if ([ivariables count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr><h2>Instance Variables </h2>\r\n"];
	  for (i = 0; i < [ivariables count]; i++)
	    {
	      [text appendString: [ivariables objectAtIndex: i]];
	    }
	}

      if ([factoryMethods count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr><h2>Class Methods </h2>\r\n"];
	  for (i = 0; i < [factoryMethods count]; i++)
	    {
	      [text appendString: [factoryMethods objectAtIndex: i]];
	    }
	}

      if ([instanceMethods count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr><h2>Instances Methods </h2>\r\n"];
	  for (i = 0; i < [instanceMethods count]; i++)
	    {
	      [text appendString: [instanceMethods objectAtIndex: i]];
	    }
	}

      // We've finished working on "className"
      ASSIGN(currentClassName, nil);
      return text;
    }
  else if (strcmp(node->name, "category") == 0)
    {
      NSString		*className = [self getProp: "class" fromNode: node];
      NSString		*catName = [self getProp: "name" fromNode: node];
      NSString		*ref = [self getProp: "id" fromNode: node];
      NSString		*declared = nil;
      NSString		*desc = nil;
      NSMutableArray	*conform = [NSMutableArray array];
      NSMutableArray	*factoryMethods = [NSMutableArray array];
      NSMutableArray	*instanceMethods = [NSMutableArray array];
      NSMutableArray	*standards = [NSMutableArray array];
      NSString		*name;
      NSString		*eref;

      if (className == nil || catName == nil)
	{
	  NSLog(@"Missing category or class name");
	  return nil;
	}
      name = [NSString stringWithFormat: @"%@ (%@)", className, catName];
      if (ref == nil)
	{
	  ref = name;
	}

      // We works on a class & category
      ASSIGN(currentClassName, className);
      ASSIGN(currentCategoryName, catName);
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

      while (node != 0 && strcmp(node->name, "method") == 0)
	{
	  BOOL		factoryMethod;
	  NSString	*s;

	  factoryMethod = [[self getProp: "factory" fromNode: node] boolValue];
	  s = [self parseMethod: node];
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

      eref = [NSString stringWithFormat: @"%@(%@)", className, catName];
      [self setEntry: name
	withExternalCompleteRef: eref
		withExternalRef: eref
			withRef: ref
		  inIndexOfType: @"category"];

      [text appendFormat: @"<h2>%@ <a name =\"%@\">(%@) </a></h2>\r\n",
	[self linkedItem: className ofTypes: classesTypes], ref, catName];
      if (declared != nil)
	{
	  [text appendFormat: @"<p><b>Declared in: </b> %@</p>\r\n", declared];
	}
      if ([conform count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<p><b>Conforms to: </b>\r\n"];
	  for (i = 0; i < [conform count]; i++)
	    {
	      NSString	*conformItem = [conform objectAtIndex: i];

	      conformItem = [self linkedItem: conformItem
				     ofTypes: protocolsTypes];
	      [text appendFormat: @"%@ %@\r\n", (i > 0 ? @", " : @""),
		conformItem];
	    }
	  [text appendString: @"</p>\r\n"];
	}
      if ([standards count] > 0)
	{
	  unsigned	i;

	  [text appendFormat: @"<p><b>Standards: </b> %@\r\n",
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

      [text appendString: @"<h2>Methods </h2>\r\n"];
      [self appendIndex: @"method" toString: text];

      if ([factoryMethods count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr><h2>Class Methods </h2>\r\n"];
	  for (i = 0; i < [factoryMethods count]; i++)
	    {
	      [text appendString: [factoryMethods objectAtIndex: i]];
	    }
	}

      if ([instanceMethods count] > 0)
	{
	  unsigned	i;

	  [text appendString: @"<hr><h2>Instances Methods </h2>\r\n"];
	  for (i = 0; i < [instanceMethods count]; i++)
	    {
	      [text appendString: [instanceMethods objectAtIndex: i]];
	    }
	}
      // We've finished working on this class/category
      ASSIGN(currentClassName, nil);
      ASSIGN(currentCategoryName, nil);
      return text;
    }
  else if (strcmp(node->name, "protocol") == 0)
    {
      NSString		*protName = [self getProp: "name" fromNode: node];
      NSString		*ref = [self getProp: "id" fromNode: node];
      NSString		*declared = nil;
      NSString		*desc = nil;
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
      ASSIGN(currentProtocolName, protName);
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
	withExternalCompleteRef: protName
	withExternalRef: protName
	withRef: ref
	inIndexOfType: @"protocol"];
      [text appendFormat: @"<h2><a name =\"%@\">%@ Protocol </a></h2>\r\n",
	ref, protName];
      if (declared != nil)
	{
	  [text appendFormat: @"<p><b>Declared in: </b> %@</p>\r\n", declared];
	}
      if ([standards count] > 0)
	{
	  unsigned	i;

	  [text appendFormat: @"<p><b>Standards: </b> %@\r\n",
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
      ASSIGN(currentProtocolName, nil);
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
      NSString		*typeName = [self getProp: "name" fromNode: node];
      NSString		*ref = [self getProp: "id" fromNode: node];
      NSString		*declared = nil;
      NSString		*desc = nil;
      NSString		*spec = nil;
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
	withExternalCompleteRef: typeName
	withExternalRef: typeName
	withRef: ref inIndexOfType: @"type"];
      [text appendFormat: @"<h3><a name =\"%@\">%@</a></h3>\r\n",
	ref, typeName];
      if (declared != nil)
	{
	  [text appendFormat: @"<p><b>Declared in: </b> %@</p>\r\n", declared];
	}
      if ([standards count] > 0)
	{
	  unsigned	i;

	  [text appendFormat: @"<p><b>Standards: </b> %@\r\n",
	    [standards objectAtIndex: 0]];
	  for (i = 1; i < [standards count]; i++)
	    {
	      [text appendFormat: @", %@\r\n", [standards objectAtIndex: i]];
	    }
	  [text appendString: @"</p>\r\n"];
	}

      [text appendFormat: @"<b>typedef </b> %@ %@<br>\r\n", spec, typeName];

      if (desc != nil)
	{
	  [text appendFormat: @"\r\n%@\r\n <hr>\r\n", desc];
	}

      return text;
    }
  else if (strcmp(node->name, "variable") == 0)
    {
      return [self parseVariable: node];
    }
  else if (strcmp(node->name, "constant") == 0)
    {
      return [self parseConstant: node];
    }
  else if (strcmp(node->name, "EOModel") == 0)
    {
      return [self parseEOModel: node];
    }
  else if (strcmp(node->name, "EOEntity") == 0)
    {
      return [self parseEOEntity: node];
    }
  else
    {
      NSLog(@"Definition of unknown type - %s", node->name);
      return nil;
    }
}

- (NSString *) parseDesc: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSDebugMLLog(@"debug", @"Start parsing desc");

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
	   *it failed we need to advance ourselves.
	   */
	  if (node == old)
	    node = node->next;
	  continue;
	}

      node = node->next;
    }
  return text;
}

- (NSString *) parseDocument
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

  text = [NSString stringWithFormat: @"<html>%@%@\r\n </html>\r\n", head, body];

  // Don't write result if !writeFlag
  if (writeFlag && [defs boolForKey: @"Monolithic"] == YES)
    {
      // Replace "UserVariables" in text
      text = textByReplacingVariablesInText(text, variablesDictionary);

      // Write the result
      [text writeToFile: currName atomically: YES];
    }

  return text;
}

- (NSString *) parseEmbed: (xmlNodePtr)node
{
  return @"An Embed";
}

- (NSString *) parseExample: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*elem = [self parseText: node->children];
  NSString		*ref = [self getProp: "id" fromNode: node];
  NSString		*cap = [self getProp: "caption" fromNode: node];
  NSDebugMLLog(@"debug", @"Start parsing example");

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
	withExternalCompleteRef: nil
	withExternalRef: nil
	withRef: ref
	inIndexOfType: @"label"];
      [text appendFormat: @"<a name =\"%@\">example </a>\r\n", ref];
    }
  else
    {
      [self setEntry: cap
	withExternalCompleteRef: nil
	withExternalRef: nil
	withRef: ref
	inIndexOfType: @"label"];
      [text appendFormat: @"<a name =\"%@\">%@</a>\r\n", ref, cap];
    }
  [text appendFormat: @"<pre>\r\n%@\r\n </pre>\r\n", elem];
  return text;
}

- (NSString *) parseFunction: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*ref = [self getProp: "id" fromNode: node];
  NSString		*type = [self getProp: "type" fromNode: node];
  NSString		*name = [self getProp: "name" fromNode: node];
  NSString		*desc = nil;
  NSString		*declared = nil;
  NSMutableString	*args = [NSMutableString stringWithString: @"("];

  NSDebugMLLog(@"debug", @"Start parsing function");

  if (ref == nil)
    {
      ref = [NSString stringWithFormat: @"function-%u", labelIndex++];
    }
  if (type == nil)
    {
      type = @"int";
    }
  //Avoid ((xxx))
  else if ([type hasPrefix: @"("] && [type hasSuffix: @")"])
    {
      type = [[type stringWithoutPrefix: @"("] stringWithoutSuffix: @")"];
    }
  type = [self linkedItem: type ofTypes: typesTypes];

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
	  if ([typ hasPrefix: @"("] && [typ hasSuffix: @")"])
	    {
	      typ = [[typ stringWithoutPrefix: @"("] stringWithoutSuffix: @")"];
	    }
	  typ = [self linkedItem: typ ofTypes: typesTypes];
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
    withExternalCompleteRef: name
    withExternalRef: name
    withRef: ref
    inIndexOfType: @"function"];
  [text appendFormat: @"<h2><a name =\"%@\">%@</a></h2>\r\n", ref, name];
  if (declared != nil)
    {
      [text appendFormat: @"<p><b>Declared in: </b> %@</p>\r\n", declared];
    }
  [text appendFormat: @"<b>Prototype: </b> %@ %@%@<br>\r\n", type, name, args];

  if (desc != nil)
    {
      [text appendString: desc];
    }
  [text appendString: @"\r\n <hr>\r\n"];

  return text;
}

- (NSString *) parseHead: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*abstract;
  NSString		*title;
  NSString		*copyright;
  NSString		*date;
  NSString		*version;
  BOOL			hadAuthor = NO;
  NSDebugMLLog(@"debug", @"Start parsing head");

  node = node->children;

  if (node == 0 || strcmp(node->name, "title") != 0
    || (title = [self parseText: node->children]) == nil)
    {
      NSLog(@"head without title");
      return nil;
    }
  [text appendFormat: @"<head>\r\n <title>%@</title>\r\n", title];

  [self setEntry: title
    withExternalCompleteRef: [currName stringByDeletingPathExtension]
    withExternalRef: [currName stringByDeletingPathExtension]
    withRef: [currName stringByDeletingPathExtension]
    inIndexOfType: @"file"];

  if ([styleSheetURL length] > 0)
    {
      [text appendFormat:
	@"<link rel = stylesheet type =\"text/css\" href =\"%@\">\r\n",
	styleSheetURL];
    }

  [text appendString: @"</head>\r\n"];
  [text appendString: @"<body>\r\n"];
  if ([prevName length] > 0)
    {
      //Avoid empty link
      NSString	*test;

      test = textByReplacingVariablesInText(prevName, variablesDictionary);
      if ([test length] > 0)
	{
	  if ([[prevName pathExtension] isEqual: pathExtension_HTML] == YES)
	    {
	      [text appendFormat: @"<a href =\"%@\">[Previous] </a>\n",
		prevName];
	    }
	  else
	    {
	      [text appendFormat: @"<a href =\"%@.html\">[Previous] </a>\n",
		prevName];
	    }
	}
    }
  if ([upName length] > 0)
    {
      NSString	*test;

      test = textByReplacingVariablesInText(upName, variablesDictionary);
      if ([test length] > 0)
	{
	  if ([[upName pathExtension] isEqual: pathExtension_HTML] == YES)
	    {
	      [text appendFormat: @"<a href =\"%@\">[Up] </a>\n", upName];
	    }
	  else
	    {
	      [text appendFormat: @"<a href =\"%@.html\">[Up] </a>\n", upName];
	    }
	}
    }
  if ([nextName length] > 0)
    {
      //Avoid empty link
      NSString	*test;

      test = textByReplacingVariablesInText(nextName, variablesDictionary);
      if ([test length] > 0)
	{
	  if ([[nextName pathExtension] isEqual: pathExtension_HTML] == YES)
	    {
	      [text appendFormat: @"<a href =\"%@\">[Next] </a>\n", nextName];
	    }
	  else
	    {
	      [text appendFormat: @"<a href =\"%@.html\">[Next] </a>\n",
		nextName];
	    }
	}
    }

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
	  [text appendString: @"<h3>Authors </h3>\r\n <dl>\r\n"];
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

- (NSString *) parseItem: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];

  NSDebugMLLog(@"debug", @"Start parsing item");
  node = node->children;

  while (node != 0)
    {
      BOOL	step = YES;

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
	  [text appendString: [self parseDef: node]];
	}
      else if (strcmp(node->name, "list") == 0
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
	      [text appendFormat: @"<p>\r\n%@</p>\r\n", elem];
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
	  [text appendString: [self parseText: node end: &node]];
	  step = NO;
	}
      if (step == YES)
	node = node->next;
    }
  return text;
}

- (NSString *) parseList: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];

  if (strcmp(node->name, "list") == 0)
    {
      [text appendString: @"<ul>\r\n"];
      node = node->children;
      while (node != 0 && strcmp(node->name, "item") == 0)
	{
	  [text appendFormat: @"<li >%@\r\n", [self parseItem: node]];
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
	  [text appendFormat: @"<li >%@\r\n", [self parseItem: node]];
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
- (NSString *) parseVariable: (xmlNodePtr)variableNode
		 orConstant: (xmlNodePtr)constantNode
		     ofType: (NSString *)indexType
{
  xmlNodePtr		node = (variableNode ? variableNode : constantNode);
  NSMutableString	*text = [NSMutableString string];
  NSString		*name = [self getProp: "name" fromNode: node];
  NSString		*type
    = variableNode ? [self getProp: "type" fromNode: node] : nil;
  NSString		*posttype
    = variableNode ? [self getProp: "posttype" fromNode: node] : nil;
  NSString		*value = [self getProp: "value" fromNode: node];
  NSString		*role = [self getProp: "role" fromNode: node];
  NSString		*ref = [self getProp: "id" fromNode: node];
  NSString		*declared = nil;
  NSString		*desc = nil;
  NSMutableArray	*standards = [NSMutableArray array];
  NSString  		*completeRefName = nil;
  NSString		*linkedType = nil;

  NSDebugMLLog(@"debug", @"Start parsing variable/constant");

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

  if (type)
    {
      linkedType = [self linkedItem: type ofTypes: typesTypes];
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
    {
      completeRefName
	= [NSString stringWithFormat: @"%@::%@", currentClassName, name];
    }
  else
    {
      completeRefName = name;
    }

  [self setEntry: name
    withExternalCompleteRef: completeRefName
    withExternalRef: name
    withRef: ref
    inIndexOfType: indexType];

  [text appendFormat: @"<h2><a name =\"%@\">%@</a></h2>\r\n", ref, name];
  if (declared != nil)
    {
      [text appendFormat: @"<p><b>Declared in: </b> %@</p>\r\n", declared];
    }
  if ([standards count] > 0)
    {
      unsigned	i;

      [text appendFormat: @"<p><b>Standards: </b> %@\r\n",
		    [standards objectAtIndex: 0]];
      for (i = 1; i < [standards count]; i++)
	{
	  [text appendFormat: @", %@\r\n", [standards objectAtIndex: i]];
	}
      [text appendString: @"</p>\r\n"];
    }

  if ([role isEqual: @"except"])
    {
      [text appendString: @"<p>Exception name </p>\r\n"];
    }
  else if ([role isEqual: @"defaults"])
    {
      [text appendString: @"<p>Defaults system key </p>\r\n"];
    }
  else if ([role isEqual: @"notify"])
    {
      [text appendString: @"<p>Notification name </p>\r\n"];
    }
  else if ([role isEqual: @"key"])
    {
      [text appendString: @"<p>Dictionary key </p>\r\n"];
    }

  if (value == nil)
    {
      [text appendFormat: @"%@ <b>%@</b>%@<br>\r\n",
	linkedType ? linkedType : @"", name, (posttype ? posttype : @"")];
    }
  else
    {
      [text appendFormat: @"%@ <b>%@</b>%@ = %@<br>\r\n",
	linkedType ? linkedType : @"", name, (posttype ? posttype : @""),
	value];
    }

  if (desc != nil)
    {
      [text appendFormat: @"\r\n%@\r\n", desc];
    }

  return text;
}

//Parse Variable
- (NSString *) parseVariable: (xmlNodePtr)node
{
  NSDebugMLLog(@"debug", @"Start parsing variable");
  return [self parseVariable: node
		  orConstant: NULL
		      ofType: @"variable"];
}

//Parse Instance Variable
- (NSString *) parseIVariable: (xmlNodePtr)node
{
  NSDebugMLLog(@"debug", @"Start parsing ivar");
  return [self parseVariable: node
		  orConstant: NULL
		      ofType: @"ivariable"];
}

// Parse Constant
- (NSString *) parseConstant: (xmlNodePtr)node
{
  NSDebugMLLog(@"debug", @"Start parsing constant");
  return [self parseVariable: NULL
		  orConstant: node
		      ofType: @"constant"];
}

- (NSString *) parseMacro: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*ref = [self getProp: "id" fromNode: node];
  NSString		*name = [self getProp: "name" fromNode: node];
  NSString		*desc = nil;
  NSString		*declared = nil;
  NSMutableString	*args = [NSMutableString stringWithString: @"("];

  NSDebugMLLog(@"debug", @"Start parsing macro");

  if (ref == nil)
    {
      ref = [NSString stringWithFormat: @"macro-%u", labelIndex++];
    }

  node = node->children;
  while (node != 0 && strcmp(node->name, "arg") == 0)
    {
      NSString	*arg = [self parseText: node->children];
      NSString	*typ = [self getProp: "type" fromNode: node];

      if (arg == nil)
	{
	  return nil;
	}
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
    withExternalCompleteRef: name
    withExternalRef: name
    withRef: ref
    inIndexOfType: @"macro"];
  [text appendFormat: @"<h3><a name =\"%@\">%@</a></h3>\r\n", ref, name];
  if (declared != nil)
    {
      [text appendFormat: @"<p><b>Declared in: </b> %@</p>\r\n", declared];
    }
  if (args == nil)
    {
      [text appendFormat: @"<b>Declaration: </b> %@<br>\r\n", name];
    }
  else
    {
      [text appendFormat: @"<b>Declaration: </b> %@%@<br>\r\n", name, args];
    }

  if (desc != nil)
    {
      [text appendString: desc];
    }
  [text appendString: @"\r\n <hr>\r\n"];

  return text;
}

- (NSString *) parseMethod: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*ref = [self getProp: "id" fromNode: node];
  NSString		*type = [self getProp: "type" fromNode: node];
  NSString		*over = [self getProp: "override" fromNode: node];
  BOOL			factory
    = [[self getProp: "factory" fromNode: node] boolValue];
  BOOL			desInit
    = [[self getProp: "init" fromNode: node] boolValue];
  NSMutableString	*lText = [NSMutableString string];
  NSMutableString	*sText = [NSMutableString string];
  BOOL			isJava = (strcmp(node->name, "jmethod") == 0);
  NSString		*desc = nil;
  NSArray		*standards = nil;
  NSString  		*methodBlockName = nil;

  NSDebugMLLog(@"debug", @"Start parsing method");

  if (currentCategoryName)
    {
      NSAssert(currentClassName, @"No Class Name");
      methodBlockName = currentClassName;
    }
  else if (currentClassName)
    {
      methodBlockName = currentClassName;
    }
  else if (currentProtocolName)
    {
      methodBlockName = currentProtocolName;
    }
  else
    {
      methodBlockName = @"unknown";
    }
  NSAssert(methodBlockName, @"No methodBlockName");

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
	{
	  type = @"Object";
	}
	  //Avoid ((xxx))
      else if ([type hasPrefix: @"("] && [type hasSuffix: @")"])
	{
	  type = [[type stringWithoutPrefix: @"("] stringWithoutSuffix: @")"];
	}
      type = [self linkedItem: type ofTypes: typesTypes];
      [decl appendString: type];
      [decl appendString: @" "];

      node = node->children;

      while (node != 0 && strcmp(node->name, "arg") == 0)
	{
	  NSString	*arg = [self parseText: node->children];
	  NSString	*typ = [self getProp: "type" fromNode: node];

	  if (arg == nil)
	    {
	      break;
	    }
	  if ([args length] > 1)
	    {
	      [args appendString: @", "];
	    }
	  if (typ != nil)
	    {
	      //Avoid ((xxx))
	      if ([typ hasPrefix: @"("] && [typ hasSuffix: @")"])
		{
		  typ = [typ stringWithoutPrefix: @"("];
		  typ = [typ stringWithoutSuffix: @")"];
		}
	      typ = [self linkedItem: typ ofTypes: typesTypes];
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
	{
	  type = @"id";
	}
	  //Avoid ((xxx))
      else if ([type hasPrefix: @"("] && [type hasSuffix: @")"])
	{
	  type = [type stringWithoutPrefix: @"("];
	  type = [type stringWithoutSuffix: @")"];
	}
      type = [self linkedItem: type ofTypes: typesTypes];
      [lText appendString: type];
      [lText appendString: @")"];

      node = node->children;
      while (node != 0 && strcmp(node->name, "sel") == 0)
	{
	  NSString	*sel = [self parseText: node->children];

	  if (sel == nil)
	    {
	      return nil;
	    }
	  [sText appendString: sel];
	  [lText appendFormat: @" <b>%@</b>", sel];
	  node = node->next;
	  if (node != 0 && strcmp(node->name, "arg") == 0)
	    {
	      NSString	*arg = [self parseText: node->children];
	      NSString	*typ = [self getProp: "type" fromNode: node];

	      if (arg == nil)
		{
		  return nil;
		}
	      if (typ != nil)
		{
		  //Avoid ((xxx))
		  if ([typ hasPrefix: @"("] && [typ hasSuffix: @")"])
		    {
		      typ = [typ stringWithoutPrefix: @"("];
		      typ = [typ stringWithoutSuffix: @")"];
		    }
		  typ = [self linkedItem: typ ofTypes: typesTypes];
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
      NSString	*eref;

      eref = [NSString stringWithFormat: @"%@::%@", methodBlockName, sText];
      [self setEntry: sText
	withExternalCompleteRef: eref
	withExternalRef: eref
	withRef: ref
	inIndexOfType: @"method"];
    }
  else
    {
      if (factory)
	{
	  NSString	*s = [@"+" stringByAppendingString: sText];
	  NSString	*eref;

	  eref
	    = [NSString stringWithFormat: @"+%@::%@", methodBlockName, sText];
	  [self setEntry: s
	    withExternalCompleteRef: eref
	    withExternalRef: eref
	    withRef: ref
	    inIndexOfType: @"method"];
	}
      else
	{
	  NSString	*s = [@"-" stringByAppendingString: sText];
	  NSString	*eref;

	  eref
	    = [NSString stringWithFormat: @"-%@::%@", methodBlockName, sText];

	  [self setEntry: s
	    withExternalCompleteRef: eref
	    withExternalRef: eref
	    withRef: ref
	    inIndexOfType: @"method"];
	}
    }
  [text appendFormat: @"<h3><a name =\"%@\">%@</a></h3>\r\n", ref, sText];
  if (desInit)
    {
      [text
	appendString: @"<b>This is the designated initialiser </b><br>\r\n"];
    }
  [text appendFormat: @"%@;<br>\r\n", lText];
  if ([over isEqual: @"subclass"])
    {
      [text appendString: @"Your subclass <em>must </em> override this "
			@"abstract method.<br>\r\n"];
    }
  else if ([over isEqual: @"never"])
    {
      [text appendString: @"Your subclass must <em>not </em> override this "
			@"method.<br>\r\n"];
    }
  if ([standards count] > 0)
    {
      unsigned	i;

      [text appendString: @"Standards: "];
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
  [text appendString: @"\r\n <hr>\r\n"];

  return text;
}

- (NSArray *) parseStandards: (xmlNodePtr)node
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

- (NSString *) parseText: (xmlNodePtr)node end: (xmlNodePtr *)endNode
{
  NSMutableString	*text = [NSMutableString string];

  NSDebugMLLog(@"debug", @"Start parsing text");

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
		NSString	*elem;
		NSString	*ref;

		elem = [self parseText: node->children];
		ref = [self getProp: "id" fromNode: node];
		if (ref == nil)
		  {
		    ref = [NSString stringWithFormat: @"label-%u",
						    labelIndex++];
		  }

		[self setEntry: elem
		  withExternalCompleteRef:
		    [NSString stringWithFormat: @"%@::%@", @"***unknown", elem]
		  withExternalRef:
		    [NSString stringWithFormat: @"%@::%@", @"***unknown", elem]
		  withRef: ref
		  inIndexOfType: @"label"];

		if (strcmp(node->name, "label") == 0)
		  {
		    [text appendFormat: @"<a name =\"%@\">%@</a>", ref, elem];
		  }
		else
		  {
		    [text appendFormat: @"<a name =\"%@\"></a>", ref];
		  }
	      }
	    else if (strcmp(node->name, "footnote") == 0)
	      {
		NSString	*elem;
		NSString	*ref;

		elem = [self parseText: node->children];
		ref = [NSString stringWithFormat: @"foot-%u",
						[footnotes count]];

		[self setEntry: elem
		  withExternalCompleteRef:
		    [NSString stringWithFormat: @"%@::%@", @"***unknown", elem]
		  withExternalRef:
		    [NSString stringWithFormat: @"%@::%@", @"***unknown", elem]
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
		  {
		    elem = ref;
		  }
		[text appendFormat: @"<a href =\"%@\">%@</a>", ref, elem];
	      }
	    else if (strcmp(node->name, "prjref") == 0)
	      {
		NSString *elem = [self parseText: node->children];
		NSString *prjName = [self getProp: "prjname" fromNode: node];
		NSString *prjFile = [self getProp: "file" fromNode: node];
		NSString *symbolKey = nil;
		NSString *link = nil;

		if ([prjName length]== 0)
		  {
		    prjName = projectName;
		  }
		if ([elem length] == 0)
		  {
		    elem = prjName;
		  }

		symbolKey = [NSString stringWithFormat: @"%@##%@",
		  prjName, ([prjFile length] ? prjFile : @"index")];
		link = [self linkForSymbolKey: symbolKey
				      ofTypes: filesTypes
				     withText: elem];
		[text appendString: link];
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

- (NSString *) parseDictionaryItem: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*key = [self getProp: "key" fromNode: node];
  NSString		*value = [self getProp: "value" fromNode: node];

  NSDebugMLLog(@"debug", @"Start parsing dictionaryItem");
  if (key == nil)
    {
      NSLog(@"dictionaryItem must have a key");
      return nil;
    }
  [text appendFormat: @"<LI><b>%@</b> = ", key];

  if (value == nil)
    {
      node = node->children;
      while (node != 0)
	{
	  value = [self parseBlock: node];
	  node = node->next;
	}
    }
  [text appendFormat: @"%@</LI>\n", value];
  return text;
}



- (NSString *) parseDictionary: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];

  NSDebugMLLog(@"debug", @"Start parsing dictionary");

  node = node->children;
  [text appendString: @"<UL>\n"];
  while (node && strcmp(node->name, "dictionaryItem") == 0)
    {
      NSString *itemString = [self parseDictionaryItem: node];
      [text appendString: itemString];
      node = node->next;
    }
  [text appendString: @"</UL>\n"];
  return text;
}

- (NSString *) parseEOModel: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*ref = [self getProp: "id" fromNode: node];
  NSString *modelName = [self getProp: "name" fromNode: node];
  NSString *version = [self getProp: "version" fromNode: node];
  NSString *adaptorName = [self getProp: "adaptorName" fromNode: node];
  NSString *adaptorClassName
    = [self getProp: "adaptorClassName" fromNode: node];

  NSString *desc = nil;
  NSString *connectionDictionary = nil;
  NSString *userDictionary = nil;
  NSMutableArray *entities = [NSMutableArray array];
  NSString *entitiesRefsList = nil;

  NSDebugMLLog(@"debug", @"Start parsing EOModel");

  if (modelName == nil)
    {
      NSLog(@"Missing model name");
      return nil;
    }
  // We're working on EOModel
  ASSIGN(currentEOModel, modelName);

  if (ref == nil)
    {
      ref = modelName;
    }

  node = node->children;

  if (node != 0 && strcmp(node->name, "EOConnectionDictionary") == 0)
    {
      connectionDictionary = [self parseDictionary: node];
      node = node->next;
    }

  if (node != 0 && strcmp(node->name, "list") == 0)
    {
      entitiesRefsList = [self parseList: node];
      node = node->next;
    }
  else
    {
      while (node && strcmp(node->name, "EOEntity") == 0)
	{
	  NSString	*s = [self parseEOEntity: node];

	  if (s != nil)
	    {
	      [entities addObject: s];
	    }
	  node = node->next;
	}
    }

  if (node != 0 && strcmp(node->name, "EOUserDictionary") == 0)
    {
      userDictionary = [self parseDictionary: node];
      node = node->next;
    }

  if (node != 0 && strcmp(node->name, "desc") == 0)
    {
      desc = [self parseDesc: node];
      node = node->next;
    }

  [self setEntry: modelName
    withExternalCompleteRef: modelName
    withExternalRef: modelName
    withRef: ref
    inIndexOfType: @"EOModel"];
  [text appendFormat: @"<h2><a name =\"%@\">%@</a></h2>\r\n",
    ref, modelName];

  if (version != nil)
    {
      [text appendFormat: @"<p><b>Version: </b> %@</p>\r\n", version];
    }

  if (adaptorName != nil)
    {
      [text appendFormat: @"<p><b>Adaptor: </b> %@</p>\r\n",
	[self linkedItem: adaptorName ofTypes: adaptorsTypes]];
    }

  if (adaptorClassName != nil)
    {
      [text appendFormat: @"<p><b>Adaptor Class: </b> %@</p>\r\n",
	[self linkedItem: adaptorClassName ofTypes: classesTypes]];
    }

  if (desc != nil)
    {
      [text appendFormat: @"<hr>\r\n%@\r\n", desc];
    }

  [text appendString: @"<h2>Entities </h2>\r\n"];
  [self appendIndex: @"EOEntities"
	   toString: text];
  [text appendString: @"<h2>User Dictionary </h2>\r\n"];
  [self appendIndex: @"UserDictionary"
	   toString: text];

  if (desc != nil)
    {
      [text appendFormat: @"<hr>\r\n%@\r\n", desc];
    }

  if (entitiesRefsList != nil)
    {
      [text appendString: @"<hr><h2>Entities </h2>\r\n"];
      [text appendString: entitiesRefsList];
    }
  else
    {
      if ([entities count] > 0)
	{
	  unsigned i = 0;
	  [text appendString: @"<hr><h2>Entities </h2>\r\n"];
	  for (i = 0; i < [entities count]; i++)
	    [text appendString: [entities objectAtIndex: i]];
	}
    }
  if (userDictionary != nil)
    {
      [text appendFormat: @"<hr><h2>UserDictionary </h2>\r\n%@",
	userDictionary];
    }
  // Stop working on EOModel
  ASSIGN(currentEOModel, nil);
  return text;
}

- (NSString *) parseEOEntity: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*ref = [self getProp: "id" fromNode: node];
  NSString		*entityName = [self getProp: "name" fromNode: node];
  NSString		*externalName
    = [self getProp: "externalName" fromNode: node];
  NSString		*className = [self getProp: "className" fromNode: node];
  NSString		*modelName = [self getProp: "modelName" fromNode: node];
  NSString		*isReadOnly
    = [self getProp: "isReadOnly" fromNode: node];
  NSString		*desc = nil;
  NSString		*userDictionary = nil;
  NSMutableArray	*attributes = [NSMutableArray array];
  NSMutableArray	*attributesUsedForLocking = [NSMutableArray array];
  NSMutableArray	*classProperties = [NSMutableArray array];
  NSMutableArray	*primaryKeyAttributes = [NSMutableArray array];
  NSMutableArray	*relationships = [NSMutableArray array];

  NSDebugMLLog(@"debug", @"Start parsing EOEntity");

  if (entityName != nil)
    {
      NSLog(@"Missing entity name");
      return nil;
    }

  // We're working on EOEntity
  ASSIGN(currentEOEntity, entityName);

  if (ref != nil)
    {
      ref = entityName;
    }

  node = node->children;

  while (node != 0 && strcmp(node->name, "EOAttribute") == 0)
    {
      NSString	*s = [self parseEOAttribute: node];

      if (s != nil)
	{
	  [attributes addObject: s];
	}
      node = node->next;
    }

  if (node != 0 && strcmp(node->name, "EOAttributesUsedForLocking") == 0)
    {
      xmlNodePtr attributeNode = node->children;
      while (attributeNode != 0
	&& strcmp(attributeNode->name, "EOAttributeRef") == 0)
	{
	  NSString	*s = [self parseEOAttributeRef: attributeNode];

	  if (s != nil)
	    {
	      [attributesUsedForLocking addObject: s];
	    }
	  attributeNode = attributeNode->next;
	}
      node = node->next;
    }

  if (node != 0 && strcmp(node->name, "EOClassProperties") == 0)
    {
      xmlNodePtr attributeNode = node->children;

      while (attributeNode != 0
	&& strcmp(attributeNode->name, "EOAttributeRef") == 0)
	{
	  NSString	*s = [self parseEOAttributeRef: attributeNode];

	  if (s != nil)
	    {
	      [classProperties addObject: s];
	    }
	  attributeNode = attributeNode->next;
	}
      node = node->next;
    }

  if (node != 0 && strcmp(node->name, "EOPrimaryKeyAttributes") == 0)
    {
      xmlNodePtr attributeNode = node->children;

      while (attributeNode != 0
	&& strcmp(attributeNode->name, "EOAttributeRef") == 0)
	{
	  NSString	*s = [self parseEOAttributeRef: attributeNode];

	  if (s != nil)
	    {
	      [primaryKeyAttributes addObject: s];
	    }
	  attributeNode = attributeNode->next;
	}
      node = node->next;
    }

  while (node != 0 && strcmp(node->name, "EORelationship") == 0)
    {
      NSString	*s = [self parseEORelationship: node];

      if (s != nil)
	{
	  [relationships addObject: s];
	}
      node = node->next;
    }

  if (node != 0 && strcmp(node->name, "EOUserDictionary") == 0)
    {
      userDictionary = [self parseDictionary: node];
      node = node->next;
    }

  if (node != 0 && strcmp(node->name, "desc") == 0)
    {
      desc = [self parseDesc: node];
      node = node->next;
    }

  [self setEntry: entityName
    withExternalCompleteRef: entityName
    withExternalRef: entityName
    withRef: ref
    inIndexOfType: @"EOEntity"];

  [text appendFormat: @"<hr><h2><a name =\"%@\">%@</a></h2>\r\n",
    ref, entityName];

  if (modelName != nil)
    {
      [text appendFormat: @"<p><b>Model: </b> %@</p>\r\n",
	[self linkedItem: modelName ofTypes: EOModelsTypes]];
    }

  if (externalName != nil)
    {
      [text appendFormat: @"<p><b>External Name: </b> %@</p>\r\n",
	externalName];
    }

  if (className != nil)
    {
      [text appendFormat: @"<p><b>Class: </b> %@</p>\r\n",
	[self linkedItem: className ofTypes: classesTypes]];
    }

  if (isReadOnly != nil)
    {
      [text appendFormat: @"<p><b>Read Only: </b> %@</p>\r\n",
	isReadOnly];
    }

  if (desc != nil)
    {
      [text appendFormat: @"<hr>\r\n%@\r\n", desc];
    }

  [text appendString: @"<hr>\r\n <UL>\r\n"];
  if ([attributes count] > 0)
    {
      [text appendFormat:
	@"<LI><A HREF=\"#%@__Attributes\">Attributes </A></LI>\r\n",
	entityName];
    }
  if ([attributesUsedForLocking count] > 0)
    {
      [text appendFormat:
	@"<LI><A HREF=\"#%@__AttributesUsedForLocking\">Attributes "
	@"Used For Locking </A></LI>\r\n",
	entityName];
    }
  if ([classProperties count] > 0)
    {
      [text appendFormat:
	@"<LI><A HREF=\"#%@__ClassProperties\">Class Properties </A></LI>\r\n",
	entityName];
    }
  if ([primaryKeyAttributes count] > 0)
    {
      [text appendFormat:
	@"<LI><A HREF=\"#%@__PrimaryKeyAttributes\">Primary Key "
	@"Attributes </A></LI>\r\n", entityName];
    }
  if ([relationships count] > 0)
    {
      [text appendFormat:
	@"<LI><A HREF=\"#%@__Relationships\">Relationships </A></LI>\r\n",
	entityName];
    }
  if (userDictionary != nil)
    {
      [text appendFormat:
	@"<LI><A HREF=\"#%@__UserDictionary\">User Dictionary </A></LI>\r\n",
	entityName];
    }
  [text appendString: @"</UL>\r\n"];



  if ([attributes count] > 0)
    {
      unsigned i = 0;

      [text appendFormat:
	@"<hr><h3><A NAME=\"%@__Attributes\">Attributes </A></h3>\r\n",
	entityName];
      [text appendString:
	@"<TABLE BORDER= 1>\n <TR><TH>Name </TH><TH>Entity </TH><TH>Class "
	@"Name </TH><TH>Type </TH><TH>DB Column Name / Definition </TH><TH>DB "
	@"Type </TH><TH>Properties </TH><TH>UserDictionary </TH><TH>"
	@"Description </TH></TR>\r\n"];
      for (i = 0; i < [attributes count]; i++)
	{
	  [text appendFormat: @"<TR>%@</TR>\r\n",
	    [attributes objectAtIndex: i]];
	}
      [text appendString: @"</TABLE>\r\n"];
    }

  if ([attributesUsedForLocking count] > 0)
    {
      unsigned i = 0;

      [text appendFormat: @"<hr><H3><A NAME=\"%@__AttributesUsedForLocking\">"
	@"Attributes Used For Locking </A></H3>\r\n",
	entityName];
      [text appendString: @"<TABLE BORDER=\"1\">\r\n"];
      for (i = 0; i < [attributesUsedForLocking count]; i++)
	{
	  NSString	*elem = [attributesUsedForLocking objectAtIndex: i];

	  [text appendFormat: @"<TR><TD>%@</TD></TR>\r\n",
	    [self linkForSymbolKey:
	      [NSString stringWithFormat: @"%@##%@", currentEOEntity, elem]
	      ofTypes: EOClassPropertiesTypes
	      withText: elem]];
	}
      [text appendString: @"</TABLE>\r\n"];
    }

  if ([classProperties count] > 0)
    {
      unsigned i = 0;

      [text appendFormat:
	@"<hr><H3><A NAME=\"%@__ClassProperties\">"
	@"Class Properties </A></h3>\r\n",
	entityName];
      [text appendString: @"<TABLE BORDER=\"1\">\r\n"];
      for (i = 0; i < [classProperties count]; i++)
	{
	  NSString	*elem = [classProperties objectAtIndex: i];

	  [text appendFormat: @"<TR><TD>%@</TD></TR>\r\n",
	    [self linkForSymbolKey:
	      [NSString stringWithFormat: @"%@##%@", currentEOEntity, elem]
	      ofTypes: EOClassPropertiesTypes
	      withText: elem]];
	}
      [text appendString: @"</TABLE>\r\n"];
    }

  if ([primaryKeyAttributes count] > 0)
    {
      unsigned i = 0;

      [text appendFormat: @"<hr><H3><A NAME=\"%@__PrimaryKeyAttributes\">"
	@"Primary Key Attributes </A></h3>\r\n",
	entityName];
      [text appendString: @"<TABLE BORDER=\"1\">\r\n"];
      for (i = 0; i < [primaryKeyAttributes count]; i++)
	{
	  NSString	*elem = [classProperties objectAtIndex: i];

	  [text appendFormat: @"<TR><TD>%@</TD></TR>\r\n",
	    [self linkForSymbolKey:
	      [NSString stringWithFormat: @"%@##%@", currentEOEntity, elem]
	      ofTypes: EOClassPropertiesTypes
	      withText: elem]];
	}
      [text appendString: @"</TABLE>\r\n"];
    }

  if ([relationships count] > 0)
    {
      unsigned i = 0;

      [text appendFormat: @"<hr><H3><A NAME=\"%@__Relationships\">"
	@"Relationships </A></h3>\r\n", entityName];

      [text appendString: @"<TABLE BORDER=\"1\">\r\n <TR><TH>Name </TH>"
	@"<TH>Entity </TH><TH>Destination Entity </TH><TH>Properties </TH>"
	@"<TH>Definition/Join(s) </TH><TH>User Dictionary </TH>"
	@"<TH>Description </TH></TR>\r\n"];
      for (i = 0; i < [relationships count]; i++)
	{
	  [text appendFormat: @"<TR>%@</TR>\r\n",
	    [relationships objectAtIndex: i]];
	}
      [text appendString: @"</TABLE>\r\n"];
    }

  if (userDictionary != nil)
    {
      [text appendFormat: @"<hr><H3><A NAME=\"%@__UserDictionary\">"
	@"User Dictionary </A></h3>\r\n",
	entityName];
      [text appendString: userDictionary];
    }

  // Stop working on EOEntity
  ASSIGN(currentEOEntity, nil);
  return text;
}

- (NSString *) parseEOAttribute: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*ref = [self getProp: "id" fromNode: node];
  NSString		*columnName
    = [self getProp: "columnName" fromNode: node];
  NSString		*definition
    = [self getProp: "definition" fromNode: node];
  NSString		*externalType
    = [self getProp: "externalType" fromNode: node];
  NSString		*attributeName = [self getProp: "name" fromNode: node];
  NSString		*valueClassName
    = [self getProp: "valueClassName" fromNode: node];
  NSString		*valueType = [self getProp: "valueType" fromNode: node];
  NSString		*entityName
    = [self getProp: "entityName" fromNode: node];
  NSString		*isReadOnly
    = [self getProp: "isReadOnly" fromNode: node];
  NSString		*isDerived = [self getProp: "isDerived" fromNode: node];
  NSString		*isFlattened
    = [self getProp: "isFlattened" fromNode: node];
  NSString		*desc = nil;
  NSString		*userDictionary = nil;
  NSString		*completeRef = nil;

  NSDebugMLLog(@"debug", @"Start parsing EOAttribute");

  if (!attributeName)
    {
      NSLog(@"Missing attribute name");
      return nil;
    }

  completeRef
    = [NSString stringWithFormat: @"%@##%@", currentEOEntity, attributeName];
  if (ref == nil)
    {
      ref = completeRef;
    }

  node = node->children;

  if (node && strcmp(node->name, "EOUserDictionary") == 0)
    {
      userDictionary = [self parseDictionary: node];
      node = node->next;
    }

  if (node && strcmp(node->name, "desc") == 0)
    {
      desc = [self parseDesc: node];
      node = node->next;
    }

  [self setEntry: attributeName
    withExternalCompleteRef: completeRef
    withExternalRef: completeRef
    withRef: ref
    inIndexOfType: @"EOAttribute"];

  [text appendFormat: @"<TD><b><a name =\"%@\">%@</a></b></TD>",
    ref, attributeName];

  if (entityName)
    {
      [text appendFormat: @"<TD>%@</TD>",
	[self linkedItem: entityName ofTypes: EOEntitiesTypes]];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }

  if (valueClassName)
    {
      [text appendFormat: @"<TD>%@</TD>",
	[self linkedItem: valueClassName ofTypes: classesTypes]];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }

  if (valueType)
    {
      [text appendFormat: @"<TD>%@</TD>", valueType];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }

  if (columnName)
    {
      [text appendFormat: @"<TD>%@</TD>", columnName];
    }
  else if (definition)
    {
      [text appendFormat: @"<TD>%@</TD>", definition];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }

  if (externalType)
    {
      [text appendFormat: @"<TD>%@</TD>", externalType];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }

  [text appendString: @"<TD>"];
  if (isReadOnly)
    {
      [text appendFormat: @"Read Only: %@<BR>", isReadOnly];
    }

  if (isDerived)
    {
      [text appendFormat: @"Derived: %@<BR>", isDerived];
    }

  if (isFlattened)
    {
      [text appendFormat: @"Flattened: %@<BR", isFlattened];
    }

  [text appendString: @"</TD>"];

  if (userDictionary)
    {
      [text appendFormat: @"<TD>%@</TD>", userDictionary];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }

  if (desc)
    {
      [text appendFormat: @"<TD>%@</TD>", desc];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }

  return text;
}

- (NSString *) parseEOAttributeRef: (xmlNodePtr)node
{
  NSString	*attributeName = [self getProp: "name" fromNode: node];

  NSDebugMLLog(@"debug", @"Start parsing EOAttributeRef");
  return attributeName;
}

- (NSString *) parseEORelationship: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString *ref = [self getProp: "id" fromNode: node];
  NSString *entityName = [self getProp: "entityName" fromNode: node];
  NSString *destinationEntityName
    = [self getProp: "destinationEntityName" fromNode: node];
  NSString *relationshipName = [self getProp: "name" fromNode: node];
  NSString *isToMany = [self getProp: "isToMany" fromNode: node];

  NSString *desc = nil;
  NSString *userDictionary = nil;
  NSString *definition = nil;
  NSMutableArray *joins = [NSMutableArray array];
  NSString *completeRef = nil;

  NSDebugMLLog(@"debug", @"Start parsing EORelationship");

  if (!relationshipName)
    {
      NSLog(@"Missing relationship name");
      return nil;
    }

  completeRef
    = [NSString stringWithFormat: @"%@##%@", currentEOEntity, relationshipName];

  // We're working on EORelationship
  ASSIGN(currentEORelationship, relationshipName);
  ASSIGN(currentEORelationshipDestinationEntity, destinationEntityName);

  if (ref == nil)
    ref = completeRef;

  node = node->children;

  if (node && strcmp(node->name, "EORelationshipComponent") == 0)
    {
      definition = [self parseEORelationshipComponent: node];
      node = node->next;
    }
  else
    {
      while (node && strcmp(node->name, "EOJoin") == 0)
	{
	  NSString	*s = [self parseEOJoin: node];

	  if (s)
	    {
	      [joins addObject: s];
	    }
	  node = node->next;
	}
    }

  if (node && strcmp(node->name, "EOUserDictionary") == 0)
    {
      userDictionary = [self parseDictionary: node->children];
      node = node->next;
    }

  if (node != 0 && strcmp(node->name, "desc") == 0)
    {
      desc = [self parseDesc: node];
      node = node->next;
    }

  [self setEntry: relationshipName
    withExternalCompleteRef: completeRef
    withExternalRef: completeRef
    withRef: ref
    inIndexOfType: @"EORelationship"];

  [text appendFormat: @"<TD><a name =\"%@\">%@</a></TD>",
		completeRef,
		relationshipName];

  if (entityName)
    {
      [text appendFormat: @"<TD>%@</TD>",
	[self linkedItem: entityName ofTypes: EOEntitiesTypes]];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }

  if (destinationEntityName)
    {
      [text appendFormat: @"<TD>%@</TD>",
	[self linkedItem: destinationEntityName ofTypes: EOEntitiesTypes]];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }

  [text appendString: @"<TD>"];
  if (isToMany)
    {
      [text appendFormat: @"to many: %@<BR>", isToMany];
    }
  [text appendString: @"</TD>"];

  if (definition)
    {
      [text appendFormat: @"<TD>%@</TD>", definition];
    }
  else if ([joins count] > 0)
    {
      unsigned int i = 0;

      [text appendString:
	@"<TD>\r\n <TABLE BORDER=\"1\">\r\n <TR><TH>Source attribute</TH>"
	@"<TH>Destination Attribute </TH><TH>Operator </TH>"
	@"<TH>Semantic </TH><TH>user Dictionary </TH>"
	@"<TH>Description </TH></TR>"];
      for (i = 0; i < [joins count]; i++)
	{
	  [text appendFormat: @"<TR>%@</TR>", [joins objectAtIndex: i]];
	}
      [text appendString: @"</TABLE>\r\n </TD>\r\n"];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }

  if (userDictionary)
    {
      [text appendFormat: @"<TD>%@</TD>", userDictionary];
    }
  else
    [text appendString: @"<TD></TD>"];

  if (desc)
    [text appendFormat: @"<TD>%@</TD>", desc];
  else
    [text appendString: @"<TD></TD>"];


  // Stop working on EORelationship
  ASSIGN(currentEORelationshipDestinationEntity, nil);
  ASSIGN(currentEORelationship, nil);
  return text;
}

- (NSString *) parseEORelationshipComponent: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*definition;

  NSDebugMLLog(@"debug", @"Start parsing EORelationshipComponent");
  definition = [self getProp: "definition" fromNode: node];
  node = node->children;
  [text appendString:
    [self linkForSymbolKey:
      [NSString stringWithFormat: @"%@##%@", currentEOEntity, definition]
      ofTypes: EOClassPropertiesTypes
      withText: definition]];
  while (node && strcmp(node->name, "EORelationshipComponent") == 0)
    {
      NSString	*s = [self parseEORelationshipComponent: node];
      if (s)
	[text appendFormat: @".%@", s];
      node = node->next;
    }
  return text;
}

- (NSString *) parseEOJoin: (xmlNodePtr)node
{
  NSMutableString	*text = [NSMutableString string];
  NSString		*ref = [self getProp: "id" fromNode: node];
  NSString *relationshipName
    = [self getProp: "relationshipName" fromNode: node];
  NSString *joinOperator = [self getProp: "joinOperator" fromNode: node];
  NSString *joinSemantic = [self getProp: "joinSemantic" fromNode: node];
  NSString *sourceAttribute = [self getProp: "sourceAttribute" fromNode: node];
  NSString *destinationAttribute
    = [self getProp: "destinationAttribute" fromNode: node];
  NSString *desc = nil;
  NSString *userDictionary = nil;

  NSDebugMLLog(@"debug", @"Start parsing EOJoin");
  /*
	  if (!ref)
	  ref = relationshipName;

	  [self setEntry: relationshipName
	  withExternalCompleteRef: relationshipName
	  withExternalRef: relationshipName
	  withRef: ref
	  inIndexOfType: @"EOJoin"];
  */
  /*  [text appendFormat: @"<h2><a name =\"%@\">%@</a></h2>\r\n",
	  ref,
	  relationshipName];
  */
  /*
  if (relationshipName)
    {
      [text appendFormat: @"<TD>%@</TD>",
	[self linkedItem: relationshipName ofTypes: EORelationshipsTypes]];
    }
  else
    {
      [text appendString: @"<TD></TD>"];
    }
  */
  if (sourceAttribute)
    {
      [text appendFormat: @"<TD>%@</TD>",
	[self linkForSymbolKey:
	  [NSString stringWithFormat: @"%@##%@",
	    currentEOEntity, sourceAttribute]
	  ofTypes: EOClassPropertiesTypes
	  withText: sourceAttribute]];
    }
  else
    [text appendString: @"<TD></TD>"];

  if (destinationAttribute)
    {
      [text appendFormat: @"<TD>%@</TD>\r\n",
	[self linkForSymbolKey:
	  [NSString stringWithFormat: @"%@##%@",
	    currentEORelationshipDestinationEntity, destinationAttribute]
	  ofTypes: EOClassPropertiesTypes
	  withText: destinationAttribute]];
    }
  else
    [text appendString: @"<TD></TD>"];

  if (joinOperator)
    {
      [text appendFormat: @"<TD>%@</TD>\r\n", joinOperator];
    }
  else
    [text appendString: @"<TD></TD>"];

  if (joinSemantic)
    {
      [text appendFormat: @"<TD>%@</TD>\r\n", joinSemantic];
    }
  else
    [text appendString: @"<TD></TD>"];


  if (userDictionary)
    [text appendString: userDictionary];
  else
    [text appendString: @"<TD></TD>"];

  if (desc)
    [text appendFormat: @"<TD>%@</TD>", desc];
  else
    [text appendString: @"<TD></TD>"];

  return text;
}


- (void) setEntry: (NSString *)entry
withExternalCompleteRef: (NSString *)externalCompleteRef
  withExternalRef: (NSString *)externalRef
		  withRef: (NSString *)ref
    inIndexOfType: (NSString *)type
{
  NSMutableDictionary *index = nil;
  NSAssert(entry, @"No entry");
  NSAssert1(ref, @"No ref for %@", entry);
  NSAssert1(type, @"No type for %@", entry);
  index = [self indexForType: type];
  [index setObject: entry forKey: ref];
  [refToFile setObject: currName forKey: ref];

  if (processFileReferencesFlag && externalCompleteRef && externalRef)
    {
      NSMutableDictionary *typeDict = [fileReferences objectForKey: type];
      if (!fileReferences)
	{
	  fileReferences = [NSMutableDictionary new];
	}
      if (!typeDict)
	{
	  typeDict = [NSMutableDictionary dictionary];
	  [fileReferences setObject: typeDict
			     forKey: type];
	}
      if (![typeDict objectForKey: externalCompleteRef])
	{
	  NSMutableDictionary	*thisEntry
	    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		entry, @"title",
		externalRef, @"ref",
		externalCompleteRef, @"completeRef",
		ref, @"fragment",
		type, @"type",
		[currName stringByDeletingPathExtension], @"fileName",
		nil];
	  [typeDict setObject: thisEntry
		       forKey: externalCompleteRef];
	}
    }
}

- (NSArray *) contents
{
  return contents;
}

- (NSDictionary *) fileReferences
{
  return fileReferences;
}

- (void) setGeneralReferences: (NSDictionary *)dict
{
  ASSIGN(generalReferences, dict);
}

- (void) setVariablesDictionary: (NSDictionary *)dict
{
  DESTROY(variablesDictionary);
  variablesDictionary = [dict mutableCopy];
}

//Return a link for item (something like: <A HREF="TheFile.html#fragment">TheItem </A>) of type types
- (NSString *) linkedItem: (NSString *)item
		 ofTypes: (NSArray *)types
{
  NSString	*linked = nil;
  NSRange	foundRange;

  foundRange = [item rangeOfCharacterFromSet:
    [NSCharacterSet alphanumericCharacterSet]];
  if (foundRange.length> 0)
    {
      NSString *goodItem = nil;
      NSDictionary *symbol = nil;
      NSRange goodRange = NSMakeRange(foundRange.location, 1);
      while (foundRange.length> 0 && NSMaxRange(foundRange) < [item length])
	{
	  foundRange = [item rangeOfCharacterFromSet:
	    [NSCharacterSet alphanumericCharacterSet]
	   options: 0
	   range: NSMakeRange(foundRange.location+1, 1)];
	  if (foundRange.length> 0)
	    goodRange.length++;
	}
      goodItem = [item substringWithRange: goodRange];
      symbol = [self findSymbolForKey: goodItem
			      ofTypes: types];
      if (symbol)
	{
	  linked = [self linkForSymbol: symbol
			      withText: goodItem];
	  if (goodRange.location> 0)
	    {
	      linked = [NSString stringWithFormat: @"%@%@",
		[item substringWithRange: NSMakeRange(0, goodRange.location-1)],
		linked];
	    }
	  if (goodRange.location+goodRange.length < [item length])
	    {
	      linked = [NSString stringWithFormat: @"%@%@", linked,
		[item substringWithRange:
		  NSMakeRange(goodRange.location+goodRange.length,
		  [item length]-(goodRange.location+goodRange.length))]];
	    }
	}
    }
  if (!linked)
    linked = item;
  return linked;
}

- (NSString *) linkForSymbolKey: (NSString *)key_
		       ofTypes: (NSArray *)types
		      withText: (NSString *)text
{
  NSDictionary *symbol = [self findSymbolForKey: key_ ofTypes: types];
  if (symbol)
    return [self linkForSymbol: symbol withText: text];
  else
    return text;
}

//Return the symbol for key
- (NSDictionary *) findSymbolForKey: (NSString *)key_ ofTypes: (NSArray *)types
{
  NSDictionary	*symbol = nil;
  unsigned	i;

  for (i = 0; symbol == nil && i < [types count]; i++)
    {
      id	type = [types objectAtIndex: i];

      symbol = [[generalReferences objectForKey: type] objectForKey: key_];
    }
  return symbol;
}


//Return a link for symbol with label text
- (NSString *) linkForSymbol: (NSDictionary *)symbol
		   withText: (NSString *)text
{
  NSString	*symbolLocation
    = [[symbol objectForKey: @"project"] objectForKey: @"location"];
  NSString	*locationTmp = location;
  NSString	*common = nil;
  NSString	*prefix = @"";
  NSString	*fragment = nil;

  if ([locationTmp length] > 0)
    {
      //Equal: no prefix
      if ([locationTmp isEqual: symbolLocation] == NO)
	{
	  if ([locationTmp hasSuffix: @"/"] == NO)
	    locationTmp = [locationTmp stringByAppendingString: @"/"];
	  if ([symbolLocation length] > 0 && ![symbolLocation hasSuffix: @"/"])
	    symbolLocation = [symbolLocation stringByAppendingString: @"/"];
	  common = [symbolLocation commonPrefixWithString: location
						  options: 0];
	  if ([common length] > 0)
	    {
	      int		i = 0;
	      NSMutableArray	*locationParts;
	      NSMutableArray	*symbolLocationParts;

	      locationParts
		= [[locationTmp componentsSeparatedByString: @"/"]
		mutableCopy];
	      AUTORELEASE(locationParts);
	      symbolLocationParts
		= [[symbolLocation componentsSeparatedByString: @"/"]
		mutableCopy];
	      AUTORELEASE(symbolLocationParts);
	      [locationParts removeLastObject];
	      [symbolLocationParts removeLastObject];
	      while ([locationParts count] > 0
		&& [symbolLocationParts count] > 0
		&& [[locationParts objectAtIndex: 0] isEqual:
		  [symbolLocationParts objectAtIndex: 0]])
		{
		  [locationParts removeObjectAtIndex: 0];
		  [symbolLocationParts removeObjectAtIndex: 0];
		}
	      prefix = [NSString string];
	      for (i = 0; i < [locationParts count]; i++)
		{
		  prefix = [@".." stringByAppendingPathComponent: prefix];
		}
	      for (i = 0; i < [symbolLocationParts count]; i++)
		{
		  prefix = [prefix stringByAppendingPathComponent:
		    [symbolLocationParts objectAtIndex: i]];
		}
	    }
	  else
	    prefix = ([symbolLocation length] > 0 ? symbolLocation : @"");
	}
    }
  else
    // No Project Location ==> take symbol location
    prefix = ([symbolLocation length] > 0 ? symbolLocation : @"");
  fragment = [symbol objectForKey: @"fragment"];
  return [NSString stringWithFormat: @"<A HREF=\"%@%@%@\">%@</A>",
   [[prefix stringByAppendingPathComponent: [symbol objectForKey: @"fileName"]]
     stringByAppendingPathExtension: pathExtension_HTML],
     ([fragment length] > 0 ? @"#" : @""),
     (fragment ? fragment : @""),
     text];
}

- (void) setWriteFlag: (BOOL)flag
{
  writeFlag = flag;
}

- (void) setProcessFileReferencesFlag: (BOOL)flag
{
  processFileReferencesFlag = flag;
}

- (void) setProjectName: (NSString *)projectName_
{
  ASSIGN(projectName, projectName_);
}

@end

//--------------------------------------------------------------------
// Return files list of files in symbols
//
// symbols:
// {
// 	class =
//  	{
//	  	"NSString" = { fileName = "NSString.gsdoc"; ...}
//		"NSArray" = { fileName = "NSArray.gsdoc"; ... }
//		...
// 	}
//	type =		{
//		...
// 	}
//	...
// }
//
// Return:
// ( NSString.gsdoc, NSArray.gsdoc, ... )
NSArray *
FilesFromSymbols(NSDictionary *symbols)
{
  NSArray		*sortedFiles = nil;
  NSMutableArray	*files = [NSMutableArray arrayWithCapacity: 2];
  NSEnumerator		*typesEnumerator = [symbols keyEnumerator];
  id			typeKey = nil;

  while ((typeKey = [typesEnumerator nextObject]) != nil)
    {
      NSDictionary	*type = [symbols objectForKey: typeKey];
      NSEnumerator	*symbolsEnumerator = [type keyEnumerator];
      id		symbolKey = nil;

      while ((symbolKey = [symbolsEnumerator nextObject]) != nil)
	{
	  NSDictionary	*symbol = [type objectForKey: symbolKey];
	  id		file = [symbol objectForKey: @"fileName"];

	  if (![files containsObject: file])
	    [files addObject: file];
	}
    }
  sortedFiles = [files sortedArrayUsingSelector: @selector(compare:)];
  return sortedFiles;
}

/*
 * Return list of files found in dir (deep search) which have
 * extension extension
 */
NSArray *
FilesInPathWithExtension(NSString *dir, NSString *extension)
{
  NSMutableArray	*files = [NSMutableArray array];
  NSString		*file = nil;
  NSFileManager		*fm = [NSFileManager defaultManager];
  NSDirectoryEnumerator	*enumerator = [fm enumeratorAtPath: dir];

  while ((file = [enumerator nextObject]) != nil)
    {
      file = [dir stringByAppendingPathComponent: file];
      if ([[file pathExtension] isEqual: extension])
	{
	  BOOL	isDirectory = NO;

	  if ([fm fileExistsAtPath: file isDirectory: &isDirectory])
	    {
	      if (isDirectory == NO)
		{
		  [files addObject: file];
		}
	    }
	}
    }
  return files;
}

//--------------------------------------------------------------------
void
AddSymbolsToReferencesWithProjectInfo(NSDictionary *symbols,
  NSMutableDictionary *references, NSDictionary *projectInfo, BOOL override)
{
  NSString	*projectName = [projectInfo objectForKey: @"projectName"];

  if (symbols)
    {
      NSEnumerator	*typesEnumerator = nil;
      id		typeKey = nil;

      NSCAssert1([symbols isKindOfClass: [NSDictionary class]],
	@"%@ is not a dictionary", symbols);
      typesEnumerator = [symbols keyEnumerator];
      while ((typeKey = [typesEnumerator nextObject]) != nil)
	{
	  NSDictionary	*type = [symbols objectForKey: typeKey];
	  if ([type isKindOfClass: [NSDictionary class]] == NO)
	    {
	      NSLog(@"Warning: Type %@ is not a dictionary", type);
	    }
	  else
	    {
	      NSEnumerator		*symbolsEnumerator;
	      id			symbolKey = nil;
	      NSMutableDictionary	*referencesType;

	      symbolsEnumerator = [type keyEnumerator];
	      referencesType = [references objectForKey: typeKey];
	      if (referencesType == nil)
		{
		  referencesType = [NSMutableDictionary dictionary];
		  [references setObject: referencesType
				 forKey: typeKey];
		}
	      while ((symbolKey = [symbolsEnumerator nextObject]) != nil)
		{
		  NSDictionary	*symbol = [type objectForKey: symbolKey];

		  if (![symbol isKindOfClass: [NSDictionary class]])
		    {
		      NSLog(@"Warning: Symbol %@ is not a dictionary", symbol);
		    }
		  else
		    {
		      NSMutableDictionary	*symbolNew;

		      symbolNew = [NSMutableDictionary
			dictionaryWithDictionary: symbol];
		      if (verbose >= 4)
			{
			  NSLog(@"Project %@ Processing reference %@",
			    projectName, symbolKey);
			}
		      if (projectInfo)
			[symbolNew setObject: projectInfo
				      forKey: @"project"];
		      NSCAssert(symbolKey, @"No symbolKey");

		      if (override || ![referencesType objectForKey: symbolKey])
			[referencesType setObject: symbolNew
					   forKey: symbolKey];
		      NSCAssert1([symbolNew objectForKey: @"ref"],
			@"No ref for symbol %@", symbolKey);
		      if (override || ![referencesType objectForKey:
			[symbolNew objectForKey: @"ref"]])
			{
			  [referencesType setObject: symbolNew
					     forKey: [symbolNew objectForKey:
						@"ref"]];
			}
		      if (projectName)
			{
			  NSString *symbolType
			    = [symbolNew objectForKey: @"type"];

			  if ([symbolType isEqual: @"file"])
			    {
			      NSString *fileName
				= [symbolNew objectForKey: @"fileName"];

			      if (fileName)
				{
				  NSString *fileRef = nil;

				  fileName
				    = [fileName stringByDeletingPathExtension];
				  fileRef
				    = [NSString stringWithFormat: @"%@##%@",
					projectName, fileName];
				  [symbolNew setObject: fileRef
					        forKey: @"completeRef"];
				  if (override
				    || ![referencesType objectForKey: fileRef])
				    {
				      [referencesType setObject: symbolNew
							 forKey: fileRef];
				    }
				}
			    }
			}
		    }
		}
	    }
	}
    }
  if (projectName)
    {
      NSString *fileName
	= [[projectInfo objectForKey: @"indexfileName"]
	  stringByDeletingPathExtension];
      NSString *fileRef = nil;
      NSMutableDictionary *referencesType = [references objectForKey: @"file"];

      if (!referencesType)
	{
	  referencesType = [NSMutableDictionary dictionary];
	  [references setObject: referencesType
			 forKey: @"file"];
	}
      if (!fileName)
	{
	  fileName = @"index";
	}
      fileRef = [NSString stringWithFormat: @"%@##%@", projectName, fileName];
      if (override || ![referencesType objectForKey: fileRef])
	{
	  NSMutableDictionary *symbol
	    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
	      fileRef, @"completeRef",
	      fileName, @"fileName",
	      fileName, @"ref",
	      @"file", @"type",
	      nil];

	  if (projectInfo)
	    {
	      [symbol setObject: projectInfo
			 forKey: @"project"];
	    }
	  [referencesType setObject: symbol
			     forKey: fileRef];
	}
    }
}

int
main(int argc, char **argv, char **env)
{
  NSProcessInfo		*proc;
  NSArray		*args;
  unsigned		i;
  NSUserDefaults	*defs;
  NSString		*makeRefsFileName = nil;
  NSString		*projectName = nil;
  NSMutableArray	*files = nil;
  NSMutableArray	*references = nil;
  NSMutableDictionary	*generalReferences = nil;
  NSMutableDictionary	*projectReferences = nil;
  NSString		*makeIndexBaseFileName = nil;
  NSString		*makeIndexFileNameGSDoc = nil;
  NSString		*makeIndexTemplateFileName = nil;
  NSMutableDictionary	*infoDictionary = nil;
  NSDictionary		*variablesDictionary = nil;
  NSMutableDictionary	*projectInfo = nil;
  BOOL			goOn = YES;
  NSFileManager		*fileManager = nil;
  CREATE_AUTORELEASE_POOL(pool);

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments: argv count: argc environment: env];
#endif
  defs = [NSUserDefaults standardUserDefaults];
  [defs registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
    @"Yes", @"Monolithic", nil]];

  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      NSLog(@"unable to get process information!");
      goOn = NO;
    }

  fileManager = [NSFileManager defaultManager];
  if (goOn == YES)
    {
      args = [proc arguments];

      // First, process arguments
      for (i = 1; goOn && i < [args count]; i++)
	{
	  NSString *arg = [args objectAtIndex: i];
	  // is this an option ?
	  if ([arg hasPrefix: @"--"])
	    {
	      NSString	*argWithoutPrefix;
	      NSString	*value;
	      NSString	*key;
	      NSArray	*parts;

	      argWithoutPrefix = [arg stringWithoutPrefix: @"--"];
	      parts = [argWithoutPrefix componentsSeparatedByString: @"="];
	      key = [parts objectAtIndex: 0];

	      if ([parts count] > 1)
		{
		  NSRange	r = NSMakeRange(1, [parts count]-1);
		  NSArray	*sub = [parts subarrayWithRange: r];

		  value = [sub componentsJoinedByString: @"="];
		}
	      else
		{
		  value = nil;
		}

	      // makeRefs option
	      if ([key isEqualToString: @"makeRefs"])
		{
		  makeRefsFileName = value;
		  if (makeRefsFileName != nil)
		    {
		      NSString	*ext = [makeRefsFileName pathExtension];

		      if ([ext isEqual: pathExtension_GSDocRefs] == NO)
			{
			  makeRefsFileName = [makeRefsFileName
			    stringByAppendingPathExtension:
			    pathExtension_GSDocRefs];
			}
		    }
		  else
		    {
		      makeRefsFileName = @"";
		    }
		}
	      else if ([key isEqualToString: @"projectName"])
		{
		  projectName = value;
		  NSCAssert([projectName length], @"No project name");
		}
	      else if ([key isEqualToString: @"refs"])
		{
		  if (references == nil)
		    {
		      references = [NSMutableArray arrayWithCapacity: 4];
		    }
		  NSCAssert([value length], @"No index");
		  [references addObject: value];
		}
	      else if ([key isEqualToString: @"makeIndex"])
		{
		  makeIndexBaseFileName = value;
		  if (makeIndexBaseFileName != nil)
		    {
		      makeIndexBaseFileName
			= [makeIndexBaseFileName stringByDeletingPathExtension];
		    }
		  else
		    {
		      makeIndexBaseFileName = @"index";
		    }
		}
	      else if ([key isEqualToString: @"makeIndexTemplate"])
		{
		  makeIndexTemplateFileName = value;
		  NSCAssert([makeIndexTemplateFileName length],
		    @"No makeIndexTemplate filename");
		}
	      else if ([key hasPrefix: @"verbose"])
		{
		  NSCAssert1(value, @"No value for %@", key);
		  verbose = [value intValue];
		  if (verbose > 0)
		    {
		      NSMutableSet *debugSet = [proc debugSet];
		      [debugSet addObject: @"dflt"];
		    }
		}
	      else if ([key hasPrefix: @"location"])
		{
		  NSCAssert1(value, @"No value for %@", key);
		  location = value;
		}
	      else if ([key hasPrefix: @"define-"])
		{
		  if (infoDictionary == nil)
		    {
		      infoDictionary = [NSMutableDictionary dictionary];
		    }
		  NSCAssert1(value, @"No value for %@", key);
		  [infoDictionary setObject: value
		    forKey: [key stringWithoutPrefix: @"define-"]];
		}
	      else
		{
		  NSLog(@"Unknown option %@", arg);
		  goOn = NO;
		}
	    }
	  else
	    {
	      if (files == nil)
		files = [NSMutableArray array];
	      /*
	       * FIXME
	       * Dirty Hack to handle *.gsdoc and *
	       * We need this because sometimes, there are too many files
	       * for commande line
	       */
	      if ([[arg lastPathComponent] hasSuffix:
		[NSString stringWithFormat: @"*.%@", pathExtension_GSDoc]]
		|| [[arg lastPathComponent]hasSuffix: @"*"])
		{
		  NSArray	*dirContent = nil;
		  int		ifile = 0;

		  arg = [arg stringByDeletingLastPathComponent];
		  if ([arg length] == 0)
		    {
		      arg = [fileManager currentDirectoryPath];
		    }
		  dirContent = [fileManager directoryContentsAtPath: arg];
		  for (ifile = 0; ifile < [dirContent count]; ifile++)
		    {
		      NSString	*file = [dirContent objectAtIndex: ifile];

		      if ([[file pathExtension] isEqual: pathExtension_GSDoc])
			{
			  [files addObject: file];
			}
		    }
		}
	      else
		{
		  [files addObject: arg];
		}
	    }
	}
    }

  //Default Values
  if (goOn)
    {
      if (projectName == nil)
	{
	  projectName = @"unknown";
	}
      if ([makeRefsFileName length]== 0)
	{
	  makeRefsFileName = [projectName
	    stringByAppendingPathExtension: pathExtension_GSDocRefs];
	}
      if (makeIndexBaseFileName != nil)
	{
	  makeIndexFileNameGSDoc = [makeIndexBaseFileName
	    stringByAppendingPathExtension: pathExtension_GSDoc];
	}
    }

  // Verify option compatibilities
  if (goOn)
    {
    }

  // Construct project references
  if (goOn)
    {
      BOOL		addedSymbols = NO;
      NSDictionary	*previousProjectReferences = nil;

      NSDebugFLLog(@"debug", @"Construct project references");
      projectReferences = [NSMutableDictionary dictionaryWithCapacity: 2];
      [projectReferences
	setObject: [NSMutableDictionary dictionaryWithCapacity: 2]
	forKey: @"symbols"];
      projectInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
	projectName, @"projectName", nil];
      if (location != nil)
	{
	  [projectInfo setObject: location forKey: @"location"];
	}
      if (makeIndexBaseFileName != nil)
	{
	  [projectInfo setObject: makeIndexBaseFileName
			  forKey: @"indexfileName"];
	}

      //Read project existing references
      if (makeRefsFileName != nil)
	{
	  BOOL isDirectory = NO;

	  if ([fileManager fileExistsAtPath: makeRefsFileName
				isDirectory: &isDirectory])
	    {
	      if (isDirectory == NO)
		{
		  previousProjectReferences = [NSDictionary
		    dictionaryWithContentsOfFile: makeRefsFileName];
		  if ([previousProjectReferences objectForKey: @"symbols"])
		    {
		      AddSymbolsToReferencesWithProjectInfo(
			[previousProjectReferences objectForKey: @"symbols"],
			[projectReferences objectForKey: @"symbols"],
			projectInfo, NO);
		      addedSymbols = YES;
		    }
		}
	    }
	}
      if (addedSymbols == NO)
	{
	  AddSymbolsToReferencesWithProjectInfo(nil,
	    [projectReferences objectForKey: @"symbols"], projectInfo, NO);
	}
    }

  // Process references (construct a dictionary of all references)
  if (goOn)
    {
      NSDebugFLLog(@"debug", @"Process references");
      generalReferences = [NSMutableDictionary dictionaryWithCapacity: 2];
      if ([references count] > 0)
	{
	  /*
	   * From last to first so references are taken in
	   * first to last priority
	   */
	  while (goOn && [references count] > 0)
	    {
	      NSString	*file = [references lastObject];
	      BOOL	isDirectory = NO;

	      if (![fileManager fileExistsAtPath: file
				     isDirectory: &isDirectory])
		{
		  NSLog(@"Index File %@ doesn't exist", file);
		  [references removeLastObject];
		}
	      else
		{
		  if (isDirectory)
		    {
		      NSArray *tmpReferences;
		
		      tmpReferences = FilesInPathWithExtension(file,
			pathExtension_GSDocRefs);

		      if (verbose >= 3)
			{
			  NSLog(@"Processing references directory %@", file);
			}
		      [references removeLastObject];
		      [references addObjectsFromArray: tmpReferences];
		    }
		  else
		    {
		      NSDictionary *generalIndexTmp = nil;

		      if (verbose >= 2)
			{
			  NSLog(@"Processing references file %@", file);
			}
		      generalIndexTmp = [NSDictionary
			dictionaryWithContentsOfFile: file];
		      if (!generalIndexTmp)
			{
			  NSLog(@"File %@ isn't a dictionary", file);
			  goOn = NO;
			}
		      else
			{
			  NSDictionary *fileProjectInfo;
			  NSDictionary *symbols;

			  fileProjectInfo
			    = [generalIndexTmp objectForKey: @"project"];
			  symbols = [generalIndexTmp objectForKey: @"symbols"];

			  NSCAssert1(fileProjectInfo,
			    @"No Project Info in %@", file);
			  NSCAssert1(symbols, @"No symbols %@", file);
			  AddSymbolsToReferencesWithProjectInfo(symbols,
			    generalReferences, fileProjectInfo, YES);
			}
		      [references removeLastObject];
		    }
		}
	    }
	}
    }
  //Variables
  if (goOn)
    {
      NSMutableDictionary	*variablesMutableDictionary;
      NSEnumerator		*enumer;
      id			key = nil;

      variablesMutableDictionary = [NSMutableDictionary dictionary];
      enumer = [infoDictionary keyEnumerator];
      NSDebugFLLog(@"debug", @"Variables");
      while ((key = [enumer nextObject]))
	{
	  id		v;
	  NSString	*k;

	  v = [infoDictionary objectForKey: key];
	  k = [NSString stringWithFormat: @"[[infoDictionary.%@]]", key];
	  [variablesMutableDictionary setObject: v forKey: k];
	}
      [variablesMutableDictionary setObject: [NSCalendarDate calendarDate]
				     forKey: @"[[timestampString]]"];
      if (makeIndexBaseFileName)
	{
	  [variablesMutableDictionary setObject: makeIndexFileNameGSDoc
					 forKey: @"[[indexFileName]]"];
	  [variablesMutableDictionary setObject: makeIndexBaseFileName
					 forKey: @"[[indexBaseFileName]]"];
	}
      if (projectName != nil)
	{
	  [variablesMutableDictionary setObject: projectName
					 forKey: @"[[projectName]]"];
	}
      variablesDictionary = [variablesMutableDictionary copy];
      AUTORELEASE(variablesDictionary);

      if (verbose >= 3)
	{
	  NSEnumerator	*enumer = [variablesDictionary keyEnumerator];
	  id		key = nil;

	  while ((key = [enumer nextObject]))
	    {
	      NSLog(@"Variables: %@=%@",
		key, [variablesDictionary objectForKey: key]);
	    }
	}
    }

  // Find Files to parse
  if (goOn)
    {
      NSDebugFLLog(@"debug", @"Find Files to parse");
      if ([files count] < 1)
	{
	  NSLog(@"No file names given to parse.");
	  goOn = NO;
	}
      else
	{
	  NSMutableArray *tmpNewFiles = [NSMutableArray array];

	  for (i = 0; goOn && i < [files count]; i++)
	    {
	      NSString *file = [files objectAtIndex: i];
	      BOOL isDirectory = NO;

	      if (![fileManager fileExistsAtPath: file
				     isDirectory: &isDirectory])
		{
		  NSLog(@"File %@ doesn't exist", file);
		  goOn = NO;
		}
	      else
		{
		  if (isDirectory)
		    {
		      NSArray	*tmpFiles;

		      tmpFiles
			= FilesInPathWithExtension(file, pathExtension_GSDoc);
		      [tmpNewFiles addObjectsFromArray: tmpFiles];
		    }
		  else
		    {
		      [tmpNewFiles addObject: file];
		    }
		}
	    }
	  files = [[tmpNewFiles sortedArrayUsingSelector: @selector(compare:)]
	    mutableCopy];
	  AUTORELEASE(files);
	}
    }

  if (goOn)
    {
      int pass = 0;

      NSDebugFLLog(@"debug", @"Parse Files");
      /*
       * 1st pass: don't write file, just parse them and
       * construct project references
       * 2nd pass: parse and write files
       */
      for (pass = 0; goOn && pass < 2; pass++)
	{
	  for (i = 0; goOn && i < [files count]; i++)
	    {
	      NSString	*file = [files objectAtIndex: i];
	      NSString	*base = [file stringByDeletingPathExtension];
	      CREATE_AUTORELEASE_POOL(arp);

	      // Don't process generated index file
	      if ([base isEqual: makeIndexBaseFileName])
		{
		  if (verbose >= 1)
		    {
		      NSLog(@"Pass %d/2 File %d/%d - Ignoring Index File "
			@"%@ (Process it later)",
			(pass+1), (i+1), [files count], file);
		    }
		}
	      else
		{
		  if (verbose >= 1)
		    {
		      NSLog(@"Pass %d/2 File %d/%d - Processing %@",
			(pass+1), (i+1), [files count], file);
		    }
		  NS_DURING
		    {
		      GSDocHtml	*p = nil;

		      p = [GSDocHtml alloc];
		      p = [p initWithFileName: file];
		      if (p != nil)
			{
			  NSString		*previousFile;
			  NSString		*nextFile;
			  NSMutableDictionary	*vmDictionary;
			  NSString		*result;

			  previousFile = ((i > 0) ? [files objectAtIndex: i-1]
			    : @"");
			  nextFile = (((i+1) < [files count])
			    ? [files objectAtIndex: i+1] : @"");
			  vmDictionary = nil;
			  result = nil;

			  [p setProjectName: projectName];
			  [p setGeneralReferences: generalReferences];
			  vmDictionary = [variablesDictionary mutableCopy];
			  [vmDictionary setObject:
			    [previousFile stringByDeletingPathExtension]
			    forKey: @"[[prev]]"];
			  [vmDictionary setObject:
			    [nextFile stringByDeletingPathExtension]
			    forKey: @"[[next]]"];
			  if (makeIndexBaseFileName)
			    {
			      [vmDictionary setObject:
				makeIndexBaseFileName forKey: @"[[up]]"];
			    }
			  [p setVariablesDictionary: vmDictionary];
			  [p setWriteFlag: (pass == 1)];
			  [p setProcessFileReferencesFlag: (pass == 0)];
			  result = [p parseDocument];
			  if (result == nil)
			    {
			      NSLog(@"Pass %d/2 File %d/%d - Error parsing %@",
				(pass+1), (i+1), [files count], file);
			      goOn = NO;
			    }
			  else
			    {
			      if (verbose >= 1)
				{
				  NSLog(@"Pass %d/2 File %d/%d"
				    @" - Parsed %@ - OK",
				    (pass+1), (i+1), [files count], file);
				}
			      if (pass == 0)
				{
				  NSDebugFLLog(@"debug",
				    @"AddSymbolsToReferencesWithProjectInfo ->"
				    @" projectRefernce");
				  AddSymbolsToReferencesWithProjectInfo(
				    [p fileReferences],
				    [projectReferences
				      objectForKey: @"symbols"],
				    nil, NO);
				  NSDebugFLLog(@"debug",
				    @"AddSymbolsToReferencesWithProjectInfo ->"
				    @" generalReference");
				  AddSymbolsToReferencesWithProjectInfo(
				    [p fileReferences], generalReferences,
				    projectInfo, YES);
				  NSDebugFLLog(@"debug",
				    @"AddSymbolsToReferencesWithProjectInfo "
				    @"finished");
				}
			    }
			  RELEASE(p);
			}
		    }
		  NS_HANDLER
		    {
		      NSLog(@"Pass %d/2 File %d/%d - Parsing '%@' - %@",
			(pass+1), (i+1), [files count], file,
			[localException reason]);
		      goOn = NO;
		    }
		  NS_ENDHANDLER
		}
	      DESTROY(arp);
	    }
	}
    }

  // Process Project References to generate Project Reference File
  if (goOn)
    {
      if (makeRefsFileName)
	{
	  [projectReferences setObject: projectInfo forKey: @"project"];
	  if (verbose >= 1)
	    {
	      NSLog(@"Writing References File %@", makeRefsFileName);
	    }
	  if ([projectReferences writeToFile: makeRefsFileName
				  atomically: YES] == NO)
	    {
	      NSLog(@"Error creating %@", makeRefsFileName);
	      goOn = NO;
	    }
	}
    }

  // Process Project References to generate Index File
  if (goOn)
    {
      if (makeIndexBaseFileName)
	{
	  NSString		*textTemplate
	    = [NSString stringWithContentsOfFile: makeIndexTemplateFileName];
	  NSMutableString	*textStart = [NSMutableString string];
	  NSMutableString	*textChapters = [NSMutableString string];
	  NSMutableString	*textClasses = [NSMutableString string];
	  NSMutableString	*textCategories = [NSMutableString string];
	  NSMutableString	*textProtocols = [NSMutableString string];
	  NSMutableString	*textFunctions = [NSMutableString string];
	  NSMutableString	*textTypes = [NSMutableString string];
	  NSMutableString	*textConstants = [NSMutableString string];
	  NSMutableString	*textVariables = [NSMutableString string];
	  NSMutableString	*textOthers = [NSMutableString string];
	  NSMutableString	*textFiles = [NSMutableString string];
	  NSMutableString	*textStop = [NSMutableString string];
	  NSMutableString	*text = nil;
	  NSMutableDictionary	*variablesMutableDictionary = nil;
	  NSString		*typeTitle = nil;
	  NSString		*finalText = nil;
	  NSDictionary		*symbolsByType
	    = [projectReferences objectForKey: @"symbols"];
	  NSString		*firstFileName = nil;
	  NSEnumerator		*typesEnumerator
	    = [symbolsByType keyEnumerator];
	  id			typeKey = nil;

	  if (verbose >= 1)
	    {
	      NSLog(@"Making Index");
	    }
	  [textStart appendFormat:
	    @"<chapter>\n <heading>%@</heading>\n", projectName];
	  while ((typeKey = [typesEnumerator nextObject]))
	    {
	      if (verbose >= 2)
		{
		  NSLog(@"Making Index for type %@", typeKey);
		}
	      text = nil;
	      if ([typeKey isEqual: @"ivariable"])
		{
		  text = nil;
		  typeTitle = @"Instance Variables";
		}
	      else if ([typeKey isEqual: @"method"])
		{
		  text = nil;
		  typeTitle = @"Methods";
		}
	      else if ([typeKey isEqual: @"file"])
		{
		  text = textFiles;
		  typeTitle = @"Files";
		}
	      else if ([typeKey isEqual: @"chapter"])
		{
		  text = textChapters;
		  typeTitle = @"Chapters";
		}
	      else if ([typeKey isEqual: @"section"])
		{
		  text = nil;
		  typeTitle = @"Section";
		}
	      else if ([typeKey isEqual: @"ubsect"])
		{
		  text = nil;
		  typeTitle = @"Subsections";
		}
	      else if ([typeKey isEqual: @"class"]
		|| [typeKey isEqual: @"jclass"])
		{
		  text = textClasses;
		  typeTitle = @"Classes";
		}
	      else if ([typeKey isEqual: @"protocol"])
		{
		  text = textProtocols;
		  typeTitle = @"Protocols";
		}
	      else if ([typeKey isEqual: @"category"])
		{
		  text = textProtocols;
		  typeTitle = @"Categories";
		}
	      else if ([typeKey isEqual: @"function"])
		{
		  text = textFunctions;
		  typeTitle = @"Functions";
		}
	      else if ([typeKey isEqual: @"macro"])
		{
		  text = textFunctions;
		  typeTitle = @"Macros";
		}
	      else if ([typeKey isEqual: @"constant"])
		{
		  text = textConstants;
		  typeTitle = @"Constants";
		}
	      else if ([typeKey isEqual: @"variable"])
		{
		  text = textVariables;
		  typeTitle = @"Global Variables";
		}
	      else
		{
		  text = textOthers;
		  typeTitle = @"Others";
		}
	      if (text != nil)
		{
		  NSArray	*symbolKeys = nil;
		  NSEnumerator	*symbolsEnumerator = nil;
		  id		symbolKey = nil;
		  NSDictionary	*typeDict;
		  typeDict = [symbolsByType objectForKey: typeKey];
		  [text appendFormat:
		    @"<section>\n <heading>%@</heading>\n <list>\n", typeTitle];
		  symbolKeys = [[typeDict allKeys]
		    sortedArrayUsingSelector: @selector(compare:)];
		  symbolsEnumerator = [symbolKeys objectEnumerator];
		  while ((symbolKey = [symbolsEnumerator nextObject]))
		    {
		      NSString *fragment = nil;
		      NSDictionary *symbol = [typeDict objectForKey: symbolKey];
		      if (text == textFiles && !firstFileName)
			firstFileName = [symbol objectForKey: @"fileName"];
		      if (verbose >= 4)
			{
			  NSLog(@"Making Index for symbol %@",
			    [symbol objectForKey: @"title"]);
			}
		      fragment = [symbol objectForKey: @"fragment"];
		      [text appendFormat:
			@"<item><uref url =\"%@%@%@\">%@</uref></item>\n",
			[[symbol objectForKey: @"fileName"]
			  stringByAppendingPathExtension: pathExtension_HTML],
			  ([fragment length] > 0 ? @"#" : @""),
			  (fragment ? fragment : @""),
			  [symbol objectForKey: @"title"]];
		    }
		  [text appendString: @"</list>\n </section>\n"];
		}
	    }
	  [textStop appendString: @"</chapter>\n"];
	  finalText = [NSString stringWithFormat:
	    @"%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n",
	    textStart, textChapters, textClasses, textCategories,
	    textProtocols, textFunctions, textTypes, textConstants,
	    textVariables, textOthers, textFiles, textStop];
	  variablesMutableDictionary = [variablesDictionary mutableCopy];
	  [variablesMutableDictionary setObject: finalText
					 forKey: @"[[content]]"];
	  [variablesMutableDictionary setObject: [firstFileName stringByDeletingPathExtension]
					 forKey: @"[[next]]"];
	  finalText = textByReplacingVariablesInText(textTemplate,
	    variablesMutableDictionary);
	  if (verbose >= 1)
	    {
	      NSLog(@"Writing Index %@", makeIndexFileNameGSDoc);
	    }
	  if (![finalText writeToFile: makeIndexFileNameGSDoc
					  atomically: YES])
	    {
	      NSLog(@"Error creating %@", makeIndexFileNameGSDoc);
	      goOn = NO;
	    }
	}
    }

  // Finally, parse index
  if (goOn)
    {
      if (makeIndexBaseFileName)
	{
	  if (verbose >= 1)
	    {
	      NSLog(@"Processing %@", makeIndexFileNameGSDoc);
	    }
	  NS_DURING
	    {
	      GSDocHtml	*p = nil;
	      p = [GSDocHtml alloc];
	      p = [p initWithFileName: makeIndexFileNameGSDoc];
	      if (p != nil)
		{
		  NSString	*result = nil;
		  [p setVariablesDictionary: variablesDictionary];
		  result = [p parseDocument];
		  if (result == nil)
		    {
		      NSLog(@"Error parsing %@", makeIndexFileNameGSDoc);
		      goOn = NO;
		    }
		  else
		    {
		      if (verbose >= 1)
			{
			  NSLog(@"Parsed %@ - OK", makeIndexFileNameGSDoc);
			}
		    }
		  RELEASE(p);
		}
	    }
	  NS_HANDLER
	    {
	      NSLog(@"Parsing '%@' - %@",
		makeIndexFileNameGSDoc, [localException reason]);
	      goOn = NO;
	    }
	  NS_ENDHANDLER;
	}
    }
  RELEASE(pool);
  return (goOn ? 0 : 1);
}

#else
int
main()
{
  NSLog(@"No libxml available");
  return 0;
}
#endif

