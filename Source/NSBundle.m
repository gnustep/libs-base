/* Implementation of NSBundle class
   Copyright (C) 1993,1994,1995, 1996 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: May 1993

   This file is part of the Gnustep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

*/

#include <assert.h>

#ifndef WIN32
#include <unistd.h>
#include <sys/param.h>		/* Needed by sys/stat */
#endif

#include <sys/stat.h>
#include <objc/objc-api.h>
#include <gnustep/base/preface.h>
#include <Foundation/objc-load.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSProcessInfo.h>

/* Deal with strchr: */
#if STDC_HEADERS || HAVE_STRING_H
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && HAVE_MEMORY_H
#include <memory.h>
#endif /* not STDC_HEADERS and HAVE_MEMORY_H */
#define rindex strrchr
#define index strchr
#define bcopy(s, d, n) memcpy ((d), (s), (n))
#define bcmp(s1, s2, n) memcmp ((s1), (s2), (n))
#define bzero(s, n) memset ((s), 0, (n))
#else /* not STDC_HEADERS and not HAVE_STRING_H */
#include <strings.h>
/* memory.h and strings.h conflict on some systems.  */
#endif /* not STDC_HEADERS and not HAVE_STRING_H */

#ifndef FREE_OBJECT
#define FFREE_OBJECT(id) ([id release],id=nil)
#define  FREE_OBJECT(id) (id?FFREE_OBJECT(id):nil)
#endif

/* This is the extension that NSBundle expect on all bundle names */
#define BUNDLE_EXT	"bundle"

/* By default, we transmorgrify extensions of type "nib" to type "xmib"
   which is the common extension for IB files for the GNUStep project
*/
static NSString *bundle_nib_ext  = @"nib";
static NSString *bundle_xmib_ext = @"xmib";

/* Class variables - We keep track of all the bundles and all the classes
   that are in each bundle
*/
static NSBundle 	*_mainBundle = nil;
static NSMutableArray	*_bundles = nil;
static NSMutableArray	*_bundleClasses = nil;

/* List of language preferences */
static NSArray   *_languages = nil;

/* When we are linking in an object file, objc_load_modules calls our
   callback routine for every Class and Category loaded.  The following
   variable stores the bundle that is currently doing the loading so we know
   where to store the class names. 
   FIXME:  This should be put into a NSThread dictionary
*/
static int _loadingBundlePos = -1;

static BOOL _stripAfterLoading;

/* Declaration from find_exec.c */
extern char *objc_find_executable(const char *name);

/* This function is provided for objc-load.c, although I'm not sure it
   really needs it (So far only needed if using GNU dld library) */
const char *
objc_executable_location( void )
{
  return [[[NSBundle mainBundle] bundlePath] cString];
}

/* Get the object file that should be located in the bundle of the same name */
static NSString *
bundle_object_name(NSString *path)
{
    NSString *name;
#if 0
    /* FIXME: This will work when NSString is fully implemented */
    name = [[path lastPathComponent] stringByDeletingPathExtension];
    name = [path stringByAppendingPathComponent:name];
    return name;
#else
#define BASENAME(str)   ((rindex(str, '/')) ? rindex(str, '/')+1 : str)
    char *s;
    char *output;
    OBJC_MALLOC(output, char, strlen(BASENAME([path cString]))+20);
    strcpy(output, BASENAME([path cString]));
    s = rindex(output, '.');
    if (s)
	*s = '\0';
    name =  [NSString stringWithFormat:@"%s/%s", [path cString], output];
    OBJC_FREE(output);
#endif
    return name;
} 

/* Construct a path from the directory, language, name and extension.  Used by 
    pathForResource:...
*/
static NSString * 
bundle_resource_path(NSString *path, NSString *lang, NSString *name, 
	NSString *ext )
{
    NSString *fullpath;
    NSString *name_ext;
    
#if 0
    /* FIXME: This will work when NSString is fully implemented */
    name_ext = [name pathExtension];
    name = [name stringByDeletingPathExtension];
#else
    char *s;
    char *output;
    OBJC_MALLOC(output, char, strlen([name cString])+1);
    strcpy(output, [name cString]);
    s = rindex(output, '.');
    if (s) 
      {
	*s = '\0';
	name_ext = [NSString stringWithCString:(s+1)];
      }
    else
	name_ext = nil;
    name = [NSString stringWithCString:output];
    OBJC_FREE(output);
#endif
    // FIXME: we could check to see if name_ext and ext match, but what
    //        would we do if they didn't?
    if (!ext)
	ext = name_ext;
    if ([ext isEqual:bundle_nib_ext])
    	ext = bundle_xmib_ext;
#if 0
    /* FIXME: This will work when NSString is fully implemented */
    if (lang) {
	fullpath = [NSString stringWithFormat: @"%@/%@.lproj/%@", 
			path, lang, name];
    } else {
	fullpath = [NSString stringWithFormat: @"%@/%@", path, name];
    }
    if (ext && [ext length] != 0)
	fullpath = [NSString stringByAppendingPathExtension:ext];
#else
    if (lang) {
	fullpath = [NSString stringWithFormat: @"%s/%s.lproj/%s", 
			[path cString], [lang cString], [name cString]];
    } else {
	fullpath = [NSString stringWithFormat: @"%s/%s", 
			[path cString], [name cString]];
    }
    if (ext && [ext length] != 0) 
	fullpath = [NSString stringWithFormat:@"%s.%s",
			[fullpath cString], [ext cString]];
#endif

#ifdef DEBUG
    fprintf(stderr, "Debug (NSBundle): path is %s\n", [fullpath cString]);
#endif
    return fullpath;
}

void
_bundle_load_callback(Class theClass, Category *theCategory)
{
    /* Don't store categories */
    assert(_loadingBundlePos >= 0);
    if (!theCategory)
        [[_bundleClasses objectAtIndex:_loadingBundlePos] 
			addObject:(id)theClass];
}

@implementation NSBundle

+ (NSBundle *)mainBundle
{
    if ( !_mainBundle ) {
	char *s;
	char *output;
	NSString *path;

	path = [[NSProcessInfo processInfo] processName];
	output = objc_find_executable([path cString]);
	assert(output);
	path = [NSString stringWithCString: output];
	OBJC_FREE(output);

	/* Strip off the name of the program */
#if 0
	/* FIXME: Should work when NSString is implemented */
	path = [path stringByDeletingLastPathComponent];
#else
	OBJC_MALLOC(output, char, strlen([path cString])+1);
	strcpy(output, [path cString]);
	s = rindex(output, '/');
	if (s && s != output) {*s = '\0';}
	path =  [NSString stringWithCString:output];
	OBJC_FREE(output);
#endif

/* Construct a path from the directory, language, name and extension.  
   Used by  */

#ifdef DEBUG
	fprintf(stderr, "Debug (NSBundle): Found main in %s\n", 
		[path cString]);
#endif
	/* We do alloc and init separately so initWithPath: does not
	   add us to the _bundles list
	*/
	_mainBundle = [NSBundle alloc];
	_mainBundle = [_mainBundle initWithPath:path];
    }
    return _mainBundle;
}

/* Due to lazy evaluation, we will not find a class if a either classNamed: or
   principalClass has not been called on the particular bundle that contains
   the class. (FIXME)
*/
+ (NSBundle *)bundleForClass:aClass
{
    int		i, count;
    NSBundle	*bundle = nil;

    // FIXME: should this be an error if aClass == nil?
    if (!aClass)
	return nil;

    count = [_bundleClasses count];
    for (i=0; i < count; i++) {
        int 	j, class_count;
    	NSArray *classList = [_bundleClasses objectAtIndex:i];
	class_count = [classList count];
	for (j = 0; j < class_count; j++) 
	    if ([aClass isEqual:[classList objectAtIndex:j]]) {
	        bundle = [_bundles objectAtIndex:i];
		break;
	}
	if (bundle)
	    break;
    }
    if (!bundle) {
	/* Is it in the main bundle? */
	if (class_is_class(aClass))
	    bundle = [NSBundle mainBundle];
    }

    return bundle;
}

+ (NSBundle *)bundleWithPath:(NSString *)path
{
    return [[[NSBundle alloc] initWithPath:path] autorelease];
}

- initWithPath:(NSString *)path;
{
    struct stat statbuf;
    [super init];

    if (!_languages)
	[[self class] setSystemLanguages:NULL];

    if (!path || [path length] == 0) {
    	[NSException raise:NSInvalidArgumentException
		format:@"No path specified for bundle"];
	/* NOT REACHED */
    }

   /* Check if we were already initialized for this directory */
    if (_bundles) {
        int i;
        int count;
        count = [_bundles count];
        for (i=0; i < count; i++) {
            if ([path isEqual:[[_bundles objectAtIndex:i] bundlePath]])
                return [_bundles objectAtIndex:i];
        }
    }

    if (stat([path cString], &statbuf) != 0) {
    	[NSException raise:NSGenericException
		format:@"Could not find path %s", [path cString]];
	/* NOT REACHED */
    }
    _path = [path retain];

    if (self == _mainBundle)
	return self;

    if (!_bundles) {
        _bundles = [[NSMutableArray arrayWithCapacity:2] retain];
	_bundleClasses = [[NSMutableArray arrayWithCapacity:2] retain];
    }
    [_bundles addObject:self];
    [_bundleClasses addObject:[[NSMutableArray arrayWithCapacity:0] retain]];

    return self;
}

/* We can't really unload the module, since objc_unload_module has
   no idea where we were loaded from, so we just dealloc everything and
   don't worry about it.
*/
- (void)dealloc
{
    int pos = [_bundles indexOfObject:self];

    if (pos >= 0) {
    	[_bundleClasses removeObjectAtIndex:pos]; 
    	[_bundles removeObjectAtIndex:pos];
    }
    FREE_OBJECT(_path);
    [super dealloc];
}

- (NSString *)bundlePath
{
    return _path;
}

- classNamed:(NSString *)className
{
    int     j, class_count;
    NSArray *classList;
    Class   theClass = Nil;
    if (!_codeLoaded) {
	if (self != _mainBundle && ![self principalClass]) {
    	    [NSException raise:NSGenericException
		format:@"No classes in bundle"];
	    /* NOT REACHED */
    	}
    }

    if (self == _mainBundle) {
	theClass = objc_lookup_class([className cString]);
	if (theClass && [[self class] bundleForClass:theClass] != _mainBundle)
	    theClass = Nil;
    } else {
    	classList = [_bundleClasses objectAtIndex: 
			[_bundles indexOfObject:self]];
    	class_count = [classList count];
    	for (j = 0; j < class_count; j++) {
	    theClass = [classList objectAtIndex:j];
	    if ([theClass isEqual:objc_lookup_class([className cString])]) {
	        break;
	    }
	    theClass = Nil;
    	}
    }

    return theClass;
}

- principalClass
{
    NSArray *classList;
    if (self == _mainBundle) {
	_codeLoaded = YES;
	return nil;	// the mainBundle does not have a principal class
    }

    if (!_codeLoaded) {
	NSString *object = bundle_object_name(_path);
	/* Link in the object file */
	_loadingBundlePos = [_bundles indexOfObject:self];
	if (objc_load_module([object cString], 
		stderr, _bundle_load_callback, NULL, NULL)) {
    	    [NSException raise:NSGenericException
		format:@"Unable to load module %s", [object cString]];
	    /* NOT REACHED */
	} else
	    _codeLoaded = YES;
	_loadingBundlePos = -1;
    }

    classList =  [_bundleClasses objectAtIndex:[_bundles indexOfObject:self]];
    if ([classList count])
        return [classList objectAtIndex:0];
    else
	return nil;
}

- (NSString *)pathForResource:(NSString *)name
		ofType:(NSString *)ext;
{
    return [[self class] pathForResource:name
           	  ofType:ext 
	     inDirectory: _path 
	     withVersion: 0];
}

+ (NSString *)pathForResource:(NSString *)name
		ofType:(NSString *)ext	
		inDirectory:(NSString *)bundlePath
		withVersion:(int)version;
{
    struct stat statbuf;
    NSString *path = nil;
    
    if (!name || [name length] == 0) {
    	[NSException raise:NSInvalidArgumentException
		format:@"No resource name specified."];
	/* NOT REACHED */
    }

    if (_languages) {
	unsigned i, count;
	count = [_languages count];
	for (i=0; i < count; i++) {
    	    path = bundle_resource_path(bundlePath, 
			[_languages objectAtIndex:i], name, ext );
    	    if ( stat([path cString], &statbuf) == 0) 
		break;
	    path = nil;
	}
    } else {
    	path = bundle_resource_path(bundlePath, @"English", name, ext );
    	if ( stat([path cString], &statbuf) != 0) {
	    path = nil;
	}

    }

    if (!path) {
	path = bundle_resource_path(bundlePath, nil, name, ext );
	if ( stat([path cString], &statbuf) != 0) {
	    path = nil;
	}
    }

    return path;
}

+ (void)stripAfterLoading:(BOOL)flag
{
    _stripAfterLoading = flag;
}

- (NSString *)localizedStringForKey:(NSString *)key	
		value:(NSString *)value
		table:(NSString *)tableName
{
     [self notImplemented:_cmd];
     return 0;
}

- (unsigned)bundleVersion
{
    return _bundleVersion;
}

- (void)setBundleVersion:(unsigned)version
{
    _bundleVersion = version;
}

+ (void)setSystemLanguages:(NSArray *)languages
{
    // static NSString *separator = @" ";

    if (_languages) {
    	FREE_OBJECT(_languages);
    }
	
    /* If called with a nil array, look in the environment for the
       language list. The languages should separated by the "separator"
       string.
    */
    if (!languages) {
	const char *env_list;
        // NSString *env;
        env_list = getenv("LANGUAGES");
	if (env_list) {
#if 0
    	    /* FIXME: This will work when NSString is fully implemented */
            env = [NSString stringWithCString:e];
            _languages = [[env componentsSeparatedByString:separator] retain];
#else
	    /* Just pick out the first one */
	    char *s;
	    s = index(env_list, ' ');
	    if (s)
		*s = '\0';
            _languages = [[NSString stringWithCString:env_list] retain];
#endif
	}
    } else
    	_languages = [languages retain];

}

@end
