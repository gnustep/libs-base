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

static GSXMLNode	*firstElement(GSXMLNode *nodes)
{
  while (nodes != nil)
    {
      if ([nodes type] == XML_ELEMENT_NODE)
	{
	  return nodes;
	}
      nodes = [nodes next];
    }
  return nil;
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
  [self outputNodeList: [node children] to: buf];
  [self decIndent];
  [buf appendString: @"</html>\n"];

  return buf;
}

- (void) outputNode: (GSXMLNode*)node to: (NSMutableString*)buf
{
  CREATE_AUTORELEASE_POOL(arp);
  GSXMLNode	*children = [node children];

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
	  NSString	*name = [prop objectForKey: @"name"];
	  NSString	*cls = [prop objectForKey: @"class"];

	  cls = [self typeRef: cls];
	  unit = [NSString stringWithFormat: @"%@(%@)", cls, name];
	  [buf appendFormat: @"<h2>%@(<a name=\"category$%@\">%@</a>)</h2>\n",
	    unit, cls, name];
	  [self outputUnit: node to: buf];
	  unit = nil;
	}
      else if ([name isEqual: @"chapter"] == YES)
	{
	  heading = @"h1";
	  [self outputNodeList: children to: buf];
	}
      else if ([name isEqual: @"class"] == YES)
	{
	  NSString	*name = [prop objectForKey: @"name"];
	  NSString	*sup = [prop objectForKey: @"super"];

	  unit = name;
	  sup = [self typeRef: sup];
	  if (sup == nil)
	    {
	      /*
	       * This is a root class.
	       */
	      [buf appendFormat: @"<h3><a name=\"class$%@\">%@</a></h3>\n",
		unit, name];
	    }
	  else
	    {
	      [buf appendFormat: @"<h3><a name=\"class$%@\">%@</a> : %@</h3>\n",
		unit, name, sup];
	    }
	  [self outputUnit: node to: buf];
	  unit = nil;
	}
      else if ([name isEqual: @"code"] == YES)
	{
	  [buf appendString: @"<code>"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</code>"];
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
	      [buf appendFormat: @"<a href=\"%@\"><code>", ename];
	    }
	  [self outputText: [node children] to: buf];
	  if (ename == nil)
	    {
	      [buf appendString: @"</code>"];
	    }
	  else
	    {
	      [buf appendFormat: @"</code></a>", ename];
	    }
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
	  [buf appendFormat: @"<a name=\"label$%@\"></a>", val];
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
	  [self outputText: [children children] to: buf];
	  [self decIndent];
	  [buf appendString: @"</title>\n"];
	  [self decIndent];
	  [buf appendString: indent];
	  [buf appendString: @"</head>\n"];
	  [buf appendString: indent];
	  [buf appendString: @"<body>\n"];
	  [self incIndent];
	  [buf appendString: indent];
	  [buf appendString: @"<h1>"];
	  [self outputText: [children children] to: buf];
	  [buf appendString: @"</h1>\n"];

	  [buf appendString: indent];
	  [buf appendString: @"<h3>Authors</h3>\n"];
	  [buf appendString: indent];
	  [buf appendString: @"<dl>\n"];
	  [self incIndent];
	  children = firstElement([children next]);
	  while ([[children name] isEqual: @"author"] == YES)
	    {
	      GSXMLNode		*author = children;
	      GSXMLNode		*tmp;
	      GSXMLNode		*email = nil;
	      GSXMLNode		*url = nil;
	      GSXMLNode		*desc = nil;

	      children = [children next];
	      children = firstElement(children);

	      tmp = firstElement([author children]);
	      if ([[tmp name] isEqual: @"email"] == YES)
		{
		  email = tmp;
		  tmp = firstElement([tmp next]);
		}
	      if ([[tmp name] isEqual: @"url"] == YES)
		{
		  url = tmp;
		  tmp = firstElement([tmp next]);
		}
	      if ([[tmp name] isEqual: @"desc"] == YES)
		{
		  desc = tmp;
		  tmp = firstElement([tmp next]);
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
		  [self outputBlock: desc to: buf inPara: NO];
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
	      [buf appendString: @"<p>Version: "];
	      [self outputNode: [children children] to: buf];
	      [buf appendString: @"</p>\n"];
	      children = firstElement([children next]);
	    }
	  if ([[children name] isEqual: @"date"] == YES)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"<p>Date: "];
	      [self outputNode: [children children] to: buf];
	      [buf appendString: @"</p>\n"];
	      children = firstElement([children next]);
	    }
	  if ([[children name] isEqual: @"abstract"] == YES)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"<blockquote>\n"];
	      [self incIndent];
	      [self outputBlock: [children children] to: buf inPara: NO];
	      [self decIndent];
	      [buf appendString: indent];
	      [buf appendString: @"</blockquote>\n"];
	      children = firstElement([children next]);
	    }
	  if ([[children name] isEqual: @"copy"] == YES)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"<p>Copyright: "];
	      [self outputNode: [children children] to: buf];
	      [buf appendString: @"</p>\n"];
	      children = firstElement([children next]);
	    }
	}
      else if ([name isEqual: @"heading"] == YES)
	{
	  [buf appendString: indent];
	  [buf appendString: @"<"];
	  [buf appendString: heading];
	  [buf appendString: @">"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</"];
	  [buf appendString: heading];
	  [buf appendString: @">\n"];
	}
      else if ([name isEqual: @"ivariable"] == YES)
	{
	  NSString	*tmp = [prop objectForKey: @"name"];

NSLog(@"Element '%@' not implemented", name); 	    // FIXME
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
	  [buf appendFormat: @"<a name=\"label$%@\">", val];
	  [self outputText: children to: buf];
	  [buf appendString: @"</a>"];
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
	      str = [NSString stringWithFormat: @"- (%@)",
		[self typeRef: str]];
	    }
	  children = nil;
	  while (tmp != nil)
	    {
	      if ([tmp type] == XML_ELEMENT_NODE)
		{
		  if ([[tmp name] isEqual: @"sel"] == YES)
		    {
		      GSXMLNode	*t = [tmp children];

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
		      GSXMLNode	*t = [tmp children];
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
		      children = [tmp next];
		      break;
		    }
		  else
		    {
		      children = tmp;
		      break;
		    }
		}
	      tmp = [tmp next];
	    }
	  if ([sel length] > 1)
	    {
	      /*
	       * Output selector heading.
	       */
	      [buf appendString: indent];
	      [buf appendFormat: @"<h3><a name=\"%@%@\">%@</a></h3>\n",
		unit, sel, [sel substringFromIndex: 1]];
	      [buf appendString: indent];
	      [buf appendString: str];
	      [buf appendString: @";<br />\n"];
	      node = children;

	      /*
	       * List standards with which method complies
	       */
	      children = [node next];
	      if ([[children name] isEqual: @"standards"])
		{
		  tmp = [node children];
		  if (tmp != nil)
		    {
		      [buf appendString: @"Standards:"];
		      while (tmp != nil)
			{
			  [buf appendString: @" "];
			  [buf appendString: [tmp name]];
			  tmp = [tmp next];
			}
		      [buf appendString: @"<br />\n"];
		    }
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
	      [buf appendString: @"<hr />\n"];
	    }
	}
      else if ([name isEqual: @"prjref"] == YES)
	{
NSLog(@"Element '%@' not implemented", name); 	    // FIXME
	}
      else if ([name isEqual: @"ref"] == YES)	// %xref
	{
	  NSString	*type = [prop objectForKey: @"type"];
	  NSString	*r = [prop objectForKey: @"id"];
	  NSString	*f = nil;
	  BOOL		isLocal = YES;

	  if ([type isEqual: @"method"] || [type isEqual: @"variable"])
	    {
	      NSString	*c = [prop objectForKey: @"class"];

	      /*
	       * No class specified ... try to infer it.
	       */
	      if (c == nil)
		{
		  /*
		   * If we are currently inside a class, category, or protocol
		   * we see if the required item exists in that unit and if so,
		   * we assume that we need a local reference.
		   */
		  if (unit != nil)
		    {
		      f = [localRefs unitRef: r type: type unit: unit];
		      if (f == nil)
			{
			  f = [globalRefs unitRef: r type: type unit: unit];
			  if (f != nil)
			    {
			      isLocal = NO;
			      c = unit;
			    }
			}
		      else
			{
			  c = unit;
			}
		    }
		  /*
		   * If we have not found it in the current unit, we check
		   * all known references to see if the item is uniquely
		   * documented somewhere.
		   */
		  if (c == nil)
		    {
		      NSDictionary	*d;

		      d = [localRefs unitRef: r type: type];
		      if ([d count] == 0)
			{
			  isLocal = NO;
			  d = [globalRefs unitRef: r type: type];
			}
		      if ([d count] == 1)
			{
			  /*
			   * Record the class where the item is documented
			   * and the file where that documentation occurs.
			   */
			  c = [[d allKeys] objectAtIndex: 0];
			  f = [d objectForKey: c];
			}
		    }
		}
	      else
		{
		  /*
		   * Simply look up the reference.
		   */
		  f = [localRefs unitRef: r type: type unit: c];
		  if (f == nil)
		    {
		      isLocal = NO;
		      f = [globalRefs unitRef: r type: type unit: c];
		    }
		}

	      if (f != nil)
		{
		  f = [f stringByAppendingPathExtension: @"html"];
		  if (isLocal == YES)
		    {
		      [buf appendFormat: @"<a href=\"#%@%@\">", c, r];
		    }
		  else
		    {
		      [buf appendFormat: @"<a href=\"%@#%@%@\">", f, c, r];
		    }
		}
	    }
	  else
	    {
	      f = [localRefs globalRef: r type: type];
	      if (f == nil)
		{
		  isLocal = NO;
		  f = [globalRefs globalRef: r type: type];
		}
	      if (f != nil)
		{
		  f = [f stringByAppendingPathExtension: @"html"];
		  if (isLocal == YES)
		    {
		      [buf appendFormat: @"<a href=\"#%@$%@\">", type, r];
		    }
		  else
		    {
		      [buf appendFormat: @"<a href=\"%@#%@$%@\">", f, type, r];
		    }
		}
	    }
	  if (f == nil)
	    {
	      NSLog(@"ref '%@' not found for %@", name, type);
	    }
	  else
	    {
	      [self outputText: [node children] to: buf];
	      [buf appendString: @"</a>\n"];
	    }
	}
      else if ([name isEqual: @"protocol"] == YES)
	{
	  NSString	*name = [prop objectForKey: @"name"];

	  unit = [NSString stringWithFormat: @"(%@)", name];
	  [buf appendFormat:
	    @"<h3><a name=\"protocol$%@\">&lt;%@&gt;</a></h3>\n", unit, name];
	  [self outputUnit: node to: buf];
	  unit = nil;
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

NSLog(@"Element '%@' not implemented", name); 	    // FIXME
	}
      else if ([name isEqual: @"section"] == YES)
	{
	  heading = @"h2";
	  [self outputNode: children to: buf];
	}
      else if ([name isEqual: @"site"] == YES)
	{
	  [buf appendString: @"<code>"];
	  [self outputText: children to: buf];
	  [buf appendString: @"</code>"];
	}
      else if ([name isEqual: @"subsect"] == YES)
	{
	  heading = @"h3";
	  [self outputNode: children to: buf];
	}
      else if ([name isEqual: @"subsubsect"] == YES)
	{
	  heading = @"h4";
	  [self outputNode: children to: buf];
	}
      else if ([name isEqual: @"type"] == YES)
	{
	  NSString	*n = [prop objectForKey: @"name"];

	  node = [node children];
	  [buf appendString: indent];
	  [buf appendFormat: @"<h3><a name=\"type$%@\">typedef %@ %@</a></h3>",
	    n, [node content], n];
	  node = [node next];

	  if (node != nil && [[node name] isEqual: @"declared"] == YES)
	    {
	      [buf appendString: indent];
	      [buf appendString: @"Declared: "];
	      [self outputText: [node children] to: buf];
	      [buf appendString: @"<br />\n"];
	      node = [node next];
	    }
	  if (node != nil && [[node name] isEqual: @"desc"] == YES)
	    {
	      [self outputNode: node to: buf];
	      node = [node next];
	    }
	  if (node != nil && [[node name] isEqual: @"standards"] == YES)
	    {
	      [self outputNode: node to: buf];
	      node = [node next];
	    }
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
	}
    }
  RELEASE(arp);
}

- (void) outputNodeList: (GSXMLNode*)node to: (NSMutableString*)buf
{
  while (node != nil)
    {
      GSXMLNode	*next = [node next];

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
      NSString	*text = [[node children] content];

      [buf appendString: indent];
      [buf appendString: @"Conform: "];
      [buf appendString: [self protocolRef: text]];
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
  if (node != nil && [[node name] isEqual: @"standards"] == YES)
    {
      [self outputNode: node to: buf];
      node = [node next];
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
  if ((s = [localRefs globalRef: n type: @"protocol"]) != nil)
    {
      t = [NSString stringWithFormat: @"<a href=\"#protocol$%@\">%@</a>", n, t];
    }
  else if ((s = [globalRefs globalRef: t type: @"protocol"]) != nil)
    {
      s = [s stringByAppendingPathExtension: @"html"];
      t = [NSString stringWithFormat: @"<a href=\"%@#protocol$%@\">%@</a>",
	s, n, t];
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

  if ((s = [localRefs globalRef: t type: @"type"]) != nil)
    {
      s = [NSString stringWithFormat: @"<a href=\"#type$%@\">%@</a>", t, t];
    }
  else if ((s = [localRefs globalRef: t type: @"class"]) != nil)
    {
      s = [NSString stringWithFormat: @"<a href=\"#class$%@\">%@</a>", t, t];
    }
  else if ((s = [globalRefs globalRef: t type: @"type"]) != nil)
    {
      s = [s stringByAppendingPathExtension: @"html"];
      s = [NSString stringWithFormat: @"<a href=\"%@#type$%@\">%@</a>",
	s, t, t];
    }
  else if ((s = [globalRefs globalRef: t type: @"class"]) != nil)
    {
      s = [s stringByAppendingPathExtension: @"html"];
      s = [NSString stringWithFormat: @"<a href=\"%@#class$%@\">%@</a>",
	s, t, t];
    }
  if (s != nil)
    {
      if ([orig length] == [t length])
	{
	  return s;
	}
      return [orig stringByReplacingString: t withString: s];
    }
  return orig;
}
@end

