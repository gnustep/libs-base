/* Implementation of NSBundle class
 *
 * Copyright (C)  1993  The Board of Trustees of  
 * The Leland Stanford Junior University.  All Rights Reserved.
 *
 * Authors: Adam Fedor, Scott Francis, Fred Harris, Paul Kunz, Tom Pavel, 
 *	    Imran Qureshi, and Libing Wang
 *
 * This file is part of an Objective-C class library 
 *
 * NSBundle.m,v 1.8 1993/10/20 00:44:53 pfkeb Exp
 */

#include <stdio.h>
#include <assert.h>
#include <unistd.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <objc/objc-api.h>
#include <objects/objc-load.h>
#include <foundation/NSBundle.h>
#include "NSObjectPrivate.h"
#include <foundation/NSException.h>
#include <foundation/NSString.h>
#include <foundation/NSArray.h>

#ifndef index
#define index strchr
#define rindex strrchr
#endif

#ifndef FREE_OBJECT
#define FFREE_OBJECT(id) ([id release],id=nil)
#define  FREE_OBJECT(id) (id?FFREE_OBJECT(id):nil)
#endif

/* This is the extension that NSBundle expect on all bundle names */
#define BUNDLE_EXT	"bundle"

/* By default, we transmorgrify extensions of type "nib" to type "xmib"
   which is the common extension for IB files for the GnuStep project
*/
#define IB_EXT		"xmib"

/* Class variables - We keep track of all the bundles and all the classes
   that are in each bundle
*/
static NSBundle 	*_mainBundle = nil;
static NSMutableArray	*_bundles = nil;
static NSMutableArray	*_bundleClasses = nil;

/* List of language preferences */
static NSArray   *_languages = nil;

/* When we are linking in an object file, objc_load_modules calls our
   callBack routine for every Class and Category loaded.  The following
   variable stores the bundle that is currently doing the loading so we know
   where to store the class names.  This is way non-thread-safe, but
   apparently this is how NeXT does it (maybe?).
*/
static int _loadingBundlePos = -1;

static BOOL _stripAfterLoading;

/* Get the object file that should be located in the bundle of the same name */
static NSString *
object_name(NSString *path)
{
    NSString *name;
    name = [[path lastPathComponent] stringByDeletingPathExtension];
    name = [path stringByAppendingPathComponent:name];
    return name;
} 

/* Construct a path from the directory, language, name and extension.  Used by 
    pathForResource:...
*/
static NSString *nib;
static NSString *xmib;

static NSString * 
construct_path(NSString *path, NSString *lang, 
	NSString *name, NSString *ext )
{
    NSString *fullpath;
    
    name = [name stringByDeletingPathExtension];
    if ([ext compare:nib] == NSOrderedSame)
    	ext = xmib;
// FIXME: change when NSString can support %@ parameters
    if (lang) {
	fullpath = [NSString stringWithFormat:
		TEMP_STRING("%s/%s.lproj/%s.%s"), [path cString], 
			[lang cString], [name cString], [ext cString]];
    } else {
	fullpath = [NSString stringWithFormat:
		TEMP_STRING("%s/%s.%s"), [path cString], 
			[name cString], [ext cString]];
    }
/*
    if (lang) {
	fullpath = [NSString stringWithFormat:
		TEMP_STRING("%@/%@.lproj/%@.%@"), path, lang, name, ext];
    } else {
	fullpath = [NSString stringWithFormat:
		TEMP_STRING("%@/%@.%@"), path, name, ext];
    }
*/
#ifdef DEBUG
    fprintf(stderr, "Debug (NSBundle): path is %s\n", [fullpath cString]);
#endif
    return fullpath;
}

void
_bundle_load_callback(Class *theClass, Category *theCategory)
{
    /* Don't store categories */
    assert(_loadingBundlePos >= 0);
    if (!theCategory)
        [[_bundleClasses objectAtIndex:_loadingBundlePos] 
			addObject:(id)theClass];
}


@implementation NSBundle

+ (void)initialize
{
    nib = STATIC_STRING("nib");
    xmib = STATIC_STRING("xmib");
}

+ (NSBundle *)mainBundle
{
    if ( !_mainBundle ) {
	NSString *path;

	path = [NSString stringWithCString:objc_executable_location()];
	/* Strip off the name of the program */
	path = [path stringByDeletingLastPathComponent];
	if (!path || [path length] == 0) {
	    fprintf(stderr, "Error (NSBundle): Cannot find main bundle.\n");
	    return nil;
	}

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
		format:TEMP_STRING("No path specified for bundle")];
	/* NOT REACHED */
    }

    if (stat([path cString], &statbuf) != 0) {
    	[NSException raise:NSGenericException
		format:TEMP_STRING("Path does not exist")];
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
    Class   *theClass = Nil;
    if (!_codeLoaded) {
	if (self != _mainBundle && ![self principalClass]) {
    	    [NSException raise:NSGenericException
		format:TEMP_STRING("Unable to get classes")];
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
	NSString *object = object_name(_path);
	/* Link in the object file */
	_loadingBundlePos = [_bundles indexOfObject:self];
	if (objc_load_module([object cString], 
		stderr, _bundle_load_callback, NULL, NULL)) {
    	    [NSException raise:NSGenericException
		format:TEMP_STRING("Unable to load module")];
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
		format:TEMP_STRING("No resource name specified.")];
	/* NOT REACHED */
    }

    if (_languages) {
	unsigned i, count;
	count = [_languages count];
	for (i=0; i < count; i++) {
    	    path = construct_path(bundlePath, [_languages objectAtIndex:i], 
	    		name, ext );
    	    if ( stat([path cString], &statbuf) == 0) 
		break;
	    path = nil;
	    count++;
	}
    } else {
    	path = construct_path(bundlePath, TEMP_STRING("English"), name, ext );
    	if ( stat([path cString], &statbuf) != 0) {
	    path = nil;
	}

    }

    if (!path) {
	path = construct_path(bundlePath, nil, name, ext );
	if ( stat([path cString], &statbuf) != 0) {
	    path = nil;
	}
    }

    /* Note: path is already autoreleased */
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
    static NSString *separator;
    if (!separator) separator = STATIC_STRING(" ");
    if (_languages) {
    	FREE_OBJECT(_languages);
    }
	
    /* If called with a nil array, look in the environment for the
       language list. The languages should separated by the "separator"
       string.
    */
    if (!languages) {
        NSString *env = [NSString stringWithCString:getenv("LANGUAGE")];
	if (env && [env length] != 0)
            _languages = [[env componentsSeparatedByString:separator] retain];
    } else
    	_languages = [languages retain];

}

// FIXME: this is here to please IndexedCollection - NSObject doesn't have it
- (int)compare:anotherObject
{
  if ([self isEqual:anotherObject])
    return 0;
  // Ordering objects by their address is pretty useless,
  // so subclasses should override this is some useful way.
  else if (self > anotherObject)
    return 1;
  else
    return -1;

}

@end
