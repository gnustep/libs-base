/** Interface for NSBundle for GNUStep   -*-objc-*-
   Copyright (C) 1995, 1997, 1999, 2001, 2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: 1995

   Updates by various authors.
   Documentation by Nicola Pero <n.pero@mi.flashnet.it>
  
   This file is part of the GNUstep Base Library.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
  */

#ifndef __NSBundle_h_GNUSTEP_BASE_INCLUDE
#define __NSBundle_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>

@class NSString;
@class NSArray;
@class NSDictionary;
@class NSMutableDictionary;

GS_EXPORT NSString* NSBundleDidLoadNotification;
GS_EXPORT NSString* NSShowNonLocalizedStrings;
GS_EXPORT NSString* NSLoadedClasses;

/**
   <p>
   NSBundle provides methods for locating and handling application (and tool)
   resources at runtime. Resources includes any time of file that the
   application might need, such as images, nib (gorm or gmodel) files,
   localization files, and any other type of file that an application
   might need to use to function. Resources also include executable
   code, which can be dynamically linked into the application at
   runtime. These files and executable code are commonly put together
   into a directory called a bundle.
   </p>
   <p>
   NSBundle knows how these bundles are organized and can search for
   files inside a bundle. NSBundle also handles locating the
   executable code, linking this in and initializing any classes that
   are located in the code. NSBundle also handles Frameworks, which are
   basically a bundle that contains a library archive. The
   organization of a framework is a little difference, but in most
   respects there is no difference between a bundle and a framework.
   </p>
   <p>
   There is one special bundle, called the mainBundle, which is
   basically the application itself. The mainBundle is always loaded
   (of course), but you can still perform other operations on the
   mainBundle, such as searching for files, just as with any other
   bundle.
   </p>
*/
@interface NSBundle : NSObject
{
  NSString	*_path;
  NSArray	*_bundleClasses;
  Class		_principalClass;
  NSDictionary	*_infoDict;
  NSMutableDictionary	*_localizations;
  unsigned	_bundleType;
  BOOL		_codeLoaded;
  unsigned	_version;
  NSString      *_frameworkVersion;
}

/** Return an array enumerating all the bundles in the application.  This
 *  does not include frameworks.  */
+ (NSArray*) allBundles;

/** Return an array enumerating all the frameworks in the application.  This
 *  does not include normal bundles.  */
+ (NSArray*) allFrameworks;

/**
 * <p>Return the bundle containing the resources for the executable.  If
 * the executable is an application, this is the main application
 * bundle (the xxx.app directory); if the executable is a tool, this
 * is a bundle 'naturally' associated with the tool: if the tool
 * executable is xxx/Tools/ix86/linux-gnu/gnu-gnu-gnu/Control then the
 * tool's main bundle directory is xxx/Tools/Resources/Control.
 * </p>
 * <p>NB: traditionally tools didn't have a main bundle -- this is a recent
 * GNUstep extension, but it's quite nice and it's here to stay.
 * </p>
 * <p>The main bundle is where the application should put all of its
 * resources, such as support files (images, html, rtf, txt, ...),
 * localization tables, .gorm (.nib) files, etc.  gnustep-make
 * (/ProjectCenter) allows you to easily specify the resource files to
 * put in the main bundle when you create an application or a tool.
 * </p>
 */
+ (NSBundle*) mainBundle;

/**
 * <p>Return the bundle to which aClass belongs.  If aClass was loaded
 * from a bundle, return the bundle; if it belongs to a framework
 * (either a framework linked into the application, or loaded
 * dynamically), return the framework; in all other cases, return the
 * main bundle.
 * </p>
 * <p>Please note that GNUstep supports plain shared libraries, while the
 * openstep standard, and other openstep-like systems, do not; the
 * behaviour when aClass belongs to a plain shared library is at the
 * moment still under investigation -- you should consider it
 * undefined since it might be changed. :-)
 * </p>
 */
+ (NSBundle*) bundleForClass: (Class)aClass;

/** Return a bundle for the path at path.  If path doesn't exist or is
 * not readable, return nil.  If you want the main bundle of an
 * application or a tool, it's better if you use +mainBundle.  */
+ (NSBundle*) bundleWithPath: (NSString*)path;

/**
  Returns an absolute path for a resource name with the extension
  ext in the specified bundlePath.  See also
  -pathForResource:ofType:inDirectory: for more information on
  searching a bundle.  
 */
+ (NSString*) pathForResource: (NSString*)name
		       ofType: (NSString*)ext
		  inDirectory: (NSString*)bundlePath;

/**
  This method has been depreciated. Version numbers were never implemented
  so this method behaves exactly like +pathForResource:ofType:inDirectory:.
 */
+ (NSString*) pathForResource: (NSString*)name
		       ofType: (NSString*)ext
		  inDirectory: (NSString*)bundlePath
		  withVersion: (int)version;

/** <init />
 * Init the bundle for reading resources from path.  path must be an
 * absolute path to a directory on disk.  If path is nil or doesn't
 * exist, initWithPath: returns nil.  If a bundle for that path
 * already existed, it is returned in place of the receiver (and the
 * receiver is deallocated).
 */
- (id) initWithPath: (NSString*)path;

/** Return the path to the bundle - an absolute path.  */
- (NSString*) bundlePath;

/** Returns the class in the bundle with the given name. If no class
    of this name exists in the bundle, then Nil is returned.
 */
- (Class) classNamed: (NSString*)className;

/** Returns the principal class of the bundle. This is the class
    specified by the NSPrincipalClass key in the Info-gnustep property
    list contained in the bundle. If this key is not found, the
    class returned is arbitrary, although it is typically the first
    class compiled into the archive.
 */
- (Class) principalClass;

+ (NSArray*) pathsForResourcesOfType: (NSString*)extension
			 inDirectory: (NSString*)bundlePath;

/**
  <p>
   Returns an array of paths for all resources with the specified
   extension and residing in the bundlePath directory. If extension is
   nil or empty, all bundle resources are returned.
   </p>
 */
- (NSArray*) pathsForResourcesOfType: (NSString*)extension
			 inDirectory: (NSString*)bundlePath;

/**
  <p>
   Returns an absolute path for a resource name with the extension ext
   in the specified bundlePath. Directories in the bundle are searched
   in the following order:
   </p>
   <example>
     root path/Resources/bundlePath
     root path/Resources/bundlePath/"language.lproj"
     root path/bundlePath
     root path/bundlePath/"language.lproj"
   </example>
   <p>
   where lanuage.lproj can be any localized language directory inside
   the bundle.
   </p>
   <p>
   If ext is nil or empty, then the first file with name and any
   extension is returned.
   </p>
*/
- (NSString*) pathForResource: (NSString*)name
		       ofType: (NSString*)ext
		  inDirectory: (NSString*)bundlePath;

/**
   Returns an absolute path for a resource name with the extension ext
   in the receivers bundle path. 
   See -pathForResource:ofType:inDirectory:.
 */
- (NSString*) pathForResource: (NSString*)name
		       ofType: (NSString*)ext;

/**
   Returns the value for the key found in the strings file tableName,
   or Localizable.strings if tableName is nil.
 */
- (NSString*) localizedStringForKey: (NSString*)key
			      value: (NSString*)value
			      table: (NSString*)tableName;

/** Returns the absolute path to the resources directory of the bundle.  */
- (NSString*) resourcePath;

/** Returns the bundle version. */
- (unsigned) bundleVersion;

/** Set the bundle version */
- (void) setBundleVersion: (unsigned)version;

#ifndef STRICT_OPENSTEP
+ (NSArray *) preferredLocalizationsFromArray: (NSArray *)localizationsArray;
+ (NSArray *) preferredLocalizationsFromArray: (NSArray *)localizationsArray 
			       forPreferences: (NSArray *)preferencesArray;

- (NSArray*) pathsForResourcesOfType: (NSString*)extension
			 inDirectory: (NSString*)bundlePath
		     forLocalization: (NSString*)localizationName;
- (NSString*) pathForResource: (NSString*)name
		       ofType: (NSString*)ext
		  inDirectory: (NSString*)bundlePath
	      forLocalization: (NSString*)localizationName;

/** Returns the info property list associated with the bundle. */
- (NSDictionary*) infoDictionary;

/** Returns a localized info property list based on the preferred
    localization or the most appropriate localization if the preferred
    one cannot be found.
*/
- (NSDictionary *)localizedInfoDictionary;

/** Returns all the localizations in the bundle. */
- (NSArray *)localizations;

/** Returns the list of localizations that the bundle uses to search
    for information. This is based on the user's preferences.
*/
- (NSArray *)preferredLocalizations;

/** Loads any executable code contained in the bundle into the
    application. Load will be called implicitly if any information
    about the bundle classes is requested, such as -principalClass or
    -classNamed:. 
 */
- (BOOL) load;

/** Returns the path to the executable code in the bundle */
- (NSString *)executablePath;
#endif

@end

#ifndef	 NO_GNUSTEP
@interface NSBundle (GNUstep)

/** This method is an experimental GNUstep extension, and
 *  might change.  At the moment, search on the standard GNUstep
 *  directories (starting from GNUSTEP_USER_ROOT, and going on to
 *  GNUSTEP_SYSTEM_ROOT) for a directory
 *  Libraries/Resources/'libraryName'/.
 */
+ (NSBundle *) bundleForLibrary: (NSString *)libraryName;

+ (NSString *) _absolutePathOfExecutable: (NSString *)path;
+ (NSString*) _gnustep_target_cpu;
+ (NSString*) _gnustep_target_dir;
+ (NSString*) _gnustep_target_os;
+ (NSString*) _library_combo;
+ (NSBundle*) gnustepBundle;
+ (NSString*) pathForGNUstepResource: (NSString*)name
			      ofType: (NSString*)ext
			 inDirectory: (NSString*)bundlePath;

@end

/** Warning - the following should never be used.  */
#define GSLocalizedString(key, comment) \
  [[NSBundle gnustepBundle] localizedStringForKey:(key) value:@"" table:nil]
#define GSLocalizedStringFromTable(key, tbl, comment) \
  [[NSBundle gnustepBundle] localizedStringForKey:(key) value:@"" table:(tbl)]

#endif /* GNUSTEP */

/**
 * <p>
 *   This function (macro) is used to get the localized
 *   translation of the string <code>key</code>.
 *   <code>key</code> is looked up in the
 *   <code>Localizable.strings</code> file for the current
 *   language.  The current language is determined by the
 *   available languages in which the application is
 *   translated, and by using the <code>NSLanguages</code> user
 *   defaults (which should contain an array of the languages
 *   preferred by the user, in order of preference).
 * </p>
 * <p>
 *   Technically, the function works by calling
 *   <code>localizedStringForKey:value:table:</code> on the
 *   main bundle, using <code>@""</code> as value, and
 *   <code>nil</code> as the table.  The <code>comment</code>
 *   is ignored when the macro is expanded; but when we have
 *   tools which can generate the
 *   <code>Localizable.strings</code> files automatically from
 *   source code, the <code>comment</code> will be used by the
 *   tools and added as a comment before the string to
 *   translate.  Upon finding something like
 * </p>
 * <p>
 *   <code>
 *      NSLocalizedString (@"My useful string",
 *        @"My useful comment about the string");
 *   </code>
 * </p>
 * <p>
 *   in the source code, the tools will generate a comment and the line
 * </p>
 * <p>
 *   <code>
 *      " My useful string" = "My useful string";
 *   </code>
 * </p>
 * <p>
 *   in the <code>Localizable.strings</code> file (the
 *   translator then can use this as a skeleton for the
 *   <code>Localizable.strings</code> for his/her own language,
 *   where she/he can replace the right hand side with the
 *   translation in her/his own language).  The comment can
 *   help the translator to decide how to translate when it is
 *   not clear how to translate (because the original string is
 *   now out of context, and out of context might not be so
 *   clear what the string means).  The comment is totally
 *   ignored by the library code.
 * </p>
 * <p>
 *   If you don't have a comment (because the string is so
 *   self-explanatory that it doesn't need it), you can leave
 *   it blank, by using <code>@""</code> as a comment.  If the
 *   string might be unclear out of context, it is recommended
 *   that you add a comment (even if it is unused for now).
 * </p>
 */
#define NSLocalizedString(key, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]

/**
 * This function (macro) does the same as
 * <code>NSLocalizedString</code>, but uses the table
 * <code>table</code> rather than the default table.  This
 * means that the string to translate will be looked up in a
 * different file than <code>Localizable.strings</code>.  For
 * example, if you pass <code>DatabaseErrors</code> as the
 * <code>table</code>, the string will be looked up for
 * translation in the file
 * <code>DatabaseErrors.strings</code>.  This allows you to
 * have the same string translated in different ways, by
 * having a different translation in different tables, and
 * choosing between the different translation by choosing a
 * different table.
 */
#define NSLocalizedStringFromTable(key, tbl, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:(tbl)]

/**
 * This function is the full-blown localization function (it
 * is actually a macro).  It looks up the string
 * <code>key</code> for translation in the table
 * <code>table</code> of the bundle <code>bundle</code>
 * (please refer to the NSBundle documentation for more
 * information on how this lookup is done).
 * <code>comment</code> is a comment, which is ignored by the
 * library (it is discarded when the macro is expanded) but which
 * can be used by tools which parse the source code and generate
 * strings table to provide a comment which the translator can
 * use when translating the string.
 */
#define NSLocalizedStringFromTableInBundle(key, tbl, bundle, comment) \
  [bundle localizedStringForKey:(key) value:@"" table:(tbl)]

#ifndef	NO_GNUSTEP
#define NSLocalizedStringFromTableInFramework(key, tbl, fpth, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" \
  table: [bundle pathForGNUstepResource:(tbl) ofType: nil inDirectory: (fpth)]
#endif /* GNUSTEP */

  /* Now Support for Quick Localization */
#ifndef NO_GNUSTEP

  /* The quickest possible way to localize a string:
    
     NSLog (_(@"New Game"));
    
     Please make use of the longer functions taking a comment when you
     get the time to localize seriously your code.
  */

/**
 * <p>
 *   This function (macro) is a GNUstep extension.
 * </p>
 * <p>
 *   <code>_(@"My string to translate")</code>
 * </p>
 * <p>
 *   is exactly the same as
 * </p>
 * <p>
 *   <code>NSLocalizedString (@"My string to translate", @"")</code>
 * </p>
 * <p>
 *   It is useful when you need to translate an application
 *   very quickly, as you just need to enclose all strings
 *   inside <code>_()</code>.  But please note that when you
 *   use this macro, you are not taking advantage of comments
 *   for the translator, so consider using
 *   <code>NSLocalizedString</code> instead when you need a
 *   comment.
 * </p>
 */
#define _(X) NSLocalizedString (X, @"")
 
  /* The quickest possible way to localize a static string:
    
     static NSString *string = __(@"New Game");
    
     NSLog (_(string)); */
 
/**
 * <p>
 *   This function (macro) is a GNUstep extension.
 * </p>
 * <p>
 *   <code>__(@"My string to translate")</code>
 * </p>
 * <p>
 *   is exactly the same as
 * </p>
 * <p>
 *   <code>NSLocalizedStaticString (@"My string to translate", @"")</code>
 * </p>
 * <p>
 *   It is useful when you need to translate an application very
 *   quickly.  You would use it as follows for static strings:
 * </p>
 * <p>
 *  <code>
 *    NSString *message = __(@"Hello there");
 
 *    ... more code ...
 
 *    NSLog (_(messages));
 *  </code>
 * </p>
 * <p>
 *   But please note that when you use this macro, you are not
 *   taking advantage of comments for the translator, so
 *   consider using <code>NSLocalizedStaticString</code>
 *   instead when you need a comment.
 * </p>
 */
#define __(X) X

  /* The better way for a static string, with a comment - use as follows -

     static NSString *string = NSLocalizedStaticString (@"New Game",
                                                        @"Menu Option");

     NSLog (_(string));

     If you need anything more complicated than this, please initialize
     the static strings manually.
*/

/**
 * <p>
 *   This function (macro) is a GNUstep extensions, and it is used
 *   to localize static strings.  Here is an example of a static
 *   string:
 * </p>
 * <p>
 *   <code>
 *     NSString *message = @"Hi there";
 
 *     ... some code ...
 
 *     NSLog (message);
 *  </code>
 * </p>
 * <p>
 *   This string can not be localized using the standard
 *   openstep functions/macros.  By using this gnustep extension,
 *   you can localize it as follows:
 * </p>
 * <p>
 *   <code>
 *     NSString *message = NSLocalizedStaticString (@"Hi there",
 *       @"Greeting");
 * 
 *     ... some code ...
 * 
 *     NSLog (NSLocalizedString (message, @""));
 *  </code>
 * </p>
 * <p>
 *   When the tools generate the
 *   <code>Localizable.strings</code> file from the source
 *   code, they will ignore the <code>NSLocalizedString</code>
 *   call while they will extract the string (and the comment)
 *   to localize from the <code>NSLocalizedStaticString</code>
 *   call.
 * </p>
 * <p>
 *   When the code is compiled, instead, the
 *   <code>NSLocalizedStaticString</code> call is ignored (discarded,
 *   it is a macro which simply expands to <code>key</code>), while
 *   the <code>NSLocalizedString</code> will actually look up the
 *   string for translation in the <code>Localizable.strings</code>
 *   file.
 * </p>
 * <p>
 *   Please note that there is currently no macro/function to
 *   localize static strings using different tables.  If you
 *   need that functionality, you have either to prepare the
 *   localization tables by hand, or to rewrite your code in
 *   such a way as not to use static strings.
 * </p>
 */
#define NSLocalizedStaticString(key, comment) key

#endif /* NO_GNUSTEP */

#endif	/* __NSBundle_h_GNUSTEP_BASE_INCLUDE */
