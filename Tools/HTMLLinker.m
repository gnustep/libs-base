/* The GNUstep HTML Linker
   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by: Nicola Pero <nicola@brainstorm.co.uk>
   Date: January 2002

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

/*
 * This tool implements a HTML linker.
 *
 * A HTML linker is able to fixup ahref links from one HTML document
 * to other HTML ones.
 *
 * It's a pretty generic tool.  Think it in this way - say that you
 * have a collection of HTML files, all in the same directory, with
 * working links from one file to the other one.
 *
 * Now you move the files around, scattering them in many directories
 * - of course the links no longer work!
 *
 * But if you run the HTML linker on the files, the HTML linker will
 * modify all links inside the files, resolving each of them to point
 * to the actual full path of the required file.  The links will work
 * again.
 *
 * In the real world, it's more complicated than this because you
 * normally put the HTML files across different directories from the
 * very beginning.  The HTML linker becomes helpful because you can
 * create links between these files as if they were in the same
 * directory ... and then - at the end - run the HTML linker to
 * actually fixup the links and make them work.  If you move around
 * the files or mess in any way with their paths, you can always fixup
 * the links afterwards by rerunning the linker - you don't need to
 * regenerate the HTML files.
 *
 * This is exactly what (auto)gsdoc does when generating the HTML - it
 * creates links from one class to another one as if they were in the
 * same directory, ignoring the issue of the real full paths on disk
 * (and whether the documentation for the other classes actually
 * exists :-).
 *
 * When the documentation is installed, the HTML linker is run, and it
 * will actually fix up the links to point to the real full paths on
 * disk (and warn about any unresolved reference).  Note that when you
 * install the documentation, files end up in different dirs of
 * GNUSTEP_LOCAL_ROOT or GNUSTEP_SYSTEM_ROOT or GNUSTEP_USER_ROOT
 * ... without the linker it would be a pain to keep cross-references
 * right.  It would probably be impossible.
 *
 * The HTML linker will only fixup links which have the attribute
 * 'rel' set to 'dynamical', as in the following example -
 *
 * <a href="NSObject_Protocol.html#-class" rel="dynamic">
 *
 * All other links will be ignored and not fixed up.  This is so that
 * you can clearly mark the links you want to be dynamically fixed up
 * by the linker; other links will not be touched.  If you want the
 * linker to attempt to fixup all links, pass the -FixupAllLinks YES
 * option to the linker.
 *
 * The linker might perform 'link checking' if run with the
 * '-CheckLinks YES' option.  link checking means that when a link is
 * fixed up, the linker checks that the destination file actually
 * contains the appropriate <a name="xxx"> tag.  For example, when
 * fixing up <a href="NSObject_Protocol.html#-class" rel="dynamic">,
 * the linker will check that the NSObject_Protocol.html file will
 * actually contain a <a name="-class"> tag somewhere, and issue a
 * warning otherwise.
 *
 * If you run the linker without 'link checking' it will not even need
 * to read the destination file, which (of course) gives better
 * performance.
 *
 * Last, please notice that when using the HTML linker in practice,
 * the tool works with two kind of files -
 *
 * 'input files' - files whose links need to be fixed up.  These files
 * are *modified* by the linker.  The old version of the file is
 * (atomically) replaced with the fixed up one.
 *
 * 'destination files' - files which can be the destination of links
 * in the input files.  These files are untouched during processing;
 * but they might be read when the linker is run with 'link checking'
 * enabled, to check that the links in the input files are actually
 * correct.  */

#include <Foundation/Foundation.h>

/* For convenience, cached for the whole tool.  */

/* [NSFileManager defaultManager]  */
static NSFileManager *fileManager = nil;

/* [[NSFileManager defaulManager] currentDirectoryPath]  */
static NSString *currentPath = nil;

/* Enumerate all .html files in a directory and subdirectories.  */
@interface HTMLDirectoryEnumerator : NSEnumerator
{
  NSDirectoryEnumerator *e;
  NSString *basePath;
}

- (id)initWithBasePath: (NSString *)path;

@end

@implementation HTMLDirectoryEnumerator : NSEnumerator

- (id)initWithBasePath: (NSString *)path
{
  ASSIGN (e, [fileManager enumeratorAtPath: path]);
  ASSIGN (basePath, path);
  return [super init];
}

- (void)dealloc
{
  RELEASE (e);
  RELEASE (basePath);
  [super dealloc];
}

- (id)nextObject
{
  NSString *s;
  
  while ((s = [e nextObject]) != nil)
    {
      NSString *extension = [s pathExtension];
      
      if ([extension isEqualToString: @"html"]  
	  || [extension isEqualToString: @"HTML"]
	  || [extension isEqualToString: @"htm"]  
	  || [extension isEqualToString: @"HTM"])
	{
	  /* NSDirectoryEnumerator returns the relative path, we
	     return the absolute.  */
	  return [basePath stringByAppendingPathComponent: s];
	}
    }

  return nil;
}

@end

/* 
 * An object representing a file which can be a destination of links.  
 */
@interface DestinationFile : NSObject
{
  /* Full name to be used when fixing up links to this file.  */
  NSString *fullName;

  /* Path on disk needed to read the file from disk - needed only when
     performing link checking.  pathOnDisk might be different from
     fullName, for example for a file on a web server.  In that case,
     fullName is the URI to the file on the web server, while
     pathOnDisk is the path to the file on disk.  */
  NSString *pathOnDisk;

  /* If the file has already been read to perform link checking, names
     is the array of all names (for any <a name="xxx"> in the file,
     xxx is put in the names array for that file) in the file.  If it
     hasn't yet been read, it's nil.  We read the file and parse it
     lazily, only if needed.  */
  NSArray *names;
}

/* Return the full name.  */
- (NSString *)fullName;

/* Checks that the file on disk contains <a name="xxx"> where xxx is
   name, lazily loading and parsing the file if needed.  Return YES if
   the file contains name, NO if it doesn't.  */
- (BOOL)checkAnchorName: (NSString *)name;

@end

/* The HTMLLinker class is very simple and is the core of the linker.
   It just keeps a table of the available destination files, and is
   able to fixup a link to point to one of those files.  */
@interface HTMLLinker : NSObject
{
  BOOL verbose;
  BOOL checkLinks;
  NSMutableDictionary *files;
  NSMutableDictionary *pathMappings;
}

- (id)initWithVerboseFlag: (BOOL)v
	   checkLinksFlag: (BOOL)f;

/* Register the file as available for resolving references.  */
- (void)registerFile: (NSString *)pathOnDisk;

/* Register a new path mapping.  */
- (void)registerPathMappings: (NSDictionary *)dict;

/* Resolve the link 'link' by fixing it up using the registered
   destination files.  Return the resolved link.  'logFile' is only
   used to print error messages.  It is the file in which the link is
   originally found; if there is problem resolving the link, the
   warning message printed out states that the problem is in file
   'logFile'.  */
- (NSString *)resolveLink: (NSString *)link
		  logFile: (NSString *)logFile;

@end

/* All the parsing code is in the following class.  It's not a real
   parser in the sense that it is just performing its minimal duty in
   the quickest possible way, so calling this a parser is a bit of a
   exaggeration ... this code can run very quickly through an HTML
   string, extracting the <a name="yyy"> tags or fixing up the <a
   href="xxx" rel="dynamical"> tags.  No more HTML parsing than this
   is done.  Remarkably, this does not need XML support in the base
   library, so you can use the HTML linker on any system.  This class
   was written in order to perform its trivial, mechanical duty /very
   fast/.  You want to be able to run the linker often and on a lot of
   files and still be happy.  */
@interface HTMLParser : NSObject
{
  /* The HTML code that we work on.  */
  unichar *chars;
  unsigned length;
}
/* Init with some HTML code to parse.  */
- (id)initWithCode: (NSString *)HTML;

/* Extract all the <a name="xxx"> tags from the HTML code, and return
   a list of them.  */
- (NSArray *)names;

/* Fix up all the links in the HTML code by feeding each of them to
   the provided HTMLLinker; return the fixed up HTML code.  If
   fixupAllLinks is 'NO', only fixup links with rel="dynamical"; if
   fixupAllLinks is 'YES', attempt to fixup all links in the HTML
   code.  logFile is the file we are fixing up; it's only used when a
   warning is issued because there is problem in the linking - the
   warning message is displayed as being about links in the file
   logFile.  */
- (NSString *)resolveLinksUsingHTMLLinker: (HTMLLinker *)linker
				  logFile: (NSString *)logFile
			    fixupAllLinks: (BOOL)fixupAllLinks;
@end


@implementation HTMLParser

- (id)initWithCode: (NSString *)HTML
{
  length = [HTML length];
  chars = malloc (sizeof(unichar) * length);
  [HTML getCharacters: chars];

  return [super init];
}

- (void)dealloc
{
  free (chars);
  [super dealloc];
}

- (NSArray *)names
{
  NSMutableArray *names = AUTORELEASE ([NSMutableArray new]);
  unsigned i = 0;

  while (i + 3 < length)
    {
      /* We ignore anything except stuff which begins with "<a ". */
      if ((chars[i] == '<') 
	  && (chars[i + 1] == 'A'  ||  chars[i + 1] == 'a')
	  && (chars[i + 2] == ' '))
	{
	  /* Ok - we got the '<a ' tag, now parse it ... we're
             searching for a name attribute.  */
	  NSString *name = nil;

	  i += 3;
	  
	  while (1)
	    {
	      /* A marker for the start of strings.  */
	      unsigned s;

	      /* If this is not a 'name' attribute, setting this to YES
		 cause us to ignore it and go on to the next one.  */
	      BOOL isNameAttribute = NO;

	      /* Read in an attribute, of the form xxx="yyy" or
                 xxx=yyy or similar, and save it if it is a name
                 attribute.  */

	      /* Skip spaces.  */
	      while (i < length  &&  (chars[i] == ' '
				      || chars[i] == '\n'
				      || chars[i] == '\r'
				      || chars[i] == '\t'))
		{ i++; }
	      
	      if (i == length) { break; }
     	      
	      /* Read the attribute.  */
	      s = i;
	      
	      while (i < length  &&  (chars[i] != ' '  
				      && chars[i] != '\n'
				      && chars[i] != '\r'
				      && chars[i] != '\t'
				      && chars[i] != '='
				      && chars[i] != '>'))
		{ i++; }

	      if (i == length) { break; }
	      if (chars[i] == '>') { break; }


	      /* I suppose i == s might happen if the file contains <a
                 ="nicola"> */
	      if (i != s)
		{
		  /* If name != nil we already found it so don't bother.  */
		  if (name == nil)
		    {
		      NSString *attribute;
		      
		      attribute = [NSString stringWithCharacters: &chars[s]  
					    length: (i - s)];
		      /* Lowercase name so that eg, HREF and href are the
			 same.  */
		      attribute = [attribute lowercaseString];
		      
		      if ([attribute isEqualToString: @"name"])
			{
			  isNameAttribute = YES;
			}
		    }
		}
	      
	      /* Skip spaces.  */
	      while (i < length  &&  (chars[i] == ' '
				      || chars[i] == '\n'
				      || chars[i] == '\r'
				      || chars[i] == '\t'))
		{ i++; }
	      
	      if (i == length) { break; }

	      /* Read the '='  */
	      if (chars[i] == '=')
		{ 
		  i++; 
		}
	      else
		{
		  /* No '=' -- go on with the next attribute.  */
		  continue; 
		}
	      
	      if (i == length) { break; }

	      /* Skip spaces.  */
	      while (i < length &&  (chars[i] == ' '
				     || chars[i] == '\n'
				     || chars[i] == '\r'
				     || chars[i] == '\t'))
		{ i++; }
	      
	      if (i == length) { break; }
     	      
	      /* Read the value.  */
	      if (chars[i] == '"')
		{
		  /* Skip the '"', then read up to a '"'.  */
		  i++;
		  if (i == length) { break; }
		  
		  s = i;

		  while (i < length   &&  (chars[i] != '"'))
		    { i++; }
		}
	      else if (chars[i] == '\'')
		{
		  /* Skip the '\'', then read up to a '\''.  */
		  i++;
		  if (i == length) { break; }
		  
		  s = i;
		  
		  while (i < length   &&  (chars[i] != '\''))
		    { i++; }
		}
	      else
		{
		  /* Read up to a space or '>'.  */
		  s = i;

		  while (i < length
			 &&  (chars[i] != ' '  
			      && chars[i] != '\n'
			      && chars[i] != '\r'
			      && chars[i] != '\t'
			      && chars[i] != '>'))
		    { i++; }
		}

	      if (name == nil  &&  isNameAttribute)
		{
		  if (i == s)
		    {
		      /* I suppose this might happen if the file
			 contains <a name=> */
		      name = @"";
		    }
		  else
		    {
		      name = [NSString stringWithCharacters: &chars[s]  
				       length: (i - s)];
		      /* Per HTML specs we lowercase name.  */
		      name = [name lowercaseString];
		    }
		}
	    }
	  
	  if (name != nil)
	    {
	      [names addObject: name];
	    }
	}
      i++;
    }

  return names;
}


- (NSString *)resolveLinksUsingHTMLLinker: (HTMLLinker *)linker
				  logFile: (NSString *)logFile
			    fixupAllLinks: (BOOL)fixupAllLinks
{
  /* We represent the output as a linked list.  Each element in the
     linked list represents a string; concatenating all the strings in
     the linked list, you obtain the output.  The trick is that these
     strings in the linked list might actually be pointers inside the
     chars array ... we are never copying stuff from the chars array -
     just keeping pointers to substrings inside it - till we generate
     the final string at the end ... for speed and efficiency reasons
     of course.  */
  struct stringFragment
    {
      unichar *chars;
      unsigned length;
      BOOL needsFreeing;
      struct stringFragment *next;
    } *head, *tail;

  /* The index of the beginning of the last string fragment (the tail).  */
  unsigned tailIndex = 0;

  /* The temporary index.  */
  unsigned i = 0;

  /* The total number of chars in the output string.  We don't know
     this beforehand because each time we fix up a link, we might add
     or remove characters from the output.  We update
     totalNumberOfChars each time we close a stringFragment.  */
  unsigned totalNumberOfChars = 0;
  

  /* Initialize the linked list.  */
  head = malloc (sizeof (struct stringFragment));
  head->chars = chars;
  head->length = 0;
  head->needsFreeing = NO;
  head->next = NULL;

  /* The last string fragment is the first one at the beginning.  */
  tail = head;
  
  while (i + 3 < length)
    {
      /* We ignore anything except stuff which begins with "<a ". */
      if ((chars[i] == '<') 
	  && (chars[i + 1] == 'A'  ||  chars[i + 1] == 'a')
	  && (chars[i + 2] == ' '))
	{
	  /* Ok - we got the '<a ' tag, now parse it ... we're
             searching for a href and a rel attributes.  */
	  NSString *href = nil;
	  NSString *rel = nil;

	  /* We also need to keep track of where the href starts and
             where it ends, because we are going to replace it with a
             different one (the fixed up one) later on if we determine
             we should do it.  */
	  unsigned hrefStart = 0, hrefEnd = 0;

	  i += 3;
	  
	  while (1)
	    {
	      /* A marker for the start of strings.  */
	      unsigned s;

	      /* If this is an interesting (href/rel) attribute or
		 not, and which one.  */
	      BOOL isHrefAttribute = NO;
	      BOOL isRelAttribute = NO;

	      /* Read in an attribute, of the form xxx="yyy" or
                 xxx=yyy or similar, and save it if it is a name
                 attribute.  */

	      /* Skip spaces.  */
	      while (i < length  &&  (chars[i] == ' '
				      || chars[i] == '\n'
				      || chars[i] == '\r'
				      || chars[i] == '\t'))
		{ i++; }
	      
	      if (i == length) { break; }
     	      
	      /* Read the attribute.  */
	      s = i;
	      
	      while (i < length  &&  (chars[i] != ' '  
				      && chars[i] != '\n'
				      && chars[i] != '\r'
				      && chars[i] != '\t'
				      && chars[i] != '='
				      && chars[i] != '>'))
		{ i++; }

	      if (i == length) { break; }
	      if (chars[i] == '>') { break; }


	      /* I suppose i == s might happen if the file contains <a
                 ="nicola"> */
	      if (i != s)
		{
		  /* If href != nil && rel != nil we already found it
                     so don't bother.  */
		  if (href == nil  ||  rel == nil)
		    {
		      NSString *attribute;
		      
		      attribute = [NSString stringWithCharacters: &chars[s]  
					    length: (i - s)];
		      /* Lowercase name so that eg, HREF and href are the
			 same.  */
		      attribute = [attribute lowercaseString];
		      
		      if (href == nil 
			  && [attribute isEqualToString: @"href"])
			{
			  isHrefAttribute = YES;
			}
		      else if (rel == nil 
			       && [attribute isEqualToString: @"rel"])
			{
			  isRelAttribute = YES;
			}
		    }
		}
	      
	      /* Skip spaces.  */
	      while (i < length  &&  (chars[i] == ' '
				      || chars[i] == '\n'
				      || chars[i] == '\r'
				      || chars[i] == '\t'))
		{ i++; }
	      
	      if (i == length) { break; }

	      /* Read the '='  */
	      if (chars[i] == '=')
		{ 
		  i++; 
		}
	      else
		{
		  /* No '=' -- go on with the next attribute.  */
		  continue; 
		}
	      
	      if (i == length) { break; }

	      /* Skip spaces.  */
	      while (i < length &&  (chars[i] == ' '
				     || chars[i] == '\n'
				     || chars[i] == '\r'
				     || chars[i] == '\t'))
		{ i++; }
	      
	      if (i == length) { break; }
     	      
	      /* Read the value.  */
	      if (isHrefAttribute)
		{
		  /* Remeber that href starts here.  */
		  hrefStart = i;
		}	      

	      if (chars[i] == '"')
		{
		  /* Skip the '"', then read up to a '"'.  */
		  i++;
		  if (i == length) { break; }
		  
		  s = i;

		  while (i < length   &&  (chars[i] != '"'))
		    { i++; }

		  if (isHrefAttribute)
		    {
		      /* Remeber that href ends here.  We don't want
			 the ending " because we already insert those
			 by our own.  */
		      hrefEnd = i + 1;
		    }
		}
	      else if (chars[i] == '\'')
		{
		  /* Skip the '\'', then read up to a '\''.  */
		  i++;
		  if (i == length) { break; }
		  
		  s = i;
		  
		  while (i < length   &&  (chars[i] != '\''))
		    { i++; }

		  if (isHrefAttribute)
		    {
		      hrefEnd = i + 1;
		    }
		}
	      else
		{
		  /* Read up to a space or '>'.  */
		  s = i;

		  while (i < length
			 &&  (chars[i] != ' '  
			      && chars[i] != '\n'
			      && chars[i] != '\r'
			      && chars[i] != '\t'
			      && chars[i] != '>'))
		    { i++; }
		  if (isHrefAttribute)
		    {
		      /* We do want the ending space.  */
		      hrefEnd = i;
		    }
		}

	      if (i == length)
		{
		  break;
		}

	      if (hrefEnd >= length)
		{
		  hrefEnd = length - 1;
		}
	      
	      if (isRelAttribute)
		{
		  if (i == s)
		    {
		      /* I suppose this might happen if the file
			 contains <a rel=> */
		      rel = @"";
		    }
		  else
		    {
		      rel = [NSString stringWithCharacters: &chars[s]  
				       length: (i - s)];
		    }
		}

	      if (isHrefAttribute)
		{
		  if (i == s)
		    {
		      /* I suppose this might happen if the file
			 contains <a href=> */
		      href = @"";
		    }
		  else
		    {
		      href = [NSString stringWithCharacters: &chars[s]  
				       length: (i - s)];
		    }
		}
	    }
	  if (href != nil  &&  (fixupAllLinks 
				|| [rel isEqualToString: @"dynamical"]))
	    {
	      /* Ok - fixup the link.  */
	      NSString *link;
	      struct stringFragment *s;

	      link = [linker resolveLink: href  logFile: logFile];

	      /* Add " before and after the link.  */
	      link = [NSString stringWithFormat: @"\"%@\"", link];
	      
	      /* Close the previous string fragment at hrefStart.  */
	      tail->length = hrefStart - tailIndex;

	      totalNumberOfChars += tail->length;

	      /* Insert immediately afterwards a string fragment containing
		 the fixed up link.  */
	      s = malloc (sizeof (struct stringFragment));
	      s->length = [link length];
	      
	      s->chars = malloc (sizeof(unichar) * s->length);
	      [link getCharacters: s->chars];
	      
	      s->needsFreeing = YES;
	      s->next = NULL;

	      tail->next = s;
	      tail = s;

	      totalNumberOfChars += tail->length;

	      /* Now prepare the new tail to start just after the end
                 of the original href in the original HTML code.  */
	      s = malloc (sizeof (struct stringFragment));
	      s->length = 0;
	      s->chars = &chars[hrefEnd];
	      s->needsFreeing = NO;
	      s->next = NULL;
	      tail->next = s;
	      tail = s;

	      tailIndex = hrefEnd;
	    }
	}
      i++;
    }

  /* Close the last open string fragment.  */
  tail->length = length - tailIndex;
  totalNumberOfChars += tail->length;

  /* Generate the output.  */
  {
    /* Allocate space for the whole output in a single chunk now that
       we know how big it should be.  */
    unichar *outputChars = malloc (sizeof(unichar) * totalNumberOfChars);
    unsigned j = 0;
    
    /* Copy into the output all the string fragments, destroying each
       of them as we go on.  */
    while (head != NULL)
      {
	struct stringFragment *s;
	
	memcpy (&outputChars[j], head->chars, 
		sizeof(unichar) * head->length);

	j += head->length;
	
	if (head->needsFreeing)
	  {
	    free (head->chars);
	  }
	
	s = head->next;
	free (head);
	head = s;
      }

    return [NSString stringWithCharacters: outputChars
		     length: totalNumberOfChars];
  }
}

@end


@implementation DestinationFile

- (id)initWithFullName: (NSString *)f
	    pathOnDisk: (NSString *)p
{
  ASSIGN (fullName, f);
  ASSIGN (pathOnDisk, p);

  return [super init];
}


- (void)dealloc
{
  RELEASE (fullName);
  RELEASE (pathOnDisk);
  RELEASE (names);
  [super dealloc];
}

- (NSString *)fullName
{
  return fullName;
}

- (BOOL)checkAnchorName: (NSString *)name
{
  /* No anchor.  */
  if (name == nil  ||  [name isEqualToString: @""])
    {
      return YES;
    }

  if (names == nil)
    {
      /* Load the file and parse it, saving the result in names.  */
      NSString *file = [NSString stringWithContentsOfFile: pathOnDisk];
      HTMLParser *parser = [[HTMLParser alloc] initWithCode: file];

      ASSIGN (names, [parser names]);
      RELEASE (parser);
   }

  return [names containsObject: name];
}

@end


@implementation HTMLLinker

- (id)initWithVerboseFlag: (BOOL)v
	   checkLinksFlag: (BOOL)f
{
  verbose = v;
  checkLinks = f;
  files = [NSMutableDictionary new];
  pathMappings = [NSMutableDictionary new];
  return [super init];
}

- (void)dealloc
{
  RELEASE (files);
  RELEASE (pathMappings);
  [super dealloc];
}

- (void)registerFile: (NSString *)pathOnDisk
{
  NSString *fullPath = pathOnDisk;
  DestinationFile *file;

  /* We only accept absolute paths.  */
  if (![pathOnDisk isAbsolutePath])
    {
      pathOnDisk = [currentPath stringByAppendingPathComponent: pathOnDisk];
    }

  /* Check if it's a directory; if it is, enumerate all HTML files
     inside it, and add all of them.  */
  {
    BOOL isDir;
    
    if (![fileManager fileExistsAtPath: pathOnDisk  isDirectory: &isDir])
      {
	if (verbose)
	  {
	    /* FIXME - Perhaps we should not actually ignore it but
               act as if it were there.  */
	    NSLog (@"Warning - destination file '%@' not found - ignored", 
		   pathOnDisk);
	  }
	return;
      }
    else
      {
	if (isDir)
	  {
	    HTMLDirectoryEnumerator *e;
	    NSString *filename;
	   
	    e = [HTMLDirectoryEnumerator alloc];
	    e = [e initWithBasePath: pathOnDisk];
	    
	    while ((filename = [e nextObject]) != nil)
	      {
		[self registerFile: filename];
	      }
	    return;
	  }
      }
  }

  /* Manage pathMappings: try to match any of the pathMappings against
     pathOnDisk, and perform the path mapping if we can match.  */
  {
    NSEnumerator *e = [pathMappings keyEnumerator];
    NSString *key;
    
    while ((key = [e nextObject]))
      {
	if ([pathOnDisk hasPrefix: key])
	  {
	    NSString *value = [pathMappings objectForKey: key];
	    
	    fullPath = [pathOnDisk substringFromIndex: [key length]];
	    fullPath = [value stringByAppendingPathComponent: fullPath];
	    break;
	  }
      }
  }

  /* Save the file properly prepared into our dictionary of
     destination files.  */
  file = [[DestinationFile alloc] initWithFullName: fullPath
				  pathOnDisk: pathOnDisk];
  [files setObject: file  forKey: [pathOnDisk lastPathComponent]]; 
  RELEASE (file);
}

- (void)registerPathMappings: (NSDictionary *)dict
{
  NSEnumerator *e = [dict keyEnumerator];
  NSString *key;
  
  while ((key = [e nextObject])) 
    {
      NSString *value = [dict objectForKey: key];
      [pathMappings setObject: value  forKey: key];
    }
}

- (NSString *)resolveLink: (NSString *)link
		  logFile: (NSString *)logFile
{
  NSString *fileLink;
  NSString *nameLink;
  NSString *relocatedFileLink;
  DestinationFile *file;

  /* Do nothing if this is evidently *not* a dynamical link to fixup.  */
  if ([link hasPrefix: @"mailto:"] || [link hasPrefix: @"news:"])
    {
      return link;
    }
  
  {
    /* Break the link string into fileLink (everything which is before
       the `#'), and nameLink (everything which is after the `#', `#'
       not included).  For example, if link is
       'NSObject_Class.html#isa', then fileLink is
       'NSObject_Class.html' and nameLink is 'isa'.  */
  
    /* Look for the #.  */
    NSRange hashRange = [link rangeOfString: @"#"];
    
    if (hashRange.location == NSNotFound)
      {
	fileLink = link;
	nameLink = nil;
      }
    else
      {
	fileLink = [link substringToIndex: hashRange.location];

	if (hashRange.location + 1 < [link length])
	  {
	    nameLink = [link substringFromIndex: (hashRange.location + 1)];
	  }
	else
	  {
	    nameLink = nil;
	  }
      }
  }
  
  /* Now lookup fileLink.  */
  
  /* If it's "", it means a reference to something inside the same
     file.  Leave it untouched - no fixup needed.  Normally these
     should not be marked as need linker fixup anyway.  */
  if ([fileLink isEqualToString: @""])
    {
      if (checkLinks)
	{
	  /* FIXME - not really the linker's task, but we might want
	     to add checking of intra-document links.  */
	}
      
      relocatedFileLink = fileLink;
    }
  else
    {
      /* First, extract the path-less filename, because it might have
	 already been fixed up by a previous run of the linker.  */
      fileLink = [fileLink lastPathComponent];
      
      /* Now simply look it up in our list of files.  */
      file = [files objectForKey: fileLink];
      
      /* Not found - leave it unfixed.  */
      if (file == nil)
	{
	  if (verbose || checkLinks)
	    {
	      NSString *m;
	      
	      m = [NSString stringWithFormat: 
			      @"%@: Unresolved reference to file '%@'\n",
			    logFile, fileLink];
	      fprintf (stderr, [m lossyCString]);
	    }
	  
	  relocatedFileLink = fileLink;
	}
      else
	{
	  relocatedFileLink = [file fullName];
	  
	  if (checkLinks)
	    {
	      if (![file checkAnchorName: nameLink])
		{
		  NSString *m;
		  
		  m = [NSString stringWithFormat: 
				  @"%@: Unresolved reference to '%@' in file '%@'\n", 
				logFile, nameLink, fileLink];
		  fprintf (stderr, [m lossyCString]);
		}
	    }
	}
    }
  
  /* Now build up the final relocated link, and return it.  */
  if (nameLink != nil)
    {
      return [NSString stringWithFormat: @"%@#%@", relocatedFileLink, 
		       nameLink];
    }
  else
    {
      return relocatedFileLink;
    }
}

@end

static void print_help_and_exit ()
{
  printf ("GNUstep HTMLLinker (gnustep-base version %d.%d.%d)\n", 
	  GNUSTEP_BASE_MAJOR_VERSION,
	  GNUSTEP_BASE_MINOR_VERSION,
	  GNUSTEP_BASE_SUBMINOR_VERSION);
  printf ("Usage: HTMLLinker [options] input_files [--Destinations destination_files]\n");
  printf (" `options' include:\n");
  printf ("  --help: print this message;\n");
  printf ("  --version: print version information;\n");
  printf ("  -Verbose YES: print verbose messages;\n");
  printf ("  -CheckLinks NO: do not check links as they are fixed up;\n");
  printf ("  -FixupAllLinks YES: attempt to fixup all links (not only dynamical ones);\n");
  printf ("  -PathMappingsFile file: read path mappings from file (a dictionary);\n");
  printf ("  -PathMappings '{\"/usr/doc\"=\"/Doc\";}': use the supplied path mappings;\n");
  exit (0);
}

static void print_version_and_exit ()
{
  printf ("GNUstep HTMLLinker (gnustep-base version %d.%d.%d)\n", 
	  GNUSTEP_BASE_MAJOR_VERSION,
	  GNUSTEP_BASE_MINOR_VERSION,
	  GNUSTEP_BASE_SUBMINOR_VERSION);
  exit (0);
}

int main (int argc, char** argv, char** env)
{
  CREATE_AUTORELEASE_POOL(pool);
  NSUserDefaults *userDefs;
  NSArray *args;
  NSMutableArray *inputFiles;
  unsigned i, count;
  BOOL verbose, checkLinks, fixupAllLinks;
  HTMLLinker *linker;
  BOOL destinations;

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  /* Set up the cache.  */
  fileManager = [NSFileManager defaultManager];
  currentPath = [fileManager currentDirectoryPath];

  /* Read basic defaults.  */
  userDefs = [NSUserDefaults standardUserDefaults];

  /* defaults are - 
     -Verbose NO
     -CheckLinks YES
     -FixupAllLinks NO
  */
  [userDefs registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
					      @"YES", @"CheckLinks", nil]];

  verbose = [userDefs boolForKey: @"Verbose"];
  checkLinks = [userDefs boolForKey: @"CheckLinks"];
  fixupAllLinks = [userDefs boolForKey: @"FixupAllLinks"];

  /* Create the linker object.  */
  linker = [[HTMLLinker alloc] initWithVerboseFlag: verbose
			       checkLinksFlag: checkLinks];

  /*
     To specify that a destination directory on disk is to be referred to
     with a different path, you can use -PathMapping, as in
     
     -PathMapping '{
                "/opt/gnustep/System/Documentation/Base"="/Documentation/Base";
                "/opt/gnustep/System/Documentation/Gui"="/Documentation/Gui";
                }'
		
     which causes all links to destination files which have the path
     beginnig with /opt/gnustep/System/Documentation/Base to be resolved as
     being to files with a path beginning with /Documentation/Base.
     
     This is only useful if you are serving HTML files off from a web server,
     where the actual path on disk is not the same as the path seen by the
     web browser.
     
     -PathMappingFile filename
     
     causes path mappings to be read from filename, which should contain
     them in dictionary format.
  */

  /* Read path mappings from PathMappingsFile if specified.  */
  {
    NSString *pathMapFile = [userDefs stringForKey: @"PathMappingsFile"];
    
    if (pathMapFile != nil)
      {
	NSDictionary *mappings;
	
	mappings = [NSDictionary dictionaryWithContentsOfFile: pathMapFile];
	
	if (mappings == nil)
	  {
	    NSLog (@"Warning - %@ does not contain a dictionary - ignored", 
		   pathMapFile);
	  }
	else
	  {
	    [linker registerPathMappings: mappings];
	  }
      }
  }
  
  /* Add PathMappings specified on the command line if any.  */
  {
    NSDictionary *paths = [userDefs dictionaryForKey: @"PathMappings"];
    
    if (paths != nil)
      {
	[linker registerPathMappings: paths];
      }
  }
  
  /* All non-options on the command line are:
     
     input files if they come before --Destinations
     
     destination files if they come after --Destinations
     
     Directories as input files or destination files means 'all .html, .htm,
     .HTML, .HTM files in the directory and subdirectories'.
     
  */
  args = [[NSProcessInfo processInfo] arguments];

  count = [args count];
  
  destinations = NO;
  inputFiles = AUTORELEASE ([NSMutableArray new]);

  for (i = 1; i < count; i++)
    {
      NSString *arg = [args objectAtIndex: i];
      
      if ([arg hasPrefix: @"--"])
	{
	  if ([arg isEqualToString: @"--help"])
	    {
	      print_help_and_exit ();
	    }
	  else if ([arg isEqualToString: @"--version"])
	    {
	      print_version_and_exit ();
	    }
	  else if ([arg isEqualToString: @"--Destinations"])
	    {
	      /* Next file names to be interpreted as destination
                 files.  */
	      destinations = YES;
	      
	    }
	  else
	    {
	      /* Ignore it for future expansions.  */
	    }
	}
      else if ([arg hasPrefix: @"-"])
	{
	  /* A GNUstep default - skip it and the next argument.  */
	  if ((i + 1) < count)
	    {
	      i++;
	      continue;
	    }
	}
      else
	{
	  if (destinations)
	    {
	      [linker registerFile: arg];
	    }
	  else
	    {
	      BOOL isDir;
	      
	      if (![fileManager fileExistsAtPath: arg
				isDirectory: &isDir])
		{
		  NSLog (@"Warning - input file '%@' not found - ignored", 
			 arg);
		}
	      else
		{
		  if (isDir)
		    {
		      HTMLDirectoryEnumerator *e;
		      NSString *filename;
		      
		      e = [HTMLDirectoryEnumerator alloc];
		      e = [e initWithBasePath: arg];
		      
		      while ((filename = [e nextObject]) != nil)
			{
			  [inputFiles addObject: filename];
			}
		    }
		  else
		    {
		      [inputFiles addObject: arg];
		    }
		}
	    }
	}
    }
  
  count = [inputFiles count];

  if (count == 0)
    {
      NSLog (@"No input files specified.");
    }
  

  for (i = 0; i < count; i++)
    {
      NSString *inputFile;
      NSString *inputFileContents;
      HTMLParser *parser;

      inputFile = [inputFiles objectAtIndex: i];
      inputFileContents = [NSString stringWithContentsOfFile: inputFile];
      
      parser = [[HTMLParser alloc] initWithCode: inputFileContents];
      inputFileContents = [parser resolveLinksUsingHTMLLinker: linker
				  logFile: inputFile
				  fixupAllLinks: fixupAllLinks];
      [inputFileContents writeToFile: inputFile
			 atomically: YES];
      RELEASE (parser);
    }

  RELEASE (linker);
  RELEASE (pool);

  return 0;
}
