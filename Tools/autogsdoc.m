/** This tool produces gsdoc files from source files.

   <title>Autogsdoc ... a tool to make documentation from source code</title>
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

<chapter>
  <heading>The autogsdoc tool</heading>
  <p>
    The autogsdoc tool is a command-line utility for parsing ObjectiveC
    source code (header files and optionally source files) in order to
    generate documentation covering the public interface of the various
    classes in the source.
  </p>
  <p>
    The simple way to use this is to run the command with one or more
    header file names as arguments ... the tool will automatically
    parse corresponding source files in the saem directory, and produce
    gsdoc files as output.
  </p>
  <p>
    Even without any human assistance, this tool will produce skeleton
    documents listing the methods in the classes found in the source
    files, but more importantly it can take specially formatted comments
    from the source files and insert those comments into the gsdoc output.
  </p>
  <p>
    Any comment beginning with  slash and <em>two</em> asterisks rathr than
    the common slash and single asterisk, is taken to be gsdoc markup to
    be use as the description of the class or method following it.  This
    comment text is reformatted and then inserted into the output.
  </p>
  <p>
    There are some cases where special extra processing is performed,
    predominantly in the first comment found in the source file,
    from which various chunks of gsdoc markup may be extracted and
    placed into appropriate locations in the output document -
  </p>
  <list>
    <item><strong>&lt;abstract&gt;</strong>
      An abstract of the content of the document ... placed in the head
      of the gsdoc output.
    </item>
    <item><strong>&lt;author&gt;</strong>
      A description of the author of the code - may be repeated to handle
      the case where a document has multiple authors.  Placed in the
      head of the gsdoc output.
    </item>
    <item><strong>&lt;back&gt;</strong>
      Placed in the gsdoc output just before the end of the body of the
      document - intended to be used for appendices, index etc.
    </item>
    <item><strong>&lt;chapter&gt;</strong>
      Placed immediately before any generated class documentation ...
      intended to be used to provide overall description of how the
      code bing documented works.
    </item>
    <item><strong>&lt;copy&gt;</strong>
      Copyright of the content of the document ... placed in the head
      of the gsdoc output.
    </item>
    <item><strong>&lt;date&gt;</strong>
      Date off the revision of the document ... placed in the head
      of the gsdoc output.  If this is omitted the tool will try to
      construct a value from the RCS Date tag (if available).
    </item>
    <item><strong>&lt;front&gt;</strong>
      Inserted into the document at the start of the body ... intended
      to provide for introduction or contents pages etc.
    </item>
    <item><strong>&lt;title&gt;</strong>
      Title of the document ... placed in the head of the gsdoc output.
      If this is omitted the tool will generate a (probably poor)
      title of its own.
    </item>
    <item><strong>&lt;version&gt;</strong>
      Version identifier of the document ... placed in the head
      of the gsdoc output.  If this is omitted the tool will try to
      construct a value from the RCS Revision tag (if available).
    </item>
  </list>
  <p>
    In comments being used to provide text for a method description, the
    following markup is removed from the text and handled specially -
  </p>
  <list>
    <item><strong>&lt;init&gt;</strong>
      The method is marked as being the designated initialiser for the class.
    </item>
    <item><strong>&lt;override-subclass&gt;</strong>
      The method is marked as being one which subclasses must override
      (eg an abstract method).
    </item>
    <item><strong>&lt;override-never&gt;</strong>
      The method is marked as being one which subclasses should <em>NOT</em>
      override.
    </item>
    <item><strong>&lt;standards&gt; ... &lt;/standards&gt;</strong>
      The markup is removed from the description and placed <em>after</em>
      it in the gsdoc output - so that the method is described as
      conforming (or not conforming) to the specified standards.
    </item>
  </list>
  <p>
    Generally, the text in comments is reformatted to standardise and
    indent it nicely ... the reformatting is <em>not</em> performed on
    any text inside an &lt;example&gt; element.<br />
    When the text is reformatted, it is broken into whitespace separated
    'words' which are then subjected to some extra processing ...
  </p>
  <list>
    <item>Certain well known constants such as YES, NO, and nil are
      enclosed in &lt;code&gt; ... &lt;/code&gt; markup.
    </item>
    <item>Method names (beginning with a plus or minus) are enclosed
      in &lt;ref...&gt; ... &lt;/ref&gt; markup.
    </item>
  </list>
  <p>
    The tools accepts certain user defaults (which can of course be
    supplied as command-line arguments as usual) -
  </p>
  <list>
    <item><strong>DocumentationDirectory</strong>
      May be used to specify the directory in which generated
      gsdoc files are to be placed.  If this is not set, output
      is placed in thge same directory as the source files.
    </item>
    <item><strong>SourceDirectory</strong>
      May be used to specify the directory in which the tool looks
      for source files.  If this is not set, the tool looks for the
      source in the same directory as the header files named on the
      command line.
    </item>
  </list>
</chapter>
   */

#include "AGSParser.h"
#include "AGSOutput.h"

#include	<config.h>

#if	HAVE_LIBXML
#include        <Foundation/GSXML.h>

static int      XML_ELEMENT_NODE;
#endif

int
main(int argc, char **argv, char **env)
{
  NSProcessInfo		*proc;
  NSArray		*args;
  unsigned		i;
  NSUserDefaults	*defs;
  NSFileManager		*mgr;
  NSString		*documentationDirectory;
  NSString		*sourceDirectory;
  AGSParser		*parser;
  AGSOutput		*output;
  CREATE_AUTORELEASE_POOL(pool);

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments: argv count: argc environment: env];
#endif

  defs = [NSUserDefaults standardUserDefaults];
  [defs registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
    @"Yes", @"Monolithic", nil]];

  sourceDirectory = [defs stringForKey: @"SourceDirectory"];
  documentationDirectory = [defs stringForKey: @"DocumentationDirectory"];

  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      NSLog(@"unable to get process information!");
      exit(1);
    }

  mgr = [NSFileManager defaultManager];

  parser = [AGSParser new];
  output = [AGSOutput new];

  args = [proc arguments];
  for (i = 1; i < [args count]; i++)
    {
      NSString *arg = [args objectAtIndex: i];

      if ([arg hasPrefix: @"-"])
	{
	  i++;		// Skip next value ... it is a default.
	}
      else if ([arg hasSuffix: @".h"])
	{
	  NSString	*ddir;
	  NSString	*sdir;
	  NSString	*file;
	  NSString	*generated;

	  file = [[arg lastPathComponent] stringByDeletingPathExtension];

	  if (sourceDirectory == nil)
	    {
	      sdir = [arg stringByDeletingLastPathComponent];
	    }
	  else
	    {
	      sdir = sourceDirectory;
	    }
	  sdir = [sdir stringByAppendingPathComponent: file];
	  sdir = [sdir stringByAppendingPathExtension: @"m"];

	  if (documentationDirectory == nil)
	    {
	      ddir = [arg stringByDeletingLastPathComponent];
	    }
	  else
	    {
	      ddir = documentationDirectory;
	    }
	  ddir = [ddir stringByAppendingPathComponent: file];
	  ddir = [ddir stringByAppendingPathExtension: @"gsdoc"];

	  if ([mgr isReadableFileAtPath: arg] == NO)
	    {
	      NSLog(@"No readable header at '%@' ... skipping", arg);
	      continue;
	    }
	  [parser reset];
	  [parser parseFile: arg isSource: NO];

	  if ([mgr isReadableFileAtPath: sdir] == YES)
	    {
	      [parser parseFile: sdir isSource: YES];
	    }

	  generated = [output output: [parser info]];

#if	HAVE_LIBXML
	  {
	    NSData	*data;
	    GSXMLParser	*parser;

	    /*
	     * Cache XML node information.
	     */
	    XML_ELEMENT_NODE
	      = [GSXMLNode typeFromDescription: @"XML_ELEMENT_NODE"];

	    data = [generated dataUsingEncoding: NSUTF8StringEncoding]; 
	    parser = [GSXMLParser parser];
	    [parser substituteEntities: YES];
	    [parser doValidityChecking: YES];
	    if ([parser parse: data] == NO || [parser parse: nil] == NO)
	      {
		NSLog(@"WARNING %@ did not produce a valid document", arg);
	      }
	    if (![[[[parser doc] root] name] isEqualToString: @"gsdoc"])
	      {
		NSLog(@"not a gsdoc document - because name node is %@",
		  [[[parser doc] root] name]);
		return 1;
	      }
	  }
#endif
	  if ([generated writeToFile: ddir atomically: YES] == NO)
	    {
	      NSLog(@"Sorry unable to write %@", ddir);
	    }
	}
      else if ([arg hasSuffix: @".m"])
	{
	  NSString	*ddir;
	  NSString	*file;

	  file = [[arg lastPathComponent] stringByDeletingPathExtension];

	  if (documentationDirectory == nil)
	    {
	      ddir = [arg stringByDeletingLastPathComponent];
	    }
	  else
	    {
	      ddir = documentationDirectory;
	    }
	  ddir = [ddir stringByAppendingPathComponent: file];
	  ddir = [ddir stringByAppendingPathExtension: @"gsdoc"];

	  if ([mgr isReadableFileAtPath: arg] == NO)
	    {
	      NSLog(@"No readable file at '%@' ... skipping", arg);
	      continue;
	    }

	  /*
	   * If we have been given a '.m' file, we assume that it contains
	   * interface details to be exported ... so we parse it first as
	   * if it were a header file, and then again as a source file.
	   */
	  [parser reset];
	  [parser parseFile: arg isSource: NO];
	  [parser parseFile: arg isSource: YES];

	  [output output: [parser info] file: ddir];
	}
      else
	{
	  NSLog(@"Unknown argument '%@' ... ignored", arg);
	}
    }

  RELEASE(pool);
  return 0;
}

