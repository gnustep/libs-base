/** 

   <title>AGSHtml ... a class to output html for a gsdoc file</title>
   Copyright (C) 2001 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 2001

   This file is part of the GNUstep Project

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   You should have received a copy of the GNU General Public
   License along with this program; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

   */

#include	<Foundation/Foundation.h>
#include        "AGSHtml.h"

static int      XML_ELEMENT_NODE;
static int      XML_ENTITY_REF_NODE;
static int      XML_TEXT_NODE;

static GSXMLNode	*firstElement(GSXMLNode *nodes)
{
  if (nodes == nil)
    {
      return nil;
    }
  if ([nodes type] == XML_ELEMENT_NODE)
    {
      return nodes;
    }
  return [nodes nextElement];
}

@implementation	AGSHtml

static NSMutableSet	*textNodes = nil;

+ (void) initialize
{
  if (self == [AGSHtml class])
    {
      /*
       * Cache XML node information.
       */
      XML_ELEMENT_NODE = [GSXMLNode typeFromDescription: @"XML_ELEMENT_NODE"];
      XML_ENTITY_REF_NODE
	= [GSXMLNode typeFromDescription: @"XML_ENTITY_REF_NODE"];
      XML_TEXT_NODE = [GSXMLNode typeFromDescription: @"XML_TEXT_NODE"];
      textNodes = [NSMutableSet new];
      [textNodes addObject: @"br"];
      [textNodes addObject: @"code"];
      [textNodes addObject: @"em"];
      [textNodes addObject: @"email"];
      [textNodes addObject: @"entry"];
      [textNodes addObject: @"file"];
      [textNodes addObject: @"label"];
      [textNodes addObject: @"prjref"];
      [textNodes addObject: @"ref"];
      [textNodes addObject: @"site"];
      [textNodes addObject: @"strong"];
      [textNodes addObject: @"uref"];
      [textNodes addObject: @"url"];
      [textNodes addObject: @"var"];
      [textNodes addObject: @"footnote"];
    }
}

- (void) dealloc
{
  RELEASE(globalRefs);
  RELEASE(localRefs);
  RELEASE(projectRefs);
  RELEASE(indent);
  [super dealloc];
}

- (void) decIndent
{
  unsigned	len = [indent length];

  if (len >= 2)
    {
      [indent deleteCharactersInRange: NSMakeRange(len - 2, 2)];
    }
}

- (void) incIndent
{
  [indent appendString: @"  "];
}

- (id) init
{
  indent = [[NSMutableString alloc] initWithCapacity: 64];
  return self;
}

/**
 * Calls -makeLink:ofType:isRef: or -makeLink:ofType:inUnit:isRef: to
 * create the first part of an anchor, and fills in the text content
 * of the anchor with n (the specified name).  Returns an entire anchor
 * string as a result.<br />
 * This method is used to create all the anchors in the html output.
 */
- (NSString*) makeAnchor: (NSString*)r
		  ofType: (NSString*)t
		    name: (NSString*)n
{
  NSString	*s;

  if (n == nil)
    {
      n = @"";
    }
  if ([t isEqualToString: @"method"] || [t isEqualToString: @"ivariable"])
    {
      s = [self makeLink: r ofType: t inUnit: nil isRef: NO];
    }
  else
    {
      s = [self makeLink: r ofType: t isRef: NO];
    }
  if (s != nil)
    {
      n = [s stringByAppendingFormat: @"%@</a>", n];
    }
  return n;
}

/**
 * Make a link for the element r with the specified type. Only the start of
 * the html element is returned (&lt;a ...&gt;).
 * If the boolean f is YES, then the link is a reference to somewhere,
 * and the method will return nil if the destination is not found in the index.
 * If f is NO, then the link is an anchor for some element being output, and
 * the method is guaranteed to succeed and return the link.
 */
- (NSString*) makeLink: (NSString*)r
		ofType: (NSString*)t
		 isRef: (BOOL)f
{
  NSString	*s;
  NSString	*kind = (f == YES) ? @"rel=\"gsdoc\" href" : @"name";
  NSString	*hash = (f == YES) ? @"#" : @"";

  if (f == NO || (s = [localRefs globalRef: r type: t]) != nil)
    {
      s = [NSString stringWithFormat: @"<a %@=\"%@%@$%@\">",
	kind, hash, t, r];
    }
  else if ((s = [globalRefs globalRef: r type: t]) != nil)
    {
      s = [s stringByAppendingPathExtension: @"html"];
      s = [NSString stringWithFormat: @"<a %@=\"%@%@%@$%@\">",
	kind, s, hash, t, r];
    }
  return s;
}

/**
 * Make a link for the element r, with the specified type t,
 * in a particular unit u. Only the start of
 * the html element is returned (&lt;a ...&gt;).<br />
 * If the boolean f is YES, then the link is a reference to somewhere,
 * otherwise the link is an anchor for some element being output.<br />
 * If there is an error, the method returns nil.
 */
- (NSString*) makeLink: (NSString*)r
		ofType: (NSString*)t
		inUnit: (NSString*)u
		 isRef: (BOOL)f
{
  NSString	*s = nil;
  NSString	*kind = (f == YES) ? @"rel=\"gsdoc\" href" : @"name";
  NSString	*hash = (f == YES) ? @"#" : @"";

  if (f == YES)
    {
      if (u == nil)
	{
	  u = unit;
	}
      s = base;
    }
  else if (u == nil)
    {
      if (category == nil)
	{
	  u = unit;
	}
      else
	{
	  u = classname;
	}
      s = [localRefs unitRef: r type: t unit: &u];
      if (s == nil)
	{
	  if (category == nil)
	    {
	      u = unit;
	    }
	  else
	    {
	      u = classname;
	    }
	  s = [globalRefs unitRef: r type: t unit: &u];
	}
    }
  else
    {
      NSString	*tmp = u;

      /*
       * Simply look up the reference.
       */
      s = [localRefs unitRef: r type: t unit: &u];
      if (s == nil)
	{
	  u = tmp;
	  s = [globalRefs unitRef: r type: t unit: &u];
	}
    }

  if (s != nil)
    {
      NSString	*sep = @"";

      if ([t isEqual: @"ivariable"] == YES)
	{
	  sep = @"*";
	}
      if ([s isEqual: base] == YES)
	{
	  s = [NSString stringWithFormat: @"<a %@=\"%@%@$%@%@%@\">",
	    kind, hash, t, u, sep, r];
	}
      else
	{
	  s = [s stringByAppendingPathExtension: @"html"];
	  s = [NSString stringWithFormat: @"<a %@=\"%@%@%@$%@%@%@\">",
	    kind, s, hash, t, u, sep, r];
	}
    }
  return s;
}

- (NSString*) outputDocument: (GSXMLNode*)node
{
  NSMutableString	*buf;

  if (localRefs == nil)
    {
      localRefs = [AGSIndex new];
      [localRefs makeRefs: node];
    }
  buf = [NSMutableString stringWithCapacity: 4096];

  [buf appendString: @"<html>\n"];
  [self incIndent];
  [self outputNodeList: node to: buf];
  [self decIndent];
  [buf appendString: @"</html>\n"];

  return buf;
}

- (void) outputIndex: (NSString*)type
	       scope: (NSString*)scope
	       title: (NSString*)title
		  to: (NSMutableString*)buf
{
  NSDictionary	*refs = [localRefs refs];
  NSDictionary	*dict;
  NSArray	*a;
  unsigned	c;
  unsigned	i;

  if (globalRefs != nil && [scope isEqual: @"global"] == YES)
    {
      refs = [globalRefs refs];
    }
  else if (projectRefs != nil && [scope isEqual: @"project"] == YES)
    {
      refs = [projectRefs refs];
    }

  if ([type isEqualToString: @"method"] == YES)
    {
      if (unit == nil)
	{
	  refs = nil;	// Can't index methods outside a unit.
	}
      dict = [refs objectForKey: @"unitmethods"];
      dict = [dict objectForKey: unit];
    }
  else if ([type isEqualToString: @"ivariable"] == YES)
    {
      if (unit == nil)
	{
	  refs = nil;	// Can't index instance variables outside a class.
	}
      dict = [refs objectForKey: @"classvars"];
      dict = [dict objectForKey: unit];
    }
  else
    {
      dict = [refs objectForKey: type];
    }

  if ([dict count] > 1 && [type isEqual: @"title"] == YES)
    {
      [buf appendString: indent];
      [buf appendFormat: @"<b>%@</b>\n", title];
      [buf appendString: indent];
      [buf appendString: @"<ul>\n"];
      [self incIndent];

      a = [dict allKeys];
      a = [a sortedArrayUsingSelector: @selector(compare:)];
      c = [a count];

      for (i = 0; i < c; i++)
	{
	  NSString	*ref = [a objectAtIndex: i];
	  NSString	*text = [dict objectForKey: ref];
	  NSString	*file = ref;

	  if ([file isEqual: base] == YES)
	    {
	      continue;	// Don't list current file.
	    }

	  [buf appendString: indent];
	  [buf appendString: @"<li><a rel=\"gsdoc\" href="];
	  [buf appendFormat: @"\"%@.html#%@$%@\">%@</a></li>\n",
	    file, type, ref, text];
	}

      [self decIndent];
      [buf appendString: indent];
      [buf appendString: @"</ul>\n"];
    }
  else if ([dict count] > 0)
    {
      NSString		*sep = @"";
      NSString		*u = unit;
      BOOL		isInUnit = NO;

      if (unit != nil)
	{
	  if ([type isEqual: @"method"] || [type isEqual: @"ivariable"])
	    {
	      isInUnit = YES;
	      if ([type isEqual: @"ivariable"])
		{
		  sep = @"*";		// List ivars in class
		}
	      else if (category != nil)
		{
		  u = classname;	// List methods in category
		}
	      else if (classname != nil)
		{
		  NSArray	*catNames;

		  /*
		   * For a class, we want to list methods in any associated
		   * categories as well as those of the class itsself.
		   */
		  catNames = [[[refs objectForKey: @"categories"]
		    objectForKey: classname] allKeys];
		  if ((c = [catNames count]) > 0)
		    {
		      NSMutableDictionary	*m = [dict mutableCopy];
		      NSDictionary		*unitDict;

		      unitDict = [refs objectForKey: @"unitmethods"];
		      for (i = 0; i < c; i++)
			{
			  NSString	*catName = [catNames objectAtIndex: i];
			  NSDictionary	*catDict;

			  catName = [classname stringByAppendingFormat: @"(%@)",
			    catName];
			  catDict = [unitDict objectForKey: catName];
			  [m addEntriesFromDictionary: catDict];
			}
		      dict = AUTORELEASE(m);
		    }
		}
	    }
	}

      [buf appendString: indent];
      [buf appendFormat: @"<b>%@</b>\n", title];
      [buf appendString: indent];
      [buf appendString: @"<ul>\n"];
      [self incIndent];

      a = [dict allKeys];
      a = [a sortedArrayUsingSelector: @selector(compare:)];
      c = [a count];

      for (i = 0; i < c; i++)
	{
	  NSString	*ref = [a objectAtIndex: i];
	  NSString	*file = [dict objectForKey: ref];
	  NSString	*text = ref;

	  [buf appendString: indent];
	  [buf appendString: @"<li><a rel=\"gsdoc\" href="];
	  if (isInUnit == YES)
	    {
	      [buf appendFormat: @"\"%@.html#%@$%@%@%@\">%@</a></li>\n",
		file, type, u, sep, ref, text];
	    }
	  else
	    {
	      [buf appendFormat: @"\"%@.html#%@$%@\">%@</a></li>\n",
		file, type, ref, text];
	    }
	}

      [self decIndent];
      [buf appendString: indent];
      [buf appendString: @"</ul>\n"];
    }
}

- (void) outputNode: (GSXMLNode*)node to: (NSMutableString*)buf
{
  CREATE_AUTORELEASE_POOL(arp);
  GSXMLNode	*children = [node firstChild];

  if ([node type] == XML_ELEMENT_NODE)
    {
      NSString		*name = [node name];
      NSDictionary	*prop = [node propertiesAsDictionary];

      if ([name isEqual: @"back"] == YES)
	{
	  // Open back division
	  [buf appendString: indent];
	  [buf appendString: @"<div>\n"];
	  [self incIndent];
	  [self outputNodeList: children to: buf];

	  // Close back division
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</div>\n"];
	}
      else if ([name isEqual: @"body"] == YES)
	{
	  /* Should already be in html body */
	  [self outputNodeList: children to: buf];

	  [buf appendString: indent];
	  [buf appendString: @"<br />\n"];
	  if (prevFile != nil)
	    {
	      [buf appendString: indent];
	      [buf appendFormat: @"<a href=\"%@\">Prev</a>\n", prevFile];
	    }
	  if (upFile != nil)
	    {
	      [buf appendString: indent];
	      [buf appendFormat: @"<a href=\"%@\">Up</a>\n", upFile];
	    }
	  if (nextFile != nil)
	    {
	      [buf appendString: indent];
	      [buf appendFormat: @"<a href=\"%@\">Next</a>\n", nextFile];
	    }

	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</body>\n"];
	}
      else if ([name isEqual: @"br"] == YES)
	{
	  [buf appendString: @"<br />"];
	}
      else if ([name isEqual: @"category"] == YES)
	{
	  NSString	*s;

	  category = [prop objectForKey: @"name"];
	  classname = [prop objectForKey: @"class"];
	  unit = [NSString stringWithFormat: @"%@(%@)", classname, category];
	  [buf appendString: indent];
	  [buf appendString: @"<h2>"];
	  [buf appendString: [self typeRef: classname]];
	  [buf appendString: @"("];
	  s = [self makeAnchor: unit ofType: @"category" name: category];
	  [buf appendString: s];
	  [buf appendString: @")</h2>\n"];
	  [self outputUnit: node to: buf];
	  unit = nil;
	  classname = nil;
	  category = nil;
	}
      else if ([name isEqual: @"chapter"] == YES)
	{
	  heading = @"h1";
	  chap++;
	  sect = 0;
	  ssect = 0;
	  sssect = 0;
	  [self outputNodeList: children to: buf];
	}
      else if ([name isEqual: @"class"] == YES)
	{
	  NSString	*sup = [prop objectForKey: @"super"];

	  classname = [prop objectForKey: @"name"];
	  unit = classname;
	  [buf appendString: indent];
	  [buf appendString: @"<h2>"];
	  [buf appendString:
	    [self makeAnchor: classname ofType: @"class" name: classname]];
	  sup = [self typeRef: sup];
	  if (sup != nil)
	    {
	      [buf appendString: @" : "];
	      [buf appendString: sup];
	    }
	  [buf appendString: @"</h2>\n"];
	  [self outputUnit: node to: buf];
	  unit = nil;
	  classname = nil;
	}
      else if ([name isEqual: @"code"] == YES)
	{
	  [buf appendString: @"<code>"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</code>"];
	}
      else if ([name isEqual: @"constant"] == YES)
	{
	  NSString	*nam;
	  NSString	*str;
	  NSString	*s;

	  nam = [prop objectForKey: @"name"];
	  str = [prop objectForKey: @"type"];
	  str = [self typeRef: str];
	  str = [str stringByAppendingFormat: @" %@;", nam];

	  /*
	   * Output heading.
	   */
	  [buf appendString: indent];
	  [buf appendString: @"<h3>"];
	  s = [self makeLink: nam ofType: @"constant" isRef: NO];
	  if (s != nil)
	    {
	      [buf appendString: s];
	      [buf appendString: nam];
	      [buf appendString: @"</a>"];
	    }
	  else
	    {
	      [buf appendString: nam];
	    }
	  [buf appendString: @"</h3>\n"];
	  [buf appendString: indent];
	  [buf appendString: str];
	  [buf appendString: @";<br />\n"];

	  node = firstElement(children);

	  if ([[node name] isEqual: @"declared"] == YES)
	    {
	      [self outputNode: node to: buf];
	      node = [node nextElement];
	    }

	  children = node;
	  if ([[children name] isEqual: @"standards"])
	    {
	      [self outputNode: children to: buf];
	    }

	  if ([[node name] isEqual: @"desc"])
	    {
	      [self outputNode: node to: buf];
	    }

	  [buf appendString: indent];
	  [buf appendString: @"<hr width=\"25%\" align=\"left\" />\n"];
	}
      else if ([name isEqual: @"contents"] == YES)
        {
	  NSDictionary	*dict;

	  dict = [[localRefs refs] objectForKey: @"contents"];
	  if ([dict count] > 0)
	    {
	      NSArray	*a;
	      unsigned	i;
	      unsigned	l = 0;

	      [buf appendString: indent];
	      [buf appendString: @"<hr width=\"50%\" align=\"left\" />\n"];
	      [buf appendString: indent];
	      [buf appendString: @"<h3>Contents -</h3>\n"];

	      a = [dict allKeys];
	      a = [a sortedArrayUsingSelector: @selector(compare:)];
	      for (i = 0; i < [a count]; i++)
		{
		  NSString	*k = [a objectAtIndex: i];
		  NSString	*v = [dict objectForKey: k];
		  unsigned	pos = 3;

		  if ([k hasSuffix: @"000"] == YES)
		    {
		      pos = 2;
		      if ([k hasSuffix: @"000000"] == YES)
			{
			  pos = 1;
			  if ([k hasSuffix: @"000"] == YES)
			    {
			      pos = 0;
			    }
			}
		      if (l == pos)
			{
			  [buf appendString: indent];
			  [buf appendString: @"<ol>\n"];
			  [self incIndent];
			}
		      else
			{
			  while (l > pos + 1)
			    {
			      [self decIndent];
			      [buf appendString: indent];
			      [buf appendString: @"</li>\n"];
			      [self decIndent];
			      [buf appendString: indent];
			      [buf appendString: @"</ol>\n"];
			      l--;
			    }
			  if (l == pos + 1)
			    {
			      [self decIndent];
			      [buf appendString: indent];
			      [buf appendString: @"</li>\n"];
			      l--;
			    }
			}
		    }
		  [buf appendString: indent];
		  [buf appendString: @"<li>\n"];
		  [self incIndent];
		  [buf appendString: indent];
		  [buf appendFormat: @"<a href=\"#%@\">%@</a>\n", k, v];
		  if (pos == 3)
		    {
		      [self decIndent];
		      [buf appendString: indent];
		      [buf appendString: @"</li>\n"];
		    }
		  else
		    {
		      l++;
		    }
		}
	      while (l > 0)
		{
		  [self decIndent];
		  [buf appendString: indent];
		  [buf appendString: @"</li>\n"];
		  [self decIndent];
		  [buf appendString: indent];
		  [buf appendString: @"</ol>\n"];
		  l--;
		}
	      [buf appendString: indent];
	      [buf appendString: @"<hr width=\"50%\" align=\"left\" />\n"];
	    }
	}
      else if ([name isEqual: @"declared"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<blockquote>\n"];
	  [self incIndent];
	  [buf appendString: indent];
	  [buf appendString: @"<dl>\n"];
	  [self incIndent];
	  [buf appendString: indent];
	  [buf appendString: @"<dt><b>Declared in:</b></dt>\n"];
	  [buf appendString: indent];
	  [buf appendString: @"<dd>"];
	  [self outputText: [node firstChild] to: buf];
	  [buf appendString: @"</dd>\n"];
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</dl>\n"];
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</blockquote>\n"];
	}
      else if ([name isEqual: @"desc"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<p>\n"];
	  [self incIndent];
	  while (children != nil)
	    {
	      children = [self outputBlock: children to: buf inPara: YES];
	    }
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</p>\n"];
	}
      else if ([name isEqual: @"em"] == YES)
	{
	  [buf appendString: @"<em>"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</em>"];
	}
      else if ([name isEqual: @"email"] == YES)
	{
	  NSString	*ename; 

	  ename = [prop objectForKey: @"address"];
	  if (ename == nil)
	    {
	      [buf appendString: @"<code>"];
	    }
	  else
	    {
	      [buf appendFormat: @"<a href=\"mailto:%@\"><code>", ename];
	    }
	  [self outputText: [node firstChild] to: buf];
	  if (ename == nil)
	    {
	      [buf appendString: @"</code>"];
	    }
	  else
	    {
	      [buf appendFormat: @"</code></a>", ename];
	    }
	}
      else if ([name isEqual: @"embed"] == YES)
	{
	  [self outputBlock: node to: buf inPara: NO];
	}
      else if ([name isEqual: @"entry"])
	{
	  NSString		*text;
	  NSString		*val;

	  text = [children content];
	  val = [prop objectForKey: @"id"];
	  if (val == nil)
	    {
	      val = text;
	    }
	  [buf appendString: [self makeAnchor: val ofType: @"label" name: @""]];
	}
      else if ([name isEqual: @"example"] == YES)
	{
	  [self outputBlock: node to: buf inPara: NO];
	}
      else if ([name isEqual: @"file"] == YES)
	{
	  [buf appendString: @"<code>"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</code>"];
	}
      else if ([name isEqual: @"footnote"] == YES)
	{
	  [buf appendString: @"<blockquote>"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</blockquote>"];
	}
      else if ([name isEqual: @"front"] == YES)
	{
	  // Open front division
	  [buf appendString: indent];
	  [buf appendString: @"<div>\n"];
	  [self incIndent];
	  [self outputNodeList: children to: buf];
	  // Close front division
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</div>\n"];
	}
      else if ([name isEqual: @"function"] == YES)
	{
	  NSString	*fun;
	  NSString	*str;
	  NSString	*s;
	  GSXMLNode	*tmp = children;
	  BOOL		hadArg = NO;

	  fun = [prop objectForKey: @"name"];
	  str = [prop objectForKey: @"type"];
	  str = [self typeRef: str];
	  str = [str stringByAppendingFormat: @" %@(", fun];
	  children = nil;
	  while (tmp != nil)
	    {
	      if ([tmp type] == XML_ELEMENT_NODE)
		{
		  if ([[tmp name] isEqual: @"arg"] == YES)
		    {
		      GSXMLNode		*t = [tmp firstChild];
		      NSString		*s;

		      if (hadArg == YES)
			{
			  str = [str stringByAppendingString: @", "];
			}

		      s = [[tmp propertiesAsDictionary] objectForKey: @"type"];
		      s = [self typeRef: s];
		      str = [str stringByAppendingString: s];

		      str = [str stringByAppendingString: @" <b>"];
		      while (t != nil)
			{
			  if ([t type] == XML_TEXT_NODE)
			    {
			      NSString	*content = [t content];

			      str = [str stringByAppendingString: content];
			    }
			  t = [t next];
			}
		      str = [str stringByAppendingString: @"</b>"];
		      hadArg = YES;
		    }
		  else if ([[tmp name] isEqual: @"vararg"] == YES)
		    {
		      if (hadArg == YES)
			{
			  str = [str stringByAppendingString: @"<b>,...</b>"];
			}
		      else
			{
			  str = [str stringByAppendingString: @"<b>,...</b>"];
			}
		      children = [tmp nextElement];
		      break;
		    }
		  else
		    {
		      children = tmp;
		      break;
		    }
		}
	      tmp = [tmp nextElement];
	    }

	  /*
	   * Output function heading.
	   */
	  [buf appendString: indent];
	  [buf appendString: @"<h3>"];
	  s = [self makeLink: fun ofType: @"function" isRef: NO];
	  if (s != nil)
	    {
	      [buf appendString: s];
	      [buf appendString: fun];
	      [buf appendString: @"</a>"];
	    }
	  else
	    {
	      [buf appendString: fun];
	    }
	  [buf appendString: @"</h3>\n"];
	  [buf appendString: indent];
	  [buf appendString: str];
	  [buf appendString: @");<br />\n"];

	  node = firstElement(children);

	  if ([[node name] isEqual: @"declared"] == YES)
	    {
	      [self outputNode: node to: buf];
	      node = [node nextElement];
	    }

	  children = node;
	  if ([[children name] isEqual: @"standards"])
	    {
	      [self outputNode: children to: buf];
	    }

	  if ([[node name] isEqual: @"desc"])
	    {
	      [self outputNode: node to: buf];
	    }

	  [buf appendString: indent];
	  [buf appendString: @"<hr width=\"25%\" align=\"left\" />\n"];
	}
      else if ([name isEqual: @"gsdoc"] == YES)
	{
	  base = [prop objectForKey: @"base"];
	  if (base == nil)
	    {
	      NSLog(@"No 'base' document name supplied in gsdoc element");
	      return;
	    }
	  nextFile = [prop objectForKey: @"next"];
	  nextFile = [nextFile stringByAppendingPathExtension: @"html"];
	  prevFile = [prop objectForKey: @"prev"];
	  prevFile = [prevFile stringByAppendingPathExtension: @"html"];
	  upFile = [prop objectForKey: @"up"];
	  upFile = [upFile stringByAppendingPathExtension: @"html"];
	  [self outputNodeList: children to: buf];
	}
      else if ([name isEqual: @"head"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<head>\n"];
	  [self incIndent];
	  children = firstElement(children);
	  [buf appendString: indent];
	  [buf appendString: @"<title>"];
	  [self incIndent];
	  [self outputText: [children firstChild] to: buf];
	  [self decIndent];
	  [buf appendString: @"</title>\n"];
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</head>\n"];
	  [buf appendString: indent];
	  [buf appendString: @"<body>\n"];
	  [self incIndent];

	  if (prevFile != nil)
	    {
	      [buf appendString: indent];
	      [buf appendFormat: @"<a href=\"%@\">Prev</a>\n", prevFile];
	    }
	  if (upFile != nil)
	    {
	      [buf appendString: indent];
	      [buf appendFormat: @"<a href=\"%@\">Up</a>\n", upFile];
	    }
	  if (nextFile != nil)
	    {
	      [buf appendString: indent];
	      [buf appendFormat: @"<a href=\"%@\">Next</a>\n", nextFile];
	    }
	  [buf appendString: indent];
	  [buf appendString: @"<br />\n"];

	  [buf appendString: indent];
	  [buf appendFormat: @"<h1><a name=\"title$%@\">", base];
	  [self outputText: [children firstChild] to: buf];
	  [buf appendString: @"</a></h1>\n"];

	  [buf appendString: indent];
	  [buf appendString: @"<h3>Authors</h3>\n"];
	  [buf appendString: indent];
	  [buf appendString: @"<dl>\n"];
	  [self incIndent];
	  children = [children nextElement];
	  while ([[children name] isEqual: @"author"] == YES)
	    {
	      GSXMLNode		*author = children;
	      GSXMLNode		*tmp;
	      GSXMLNode		*email = nil;
	      GSXMLNode		*url = nil;
	      GSXMLNode		*desc = nil;

	      children = [children nextElement];

	      tmp = [author firstChildElement];
	      if ([[tmp name] isEqual: @"email"] == YES)
		{
		  email = tmp;
		  tmp = [tmp nextElement];
		}
	      if ([[tmp name] isEqual: @"url"] == YES)
		{
		  url = tmp;
		  tmp = [tmp nextElement];
		}
	      if ([[tmp name] isEqual: @"desc"] == YES)
		{
		  desc = tmp;
		  tmp = [tmp nextElement];
		}

	      [buf appendString: indent];
	      if (url == nil)
		{
		  [buf appendString: @"<dt>"];
		  [buf appendString: [[author propertiesAsDictionary]
		    objectForKey: @"name"]];
		}
	      else
		{
		  [buf appendString: @"<dt><a href=\""];
		  [buf appendString: [[url propertiesAsDictionary]
		    objectForKey: @"url"]];
		  [buf appendString: @"\">"];
		  [buf appendString: [[author propertiesAsDictionary]
		    objectForKey: @"name"]];
		  [buf appendString: @"</a>"];
		}
	      if (email != nil)
		{
		  [buf appendString: @"("];
		  [self outputNode: email to: buf];
		  [buf appendString: @")"];
		}
	      [buf appendString: @"</dt>\n"];
	      [buf appendString: indent];
	      [buf appendString: @"<dd>\n"];
	      if (desc != nil)
		{
		  [self incIndent];
		  while (desc != nil)
		    {
		      desc = [self outputBlock: desc to: buf inPara: NO];
		    }
		  [self decIndent];
		}
	      [buf appendString: indent];
	      [buf appendString: @"</dd>\n"];
	    }
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</dl>\n"];
	  if ([[children name] isEqual: @"version"] == YES)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"<p><b>Version:</b> "];
	      [self outputText: [children firstChild] to: buf];
	      [buf appendString: @"</p>\n"];
	      children = [children nextElement];
	    }
	  if ([[children name] isEqual: @"date"] == YES)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"<p><b>Date:</b> "];
	      [self outputText: [children firstChild] to: buf];
	      [buf appendString: @"</p>\n"];
	      children = [children nextElement];
	    }
	  if ([[children name] isEqual: @"abstract"] == YES)
	    {
	      GSXMLNode	*tmp = [children firstChild];

	      [buf appendString: indent];
	      [buf appendString: @"<blockquote>\n"];
	      [self incIndent];
	      while (tmp != nil)
		{
		  tmp = [self outputBlock: tmp to: buf inPara: NO];
		}
	      [self decIndent];
	      [buf appendString: indent];
	      [buf appendString: @"</blockquote>\n"];
	      children = [children nextElement];
	    }
	  if ([[children name] isEqual: @"copy"] == YES)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"<p><b>Copyright:</b> (C) "];
	      [self outputText: [children firstChild] to: buf];
	      [buf appendString: @"</p>\n"];
	      children = [children nextElement];
	    }
	}
      else if ([name isEqual: @"heading"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<"];
	  [buf appendString: heading];
	  [buf appendString: @">"];
	  [buf appendFormat: @"<a name=\"%03u%03u%03u%03u\">",
	    chap, sect, ssect, sssect];
	  [self outputText: children to: buf];
	  [buf appendString: @"</a></"];
	  [buf appendString: heading];
	  [buf appendString: @">\n"];
	}
      else if ([name isEqual: @"index"] == YES)
        {
	  NSString	*scope = [prop objectForKey: @"scope"];
	  NSString	*type = [prop objectForKey: @"type"];
	  NSString	*title = [type capitalizedString];

	  [self outputIndex: type scope: scope title: title to: buf];
	}
      else if ([name isEqual: @"ivar"] == YES)	// %phrase
	{
	  [buf appendString: @"<var>"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</var>"];
	}
      else if ([name isEqual: @"ivariable"] == YES)
	{
	  NSString	*n = [prop objectForKey: @"name"];
	  NSString	*t = [prop objectForKey: @"type"];
	  NSString	*v = [prop objectForKey: @"validity"];
	  NSString	*s;
	  GSXMLNode	*tmp = children;

	  [buf appendString: indent];
	  [buf appendString: @"<h3>"];
	  s = [self makeLink: n ofType: @"ivariable" inUnit: nil isRef: NO];
	  if (s != nil)
	    {
	      [buf appendString: s];
	      [buf appendString: n];
	      [buf appendString: @"</a>"];
	    }
	  else
	    {
	      [buf appendString: n];
	    }
	  [buf appendString: @"</h3>\n"];
	  if (v == nil)
	    {
	      v = @"public";
	    }
	  [buf appendFormat: @"%@@%@ %@ <b>%@</b>;<br />\n", indent, v, t, n];

	  if ([[children name] isEqual: @"desc"] == YES)
	    {
	      children = [children nextElement];
	    }
	  /*
	   * List standards with which method complies
	   */
	  if ([[children name] isEqual: @"standards"])
	    {
	      [self outputNode: children to: buf];
	    }
	  if ([[tmp name] isEqual: @"desc"])
	    {
	      [self outputNode: tmp to: buf];
	    }

	  [buf appendString: indent];
	  [buf appendString: @"<hr width=\"25%\" align=\"left\" />\n"];
	}
      else if ([name isEqual: @"label"] == YES)	// %anchor
	{
	  NSString		*text;
	  NSString		*val;

	  text = [children content];
	  val = [prop objectForKey: @"id"];
	  if (val == nil)
	    {
	      val = text;
	    }
	  [buf appendString:
	    [self makeAnchor: val ofType: @"label" name: text]];
	}
      else if ([name isEqual: @"method"] == YES)
	{
	  NSString	*sel;
	  NSString	*str;
	  GSXMLNode	*tmp = children;
	  BOOL		hadArg = NO;

	  sel = [prop objectForKey: @"factory"];
	  str = [prop objectForKey: @"type"];
	  if (sel != nil && [sel boolValue] == YES)
	    {
	      sel = @"+";
	      str = [NSString stringWithFormat: @"+ (%@) ",
		[self typeRef: str]];
	    }
	  else
	    {
	      sel = @"-";
	      str = [NSString stringWithFormat: @"- (%@) ",
		[self typeRef: str]];
	    }
	  children = nil;
	  while (tmp != nil)
	    {
	      if ([tmp type] == XML_ELEMENT_NODE)
		{
		  if ([[tmp name] isEqual: @"sel"] == YES)
		    {
		      GSXMLNode	*t = [tmp firstChild];

		      str = [str stringByAppendingString: @"<b>"];
		      while (t != nil)
			{
			  if ([t type] == XML_TEXT_NODE)
			    {
			      NSString	*content = [t content];

			      sel = [sel stringByAppendingString: content];
			      if (hadArg == YES)
				{
				  str = [str stringByAppendingString: @" "];
				}
			      str = [str stringByAppendingString: content];
			    }
			  t = [t next];
			}
		      str = [str stringByAppendingString: @"</b>"];
		    }
		  else if ([[tmp name] isEqual: @"arg"] == YES)
		    {
		      GSXMLNode	*t = [tmp firstChild];
		      NSString	*s;

		      s = [[tmp propertiesAsDictionary] objectForKey: @"type"];
		      s = [self typeRef: s];
		      str = [str stringByAppendingFormat: @" (%@)", s];
		      while (t != nil)
			{
			  if ([t type] == XML_TEXT_NODE)
			    {
			      str = [str stringByAppendingString: [t content]];
			    }
			  t = [t next];
			}
		      hadArg = YES;	// Say we have found an arg.
		    }
		  else if ([[tmp name] isEqual: @"vararg"] == YES)
		    {
		      sel = [sel stringByAppendingString: @",..."];
		      str = [str stringByAppendingString: @"<b>,...</b>"];
		      children = [tmp nextElement];
		      break;
		    }
		  else
		    {
		      children = tmp;
		      break;
		    }
		}
	      tmp = [tmp nextElement];
	    }
	  if ([sel length] > 1)
	    {
	      NSString	*s;

	      /*
	       * Output selector heading.
	       */
	      [buf appendString: indent];
	      [buf appendString: @"<h3>"];
	      s = [self makeLink: sel ofType: @"method" inUnit: nil isRef: NO];
	      if (s != nil)
		{
		  [buf appendString: s];
		  [buf appendString: [sel substringFromIndex: 1]];
		  [buf appendString: @"</a>"];
		}
	      else
		{
		  [buf appendString: [sel substringFromIndex: 1]];
		}
	      [buf appendString: @"</h3>\n"];
	      [buf appendString: indent];
	      [buf appendString: str];
	      [buf appendString: @";<br />\n"];

	      node = firstElement(children);

	      /*
	       * List standards with which method complies
	       */
	      children = firstElement(node);
	      if ([[children name] isEqual: @"standards"])
		{
		  [self outputNode: children to: buf];
		}

	      if ((str = [prop objectForKey: @"init"]) != nil
		&& [str boolValue] == YES)
		{
		  [buf appendString: @"This is a designated initialiser "
		    @"for the class.<br />\n"];
		}
	      str = [prop objectForKey: @"override"];
	      if ([str isEqual: @"subclass"] == YES)
		{
		  [buf appendString: @"Subclasses <strong>should</strong> "
		    @"override this method.<br />\n"];
		}
	      else if ([str isEqual: @"never"] == YES)
		{
		  [buf appendString: @"Subclasses should <strong>NOT</strong> "
		    @"override this method.<br />\n"];
		}

	      if ([[node name] isEqual: @"desc"])
		{
		  [self outputNode: node to: buf];
		}
	      [buf appendString: indent];
	      [buf appendString: @"<hr width=\"25%\" align=\"left\" />\n"];
	    }
	}
      else if ([name isEqual: @"p"] == YES)
	{
	  [self outputBlock: node to: buf inPara: NO];
	}
      else if ([name isEqual: @"prjref"] == YES)
	{
	  NSLog(@"Element '%@' not implemented", name); 	    // FIXME
	}
      else if ([name isEqual: @"ref"] == YES)	// %xref
	{
	  NSString	*type = [prop objectForKey: @"type"];
	  NSString	*r = [prop objectForKey: @"id"];
	  GSXMLNode	*tmp = [node firstChild];
	  NSString	*s;

	  if ([type isEqual: @"method"] || [type isEqual: @"ivariable"])
	    {
	      s = [prop objectForKey: @"class"];
	      s = [self makeLink: r ofType: type inUnit: s isRef: YES];
	    }
	  else
	    {
	      s = [self makeLink: r ofType: type isRef: YES];
	    }
	  if (s == nil)
	    {
	      NSLog(@"ref '%@' not found for %@", r, type);
	      if (tmp == nil)
		{
		  [buf appendString: r];
		}
	      else
		{
		  [self outputText: tmp to: buf];
		}
	      [buf appendString: @"\n"];
	    }
	  else
	    {
	      [buf appendString: s];
	      if (tmp == nil)
		{
		  [buf appendString: r];
		}
	      else
		{
		  [self outputText: tmp to: buf];
		}
	      [buf appendString: @"</a>\n"];
	    }
	}
      else if ([name isEqual: @"protocol"] == YES)
	{
	  NSString	*name = [prop objectForKey: @"name"];

	  unit = [NSString stringWithFormat: @"(%@)", name];
	  [buf appendString: indent];
	  [buf appendString: @"<h2>"];
	  [buf appendString:
	    [self makeAnchor: unit ofType: @"protocol" name: name]];
	  [buf appendString: @"</h2>\n"];
	  [self outputUnit: node to: buf];
	  unit = nil;
	}
      else if ([name isEqual: @"EOEntity"] == YES
	|| [name isEqual: @"EOModel"] == YES
	|| [name isEqual: @"macro"] == YES)
	{
	  NSString	*tmp = [prop objectForKey: @"name"];

	  NSLog(@"Element '%@' not implemented", name); 	    // FIXME
	}
      else if ([name isEqual: @"section"] == YES)
	{
	  heading = @"h2";
	  sect++;
	  ssect = 0;
	  sssect = 0;
	  [self outputNodeList: children to: buf];
	}
      else if ([name isEqual: @"site"] == YES)
	{
	  [buf appendString: @"<code>"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</code>"];
	}
      else if ([name isEqual: @"standards"])
	{
	  GSXMLNode	*tmp = [node firstChild];
	  BOOL		first = YES;

	  if (tmp != nil)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"<b>Standards:</b>"];
	      while (tmp != nil)
		{
		  if ([tmp type] == XML_ELEMENT_NODE)
		    {
		      if (first == YES)
			{
			  first = NO;
			  [buf appendString: @" "];
			}
		      else
			{
			  [buf appendString: @", "];
			}
		      [buf appendString: [tmp name]];
		    }
		  tmp = [tmp nextElement];
		}
	      [buf appendString: @"<br />\n"];
	    }
	}
      else if ([name isEqual: @"strong"] == YES)
	{
	  [buf appendString: @"<strong>"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</strong>"];
	}
      else if ([name isEqual: @"subsect"] == YES)
	{
	  heading = @"h3";
	  ssect++;
	  sssect = 0;
	  [self outputNodeList: children to: buf];
	}
      else if ([name isEqual: @"subsubsect"] == YES)
	{
	  heading = @"h4";
	  sssect++;
	  [self outputNodeList: children to: buf];
	}
      else if ([name isEqual: @"type"] == YES)
	{
	  NSString	*nam;
	  NSString	*str;
	  NSString	*s;

	  nam = [prop objectForKey: @"name"];
	  str = [prop objectForKey: @"type"];
	  str = [self typeRef: str];
	  str = [NSString stringWithFormat: @"typedef %@ %@", str, nam];

	  /*
	   * Output typedef heading.
	   */
	  [buf appendString: indent];
	  [buf appendString: @"<h3>"];
	  s = [self makeLink: nam ofType: @"type" isRef: NO];
	  if (s != nil)
	    {
	      [buf appendString: s];
	      [buf appendString: nam];
	      [buf appendString: @"</a>"];
	    }
	  else
	    {
	      [buf appendString: nam];
	    }
	  [buf appendString: @"</h3>\n"];
	  [buf appendString: indent];
	  [buf appendString: str];
	  [buf appendString: @";<br />\n"];

	  node = firstElement(children);

	  if (node != nil && [[node name] isEqual: @"declared"] == YES)
	    {
	      [self outputNode: node to: buf];
	      node = [node nextElement];
	    }

	  children = node;
	  if ([[children name] isEqual: @"standards"])
	    {
	      [self outputNode: children to: buf];
	    }

	  if (node != nil && [[node name] isEqual: @"desc"] == YES)
	    {
	      [self outputNode: node to: buf];
	      node = [node nextElement];
	    }

	  [buf appendString: indent];
	  [buf appendString: @"<hr width=\"25%\" align=\"left\" />\n"];
	}
      else if ([name isEqual: @"uref"] == YES)
	{
	  [buf appendString: @"<a href=\""];
	  [buf appendString: [prop objectForKey: @"url"]];
	  [buf appendString: @"\">"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</a>"];
	}
      else if ([name isEqual: @"url"] == YES)
	{
NSLog(@"Element '%@' not implemented", name); 	    // FIXME
	}
      else if ([name isEqual: @"var"] == YES)	// %phrase
	{
	  [buf appendString: @"<var>"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</var>"];
	}
      else if ([name isEqual: @"variable"] == YES)
	{
	  NSString	*nam;
	  NSString	*str;
	  NSString	*s;

	  nam = [prop objectForKey: @"name"];
	  str = [prop objectForKey: @"type"];
	  str = [self typeRef: str];
	  str = [str stringByAppendingFormat: @" %@", nam];

	  /*
	   * Output variable heading.
	   */
	  [buf appendString: indent];
	  [buf appendString: @"<h3>"];
	  s = [self makeLink: nam ofType: @"variable" isRef: NO];
	  if (s != nil)
	    {
	      [buf appendString: s];
	      [buf appendString: nam];
	      [buf appendString: @"</a>"];
	    }
	  else
	    {
	      [buf appendString: nam];
	    }
	  [buf appendString: @"</h3>\n"];
	  [buf appendString: indent];
	  [buf appendString: str];
	  [buf appendString: @";<br />\n"];

	  node = firstElement(children);

	  if ([[node name] isEqual: @"declared"] == YES)
	    {
	      [self outputNode: node to: buf];
	      node = [node nextElement];
	    }

	  children = node;
	  if ([[children name] isEqual: @"standards"])
	    {
	      [self outputNode: children to: buf];
	    }

	  if ([[node name] isEqual: @"desc"])
	    {
	      [self outputNode: node to: buf];
	    }

	  [buf appendString: indent];
	  [buf appendString: @"<hr width=\"25%\" align=\"left\" />\n"];
	}
      else
	{
	  GSXMLNode	*tmp;
	  /*
	   * Try outputing as any of the list elements.
	   */
	  tmp = [self outputList: node to: buf];
	  if (tmp == node)
	    {
	      NSLog(@"Element '%@' not implemented", name);	// FIXME
	    }
	  node = tmp;
	}
    }
  RELEASE(arp);
}

- (void) outputNodeList: (GSXMLNode*)node to: (NSMutableString*)buf
{
  while (node != nil)
    {
      GSXMLNode	*next = [node nextElement];

      [self outputNode: node to: buf];
      node = next;
    }
}

/**
 * Outputs zero or more nodes at the same level as long as the nodes
 * are valid %block elements.  Returns nil or the first node not output.
 * The value of flag is used to control paragraph nesting ... if YES
 * we close a paragraph before opening a new one, and open again once
 * the new paragraph closes.
 */
- (GSXMLNode*) outputBlock: (GSXMLNode*)node
			to: (NSMutableString*)buf
		    inPara: (BOOL)flag
{
  if (node != nil &&  [node type] == XML_ELEMENT_NODE)
    {
      GSXMLNode	*tmp = node;
      NSString	*n;

      node = [self outputList: node to: buf];
      if (node != tmp)
	{
	  return node;
	}
      n = [node name];
      if ([n isEqual: @"p"] == YES)
	{
	  if (flag == YES)
	    {
	      [self decIndent];
	      [buf appendString: indent];
	      [buf appendString: @"</p>\n"];
	    }
	  [buf appendString: indent];
	  [buf appendString: @"<p>\n"];
	  [self incIndent];
	  [self outputText: [node firstChild] to: buf];
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</p>\n"];
	  if (flag == YES)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"<p>\n"];
	      [self incIndent];
	    }
	  return [node nextElement];
	}
      else if ([n isEqual: @"example"] == YES)
	{
	  [buf appendString: @"<pre>\n"];
	  [self outputText: [node firstChild] to: buf];
	  [buf appendString: @"\n</pre>\n"];
	  return [node nextElement];
	}
      else if ([n isEqual: @"embed"] == YES)
	{
	  NSLog(@"Element 'embed' not supported");
	  return [node nextElement];
	}
      else if ([n isEqual: @"index"] == YES)
	{
	  [self outputNode: node to: buf];
	  return [node nextElement];
	}
      else if ([textNodes member: n] != nil)
	{
	  [buf appendString: indent];
	  node = [self outputText: node to: buf];
	  [buf appendString: @"\n"];
	  return node;
	}
      else
	{
	  NSLog(@"Non-block element '%@' in block ...", n);
	  return node;
	}
    }

  [buf appendString: indent];
  node = [self outputText: node to: buf];
  [buf appendString: @"\n"];
  return node;
}

/**
 * Outputs a node as long as it is a
 * valid %list element.  Returns next node at this level.
 */
- (GSXMLNode*) outputList: (GSXMLNode*)node to: (NSMutableString*)buf
{
  NSString	*name = [node name];
  GSXMLNode	*children = [node firstChildElement];

  if ([name isEqual: @"list"] == YES)
    {
      [buf appendString: indent];
      [buf appendString: @"<ul>\n"];
      [self incIndent];
      while (children != nil)
	{
	  GSXMLNode	*tmp = [children firstChild];

	  [buf appendString: indent];
	  [buf appendString: @"<li>\n"];
	  [self incIndent];
	  while (tmp != nil)
	    {
	      tmp = [self outputBlock: tmp to: buf inPara: NO];
	    }
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</li>\n"];
	  children = [children nextElement];
	}
      [self decIndent];
      [buf appendString: indent];
      [buf appendString: @"</ul>\n"];
    }
  else if ([name isEqual: @"enum"] == YES)
    {
      [buf appendString: indent];
      [buf appendString: @"<ol>\n"];
      [self incIndent];
      while (children != nil)
	{
	  GSXMLNode	*tmp = [children firstChild];

	  [buf appendString: indent];
	  [buf appendString: @"<li>\n"];
	  [self incIndent];
	  while (tmp != nil)
	    {
	      tmp = [self outputBlock: tmp to: buf inPara: NO];
	    }
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</li>\n"];
	  children = [children nextElement];
	}
      [self decIndent];
      [buf appendString: indent];
      [buf appendString: @"</ol>\n"];
    }
  else if ([name isEqual: @"deflist"] == YES)
    {
      [buf appendString: indent];
      [buf appendString: @"<dl>\n"];
      [self incIndent];
      while (children != nil)
	{
	  GSXMLNode	*tmp;

	  [buf appendString: indent];
	  [buf appendString: @"<dt>"];
	  [self outputText: [children firstChild] to: buf];
	  [buf appendString: @"</dt>\n"];
	  children = [children nextElement];
	  [buf appendString: indent];
	  [buf appendString: @"<dd>\n"];
	  [self incIndent];
	  tmp = [children firstChild];
	  while (tmp != nil)
	    {
	      tmp = [self outputBlock: tmp to: buf inPara: NO];
	    }
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</dd>\n"];
	  children = [children nextElement];
	}
      [self decIndent];
      [buf appendString: indent];
      [buf appendString: @"</dl>\n"];
    }
  else if ([name isEqual: @"qalist"] == YES)
    {
      [buf appendString: indent];
      [buf appendString: @"<dl>\n"];
      [self incIndent];
      while (children != nil)
	{
	  GSXMLNode	*tmp;

	  [buf appendString: indent];
	  [buf appendString: @"<dt>"];
	  [self outputText: [children firstChild] to: buf];
	  [buf appendString: @"</dt>\n"];
	  children = [children nextElement];
	  [buf appendString: indent];
	  [buf appendString: @"<dd>\n"];
	  [self incIndent];
	  tmp = [children firstChild];
	  while (tmp != nil)
	    {
	      tmp = [self outputBlock: tmp to: buf inPara: NO];
	    }
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</dd>\n"];
	  children = [children nextElement];
	}
      [self decIndent];
      [buf appendString: indent];
      [buf appendString: @"</dl>\n"];
    }
  else if ([name isEqual: @"dictionary"] == YES)
    {
NSLog(@"Element '%@' not implemented", name); // FIXME
    }
  else
    {
      return node;	// Not a list
    }
  node = [node nextElement];
  return node;
}

/**
 * Outputs zero or more nodes at the same level as long as the nodes
 * are valid %text elements.  Returns nil or the first node not output.
 */
- (GSXMLNode*) outputText: (GSXMLNode*)node to: (NSMutableString*)buf
{
  while (node != nil)
    {
      if ([node type] == XML_TEXT_NODE)
	{
	  [buf appendString: [node content]];
	}
      else if ([node type] == XML_ENTITY_REF_NODE)
	{
	  [buf appendString: @"&"];
	  [buf appendString: [node name]]; 
	  [buf appendString: @";"];
	}
      else if ([node type] == XML_ELEMENT_NODE)
	{
	  NSString	*name = [node name];

	  if ([textNodes member: name] != nil)
	    {
	      [self outputNode: node to: buf];
	    }
	  else
	    {
	      return node;	// Not a text node.
	    }
	}
      node = [node next];
    }
  return node;
}

- (void) outputUnit: (GSXMLNode*)node to: (NSMutableString*)buf
{
  GSXMLNode	*t;
  NSArray	*a;

  node = [node firstChildElement];
  if (node != nil && [[node name] isEqual: @"declared"] == YES)
    {
      [self outputNode: node to: buf];
      node = [node nextElement];
    }

  if (node != nil && [[node name] isEqual: @"conform"] == YES)
    {
      [buf appendString: indent];
      [buf appendString: @"<blockquote>\n"];
      [self incIndent];
      [buf appendString: indent];
      [buf appendString: @"<dl>\n"];
      [self incIndent];
      [buf appendString: indent];
      [buf appendString: @"<dt><b>Conforms to:</b></dt>\n"];
      while (node != nil && [[node name] isEqual: @"conform"] == YES)
	{
	  NSString	*text = [[node firstChild] content];

	  [buf appendString: indent];
	  [buf appendString: @"<dd>"];
	  [buf appendString: [self protocolRef: text]];
	  [buf appendString: @"</dd>\n"];
	  node = [node nextElement];
	}
      [self decIndent];
      [buf appendString: indent];
      [buf appendString: @"</dl>\n"];
      [self decIndent];
      [buf appendString: indent];
      [buf appendString: @"</blockquote>\n"];
    }

  t = node;
  while (t != nil && [[t name] isEqual: @"standards"] == NO)
    {
      t = [t nextElement];
    }
  if (t != nil && [t firstChild] != nil)
    {
      t = [t firstChild];
      [buf appendString: indent];
      [buf appendString: @"<blockquote>\n"];
      [self incIndent];
      [buf appendString: indent];
      [buf appendString: @"<b>Standards:</b>\n"];
      [buf appendString: indent];
      [buf appendString: @"<ul>\n"];
      [self incIndent];
      while (t != nil)
	{
	  if ([t type] == XML_ELEMENT_NODE)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"<li>"];
	      [buf appendString: [t name]];
	      [buf appendString: @"</li>\n"];
	    }
	  t = [t nextElement];
	}
      [self decIndent];
      [buf appendString: indent];
      [buf appendString: @"</ul>\n"];
      [self decIndent];
      [buf appendString: indent];
      [buf appendString: @"</blockquote>\n"];
    }

  if (node != nil && [[node name] isEqual: @"desc"] == YES)
    {
      [self outputNode: node to: buf];
      node = [node nextElement];
    }

  if (node != nil && [[node name] isEqual: @"ivariable"] == YES)
    {
      [buf appendString: indent];
      [buf appendString: @"<hr width=\"50%\" align=\"left\" />\n"];
      [buf appendString: indent];
      [buf appendString: @"<h3>Instance variables</h3>\n"];
      while (node != nil && [[node name] isEqual: @"ivariable"] == YES)
	{
	  [self outputNode: node to: buf];
	  node = [node nextElement];
	}
    }

  a = [localRefs methodsInUnit: unit];
  if ([a count] > 0)
    {
      [self outputIndex: @"method"
		  scope: @"global"
		  title: @"Method summary"
		     to: buf];
      [buf appendString: indent];
      [buf appendString: @"<hr width=\"50%\" align=\"left\" />\n"];
      while (node != nil)
	{
	  if ([[node name] isEqual: @"method"] == YES)
	    {
	      [self outputNode: node to: buf];
	    }
	  node = [node nextElement];
	}
    }
}

/**
 * Try to make a link to the documentation for the supplied protocol.
 */
- (NSString*) protocolRef: (NSString*)t
{
  NSString	*n;
  NSString	*s;

  t = [t stringByTrimmingSpaces];
  n = [NSString stringWithFormat: @"(%@)", t];
  s = [self makeLink: n ofType: @"protocol" isRef: YES];
  if (s != nil)
    {
      s = [s stringByAppendingString: t];
      t = [s stringByAppendingString: @"</a>"];
    }
  return t;
}

- (void) setGlobalRefs: (AGSIndex*)r
{
  ASSIGN(globalRefs, r);
}

- (void) setLocalRefs: (AGSIndex*)r
{
  ASSIGN(localRefs, r);
}

- (void) setProjectRefs: (AGSIndex*)r
{
  ASSIGN(projectRefs, r);
}

/**
 * Assuming that the supplied string contains type information (as used
 * in a method declaration or type cast), we make an attempt at extracting
 * the basic type, and seeing if we can find a documented declaration for
 * it.  If we can, we return a modified version of the string containing
 * a link to the appropriate documentation.  Otherwise, we just return the
 * plain type string.  In all cases, we strip leading and trailing white space.
 */
- (NSString*) typeRef: (NSString*)t
{
  NSString	*orig = [t stringByTrimmingSpaces];
  NSString	*s;
  unsigned	end = [orig length];
  unsigned	start;

  t = orig;
  while (end > 0)
    {
      unichar	c = [t characterAtIndex: end-1];

      if (c != '*' && !isspace(c))
	{
	  break;
	}
      end--;
    }
  start = end;
  while (start > 0)
    {
      unichar	c = [t characterAtIndex: start-1];

      if (c != '_' && !isalnum(c))
	{
	  break;
	}
      start--;
    }
  t = [orig substringWithRange: NSMakeRange(start, end - start)];

  s = [self makeLink: t ofType: @"type" isRef: YES];
  if (s == nil)
    {
      s = [self makeLink: t ofType: @"class" isRef: YES];
    }

  if (s != nil)
    {
      s = [s stringByAppendingFormat: @"%@</a>", t];
      if ([orig length] == [t length])
	{
	  return s;
	}
      return [orig stringByReplacingString: t withString: s];
    }
  return orig;
}

@end

