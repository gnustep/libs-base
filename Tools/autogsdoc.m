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
  <section>
    <heading>overview</heading>
    <p>
      The autogsdoc tool is a command-line utility for parsing ObjectiveC
      source code (header files and optionally source files) in order to
      generate documentation covering the public interface of the various
      classes, categories, and protocols in the source.
    </p>
    <p>
      The simple way to use this is to run the command with one or more
      header file names as arguments ... the tool will automatically
      parse corresponding source files in the same directory as the
      headers (or the current directory, or the directory specified
      using the DocumentationDirectory default), and produce gsdoc
      and html files as output.
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
      comment text is reformatted and then inserted into the output.<br />
      Where multiple comments are associatd with the same item, they are
      joined together with a line break (&lt;br /&gt;) between each if
      necessary.
    </p>
    <p>
      The tool can easily be used to document programs as well as libraries,
      simply by giving it the name of the source file containing the main()
      function of the program - it takes the special comments from that
      function and handles them specially, inserting them as a section at
      the end of the first chapter of the document (it creates the first
      chapter if necessary).
    </p>
  </section>
  <section>
    <heading>Extra markup</heading>
    <p>
      There are some cases where special extra processing is performed,
      predominantly in the first comment found in the source file,
      from which various chunks of gsdoc markup may be extracted and
      placed into appropriate locations in the output document -
    </p>
    <list>
      <item><strong>AutogsdocSource</strong>
	In any line where <code>AutogsdocSource</code>: is found, the remainder
	of the line is taken as a source file name to be used instead of
	making the assumption that each .h file processed uses a .m file
	of the same name.  You may supply multiple <code>AutogsdocSource</code>:
	lines where a header file declares items which are defined in
	multiple source files.<br />
	If a file name is absolute, it is used just as supplied.<br />
	If on the other hand, it is a relative path, the software looks for
	the source file first relative to the location of the header file,
	and if not found there, relative to the current directory in which
	autogsdoc is running, and finally relative to the directory
	specified by the DocumentationDirectory default.
      </item>
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
	Any line of the form '<code>Author</code>: name &lt;email-address&gt;',
	or '<code>By</code>: name &lt;email-address&gt;',
	or '<code>Author</code>: name' or '<code>By</code>: name'
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
	code being documented works.<br />Any documentation for the main()
	function of a program is inserted as a section at the end of this
	chapter.
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
	title of its own - so you should include this markup manually.
      </item>
      <item>
	<strong>NB</strong>This markup may be used within
	class, category, or protocol documentation ... if so, it is
	extracted and wrapped round the rest of the documentation for
	the class as the classes chapter.
	The rest of the class documentation is normally
	inserted at the end of the chapter, but may instead be substituted
	in in place of the &lt;unit /&gt; pseudo-element within the
	&lt;chapter&gt; element.
      </item>
      <item><strong>&lt;version&gt;</strong>
	Version identifier of the document ... placed in the head
	of the gsdoc output.  If this is omitted the tool will try to
	construct a value from the RCS Revision tag (if available).
      </item>
    </list>
  </section>
  <section>
    <heading>Method markup</heading>
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
  </section>
  <section>
    <heading>Automated markup</heading>
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
	whitespace to be recognized (though a comma, fullstop, or semicolon
	at the end of the specifier will act like whitespace).
      </item>
      <item>Method specifiers including class names (beginning and ending with
	square brackets) are enclosed in &lt;ref...&gt; ... &lt;/ref&gt; markup.
	<br />eg. <code>[</code>NSObject-init<code>]</code>,
	will create a reference to the init method of NSObject (either the
	class proper, or any of its categories), while
	<br /><code>[</code>(NSCopying)-copyWithZone:<code>]</code>, creates a
	reference to a method in the NSCopyIng protocol.
	<br />Note that no spaces must appear between the square brackets
	in these specifiers.
	<br />Protocol names are enclosed in round brackets rather than
	the customary angle brackets, because gsdoc is an XML language, and
	XML treats angle brackets specially.
      </item>
      <item>Class names (and also protocol and category names) enclosed
	in square brackets are also cross referenced.
	<br />Protocol names are enclosed in round brackets rather than
	the customary angle brackets, because gsdoc is an XML language, and
	XML treats angle brackets specially.
      </item>
      <item>Function names (ending with '()') other than 'main()' are enclosed
	in &lt;ref...&gt; ... &lt;/ref&gt; markup.<br />
	eg. "NSLogv()" (without the quotes) would be wrapped in a gsdoc
	reference element to point to the documentation of the NSLog function.
	<br />Note the fact that the function name must be surrounded by
	whitespace (though a comma, fullstop, or semicolon at the end
	of the specifier will also act as a whitespace terminator).
      </item>
    </list>
  </section>
  <section>
    <heading>Arguments and Defaults</heading>
    <p>
      The tools accepts certain user defaults (which can of course be
      supplied as command-line arguments as usual) -
    </p>
    <list>
      <item><strong>Clean</strong>
	If this boolean value is set to YES, then rather than generating
	documentation, the tool removes all gsdoc files generated in the
	project, and all html files generated from them (as well as any
	which would be generated from gsdoc files listed explicitly),
	and finally removes the project index file.<br />
	The only exception to this is that template gsdoc files (ie those
	specifield using "-ConstantsTemplate ...", "-FunctionsTemplate ..."
        arguments etc) are not deleted unless the CleanTemplates flag is set.
      </item>
      <item><strong>CleanTemplates</strong>
	This flag specifies whether template gsdoc files are to be removed
	along with other files when the Clean option is specified.
	The default is for them not to be removed ... since these templates
	may have been produced manually and just had data inserted into them.
      </item>
      <item><strong>ConstantsTemplate</strong>
	Specify the name of a template document into which documentation
	about constants should be inserted from all files in the project.<br />
	This is useful if constants in the source code are scattered around many
	files, and you need to group them into one place.<br />
	You are responsible for ensuring that the basic template document
	(into which individual constant documentation is inserted) contains
	all the other information you want, but as a convenience autogsdoc
	will generate a simple template (which you may then edit) for you
	if the file does not exist.
	<br />Insertion takes place immediately before the <em>back</em>
	element (or if that does not exist, immediately before the end
	of the <em>body</em> element) in the template.
      </item>
      <item><strong>Declared</strong>
	Specify where headers are to be documented as being found.<br />
	The actual name produced in the documentation is formed by appending
	the last component of the header file name to the value of this
	default.<br />
	If this default is not specified, the full name of the header file
	(as supplied on the command line), with the HeaderDirectory
	default prepended, is used.<br />
	A typical usage of this might be <code>"-Declared Foundation"</code>
	when generating documentation for the GNUstep base library.  This
	would result in the documentation saying that NSString is declared
	in <code>Foundation/NSString.h</code>
      </item>
      <item><strong>DocumentAllInstanceVariables</strong>
	This flag permits you to generate documentation for all instance
	variables.  Normally, only those explicitly declared 'public' or
	'protected' will be documented.
      </item>
      <item><strong>DocumentationDirectory</strong>
	May be used to specify the directory in which generated
	documentation is to be placed.  If this is not set, output
	is placed in the current directory.  This directory is also
	used as a last resort to locate source files (not headers).
      </item>
      <item><strong>Files</strong>
	Specifies the name of a file containing a list of file names as
	a property list array <em>(name1,name2,...)</em> format.  If this
	is present, filenames in the program argument list are ignored and
	the names in this file are used as the list of names to process.
      </item>
      <item><strong>FunctionsTemplate</strong>
	Specify the name of a template document into which documentation
	about functions should be inserted from all files in the project.<br />
	This is useful if function source code is scattered around many
	files, and you need to group it into one place.<br />
	You are responsible for ensuring that the basic template document
	(into which individual function documentation is inserted) contains
	all the other information you want, but as a convenience autogsdoc
	will generate a simple template (which you may then edit) for you
	if the file does not exist.
	<br />Insertion takes place immediately before the <em>back</em>
	element (or if that does not exist, immediately before the end
	of the <em>body</em> element) in the template.
      </item>
      <item><strong>GenerateHtml</strong>
	May be used to specify if HTML output is to be generated.
	Defaults to YES.
      </item>
      <item><strong>HeaderDirectory</strong>
	May be used to specify the directory to be searched for header files.
	When supplied, this value is prepended to relative header names,
	otherwise the relative header names are interpreted relative to
	the current directory.<br />
	Header files specified as absolute paths are not influenced by this
	default.
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
	the index.<br />
	NB. Local projects with the same name as the project currently
	being documented will <em>not</em> be included by this mechanism.
	If you wish to include such projects, you must do so explicitly
	using <em>"-Projects ..."</em>
      </item>
      <item><strong>MacrosTemplate</strong>
	Specify the name of a template document into which documentation
	about macros should be inserted from all files in the project.<br />
	This is useful if macro code is scattered around many
	files, and you need to group it into one place.<br />
	You are responsible for ensuring that the basic template document
	(into which individual macro documentation is inserted) contains
	all the other information you want, but as a convenience autogsdoc
	will generate a simple template (which you may then edit) for you
	if the file does not exist.
	<br />Insertion takes place immediately before the <em>back</em>
	element (or if that does not exist, immediately before the end
	of the <em>body</em> element) in the template.
      </item>
      <item><strong>Project</strong>
	May be used to specify the name of this project ... determines the
	name of the index reference file produced as part of the documentation
	to provide information enabling other projects to cross-reference to
	items in this project.
      </item>
      <item><strong>Projects</strong>
	This value may be supplied as a dictionary containing the paths to
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
	the index.<br />
	NB. System projects with the same name as the project currently
	being documented will <em>not</em> be included by this mechanism.
	If you wish to include such projects, you must do so explicitly
	using <em>"-Projects ..."</em>
      </item>
      <item><strong>TypedefsTemplate</strong>
	Specify the name of a template document into which documentation
	about typedefs should be inserted from all files in the project.<br />
	This is useful if typedef source code is scattered around many
	files, and you need to group it into one place.<br />
	You are responsible for ensuring that the basic template document
	(into which individual typedef documentation is inserted) contains
	all the other information you want, but as a convenience autogsdoc
	will generate a simple template (which you may then edit) for you
	if the file does not exist.
	<br />Insertion takes place immediately before the <em>back</em>
	element (or if that does not exist, immediately before the end
	of the <em>body</em> element) in the template.
      </item>
      <item><strong>Up</strong>
	A string used to supply the name to be used in the 'up' link from
	generated gsdoc documents.  This should normally be the name of a
	file which contains an index of the contents of a project.<br />
	If this is missing or set to an empty string, then no 'up' link
	will be provided in the documents.
      </item>
      <item><strong>VariablesTemplate</strong>
	Specify the name of a template document into which documentation
	about variables should be inserted from all files in the project.<br />
	This is useful if variable source code is scattered around many
	files, and you need to group it into one place.<br />
	You are responsible for ensuring that the basic template document
	(into which individual variable documentation is inserted) contains
	all the other information you want, but as a convenience autogsdoc
	will generate a simple template (which you may then edit) for you
	if the file does not exist.
	<br />Insertion takes place immediately before the <em>back</em>
	element (or if that does not exist, immediately before the end
	of the <em>body</em> element) in the template.
      </item>
      <item><strong>Verbose</strong>
	A boolean used to specify whether you want verbose debug/warning
	output to be produced.
      </item>
      <item><strong>Warn</strong>
	A boolean used to specify whether you want standard warning
	output (eg report of undocumented methods) produced.
      </item>
      <item><strong>WordMap</strong>
	This value is a dictionary used to map identifiers/keywords found
	in the source files  to other words.  Generally you will not have
	to use this, but it is sometimes helpful to avoid the parser being
	confused by the use of C preprocessor macros.  You can effectively
	redefine the macro to something less confusing.<br />
	The value you map the identifier to must be one of -<br />
	Another identifier,<br />
	An empty string - the value is ignored,<br />
	Two slashes ('//') - the rest of the line is ignored.<br />
      </item>
    </list>
  </section>
  <section>
    <heading>Inter-document linkage</heading>
    <p>
      The 'Up' default is used to specify the name of a document which
      should be used as the 'up' link for any other documents used.<br />
      This name must not include a path or extension.<br />
      Generally, the document referred to by this default should be a
      hand-edited gsdoc document which should have a <em>back</em>
      section containing a project index. eg.
    </p>
<example>
  &lt;?xml version="1.0"?&gt;
  &lt;!DOCTYPE gsdoc PUBLIC "-//GNUstep//DTD gsdoc 1.0.0//EN" 
  "http://www.gnustep.org/gsdoc-1_0_0.xml"&gt;
  &lt;gsdoc base="index"&gt;
    &lt;head&gt;
      &lt;title&gt;My project reference&lt;/title&gt;
      &lt;author name="my name"&gt;&lt;/author&gt;
    &lt;/head&gt;
    &lt;body&gt;
      &lt;chapter&gt;
        &lt;heading&gt;My project reference&lt;/heading&gt;
      &lt;/chapter&gt;
      &lt;back&gt;
        &lt;index scope="project" type="title" /&gt;
      &lt;/back&gt;
    &lt;/body&gt;
  &lt;/gsdoc&gt;
</example>
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
  NSString		*documentationDirectory;
  NSString		*declared;
  NSString		*headerDirectory;
  NSString		*project;
  NSString		*refsName;
  NSDictionary		*originalIndex;
  AGSIndex		*projectRefs;
  AGSIndex		*globalRefs;
  NSDate		*rDate = nil;
  NSString		*refsFile;
  id			obj;
  unsigned		count;
  unsigned		firstFile = 1;
  BOOL			generateHtml = YES;
  BOOL			ignoreDependencies = NO;
  BOOL			showDependencies = NO;
  BOOL			verbose = NO;
  BOOL			warn = NO;
  NSArray		*files = nil;
  NSMutableArray	*sFiles = nil;	// Source
  NSMutableArray	*gFiles = nil;	// GSDOC
  NSMutableArray	*hFiles = nil;	// HTML
#if GS_WITH_GC == 0
  NSAutoreleasePool	*outer = nil;
  NSAutoreleasePool	*pool = nil;
#endif

  [NSProcessInfo initializeWithArguments: argv count: argc environment: env];

#if GS_WITH_GC == 0
  outer = [NSAutoreleasePool new];
#endif

#ifndef HAVE_LIBXML
  NSLog(@"ERROR: The GNUstep Base Library was built\n"
@"        without an available libxml library. Autogsdoc needs the libxml\n"
@"        library to function. Aborting");
  exit(1);
#endif

  defs = [NSUserDefaults standardUserDefaults];
  [defs registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
    @"Untitled", @"Project",
    nil]];

  verbose = [defs boolForKey: @"Verbose"];
  warn = [defs boolForKey: @"Warn"];
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
  refsName = [[project stringByAppendingPathExtension: @"igsdoc"] copy];

  headerDirectory = [defs stringForKey: @"HeaderDirectory"];
  if (headerDirectory == nil)
    {
      headerDirectory = @"";
    }

  documentationDirectory = [defs stringForKey: @"DocumentationDirectory"];
  if (documentationDirectory == nil)
    {
      documentationDirectory = @"";
    }

  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      NSLog(@"unable to get process information!");
      exit(1);
    }

  /*
   * Build an array of files to be processed.
   */
  obj = [defs stringForKey: @"Files"];
  if (obj != nil)
    {
      files = [NSArray arrayWithContentsOfFile: obj];
      if (files == nil)
	{
	  NSLog(@"Failed to load files from '%@'", obj);
	  exit(1);
	}
      firstFile = 0;	// Not an argument list ... read from index 0
    }
  else
    {
      files = [proc arguments];
      firstFile = 1;	// An argument list ... ignore the program name.
    }
  sFiles = [NSMutableArray array];
  gFiles = [NSMutableArray array];
  hFiles = [NSMutableArray array];
  count = [files count];
  if (verbose == YES)
    {
      NSLog(@"Proc ... %@", proc);
      NSLog(@"Name ... %@", [proc processName]);
      NSLog(@"Files ... %@", files);
      NSLog(@"HeaderDirectory ... %@", headerDirectory);
      NSLog(@"DocumentationDirectory ... %@", documentationDirectory);
    }
  for (i = firstFile; i < count; i++)
    {
      NSString *arg = [files objectAtIndex: i];

      if ([arg hasPrefix: @"-"] == YES)
	{
	  i++;	// a default
	}
      else if ([arg hasSuffix: @".h"] == YES)
	{
	  [sFiles addObject: arg];
	}
      else if ([arg hasSuffix: @".m"] == YES)
	{
	  [sFiles addObject: arg];
	}
      else if ([arg hasSuffix: @".gsdoc"] == YES)
	{
	  [gFiles addObject: arg];
	}
      else if ([arg hasSuffix: @".html"] == YES)
	{
	  [hFiles addObject: arg];
	}
      else
	{
	  // Skip this value ... not a known file type.
	  NSLog(@"Unknown argument '%@' ... ignored", arg);
	}
    }

  mgr = [NSFileManager defaultManager];

  /*
   * Load any old project indexing information and determine when the
   * indexing information was last updated (never ==> distant past)
   */
  refsFile = [documentationDirectory
    stringByAppendingPathComponent: project];
  refsFile = [refsFile stringByAppendingPathExtension: @"igsdoc"];
  projectRefs = [AGSIndex new];
  originalIndex = nil;
  rDate = [NSDate distantPast];
  if ([mgr isReadableFileAtPath: refsFile] == YES)
    {
      originalIndex
	= [[NSDictionary alloc] initWithContentsOfFile: refsFile];
      if (originalIndex == nil)
	{
	  NSLog(@"Unable to read project file '%@'", refsFile);
	}
      else
	{
	  NSDictionary	*dict;

	  [projectRefs mergeRefs: originalIndex override: NO];
	  dict = [mgr fileAttributesAtPath: refsFile traverseLink: YES];
	  rDate = [dict fileModificationDate];
	}
    }

  if ([defs boolForKey: @"Clean"] == YES)
    {
      NSDictionary	*output;
      NSEnumerator	*enumerator;
      NSArray		*outputNames;
      NSMutableSet	*allPaths;
      NSMutableSet	*templates = nil;
      NSSet		*preserve = nil;
      NSString		*path;
      NSArray	*keys = [NSArray arrayWithObjects:
	@"Constants",
	@"Functions",
	@"Macros",
	@"Typedefs",
	@"Variables",
	nil];

      /*
       * Build a set of all template files.
       */
      templates = AUTORELEASE([NSMutableSet new]);
      enumerator = [keys objectEnumerator];
      while ((path = [enumerator nextObject]) != nil)
	{
	  path = [path stringByAppendingString: @"Template"];
	  path = [defs stringForKey: path];
	  if (path != nil)
	    {
	      path = [path stringByAppendingPathExtension: @"gsdoc"];
	      if ([path isAbsolutePath] == NO)
		{
		  path = [documentationDirectory
		    stringByAppendingPathComponent: path];
		}
	      [templates addObject: path];
	    }
	}

      /*
       * Unless we are supposed to clean templates, we preserve any
       * template gsdoc files, but remove any generated content.
       */
      if ([defs boolForKey: @"CleanTemplates"] == NO)
	{
	  preserve = templates;
	  enumerator = [templates objectEnumerator];
	  while ((path = [enumerator nextObject]) != nil)
	    {
	      if ([mgr isReadableFileAtPath: path] == YES)
		{
		  NSMutableString	*ms;
		  NSEnumerator		*e = [keys objectEnumerator];
		  NSString		*k;
		  unsigned		length;

		  ms = [[NSMutableString alloc] initWithContentsOfFile: path];
		  if (ms == nil)
		    {
		      NSLog(@"Cleaning ... failed to read '%@'", path);
		      continue;
		    }
		  length = [ms length];
		  while ((k = [e nextObject]) != nil)
		    {
		      NSString	*ss;
		      NSString	*es;
		      NSRange	sr;
		      NSRange	er;

		      ss = [NSString stringWithFormat: @"<!--Start%@-->", k];
		      sr = [ms rangeOfString: ss];
		      es = [NSString stringWithFormat: @"<!--End%@-->", k];
		      er = [ms rangeOfString: es];
		      if (sr.length > 0 && er.length > 0
			&& er.location > sr.location)
			{
			  NSRange	r;

			  r.location = sr.location;
			  r.length = NSMaxRange(er) - r.location;
			  [ms replaceCharactersInRange: r withString: @""];
			}
		    }
		  if ([ms length] != length)
		    {
		      if ([ms writeToFile: path atomically: YES] == NO)
			{
			  NSLog(@"Cleaning ... failed to write '%@'", path);
			}
		    }
		}
	    }
	}

      /*
       * Build a list of all generated gsdoc files, then remove them
       * and their corresponding html documents.
       */
      output = [[projectRefs refs] objectForKey: @"output"];
      enumerator = [output objectEnumerator];
      allPaths = [[NSMutableSet alloc] initWithSet: templates];
      while ((outputNames = [enumerator nextObject]) != nil)
	{
	  [allPaths addObjectsFromArray: outputNames];
	}
      enumerator = [allPaths objectEnumerator];
      while ((path = [enumerator nextObject]) != nil)
	{
	  /*
	   * Delete any gsdoc files which are not in the preserve set.
	   */
	  if ([preserve member: path] == nil)
	    {
	      if ([mgr fileExistsAtPath: path] == YES)
		{
		  if ([mgr removeFileAtPath: path handler: nil] == NO)
		    {
		      NSLog(@"Cleaning ... failed to remove %@", path);
		    }
		}
	    }
	  path = [path stringByDeletingPathExtension];
	  path = [path stringByAppendingPathExtension: @"html"];
	  if ([mgr fileExistsAtPath: path] == YES)
	    {
	      if ([mgr removeFileAtPath: path handler: nil] == NO)
		{
		  NSLog(@"Cleaning ... failed to remove %@", path);
		}
	    }
	}
      RELEASE(allPaths);

      /*
       * Remove the project index file.
       */
      if ([mgr fileExistsAtPath: refsFile] == YES)
	{
	  if ([mgr removeFileAtPath: refsFile handler: nil] == NO)
	    {
	      NSLog(@"Cleaning ... failed to remove %@", refsFile);
	    }
	}

      /*
       * Remove any HTML documents resulting from gsdoc files which
       * were specified on the command line rather than generated.
       */
      enumerator = [gFiles objectEnumerator];
      while ((path = [enumerator nextObject]) != nil)
	{
	  path = [path lastPathComponent];
	  path = [path stringByDeletingPathExtension];
	  path = [path stringByAppendingPathExtension: @"html"];
	  path = [documentationDirectory
	    stringByAppendingPathComponent: path];
	  if ([mgr fileExistsAtPath: path] == YES)
	    {
	      if ([mgr removeFileAtPath: path handler: nil] == NO)
		{
		  NSLog(@"Cleaning ... failed to remove %@", path);
		}
	    }
	}
      return 0;
    }

  if ([sFiles count] == 0 && [gFiles count] == 0 && [hFiles count] == 0)
    {
      NSLog(@"No filename arguments found ... giving up");
      return 1;
    }

  count = [sFiles count];
  if (count > 0)
    {
      AGSParser		*parser;
      AGSOutput		*output;
      NSString		*up;

      up = [defs stringForKey: @"Up"];

#if GS_WITH_GC == 0
      pool = [NSAutoreleasePool new];
#endif

      parser = [AGSParser new];
      [parser setWordMap: [defs dictionaryForKey: @"WordMap"]];
      output = [AGSOutput new];
      if ([defs boolForKey: @"Standards"] == YES)
	{
	  [parser setGenerateStandards: YES];
	}
      if ([defs boolForKey: @"DocumentAllInstanceVariables"] == YES)
	{
	  [parser setDocumentAllInstanceVariables: YES];
	}

      for (i = 0; i < count; i++)
	{
	  NSString		*hfile = [sFiles objectAtIndex: i];
	  NSString		*gsdocfile;
	  NSString		*file;
	  NSMutableArray	*a;
	  NSDictionary		*attrs;
	  NSDate		*sDate = nil;
	  NSDate		*gDate = nil;
	  unsigned		j;

#if GS_WITH_GC == 0
	  if (pool != nil)
	    {
	      RELEASE(pool);
	      pool = [NSAutoreleasePool new];
	    }
#endif

	  /*
	   * Note the name of the header file without path or extension.
	   * This will be used to generate the output file.
	   */
	  file = [hfile stringByDeletingPathExtension];
	  file = [file lastPathComponent];

	  /*
	   * Ensure that header file name is set up using the
	   * header directory specified unless it is absolute.
	   */
	  if ([hfile isAbsolutePath] == NO)
	    {
	      if ([headerDirectory length] > 0
	        && [[hfile pathExtension] isEqual: @"h"] == YES)
		{
		  hfile = [headerDirectory stringByAppendingPathComponent:
		    hfile];
		}
	    }

	  gsdocfile = [documentationDirectory
	    stringByAppendingPathComponent: file];
	  gsdocfile = [gsdocfile stringByAppendingPathExtension: @"gsdoc"];

	  if (ignoreDependencies == NO)
	    {
	      NSDate	*d;

	      /*
	       * Ask existing project info (.gsdoc file) for dependency
	       * information.  Then check the dates on the source files
	       * and the header file.
	       */
	      a = [projectRefs sourcesForHeader: hfile];
	      [a insertObject: hfile atIndex: 0];
	      for (j = 0; j < [a count]; j++)
		{
		  NSString	*sfile = [a objectAtIndex: j];

		  attrs = [mgr fileAttributesAtPath: sfile
				       traverseLink: YES];
		  d = [attrs fileModificationDate];
		  if (sDate == nil || [d earlierDate: sDate] == sDate)
		    {
		      sDate = d;
		      AUTORELEASE(RETAIN(sDate));
		    }
		}
	      if (verbose == YES)
		{
		  NSLog(@"Saved sources for %@ are %@ ... %@", hfile, a, sDate);
		}

	      /*
	       * Ask existing project info (.gsdoc file) for dependency
	       * information.  Then check the dates on the output files.
	       * If none are set, assume the defualt.
	       */
	      a = [projectRefs outputsForHeader: hfile];
	      if ([a count] == 0)
		{
		  [a insertObject: gsdocfile atIndex: 0];
		}
	      for (j = 0; j < [a count]; j++)
		{
		  NSString	*ofile = [a objectAtIndex: j];

		  attrs = [mgr fileAttributesAtPath: ofile traverseLink: YES];
		  d = [attrs fileModificationDate];
		  if (gDate == nil || [d laterDate: gDate] == gDate)
		    {
		      gDate = d;
		      AUTORELEASE(RETAIN(gDate));
		    }
		}
	      if (verbose == YES)
		{
		  NSLog(@"Saved outputs for %@ are %@ ... %@", hfile, a, gDate);
		}
	    }

	  if (gDate == nil || [sDate earlierDate: gDate] == gDate)
	    {
	      NSArray	*modified;

	      if (showDependencies == YES)
		{
		  NSLog(@"%@: source %@, gsdoc %@ ==> regenerate",
		    file, sDate, gDate);
		}
	      [parser reset];

	      /*
	       * Try to parse header to see what needs documenting.
	       * If the header given was actually a .m file, this will
	       * parse that file for declarations rather than definitions.
	       */
	      if ([mgr isReadableFileAtPath: hfile] == NO)
		{
		  NSLog(@"No readable header at '%@' ... skipping", hfile);
		  continue;
		}
	      if (declared != nil)
		{
		  [parser setDeclared:
		    [declared stringByAppendingPathComponent:
		      [hfile lastPathComponent]]];
		}
	      [parser parseFile: hfile isSource: NO];

	      /*
	       * Record dependency information.
	       */
	      a = [parser outputs];
	      if ([a count] > 0)
		{
		  /*
		   * Adjust the location of the output files to be in the
		   * documentation directory.
		   */
		  for (j = 0; j < [a count]; j++)
		    {
		      NSString	*s = [a objectAtIndex: j];

		      if ([s isAbsolutePath] == NO)
			{
			  s = [documentationDirectory
			    stringByAppendingPathComponent: s];
			  [a replaceObjectAtIndex: j withObject: s];
			}
		    }
		  if (verbose == YES)
		    {
		      NSLog(@"Computed outputs for %@ are %@", hfile, a);
		    }
		  [projectRefs setOutputs: a forHeader: hfile];
		}
	      a = [parser sources];
	      if ([a count] > 0)
		{
		  [projectRefs setSources: a forHeader: hfile];
		}
	      if (verbose == YES)
		{
		  NSLog(@"Computed sources for %@ are %@", hfile, a);
		}

	      for (j = 0; j < [a count]; j++)
		{
		  NSString	*sfile = [a objectAtIndex: j];

		  /*
		   * If we can read a source file, parse it for any
		   * additional information on items found in the header.
		   */
		  if ([mgr isReadableFileAtPath: sfile] == YES)
		    {
		      [parser parseFile: sfile isSource: YES];
		    }
		  else
		    {
		      NSLog(@"No readable source at '%@' ... ignored", sfile);
		    }
		}

	      /*
	       * Set up linkage for this file.
	       */
	      [[parser info] setObject: file forKey: @"base"];
	      [[parser info] setObject: documentationDirectory
				forKey: @"directory"];

	      /*
	       * Only produce linkage if the up link is not empty.
	       * Don't add an up link if this *is* the up link document.
	       */
	      if ([up length] > 0 && [up isEqual: file] == NO)
		{
		  [[parser info] setObject: up forKey: @"up"];
		}

	      modified = [output output: [parser info]];
	      if (modified == nil)
		{
		  NSLog(@"Sorry unable to write %@", gsdocfile);
		}
	      else
		{
		  unsigned	c = [modified count];

		  while (c-- > 0)
		    {
		      NSString	*f;

		      f = [[modified objectAtIndex: c] lastPathComponent];
		      if ([gFiles containsObject: f] == NO)
			{
			  [gFiles addObject: f];
			}
		    }
		}
	    }
	  else
	    {
	      /*
	       * Add the .h file to the list of those to process.
	       */
	      [gFiles addObject: [hfile lastPathComponent]];
	    }
	}
#if GS_WITH_GC == 0
      DESTROY(pool);
#endif
      DESTROY(parser);
      DESTROY(output);
    }

  count = [gFiles count];
  if (count > 0)
    {
      NSDictionary	*projectIndex;
      CREATE_AUTORELEASE_POOL(arp);

      for (i = 0; i < count; i++)
	{
	  NSString	*arg = [gFiles objectAtIndex: i];
	  NSString	*gsdocfile;
	  NSString	*file;
	  NSDictionary	*attrs;
	  NSDate	*gDate = nil;

#if GS_WITH_GC == 0
	  if (arp != nil)
	    {
	      RELEASE(arp);
	      arp = [NSAutoreleasePool new];
	    }
#endif
	  file = [[arg lastPathComponent] stringByDeletingPathExtension];

	  gsdocfile = [documentationDirectory
	    stringByAppendingPathComponent: file];
	  gsdocfile = [gsdocfile stringByAppendingPathExtension: @"gsdoc"];

	  /*
	   * If our source file is a gsdoc file ... it may be located
	   * in the current (input) directory rather than the documentation
	   * (output) directory.
	   */
	  if ([mgr isReadableFileAtPath: gsdocfile] == NO)
	    {
	      gsdocfile = [file stringByAppendingPathExtension: @"gsdoc"];
	    }
	  if (ignoreDependencies == NO)
	    {
	      attrs = [mgr fileAttributesAtPath: gsdocfile traverseLink: YES];
	      gDate = [attrs fileModificationDate];
	      AUTORELEASE(RETAIN(gDate));
	    }

	  /*
	   * Now we try to process the gsdoc data to make index info
	   * unless the project index is already more up to date than
	   * this file (or the gsdoc file does not exist of course).
	   */
	  if (gDate != nil && [gDate earlierDate: rDate] == rDate)
	    {
	      if (showDependencies == YES)
		{
		  NSLog(@"%@: gsdoc %@, index %@ ==> regenerate",
		    file, gDate, rDate);
		}
	      if ([mgr isReadableFileAtPath: gsdocfile] == YES)
		{
		  GSXMLNode	*root;
		  GSXMLParser	*parser;
		  AGSIndex	*localRefs;

		  parser = [GSXMLParser parserWithContentsOfFile: gsdocfile];
		  [parser substituteEntities: NO];
		  [parser doValidityChecking: YES];
		  [parser keepBlanks: NO];
		  if ([parser parse] == NO)
		    {
		      NSLog(@"WARNING %@ is not a valid document", gsdocfile);
		    }
		  root = [[parser document] root];
		  if (![[root name] isEqualToString: @"gsdoc"])
		    {
		      NSLog(@"not a gsdoc document - because name node is %@",
			[root name]);
		      return 1;
		    }

		  localRefs = AUTORELEASE([AGSIndex new]);
		  [localRefs makeRefs: root];

		  /*
		   * accumulate index info in project references
		   */
		  [projectRefs mergeRefs: [localRefs refs] override: NO];
		}
	      else
		{
		  NSLog(@"No readable documentation at '%@' ... skipping",
		    gsdocfile);
		}
	    }
	}
#if GS_WITH_GC == 0
      DESTROY(arp);
#endif

      /*
       * Save project references if they have been modified.
       */
      projectIndex = [projectRefs refs];
      if (projectIndex != nil && [originalIndex isEqual: projectIndex] == NO)
	{
	  if ([projectIndex writeToFile: refsFile atomically: YES] == NO)
	    {
	      NSLog(@"Sorry unable to write %@", refsFile);
	    }
	}
      DESTROY(originalIndex);
    }

  globalRefs = [AGSIndex new];
  
  /*
   * If we are either generating html output, or relocating existing
   * html documents, we must build up the indexing information needed
   * for any cross-referencing etc.
   */
  if (generateHtml == YES || [hFiles count] > 0)
    {
      NSMutableDictionary	*projects;
      NSString			*systemProjects;
      NSString			*localProjects;
      CREATE_AUTORELEASE_POOL (pool);

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

		  if ([ext isEqualToString: @"igsdoc"] == YES
		    && [[file lastPathComponent] isEqual: refsName] == NO)
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
		  

		  if ([ext isEqualToString: @"igsdoc"] == YES
		    && [[file lastPathComponent] isEqual: refsName] == NO)
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

#if GS_WITH_GC == 0
      RELEASE(pool);
#endif
    }

  /*
   * Next pass ... generate html output from gsdoc files if required.
   */
  count = [gFiles count];
  if (generateHtml == YES && count > 0)
    {
#if GS_WITH_GC == 0
      pool = [NSAutoreleasePool new];
#endif

      for (i = 0; i < count; i++)
	{
	  NSString	*arg = [gFiles objectAtIndex: i];
	  NSString	*gsdocfile;
	  NSString	*htmlfile;
	  NSString	*file;
	  NSString	*generated;
	  NSDictionary	*attrs;
	  NSDate	*gDate = nil;
	  NSDate	*hDate = nil;

#if GS_WITH_GC == 0
	  if (pool != nil)
	    {
	      RELEASE(pool);
	      pool = [NSAutoreleasePool new];
	    }
#endif
	  file = [[arg lastPathComponent] stringByDeletingPathExtension];

	  gsdocfile = [documentationDirectory
	    stringByAppendingPathComponent: file];
	  gsdocfile = [gsdocfile stringByAppendingPathExtension: @"gsdoc"];
	  htmlfile = [documentationDirectory
	    stringByAppendingPathComponent: file];
	  htmlfile = [htmlfile stringByAppendingPathExtension: @"html"];

	  /*
	   * If the gsdoc file name was specified as a source file,
	   * it may be in the source directory rather than the documentation
	   * directory.
	   */
	  if ([mgr isReadableFileAtPath: gsdocfile] == NO
	    && [arg hasSuffix: @".gsdoc"] == YES)
	    {
	      gsdocfile = [file stringByAppendingPathExtension: @"gsdoc"];
	    }

	  if (ignoreDependencies == NO)
	    {
	      /*
	       * When were the files last modified?
	       */
	      attrs = [mgr fileAttributesAtPath: gsdocfile traverseLink: YES];
	      gDate = [attrs fileModificationDate];
	      AUTORELEASE(RETAIN(gDate));
	      attrs = [mgr fileAttributesAtPath: htmlfile traverseLink: YES];
	      hDate = [attrs fileModificationDate];
	      AUTORELEASE(RETAIN(hDate));
	    }

	  if ([mgr isReadableFileAtPath: gsdocfile] == YES)
	    {
	      if (hDate == nil || [gDate earlierDate: hDate] == hDate)
		{
		  GSXMLNode	*root;
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
		  root = [[parser document] root];
		  if (![[root name] isEqualToString: @"gsdoc"])
		    {
		      NSLog(@"not a gsdoc document - because name node is %@",
			[root name]);
		      return 1;
		    }

		  localRefs = AUTORELEASE([AGSIndex new]);
		  [localRefs makeRefs: root];

		  /*
		   * We perform final output
		   */
		  html = AUTORELEASE([AGSHtml new]);
		  [html setGlobalRefs: globalRefs];
		  [html setProjectRefs: projectRefs];
		  [html setLocalRefs: localRefs];
		  generated = [html outputDocument: root];
		  if ([generated writeToFile: htmlfile atomically: YES] == NO)
		    {
		      NSLog(@"Sorry unable to write %@", htmlfile);
		    }
		}
	    }
	  else if ([arg hasSuffix: @".gsdoc"] == YES)
	    {
	      NSLog(@"No readable documentation at '%@' ... skipping",
		gsdocfile);
	    }
	}
#if GS_WITH_GC == 0
      RELEASE(pool);
#endif
    }

  /*
   * Relocate existing html documents if required ... adjust all cross
   * referencing within those documents.
   */
  count = [hFiles count];
  if (count > 0)
    {
#if GS_WITH_GC == 0
      pool = [NSAutoreleasePool new];
#endif

      for (i = 0; i < count; i++)
	{
	  NSString	*file = [hFiles objectAtIndex: i];
	  NSString	*src;
	  NSString	*dst;

#if GS_WITH_GC == 0
	  if (pool != nil)
	    {
	      RELEASE(pool);
	      pool = [NSAutoreleasePool new];
	    }
#endif

	  file = [file lastPathComponent];

	  src = file;
	  dst = [documentationDirectory stringByAppendingPathComponent: file];

	  /*
	   * If we can't find the file in the source directory, assume
	   * it is in the documentation directory already, and just needs
	   * cross-refs rebuilding.
	   */
	  if ([mgr isReadableFileAtPath: src] == NO)
	    {
	      src = dst;
	    }

	  if ([mgr isReadableFileAtPath: src] == YES)
	    {
	      NSData		*d;
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
		  if (verbose == YES)
		    {
		      NSLog(@"Replace %@ with %@",
			[s substringWithRange: replace],
			repstr ? repstr : @"self");
		    }
		  if (repstr != nil)
		    {
		      int	offset = [repstr length] - replace.length;

		      p += offset;
		      l += offset;
		      [s replaceCharactersInRange: replace withString: repstr];
		    }

		  r = [s rangeOfString: @"<a rel=\"gsdoc\" href=\""
			       options: NSLiteralSearch
				 range: NSMakeRange(p, l - p)];
		}

	      d = [s dataUsingEncoding: NSUTF8StringEncoding];
	      [d writeToFile: dst atomically: YES];
	    }
	  else if ([file hasSuffix: @".gsdoc"] == YES)
	    {
	      NSLog(@"No readable documentation at '%@' ... skipping", src);
	    }
	}
#if GS_WITH_GCC == 0
      RELEASE(pool);
#endif
    }

  RELEASE(outer);
  return 0;
}

