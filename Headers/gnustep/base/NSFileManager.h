/* -*-objc-*-
   NSFileManager.h

   Copyright (C) 1997,1999 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: Feb 1997

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

#ifndef __NSFileManager_h_GNUSTEP_BASE_INCLUDE
#define __NSFileManager_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

#ifndef	STRICT_OPENSTEP
#include <Foundation/NSUtilities.h>
#include <Foundation/NSDictionary.h>

@class NSNumber;
@class NSString;
@class NSData;
@class NSDate;
@class NSArray;
@class NSMutableArray;

@class NSDirectoryEnumerator;

@interface NSFileManager : NSObject
{
  NSString	*_lastError;
}

+ (NSFileManager*) defaultManager;

- (BOOL) changeCurrentDirectoryPath: (NSString*)path;
- (BOOL) changeFileAttributes: (NSDictionary*)attributes
		       atPath: (NSString*)path;
- (NSArray*) componentsToDisplayForPath: (NSString*)path;
- (NSData*) contentsAtPath: (NSString*)path;
- (BOOL) contentsEqualAtPath: (NSString*)path1
		     andPath: (NSString*)path2;
- (BOOL) copyPath: (NSString*)source
	   toPath: (NSString*)destination
	  handler: (id)handler;
- (BOOL) createDirectoryAtPath: (NSString*)path
		    attributes: (NSDictionary*)attributes;
- (BOOL) createFileAtPath: (NSString*)path
		 contents: (NSData*)contents
	       attributes: (NSDictionary*)attributes;
- (BOOL) createSymbolicLinkAtPath: (NSString*)path
		      pathContent: (NSString*)otherPath;
- (NSString*) currentDirectoryPath;
- (NSArray*) directoryContentsAtPath: (NSString*)path;
- (NSString*) displayNameAtPath: (NSString*)path;
- (NSDirectoryEnumerator*) enumeratorAtPath: (NSString*)path;
- (NSDictionary*) fileAttributesAtPath: (NSString*)path
			  traverseLink: (BOOL)flag;
- (BOOL) fileExistsAtPath: (NSString*)path;
- (BOOL) fileExistsAtPath: (NSString*)path isDirectory: (BOOL*)isDirectory;
- (NSDictionary*) fileSystemAttributesAtPath: (NSString*)path;
- (const char*) fileSystemRepresentationWithPath: (NSString*)path;
- (BOOL) isExecutableFileAtPath: (NSString*)path;
- (BOOL) isDeletableFileAtPath: (NSString*)path;
- (BOOL) isReadableFileAtPath: (NSString*)path;
- (BOOL) isWritableFileAtPath: (NSString*)path;
- (BOOL) linkPath: (NSString*)source
	   toPath: (NSString*)destination
	  handler: (id)handler;
- (BOOL) movePath: (NSString*)source
	   toPath: (NSString*)destination 
	  handler: (id)handler;
- (NSString*) pathContentOfSymbolicLinkAtPath: (NSString*)path;
- (BOOL) removeFileAtPath: (NSString*)path
		  handler: (id)handler;
- (NSString*) stringWithFileSystemRepresentation: (const char*)string
					  length: (unsigned int)len;
- (NSArray*) subpathsAtPath: (NSString*)path;

@end /* NSFileManager */


@interface NSObject (NSFileManagerHandler)
- (BOOL) fileManager: (NSFileManager*)fileManager
  shouldProceedAfterError: (NSDictionary*)errorDictionary;
- (void) fileManager: (NSFileManager*)fileManager
  willProcessPath: (NSString*)path;
@end


@interface NSDirectoryEnumerator : NSEnumerator
{
  void *_stack; /* GSIArray */
  char *_top_path;
  char *_current_file_path;
  NSString *(*_stringWithFileSysImp)(id, SEL, char *, unsigned);
  struct 
  {
    BOOL isRecursive: 1;
    BOOL isFollowing: 1;
    BOOL justContents: 1;
  } _flags;
}

- (id) initWithDirectoryPath: (NSString*)path 
   recurseIntoSubdirectories: (BOOL)recurse
              followSymlinks: (BOOL)follow
                justContents: (BOOL)justContents;

- (NSDictionary*) directoryAttributes;
- (NSDictionary*) fileAttributes;
- (void) skipDescendents;

@end /* NSDirectoryEnumerator */

/* File Attributes */
GS_EXPORT NSString* const NSFileAppendOnly;
GS_EXPORT NSString* const NSFileCreationDate;
GS_EXPORT NSString* const NSFileDeviceIdentifier;
GS_EXPORT NSString* const NSFileExtensionHidden;
GS_EXPORT NSString* const NSFileGroupOwnerAccountID;
GS_EXPORT NSString* const NSFileGroupOwnerAccountName;
GS_EXPORT NSString* const NSFileHFSCreatorCode;
GS_EXPORT NSString* const NSFileHFSTypeCode;
GS_EXPORT NSString* const NSFileImmutable;
GS_EXPORT NSString* const NSFileModificationDate;
GS_EXPORT NSString* const NSFileOwnerAccountID;
GS_EXPORT NSString* const NSFileOwnerAccountName;
GS_EXPORT NSString* const NSFilePosixPermissions;
GS_EXPORT NSString* const NSFileReferenceCount;
GS_EXPORT NSString* const NSFileSize;
GS_EXPORT NSString* const NSFileSystemFileNumber;
GS_EXPORT NSString* const NSFileSystemNumber;
GS_EXPORT NSString* const NSFileType;

/* File Types */

GS_EXPORT NSString* const NSFileTypeDirectory;
GS_EXPORT NSString* const NSFileTypeRegular;
GS_EXPORT NSString* const NSFileTypeSymbolicLink;
GS_EXPORT NSString* const NSFileTypeSocket;
GS_EXPORT NSString* const NSFileTypeFifo;
GS_EXPORT NSString* const NSFileTypeCharacterSpecial;
GS_EXPORT NSString* const NSFileTypeBlockSpecial;
GS_EXPORT NSString* const NSFileTypeUnknown;

/* FileSystem Attributes */

GS_EXPORT NSString* const NSFileSystemSize;
GS_EXPORT NSString* const NSFileSystemFreeSize;
GS_EXPORT NSString* const NSFileSystemNodes;
GS_EXPORT NSString* const NSFileSystemFreeNodes;

/* Easy access to attributes in a dictionary */

@interface NSDictionary(NSFileAttributes)
- (NSDate*) fileCreationDate;
- (BOOL) fileExtensionHidden;
- (int) fileHFSCreatorCode;
- (int) fileHFSTypeCode;
- (BOOL) fileIsAppendOnly;
- (BOOL) fileIsImmutable;
- (unsigned long long) fileSize;
- (NSString*) fileType;
- (unsigned long) fileOwnerAccountID;
- (NSString*) fileOwnerAccountName;
- (unsigned long) fileGroupOwnerAccountID;
- (NSString*) fileGroupOwnerAccountName;
- (NSDate*) fileModificationDate;
- (unsigned long) filePosixPermissions;
- (unsigned long) fileSystemNumber;
- (unsigned long) fileSystemFileNumber;
@end

#endif
#endif /* __NSFileManager_h_GNUSTEP_BASE_INCLUDE */
