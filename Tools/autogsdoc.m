/** This tool produces gsdoc files from source files.

   <title>Autogsdoc ... a tool to make documentation from source code</title>
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

<chapter>
  <heading>The autogsdoc tool</heading>
  <p>
    The autogsdoc tool is a command-line utility for parsing ObjectiveC
    source code (header files and optionally source files) in order to
    generate documentation covering the public interface of the various
    classes, categories, and protocols in the source.
  </p>
  <p>
    The simple way to use this is to run the command with one or more
    header file names as arguments ... the tool will automatically
    parse corresponding source files in the same directory, and produce
    gsdoc files as output.  You may also supply source file names
    (in which case documentation will be produced for the private
    methods within the source files), and the names of existing gsdoc
    documentation files (in which case their contents will be indexed).
  </p>
  <p>
    Even without any human assistance, this tool will produce skeleton
    documents listing the methods in the classes found in the source
    files, but more importantly it can take specially formatted comments
    from the source files and insert those comments into the gsdoc output.
  </p>
  <p>
    Any comment beginning with slash and <em>two</em> asterisks rather than
    the common slash and single asterisk, is taken to be gsdoc markup, to
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
      head of the gsdoc output.<br />
      As an aid to readability of the source, some special additional
      processing is performed related to the document author -<br />
      Any line of the form 'Author: name &lt;email-address&gt;', or
      'By: name &lt;email-address&gt;', or 'Author: name' or 'By: name'
      will be recognised and converted to an <em>author</em> element,
      possibly containing an <em>email</em> element.
    </item>
    <item><strong>&lt;back&gt;</strong>
      Placed in the gsdoc output just before the end of the body of the
      document - intended to be used for appendices, index etc.
    </item>
    <item><strong>&lt;chapter&gt;</strong>
      Placed immediately before any generated class documentation ...
      intended to be used to provide overall description of how the
      code being documented works.<br />
    </item>
    <item><strong>&lt;copy&gt;</strong>
      Copyright of the content of the document ... placed in the head
      of the gsdoc output.<br />
      As an aid to readability of the source, some special additional
      processing is performed -<br />
      Any line of the form 'Copyright (C) text' will be recognised and
      converted to a <em>copy</em> element.
    </item>
    <item><strong>&lt;date&gt;</strong>
      Date of the revision of the document ... placed in the head
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
    <item>
      <strong>NB</strong>This markup may be used within
      class, category, or protocol documentation ... if so, it is
      extracted and wrapped round the rest of the documentation for
      the class as the classes chapter.
      The rest of the class documentation is normally
      inserted at the end of the chapter, but may instead be sbstituted
      in in place of the &lt;unit /&gt; pseudo-element within the
      &lt;chapter&gt; element.
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
    <item><strong>&lt;init /&gt;</strong>
      The method is marked as being the designated initialiser for the class.
    </item>
    <item><strong>&lt;override-subclass /&gt;</strong>
      The method is marked as being one which subclasses must override
      (eg an abstract method).
    </item>
    <item><strong>&lt;override-never /&gt;</strong>
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
    <item>The names of method arguments within method descriptions are
      enclosed in &lt;var&gt; ... &lt;/var&gt; markup.
    </item>
    <item>Method names (beginning with a plus or minus) are enclosed
      in &lt;ref...&gt; ... &lt;/ref&gt; markup.<br />
      eg. "-init" (without the quotes) would be wrapped in a gsdoc
      reference element to point to the init method of the current
      class or, if only one known class had an init method, it
      would refer to the method of that class.
      <br />Note the fact that the method name must be surrounded by
      whitespace (though a comma, fullstop, or semicolon at the end
      of the specifier will also act as a whitespace terminator).
    </item>
    <item>Method specifiers including class names (beginning and ending with
      square brackets) are enclosed in &lt;ref...&gt; ... &lt;/ref&gt; markup.
      <br />eg. [ NSObject-init],
      will create a reference to the init method of NSObject, while
      <br />[ (NSCopying)-copyWithZone:], creates a
      reference to a method in the NSCopyIng protocol, and
      <br />[ NSObject(TimedPerformers)-performSelector:withObject:afterDelay:],
      creates a reference to a method in the TimedPerformers category.
      <br />Note that no spaces must appear between the square brackets
      in these specifiers.
    </item>
  </list>
  <p>
    The tools accepts certain user defaults (which can of course be
    supplied as command-line arguments as usual) -
  </p>
  <list>
    <item><strong>AutoIndex</strong>
      A boolean value which may be used to specify that the program should
      generate an index file for the project automatically.  This defaults
      to NO.
    </item>
    <item><strong>Declared</strong>
      Specify where headers are to be documented as being found.<br />
      The actual name produced in the documentation is formed by appending
      the last component of the header file name to the value of this
      default.<br />
      If this default is not specified, the full name of the header file
      (as supplied on the command line), with the HeaderDirectory
      default prepended, is used.<br />
      A typical usage of this might be <code>-Declared Foundation</code>
      when generating documentation for the GNUstep base library.  This
      would result in the documentation saying that NSString is declared
      in <code>Foundation/NSString.h</code>
    </item>
    <item><strong>DocumentationDirectory</strong>
      May be used to specify the directory in which generated
      documentation is to be placed.  If this is not set, output
      is placed in the current directory.
    </item>
    <item><strong>GenerateHtml</strong>
      May be used to specify if HTML output is to be generated.
      Defaults to YES.
    </item>
    <item><strong>HeaderDirectory</strong>
      May be used to specify the directory to be searched for header files.
      If this is not specified, headers are looked for relative to the
      current directory or using absolute path names if given.
    </item>
    <item><strong>IgnoreDependencies</strong>
      A boolean value which may be used to specify that the program should
      ignore file modification times and regenerate files anyway.  Provided
      for use in conjunction with the <code>make</code> system, which is
      expected to manage dependency checking itsself.
    </item>
    <item><strong>LocalProjects</strong>
      This value is used to control the automatic inclusion of local
      external projects into the indexing system for generation of
      cross-references in final document output.<br />
      If set to 'None', then no local project references are done,
      otherwise, the 'Local' GNUstep documentation directory is recursively
      searched for files with a <code>.igsdoc</code> extension, and the
      indexing information from those files is used.<br />
      The value of this string is also used to generate the filenames in
      the cross reference ... if it is an empty string, the path to use
      is assumed to be a file in the same directory where the igsdoc
      file was found, otherwise it is used as a prefix to the name in
      the index.
    </item>
    <item><strong>Project</strong>
      May be used to specify the name of this project ... determines the
      name of the index reference file produced as part of the documentation
      to provide information enabling other projects to cross-reference to
      items in this project.
    </item>
    <item><strong>Projects</strong>
      This value may be supplies as a dictionary containing the paths to
      the igsdoc index/reference files used by external projects, along
      with values to be used to map the filenames found in the indexes.<br />
      For example, if a project index (igsdoc) file says that the class
      <code>Foo</code> is found in the file <code>Foo</code>, and the
      path associated with that project index is <code>/usr/doc/proj</code>,
      Then generated html output may reference the class as being in
      <code>/usr/doc/prj/Foo.html</code>
    </item>
    <item><strong>ShowDependencies</strong>
      A boolean value which may be used to specify that the program should
      log which files are being regenerated because of their dependencies
      on other files.
    </item>
    <item><strong>Standards</strong>
      A boolean value used to specify whether the program should insert
      information about standards complience into ythe documentation.
      This should only be used when documenting the GNUstep libraries
      and tools themselves as it assumes that the code being documented
      is part of GNUstep and possibly complies with the OpenStep standard
      or implements MacOS-X compatible methods.
    </item>
    <item><strong>SourceDirectory</strong>
      May be used to specify the directory to be searched for source
      (anything other than <code>.h</code> files ... which are controlled
      by the HeaderDirectory default).<br />
      If this is not specified, sources are looked for relative to the
      current directory or using absolute path names if given.
    </item>
    <item><strong>SystemProjects</strong>
      This value is used to control the automatic inclusion of system
      external projects into the indexing system for generation of
      cross-references in final document output.<br />
      If set to 'None', then no system project references are done,
      otherwise, the 'System' GNUstep documentation directory is recursively
      searched for files with a <code>.igsdoc</code> extension, and the
      indexing information from those files is used.<br />
      The value of this string is also used to generate the filenames in
      the cross reference ... if it is an empty string, the path to use
      is assumed to be a file in the same directory where the igsdoc
      file was found, otherwise it is used as a prefix to the name in
      the index.
    </item>
    <item><strong>Up</strong>
      A string used to supply the name to be used in the 'up' link from
      generated gsdoc documents.  This should normally be the name of a
      file which contains an index of the contents of a project.<br />
      If this is explicitly set to an empty string, then no 'up' link
      will be provided in the documents.
    </item>
  </list>
  <section>
    <heading>Inter-document linkage</heading>
    <p>
      Normally, the 'Up' default is used to specify the name of a document
      which should be used as the 'up' link for any other documents used.
      However, if this default is omitted, the tool will make certain
      assumptions about linkage as follows -
    </p>
    <p>
      If the first file listed on the command line is a gsdoc document,
      it will be assumed to be the 'top' document and will be referenced
      in the 'up' link for all subsequent documents.<br />
      Otherwise, autogsdoc will generate an index file called 'index.gsdoc'
      which will be used as the 'top' file.
    </p>
    <p>
      Where autogsdoc is used with only a single file name, the
      above assumed linkage is <em>not</em> set up.
    </p>
  </section>
</chapter>
<back>
  <index type="title" scope="project" />
  <index type="class" scope="project" />
</back>
   */

#include	<config.h>

#include "AGSParser.h"
#include "AGSOutput.h"
#include "AGSIndex.h"
#include "AGSHtml.h"


int
main(int argc, char **argv, char **env)
{
  NSProcessInfo		*proc;
  unsigned		i;
  NSUserDefaults	*defs;
  NSFileManager		*mgr;
  NSMutableDictionary	*projects;
  NSString		*documentationDirectory;
  NSString		*declared;
  NSString		*headerDirectory;
  NSString		*sourceDirectory;
  NSString		*project;
  NSString		*up;
  NSString		*refsFile;
  NSString		*systemProjects;
  NSString		*localProjects;
  AGSIndex		*projectRefs;
  AGSIndex		*globalRefs;
  AGSParser		*parser;
  AGSOutput		*output;
  id			obj;
  BOOL			generateHtml = YES;
  BOOL			ignoreDependencies = NO;
  BOOL			showDependencies = NO;
  BOOL			autoIndex = NO;
  BOOL			modifiedRefs = NO;
  NSDate		*rDate = nil;
  NSMutableArray	*files = nil;
  NSMutableArray	*hFiles = nil;
  CREATE_AUTORELEASE_POOL(outer);
  CREATE_AUTORELEASE_POOL(pool);

  RELEASE(pool);

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments: argv count: argc environment: env];
#endif

#if HAVE_LIBXML == 0
  NSLog(@"ERROR: The GNUstep Base Library was built\n"
@"        without an available libxml library. Autogsdoc needs the libxml\n"
@"        library to function. Aborting");
  exit(1);
#endif

  defs = [NSUserDefaults standardUserDefaults];
  [defs registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
    @"Untitled", @"Project",
    nil]];

  autoIndex = [defs boolForKey: @"AutoIndex"];
  ignoreDependencies = [defs boolForKey: @"IgnoreDependencies"];
  showDependencies = [defs boolForKey: @"ShowDependencies"];
  if (ignoreDependencies == YES)
    {
      if (showDependencies == YES)
	{
	  showDependencies = NO;
	  NSLog(@"ShowDependencies(YES) used with IgnoreDependencies(YES)");
	}
    }

  obj = [defs objectForKey: @"GenerateHtml"];
  if (obj != nil)
    {
      generateHtml = [defs boolForKey: @"GenerateHtml"];
    }

  declared = [defs stringForKey: @"Declared"];
  project = [defs stringForKey: @"Project"];
  up = [defs stringForKey: @"Up"];
  if ([up isEqual: @""] && autoIndex == YES)
    {
      autoIndex = NO;
      NSLog(@"Up(\"\") used with AutoIndex(YES)");
    }

  localProjects = [defs stringForKey: @"LocalProjects"];
  if (localProjects == nil)
    {
      localProjects = @"";
    }
  systemProjects = [defs stringForKey: @"SystemProjects"];
  if (systemProjects == nil)
    {
      systemProjects = @"";
    }
  projects = [[defs dictionaryForKey: @"Projects"] mutableCopy];
  AUTORELEASE(projects);

  headerDirectory = [defs stringForKey: @"HeaderDirectory"];
  if (headerDirectory == nil)
    {
      headerDirectory = @"";
    }

  sourceDirectory = [defs stringForKey: @"SourceDirectory"];
  if (sourceDirectory == nil)
    {
      sourceDirectory = @"";
    }

  documentationDirectory = [defs stringForKey: @"DocumentationDirectory"];
  if (documentationDirectory == nil)
    {
      documentationDirectory = @"";
    }

  refsFile = [documentationDirectory stringByAppendingPathComponent: project];
  refsFile = [refsFile stringByAppendingPathExtension: @"igsdoc"];


  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      NSLog(@"unable to get process information!");
      exit(1);
    }

  /*
   * Build an array of files to be processed.
   */
  files = AUTORELEASE([[proc arguments] mutableCopy]);
  hFiles = [NSMutableArray array];
  [files removeObjectAtIndex: 0];
  for (i = 0; i < [files count]; i++)
    {
      NSString *arg = [files objectAtIndex: i];

      if ([arg hasPrefix: @"-"])
	{
	  // Skip this and next value ... it is a default.
	  [files removeObjectAtIndex: i];
	  [files removeObjectAtIndex: i];
	  i--;
	}
      else if ([arg hasSuffix: @".h"] == NO
	&& [arg hasSuffix: @".m"] == NO
	&& [arg hasSuffix: @".gsdoc"] == NO)
	{
	  if ([arg hasSuffix: @".html"] == YES)
	    {
	      // Make a note of any html files found.
	      [hFiles addObject: [files objectAtIndex: i]];
	    }
	  else
	    {
	      // Skip this value ... not a known file type.
	      NSLog(@"Unknown argument '%@' ... ignored", arg);
	    }
	  [files removeObjectAtIndex: i];
	  i--;
	}
    }
  if ([files count] < 1 && [hFiles count] < 1)
    {
      NSLog(@"No filename arguments found ... giving up");
      return 1;
    }

  mgr = [NSFileManager defaultManager];

  globalRefs = [AGSIndex new];
  parser = [AGSParser new];
  if ([defs boolForKey: @"Standards"] == YES)
    {
      [parser setGenerateStandards: YES];
    }
  output = [AGSOutput new];

  /*
   * Load any old project indexing information and determine when the
   * indexing information was last updated (never ==> distant past)
   */
  projectRefs = [AGSIndex new];
  rDate = [NSDate distantPast];
  if ([mgr isReadableFileAtPath: refsFile] == YES)
    {
      NSDictionary	*dict;

      dict = [[NSDictionary alloc] initWithContentsOfFile: refsFile];
      if (dict == nil)
	{
	  NSLog(@"Unable to read project file '%@'", refsFile);
	}
      else
	{
	  [projectRefs mergeRefs: dict override: NO];
	  RELEASE(dict);
	  dict = [mgr fileAttributesAtPath: refsFile traverseLink: YES];
	  rDate = [dict objectForKey: NSFileModificationDate];
	}
    }

  pool = [NSAutoreleasePool new];
  for (i = 0; i < [files count]; i++)
    {
      NSString		*arg = [files objectAtIndex: i];
      NSString		*gsdocfile;
      NSString		*hfile;
      NSString		*sfile;
      NSString		*ddir;
      NSString		*hdir;
      NSString		*sdir;
      NSString		*file;
      NSString		*generated;
      BOOL		isSource = [arg hasSuffix: @".m"];
      BOOL		isDocumentation = [arg hasSuffix: @".gsdoc"];
      NSDictionary	*attrs;
      NSDate		*sDate = nil;
      NSDate		*gDate = nil;

      if (pool != nil)
	{
	  RELEASE(pool);
	  pool = [NSAutoreleasePool new];
	}
      file = [[arg lastPathComponent] stringByDeletingPathExtension];
      hdir = [arg stringByDeletingLastPathComponent];
      if ([hdir length] == 0)
	{
	  hdir = headerDirectory;
	  sdir = sourceDirectory;
	}
      else if ([hdir isAbsolutePath] == YES)
	{
	  sdir = hdir;
	}
      else
	{
	  sdir = [sourceDirectory stringByAppendingPathComponent: hdir];
	  hdir = [headerDirectory stringByAppendingPathComponent: hdir];
	}
      ddir = documentationDirectory;

      hfile = [hdir stringByAppendingPathComponent: file];
      hfile = [hfile stringByAppendingPathExtension: @"h"];
      sfile = [sdir stringByAppendingPathComponent: file];
      sfile = [sfile stringByAppendingPathExtension: @"m"];
      gsdocfile = [ddir stringByAppendingPathComponent: file];
      gsdocfile = [gsdocfile stringByAppendingPathExtension: @"gsdoc"];

      if (ignoreDependencies == NO)
	{
	  /*
	   * When were the files last modified?
	   */
	  attrs = [mgr fileAttributesAtPath: hfile traverseLink: YES];
	  sDate = [attrs objectForKey: NSFileModificationDate];
	  AUTORELEASE(RETAIN(sDate));
	  attrs = [mgr fileAttributesAtPath: sfile traverseLink: YES];
	  if (attrs != nil)
	    {
	      NSDate	*d;

	      d = [attrs objectForKey: NSFileModificationDate];
	      if (sDate == nil || [d earlierDate: sDate] == sDate)
		{
		  sDate = d;
		  AUTORELEASE(RETAIN(sDate));
		}
	    }
	}

      if (up == nil && [files count] > 1)
	{
	  /*
	   * If we have multiple files to process, we want one to point to all
	   * the others and be an 'up' link for them ... if the first file is
	   * '.gsdoc' file, we assume it performs that indexing function,
	   * otherwise we use a default name.
	   */
	  if (isDocumentation == YES)
	    {
	      ASSIGN(up, file);
	    }
	  else
	    {
	      ASSIGN(up, @"index");
	      autoIndex = YES;		// Generate it if needed.
	    }
	}

      if (isDocumentation == NO)
	{
	  /*
	   * The file we are processing is not a gsdoc file ... so
	   * we need to try to generate the gsdoc from source code.
	   */
	  if (ignoreDependencies == NO)
	    {
	      attrs = [mgr fileAttributesAtPath: gsdocfile traverseLink: YES];
	      gDate = [attrs objectForKey: NSFileModificationDate];
	      AUTORELEASE(RETAIN(gDate));
	    }

	  if (gDate == nil || [sDate earlierDate: gDate] == gDate)
	    {
	      if (showDependencies == YES)
		{
		  NSLog(@"%@: source %@, gsdoc %@ ==> regenerate",
		    file, sDate, gDate);
		}
	      [parser reset];

	      if (isSource == NO)
		{
		  /*
		   * Try to parse header to see what needs documenting.
		   */
		  if ([mgr isReadableFileAtPath: hfile] == NO)
		    {
		      NSLog(@"No readable header at '%@' ... skipping",
			hfile);
		      continue;
		    }
		  if (declared != nil)
		    {
		      [parser setDeclared:
			[declared stringByAppendingPathComponent:
			  [hfile lastPathComponent]]];
		    }
		  [parser parseFile: hfile isSource: NO];
		}
	      else if (isSource == YES)
		{
		  /*
		   * Try to parse source *as-if-it-was-a-header*
		   * to see what needs documenting.
		   */
		  if ([mgr isReadableFileAtPath: sfile] == NO)
		    {
		      NSLog(@"No readable source at '%@' ... skipping",
			sfile);
		      continue;
		    }
		  if (declared != nil)
		    {
		      [parser setDeclared:
			[declared stringByAppendingPathComponent:
			  [sfile lastPathComponent]]];
		    }
		  [parser parseFile: sfile isSource: NO];
		}

	      /*
	       * If we can read a source file, parse it for any
	       * additional information on items found in the header.
	       */
	      if ([mgr isReadableFileAtPath: sfile] == YES)
		{
		  [parser parseFile: sfile isSource: YES];
		}

	      /*
	       * Set up linkage for this file.
	       */
	      [[parser info] setObject: file forKey: @"base"];

	      /*
	       * Only produce linkage if the up link is not empty.
	       * Don't add an up link if this *is* the up link document.
	       */
	      if ([up length] > 0 && [up isEqual: file] == NO)
		{
		  [[parser info] setObject: up forKey: @"up"];
		}

	      generated = [output output: [parser info]];

	      if ([generated writeToFile: gsdocfile
			      atomically: YES] == NO)
		{
		  NSLog(@"Sorry unable to write %@", gsdocfile);
		}
	      else
		{
		  gDate = [NSDate date];	// Just generated.
		}
	    }
	}
      else
	{
	  /*
	   * Our source file is a gsdoc file ... so it may be located
	   * in the source (input) directory rather than the documentation
	   * (output) directory.
	   */
	  if ([mgr isReadableFileAtPath: gsdocfile] == NO)
	    {
	      gsdocfile = [sdir stringByAppendingPathComponent: file];
	      gsdocfile = [gsdocfile stringByAppendingPathExtension:
		@"gsdoc"];
	    }
	  if (ignoreDependencies == NO)
	    {
	      attrs = [mgr fileAttributesAtPath: gsdocfile traverseLink: YES];
	      gDate = [attrs objectForKey: NSFileModificationDate];
	      AUTORELEASE(RETAIN(gDate));
	    }
	}

      /*
       * Now we try to process the gsdoc data to make index info
       * unless the project index is already more up to date than
       * this file.
       */
      if (gDate == nil || [gDate earlierDate: rDate] == rDate)
	{
	  if (showDependencies == YES)
	    {
	      NSLog(@"%@: gsdoc %@, index %@ ==> regenerate",
		file, sDate, gDate);
	    }
	  if ([mgr isReadableFileAtPath: gsdocfile] == YES)
	    {
	      GSXMLParser	*parser;
	      AGSIndex		*localRefs;

	      parser = [GSXMLParser parserWithContentsOfFile: gsdocfile];
	      [parser substituteEntities: NO];
	      [parser doValidityChecking: YES];
	      [parser keepBlanks: NO];
	      if ([parser parse] == NO)
		{
		  NSLog(@"WARNING %@ is not a valid document", gsdocfile);
		}
	      if (![[[[parser doc] root] name] isEqualToString: @"gsdoc"])
		{
		  NSLog(@"not a gsdoc document - because name node is %@",
		    [[[parser doc] root] name]);
		  return 1;
		}

	      localRefs = AUTORELEASE([AGSIndex new]);
	      [localRefs makeRefs: [[parser doc] root]];

	      /*
	       * accumulate index info in project references
	       */
	      [projectRefs mergeRefs: [localRefs refs] override: NO];
	      modifiedRefs = YES;
	    }
	  else if (isDocumentation)
	    {
	      NSLog(@"No readable documentation at '%@' ... skipping",
		gsdocfile);
	    }
	}
    }

  /*
   * Make sure auto-generation of index file is done.
   */
  if (autoIndex == YES)
    {
      if ([files containsObject: up] == YES)
	{
	  NSLog(@"AutoIndex(YES) set, but Up(%@) listed in source files", up);
	}
      else
	{
	  NSString	*upFile = documentationDirectory;

	  upFile = [upFile stringByAppendingPathComponent: up];
	  upFile = [upFile stringByAppendingPathExtension: @"gsdoc"];

	  if ([mgr isReadableFileAtPath: upFile] == NO)
	    {
	      NSString	*upString = [NSString stringWithFormat:
		@"<?xml version=\"1.0\"?>\n"
		@"<!DOCTYPE gsdoc PUBLIC "
		@"\"-//GNUstep//DTD gsdoc 0.6.7//EN\" "
		@"\"http://www.gnustep.org/gsdoc-0_6_7.xml\">\n"
		@"<gsdoc base=\"index\">\n"
		@"  <head>\n"
		@"    <title>%@ project reference</title>\n"
		@"    <author name=\"autogsdoc\"></author>\n"
		@"  </head>\n"
		@"  <body>\n"
		@"    <chapter>\n"
		@"      <heading>%@ project reference</heading>\n"
		@"    </chapter>\n"
		@"    <back>\n"
		@"      <index scope=\"project\" type=\"title\" />\n"
		@"    </back>\n"
		@"  </body>\n"
		@"</gsdoc>\n",
		  project, project];

	      if ([upString writeToFile: upFile atomically: YES] == NO)
		{
		  NSLog(@"Unable to write %@", upFile);
		}
	    }
	  [files insertObject: upFile atIndex: 0];
	}
    }

  DESTROY(up);

  /*
   * Save project references.
   */
  if (modifiedRefs == YES)
    {
      if ([[projectRefs refs] writeToFile: refsFile atomically: YES] == NO)
	{
	  NSLog(@"Sorry unable to write %@", refsFile);
	}
    }

  RELEASE(pool);

  /*
   * If we are either generating html output, or relocating existing
   * html documents, we must build up the indexing information needed
   * for any cross-referencing etc.
   */
  if (generateHtml == YES || [hFiles count] > 0)
    {
      pool = [NSAutoreleasePool new];
      /*
       * Merge any external project references into the
       * main cross reference index.
       */
      if ([systemProjects caseInsensitiveCompare: @"None"] != NSOrderedSame)
	{
	  NSString	*base = [NSSearchPathForDirectoriesInDomains(
	    NSDocumentationDirectory, NSSystemDomainMask, NO) lastObject];

	  base = [base stringByStandardizingPath];
	  if (base != nil)
	    {
	      NSDirectoryEnumerator *enumerator = [mgr enumeratorAtPath: base];
	      NSString		*file;

	      if ([systemProjects isEqual: @""] == YES)
		{
		  systemProjects = base;	// Absolute path
		}
	      while ((file = [enumerator nextObject]) != nil)
		{
		  NSString	*ext = [file pathExtension];

		  if ([ext isEqualToString: @"igsdoc"] == YES)
		    {
		      NSString	*key;
		      NSString	*val;

		      if (projects == nil)
			{
			  projects = [NSMutableDictionary dictionary];
			}
		      key = [base stringByAppendingPathComponent: file];
		      val = [file stringByDeletingLastPathComponent];
		      val
			= [systemProjects stringByAppendingPathComponent: val];
		      [projects setObject: val forKey: key];
		    }
		}
	    }
	}

      if ([localProjects caseInsensitiveCompare: @"None"] != NSOrderedSame)
	{
	  NSString	*base = [NSSearchPathForDirectoriesInDomains(
	    NSDocumentationDirectory, NSLocalDomainMask, NO) lastObject];

	  base = [base stringByStandardizingPath];
	  if (base != nil)
	    {
	      NSDirectoryEnumerator	*enumerator;
	      NSString			*file;

	      enumerator = [mgr enumeratorAtPath: base];
	      if ([localProjects isEqual: @""] == YES)
		{
		  localProjects = base;	// Absolute path
		}
	      while ((file = [enumerator nextObject]) != nil)
		{
		  NSString	*ext = [file pathExtension];

		  if ([ext isEqualToString: @"igsdoc"] == YES)
		    {
		      NSString	*key;
		      NSString	*val;

		      if (projects == nil)
			{
			  projects = [NSMutableDictionary dictionary];
			}
		      key = [base stringByAppendingPathComponent: file];
		      val = [file stringByDeletingLastPathComponent];
		      val = [localProjects stringByAppendingPathComponent: val];
		      [projects setObject: val forKey: key];
		    }
		}
	    }
	}

      if (projects != nil)
	{
	  NSEnumerator	*e = [projects keyEnumerator];
	  NSString	*k;

	  while ((k = [e nextObject]) != nil)
	    {
	      if ([mgr isReadableFileAtPath: k] == NO)
		{
		  NSLog(@"Unable to read project file '%@'", k);
		}
	      else
		{
		  NSDictionary	*dict;

		  dict = [[NSDictionary alloc] initWithContentsOfFile: k];

		  if (dict == nil)
		    {
		      NSLog(@"Unable to read project file '%@'", k);
		    }
		  else
		    {
		      AGSIndex		*tmp;
		      NSString		*p;

		      tmp = [AGSIndex new];
		      [tmp mergeRefs: dict override: NO];
		      RELEASE(dict);
		      /*
		       * Adjust path to external project files ...
		       */
		      p = [projects objectForKey: k];
		      if ([p isEqual: @""] == YES)
			{
			  p = [k stringByDeletingLastPathComponent];
			}
		      [tmp setDirectory: p];
		      [globalRefs mergeRefs: [tmp refs] override: YES];
		      RELEASE(tmp);
		    }
		}
	    }
	}

      /*
       * Accumulate project index info into global index
       */
      [globalRefs mergeRefs: [projectRefs refs] override: YES];

      RELEASE(pool);
    }

  /*
   * Next pass ... generate html output from gsdoc files if required.
   */
  if (generateHtml == YES)
    {
      pool = [NSAutoreleasePool new];

      for (i = 0; i < [files count]; i++)
	{
	  NSString	*arg = [files objectAtIndex: i];
	  NSString	*gsdocfile;
	  NSString	*htmlfile;
	  NSString	*ddir;
	  NSString	*file;
	  NSString	*generated;
	  NSDictionary	*attrs;
	  NSDate	*gDate = nil;
	  NSDate	*hDate = nil;

	  if (pool != nil)
	    {
	      RELEASE(pool);
	      pool = [NSAutoreleasePool new];
	    }
	  file = [[arg lastPathComponent] stringByDeletingPathExtension];
	  ddir = documentationDirectory;

	  gsdocfile = [ddir stringByAppendingPathComponent: file];
	  gsdocfile = [gsdocfile stringByAppendingPathExtension: @"gsdoc"];
	  htmlfile = [ddir stringByAppendingPathComponent: file];
	  htmlfile = [htmlfile stringByAppendingPathExtension: @"html"];

	  /*
	   * If the gsdoc file name was specified as a source file,
	   * it may be in the source directory rather than the documentation
	   * directory.
	   */
	  if ([mgr isReadableFileAtPath: gsdocfile] == NO
	    && [arg hasSuffix: @".gsdoc"] == YES)
	    {
	      NSString	*sdir = [arg stringByDeletingLastPathComponent];

	      if ([sdir length] == 0)
		{
		  sdir = sourceDirectory;
		}
	      else if ([sdir isAbsolutePath] == NO)
		{
		  sdir = [sourceDirectory stringByAppendingPathComponent: sdir];
		}
	      gsdocfile = [sdir stringByAppendingPathComponent: file];
	      gsdocfile = [gsdocfile stringByAppendingPathExtension: @"gsdoc"];
	    }

	  if (ignoreDependencies == NO)
	    {
	      /*
	       * When were the files last modified?
	       */
	      attrs = [mgr fileAttributesAtPath: gsdocfile traverseLink: YES];
	      gDate = [attrs objectForKey: NSFileModificationDate];
	      AUTORELEASE(RETAIN(gDate));
	      attrs = [mgr fileAttributesAtPath: htmlfile traverseLink: YES];
	      hDate = [attrs objectForKey: NSFileModificationDate];
	      AUTORELEASE(RETAIN(hDate));
	    }

	  if ([mgr isReadableFileAtPath: gsdocfile] == YES)
	    {
	      if (hDate == nil || [gDate earlierDate: hDate] == hDate)
		{
		  GSXMLParser	*parser;
		  AGSIndex	*localRefs;
		  AGSHtml	*html;

		  if (showDependencies == YES)
		    {
		      NSLog(@"%@: gsdoc %@, html %@ ==> regenerate",
			file, gDate, hDate);
		    }
		  parser = [GSXMLParser parserWithContentsOfFile: gsdocfile];
		  [parser substituteEntities: NO];
		  [parser doValidityChecking: YES];
		  [parser keepBlanks: NO];
		  if ([parser parse] == NO)
		    {
		      NSLog(@"WARNING %@ is not a valid document", gsdocfile);
		    }
		  if (![[[[parser doc] root] name] isEqualToString: @"gsdoc"])
		    {
		      NSLog(@"not a gsdoc document - because name node is %@",
			[[[parser doc] root] name]);
		      return 1;
		    }

		  localRefs = AUTORELEASE([AGSIndex new]);
		  [localRefs makeRefs: [[parser doc] root]];

		  /*
		   * We perform final output
		   */
		  html = AUTORELEASE([AGSHtml new]);
		  [html setGlobalRefs: globalRefs];
		  [html setProjectRefs: projectRefs];
		  [html setLocalRefs: localRefs];
		  generated = [html outputDocument: [[parser doc] root]];
		  if ([generated writeToFile: htmlfile atomically: YES] == NO)
		    {
		      NSLog(@"Sorry unable to write %@", htmlfile);
		    }
		}
	    }
	  else
	    {
	      NSLog(@"No readable documentation at '%@' ... skipping",
		gsdocfile);
	    }
	}
      RELEASE(pool);
    }

  /*
   * Relocate existing html documents if required ... adjust all cross
   * referencing within those documents.
   */
  if ([hFiles count] > 0)
    {
      pool = [NSAutoreleasePool new];

      for (i = 0; i < [hFiles count]; i++)
	{
	  NSString	*file = [hFiles objectAtIndex: i];
	  NSString	*src;
	  NSString	*dst;
	  NSString	*sdir;
	  NSString	*ddir;

	  if (pool != nil)
	    {
	      RELEASE(pool);
	      pool = [NSAutoreleasePool new];
	    }
	  file = [file lastPathComponent];
	  sdir = sourceDirectory;
	  ddir = documentationDirectory;

	  src = [sdir stringByAppendingPathComponent: file];
	  dst = [ddir stringByAppendingPathComponent: file];

	  /*
	   * If we can't find the file in the source directory, assume
	   * it is in the ddocumentation directory already, and just needs
	   * cross-refs rebuilding.
	   */
	  if ([mgr isReadableFileAtPath: src] == NO)
	    {
	      src = dst;
	    }

	  if ([mgr isReadableFileAtPath: src] == YES)
	    {
	      NSMutableString	*s;
	      NSRange		r;
	      unsigned		l;
	      unsigned		p;
	      AGSHtml		*html;

	      html = AUTORELEASE([AGSHtml new]);
	      [html setGlobalRefs: globalRefs];
	      [html setProjectRefs: projectRefs];
	      [html setLocalRefs: nil];

	      s = [NSMutableString stringWithContentsOfFile: src];
	      l = [s length];
	      p = 0;
	      r = NSMakeRange(p, l);
	      r = [s rangeOfString: @"<a rel=\"gsdoc\" href=\""
			   options: NSLiteralSearch
			     range: r];
	      while (r.length > 0)
		{
		  NSRange	replace;
		  NSString	*repstr;
		  NSString	*href;
		  NSString	*type;
		  NSString	*unit = nil;

		  replace.location = r.location;
		  p = NSMaxRange(r);

		  r = [s rangeOfString: @"\">"
			       options: NSLiteralSearch
				 range: NSMakeRange(p, l - p)];
		  if (r.length == 0)
		    {
		      NSLog(@"Unterminated gsdoc rel at %u", p);
		      break;
		    }
		  else
		    {
		      replace = NSMakeRange(replace.location,
			NSMaxRange(r) - replace.location);
		      href = [s substringWithRange:
			NSMakeRange(p, r.location - p)];
		      p = NSMaxRange(replace);
		    }

		  /*
		   * Skip past the '#' to the local reference.
		   */
		  r = [href rangeOfString: @"#"
				  options: NSLiteralSearch];
		  if (r.length == 0)
		    {
		      NSLog(@"Missing '#' in href at %u", replace.location);
		      break;
		    }
		  href = [href substringFromIndex: NSMaxRange(r)];

		  /*
		   * Split out the reference type information.
		   */
		  r = [href rangeOfString: @"$"
				  options: NSLiteralSearch];
		  if (r.length == 0)
		    {
		      NSLog(@"Missing '$' in href at %u", replace.location);
		      break;
		    }
		  type = [href substringToIndex: r.location];
		  href = [href substringFromIndex: NSMaxRange(r)];

		  /*
		   * Parse unit name from method or instance variable link.
		   */
		  if ([type isEqual: @"method"] == YES
		    || [type isEqual: @"ivariable"] == YES)
		    {
		      if ([type isEqual: @"method"] == YES)
			{
			  r = [href rangeOfString: @"-"
					  options: NSLiteralSearch];
			  if (r.length == 0)
			    {
			      r = [href rangeOfString: @"+"
					      options: NSLiteralSearch];
			    }
			  if (r.length > 0)
			    {
			      unit = [href substringToIndex: r.location];
			      href = [href substringFromIndex: NSMaxRange(r)-1];
			    }
			}
		      else
			{
			  r = [href rangeOfString: @"*"
					  options: NSLiteralSearch];
			  if (r.length > 0)
			    {
			      unit = [href substringToIndex: r.location];
			      href = [href substringFromIndex: NSMaxRange(r)];
			    }
			}
		      if (unit == nil)
			{
			  NSLog(@"Missing unit name terminator at %u",
			    replace.location);
			  break;
			}
		    }
		  if (unit == nil)
		    {
		      repstr = [html makeLink: href
				       ofType: type
					isRef: YES];
		    }
		  else
		    {
		      repstr = [html makeLink: href
				       ofType: type
				       inUnit: unit
					isRef: YES];
		    }
		  if (repstr != nil)
		    {
		      p += ([repstr length] - replace.length);
		      [s replaceCharactersInRange: replace withString: repstr];
		    }

		  r = [s rangeOfString: @"<a rel=\"gsdoc\" href=\""
			       options: NSLiteralSearch
				 range: NSMakeRange(p, l - p)];
		}
	      [s writeToFile: dst atomically: YES];
	    }
	  else
	    {
	      NSLog(@"No readable documentation at '%@' ... skipping", src);
	    }
	}
      RELEASE(pool);
    }

  RELEASE(outer);
  return 0;
}

