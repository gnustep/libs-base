/** 

   <title>AGSHtml ... a class to output html for a gsdoc file</title>
   Copyright <copy>(C) 2001 Free Software Foundation, Inc.</copy>

   Written by:  <author name="Richard Frith-Macdonald">
   <email>richard@brainstorm.co.uk</email></author>
   Created: October 2001

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

#include	<Foundation/Foundation.h>
#include        "AGSHtml.h"

static int      XML_ELEMENT_NODE;
static int      XML_TEXT_NODE;

@implementation	AGSHtml

+ (void) initialize
{
  if (self == [AGSHtml class])
    {
      /*
       * Cache XML node information.
       */
      XML_ELEMENT_NODE = [GSXMLNode typeFromDescription: @"XML_ELEMENT_NODE"];
      XML_TEXT_NODE = [GSXMLNode typeFromDescription: @"XML_TEXT_NODE"];
    }
}

- (void) dealloc
{
  RELEASE(globalRefs);
  RELEASE(localRefs);
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
  [self outputNode: node to: buf];
  [self decIndent];
  [buf appendString: @"</html>\n"];

  return buf;
}

- (void) outputNode: (GSXMLNode*)node to: (NSMutableString*)buf
{
  GSXMLNode	*children = [node children];
  GSXMLNode	*next = [node next];
  BOOL		newUnit = NO;

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
	  [self outputNode: children to: buf];
	  children = nil;

	  // Close back division
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</div>\n"];
	}
      else if ([name isEqual: @"body"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<body>\n"];
	  [self incIndent];
	  [self outputNode: children to: buf];
	  children = nil;
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</body>\n"];
	}
      else if ([name isEqual: @"category"] == YES)
	{
	  newUnit = YES;
	  unit = [NSString stringWithFormat: @"%@(%@)",
	    [prop objectForKey: @"class"], [prop objectForKey: @"name"]];
	  [self outputUnit: node to: buf];
	  children = nil;
	}
      else if ([name isEqual: @"chapter"] == YES)
	{
	  heading = @"h1";
	  [self outputNode: children to: buf];
	  children = nil;
	}
      else if ([name isEqual: @"class"] == YES)
	{
	  newUnit = YES;
	  unit = [prop objectForKey: @"name"];
	  [self outputUnit: node to: buf];
	  children = nil;
	}
      else if ([name isEqual: @"desc"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<p>\n"];
	  [self incIndent];
	  [self outputBlock: children to: buf inPara: YES];
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</p>\n"];
	}
      else if ([name isEqual: @"front"] == YES)
	{
	  // Open front division
	  [buf appendString: indent];
	  [buf appendString: @"<div>\n"];
	  [self incIndent];
	  [self outputNode: children to: buf];
	  children = nil;
	  // Close front division
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</div>\n"];
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
	  prevFile = [prop objectForKey: @"pref"];
	  prevFile = [prevFile stringByAppendingPathExtension: @"html"];
	  upFile = [prop objectForKey: @"up"];
	  upFile = [upFile stringByAppendingPathExtension: @"html"];
	}
      else if ([name isEqual: @"head"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<head>\n"];
	  [self incIndent];
	  [self outputNode: children to: buf];
	  children = nil;
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</head>\n"];
	}
      else if ([name isEqual: @"heading"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<"];
	  [buf appendString: heading];
	  [buf appendString: @">"];
	  [self outputText: children to: buf];
	  children = nil;
	  [buf appendString: @"</"];
	  [buf appendString: heading];
	  [buf appendString: @">\n"];
	}
      else if ([name isEqual: @"ivariable"] == YES)
	{
	  NSString	*tmp = [prop objectForKey: @"name"];

	}
      else if ([name isEqual: @"entry"] || [name isEqual: @"label"])
	{
	  NSString		*text;
	  NSString		*val;

	  text = [children content];
	  children = nil;
	  val = [prop objectForKey: @"id"];
	  if (val == nil)
	    {
	      val = text;
	    }
	}
      else if ([name isEqual: @"method"] == YES)
	{
	  NSString	*sel = @"";
	  GSXMLNode	*tmp = children;

	  sel = [prop objectForKey: @"factory"];
	  if (sel != nil && [sel boolValue] == YES)
	    {
	      sel = @"+";
	    }
	  else
	    {
	      sel = @"-";
	    }
	  children = nil;
	  while (tmp != nil)
	    {
	      if ([tmp type] == XML_ELEMENT_NODE)
		{
		  if ([[tmp name] isEqual: @"sel"] == YES)
		    {
		      GSXMLNode	*t = [tmp children];

		      while (t != nil)
			{
			  if ([t type] == XML_TEXT_NODE)
			    {
			      sel = [sel stringByAppendingString: [t content]];
			    }
			  t = [t next];
			}
		    }
		  else if ([[tmp name] isEqual: @"arg"] == NO)
		    {
		      children = tmp;
		      break;
		    }
		  else if ([[tmp name] isEqual: @"vararg"] == YES)
		    {
		      sel = [sel stringByAppendingString: @",..."];
		      children = [tmp next];
		      break;
		    }
		}
	      tmp = [tmp next];
	    }
	  if ([sel length] > 1)
	    {
	    }
	}
      else if ([name isEqual: @"protocol"] == YES)
	{
	  newUnit = YES;
	  unit = [prop objectForKey: @"name"];
	  [self outputUnit: node to: buf];
	  children = nil;
	}
      else if ([name isEqual: @"constant"] == YES
	|| [name isEqual: @"EOEntity"] == YES
	|| [name isEqual: @"EOModel"] == YES
	|| [name isEqual: @"function"] == YES
	|| [name isEqual: @"macro"] == YES
	|| [name isEqual: @"type"] == YES
	|| [name isEqual: @"variable"] == YES)
	{
	  NSString	*tmp = [prop objectForKey: @"name"];

	}
      else if ([name isEqual: @"section"] == YES)
	{
	  heading = @"h2";
	  [self outputNode: children to: buf];
	  children = nil;
	}
      else if ([name isEqual: @"subsect"] == YES)
	{
	  heading = @"h3";
	  [self outputNode: children to: buf];
	  children = nil;
	}
      else if ([name isEqual: @"subsubsect"] == YES)
	{
	  heading = @"h4";
	  [self outputNode: children to: buf];
	  children = nil;
	}
      else if ([name isEqual: @"title"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<title>"];
	  [self incIndent];
	  [self outputText: children to: buf];
	  children = nil;
	  [self decIndent];
	  [buf appendString: @"</title>\n"];
	}
      else
	{
	  GSXMLNode	*tmp;
	  /*
	   * Try outputing as any of the common elements.
	   */
	  tmp = [self outputBlock: node to: buf inPara: NO];
	  if (tmp == node)
	    {
	      NSLog(@"Element '%@' not implemented", name);	// FIXME
	    }
	  else
	    {
	      next = tmp;
	    }
	}
    }

  if (children != nil)
    {
      [self outputNode: children to: buf];
    }
  if (newUnit == YES)
    {
      unit = nil;
    }
  if (next != nil)
    {
      [self outputNode: next to: buf];
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
  while (node != nil)
    {
      BOOL	changed = YES;

      while (changed == YES)
	{
	  GSXMLNode	*tmp = node;

	  node = [self outputText: node to: buf];
	  if (node == tmp)
	    {
	      node = [self outputList: node to: buf];
	    }
	  if (node == tmp)
	    {
	      changed = NO;
	    }
	}
      if (node != nil)
	{
	  NSString	*n;

	  if ([node type] != XML_ELEMENT_NODE)
	    {
	      NSLog(@"Unexpected node type in block");
	      break;	// Not a known node type;
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
	      [self outputText: [node children] to: buf];
	      [self decIndent];
	      [buf appendString: indent];
	      [buf appendString: @"</p>\n"];
	      if (flag == YES)
		{
		  [buf appendString: indent];
		  [buf appendString: @"<p>\n"];
		  [self incIndent];
		}
	      node = [node next];
	    }
	  else if ([n isEqual: @"example"] == YES)
	    {
	      [buf appendString: @"\n<pre>\n"];
	      [self outputText: [node children] to: buf];
	      [buf appendString: @"\n</pre>\n"];
	      node = [node next];
	    }
	  else if ([n isEqual: @"embed"] == YES)
	    {
	      NSLog(@"Element 'embed' not supported");
	      node = [node next];
	    }
	  else
	    {
	      return node;	// Not a block node.
	    }
	}
    }
  return node;
}

/**
 * Outputs zero or more nodes at the same level as long as the nodes
 * are valid %list elements.  Returns nil or the first node not output.
 */
- (GSXMLNode*) outputList: (GSXMLNode*)node to: (NSMutableString*)buf
{
  while (node != nil && [node type] == XML_ELEMENT_NODE)
    {
      NSString	*name = [node name];
      GSXMLNode	*children = [node children];

      if ([name isEqual: @"list"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<ul>\n"];
	  [self incIndent];
	  while (children != nil)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"<li>\n"];
	      [self incIndent];
	      [self outputBlock: [children children] to: buf inPara: NO];
	      [self decIndent];
	      [buf appendString: indent];
	      [buf appendString: @"</li>\n"];
	      children = [children next];
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
	      [buf appendString: indent];
	      [buf appendString: @"<li>\n"];
	      [self incIndent];
	      [self outputBlock: [children children] to: buf inPara: NO];
	      [self decIndent];
	      [buf appendString: indent];
	      [buf appendString: @"</li>\n"];
	      children = [children next];
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
	      [buf appendString: indent];
	      [buf appendString: @"<dt>"];
	      [self outputText: [children children] to: buf];
	      [buf appendString: @"</dt>\n"];
	      children = [children next];
	      [buf appendString: indent];
	      [buf appendString: @"<dd>\n"];
	      [self incIndent];
	      [self outputBlock: [children children] to: buf inPara: NO];
	      [self decIndent];
	      [buf appendString: indent];
	      [buf appendString: @"</dd>\n"];
	      children = [children next];
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
	      [buf appendString: indent];
	      [buf appendString: @"<dt>"];
	      [self outputText: [children children] to: buf];
	      [buf appendString: @"</dt>\n"];
	      children = [children next];
	      [buf appendString: indent];
	      [buf appendString: @"<dd>\n"];
	      [self incIndent];
	      [self outputBlock: [children children] to: buf inPara: NO];
	      [self decIndent];
	      [buf appendString: indent];
	      [buf appendString: @"</dd>\n"];
	      children = [children next];
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
      node = [node next];
    }
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
      else if ([node type] == XML_ELEMENT_NODE)
	{
	  NSString	*name = [node name];
	  GSXMLNode	*children = [node children];
	  NSDictionary	*prop = [node propertiesAsDictionary];

	  if ([name isEqual: @"br"] == YES)
	    {
	      [buf appendString: @"<br />"];
	    }
	  else if ([name isEqual: @"ref"] == YES)	// %xref
	    {
NSLog(@"Element '%@' not implemented", name); 	    // FIXME
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
	  else if ([name isEqual: @"email"] == YES)
	    {
NSLog(@"Element '%@' not implemented", name); 	    // FIXME
	    }
	  else if ([name isEqual: @"prjref"] == YES)
	    {
NSLog(@"Element '%@' not implemented", name); 	    // FIXME
	    }
	  else if ([name isEqual: @"label"] == YES)	// %anchor
	    {
NSLog(@"Element '%@' not implemented", name); 	    // FIXME
	    }
	  else if ([name isEqual: @"entry"] == YES)
	    {
NSLog(@"Element '%@' not implemented", name); 	    // FIXME
	    }
	  else if ([name isEqual: @"var"] == YES)	// %phrase
	    {
	      [buf appendString: @"<var>"];
	      [self outputText: children to: buf];
	      [buf appendString: @"</var>"];
	    }
	  else if ([name isEqual: @"em"] == YES)
	    {
	      [buf appendString: @"<em>"];
	      [self outputText: children to: buf];
	      [buf appendString: @"</em>"];
	    }
	  else if ([name isEqual: @"code"] == YES)
	    {
	      [buf appendString: @"<code>"];
	      [self outputText: children to: buf];
	      [buf appendString: @"</code>"];
	    }
	  else if ([name isEqual: @"file"] == YES)
	    {
	      [buf appendString: @"<code>"];
	      [self outputText: children to: buf];
	      [buf appendString: @"</code>"];
	    }
	  else if ([name isEqual: @"site"] == YES)
	    {
	      [buf appendString: @"<code>"];
	      [self outputText: children to: buf];
	      [buf appendString: @"</code>"];
	    }
	  else if ([name isEqual: @"footnote"] == YES)
	    {
NSLog(@"Element '%@' not implemented", name); 	    // FIXME
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
  GSXMLNode	*u = node;

  node = [node children];
  if (node != nil && [[node name] isEqual: @"declared"] == YES)
    {
      [buf appendString: indent];
      [buf appendString: @"Declared: "];
      [self outputText: [node children] to: buf];
      [buf appendString: @"<br />\n"];
      node = [node next];
    }
  while (node != nil && [[node name] isEqual: @"conform"] == YES)
    {
      [buf appendString: indent];
      [buf appendString: @"Conform: "];
      [self outputText: [node children] to: buf];
      [buf appendString: @"<br />\n"];
      node = [node next];
    }
  if (node != nil && [[node name] isEqual: @"desc"] == YES)
    {
      [self outputNode: node to: buf];
      node = [node next];
    }
  while (node != nil && [[node name] isEqual: @"method"] == YES)
    {
      [self outputNode: node to: buf];
      node = [node next];
    }
  if (node != nil && [[node name] isEqual: @"standaards"] == YES)
    {
      [self outputNode: node to: buf];
      node = [node next];
    }
}

- (void) setGlobalRefs: (AGSIndex*)r
{
  ASSIGN(globalRefs, r);
}

- (void) setLocalRefs: (AGSIndex*)r
{
  ASSIGN(localRefs, r);
}

@end

