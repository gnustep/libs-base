/* 
   NSFileManager.h

   Copyright (C) 1997 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#ifndef __NSFileManager_h_GNUSTEP_BASE_INCLUDE
#define __NSFileManager_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
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

// Getting the default manager
+ (NSFileManager*)defaultManager;

// Directory operations
- (BOOL)changeCurrentDirectoryPath:(NSString*)path;
- (BOOL)createDirectoryAtPath:(NSString*)path
  attributes:(NSDictionary*)attributes;
- (NSString*)currentDirectoryPath;

// File operations
- (BOOL)copyPath:(NSString*)source toPath:(NSString*)destination
  handler:handler;
- (BOOL)movePath:(NSString*)source toPath:(NSString*)destination 
  handler:handler;
- (BOOL)linkPath:(NSString*)source toPath:(NSString*)destination
  handler:handler;
- (BOOL)removeFileAtPath:(NSString*)path
  handler:handler;
- (BOOL)createFileAtPath:(NSString*)path contents:(NSData*)contents
  attributes:(NSDictionary*)attributes;

// Getting and comparing file contents	
- (NSData*)contentsAtPath:(NSString*)path;
- (BOOL)contentsEqualAtPath:(NSString*)path1 andPath:(NSString*)path2;

// Detemining access to files
- (BOOL)fileExistsAtPath:(NSString*)path;
- (BOOL)fileExistsAtPath:(NSString*)path isDirectory:(BOOL*)isDirectory;
- (BOOL)isReadableFileAtPath:(NSString*)path;
- (BOOL)isWritableFileAtPath:(NSString*)path;
- (BOOL)isExecutableFileAtPath:(NSString*)path;
- (BOOL)isDeletableFileAtPath:(NSString*)path;

// Getting and setting attributes
- (NSDictionary*)fileAttributesAtPath:(NSString*)path traverseLink:(BOOL)flag;
- (NSDictionary*)fileSystemAttributesAtPath:(NSString*)path;
- (BOOL)changeFileAttributes:(NSDictionary*)attributes atPath:(NSString*)path;

// Discovering directory contents
- (NSArray*)directoryContentsAtPath:(NSString*)path;
- (NSDirectoryEnumerator*)enumeratorAtPath:(NSString*)path;
- (NSArray*)subpathsAtPath:(NSString*)path;

// Symbolic-link operations
- (BOOL)createSymbolicLinkAtPath:(NSString*)path
  pathContent:(NSString*)otherPath;
- (NSString*)pathContentOfSymbolicLinkAtPath:(NSString*)path;

// Converting file-system representations
- (const char*)fileSystemRepresentationWithPath:(NSString*)path;
- (NSString*)stringWithFileSystemRepresentation:(const char*)string
  length:(unsigned int)len;

@end /* NSFileManager */


@interface NSObject (NSFileManagerHandler)
- (BOOL)fileManager:(NSFileManager*)fileManager
  shouldProceedAfterError:(NSDictionary*)errorDictionary;
- (void)fileManager:(NSFileManager*)fileManager
  willProcessPath:(NSString*)path;
@end


@interface NSDirectoryEnumerator : NSEnumerator
{
    NSMutableArray*	enumStack;
    NSMutableArray*	pathStack;
    NSString*		currentFileName;
    NSString*		currentFilePath;
    NSString*		topPath;
    struct {
	BOOL		isRecursive:1;
 	BOOL		isFollowing:1;
   } flags;
}

// Initializing
- initWithDirectoryPath:(NSString*)path 
  recurseIntoSubdirectories:(BOOL)recurse
  followSymlinks:(BOOL)follow
  prefixFiles:(BOOL)prefix;

// Getting attributes
- (NSDictionary*)directoryAttributes;
- (NSDictionary*)fileAttributes;

// Skipping subdirectories
- (void)skipDescendents;

@end /* NSDirectoryEnumerator */

/* File Attributes */
extern NSString* NSFileSize;
extern NSString* NSFileModificationDate;
extern NSString* NSFileOwnerAccountNumber;
extern NSString* NSFileOwnerAccountName;
extern NSString* NSFileGroupOwnerAccountNumber;
extern NSString* NSFileReferenceCount;
extern NSString* NSFileIdentifier;
extern NSString* NSFileDeviceIdentifier;
extern NSString* NSFilePosixPermissions;
extern NSString* NSFileType;

/* File Types */

extern NSString* NSFileTypeDirectory;
extern NSString* NSFileTypeRegular;
extern NSString* NSFileTypeSymbolicLink;
extern NSString* NSFileTypeSocket;
extern NSString* NSFileTypeFifo;
extern NSString* NSFileTypeCharacterSpecial;
extern NSString* NSFileTypeBlockSpecial;
extern NSString* NSFileTypeUnknown;

/* FileSystem Attributes */

extern NSString* NSFileSystemSize;
extern NSString* NSFileSystemFreeSize;
extern NSString* NSFileSystemNodes;
extern NSString* NSFileSystemFreeNodes;
extern NSString* NSFileSystemNumber;

/* Easy access to attributes in a dictionary */

@interface NSDictionary(NSFileAttributes)
- (NSNumber*)fileSize;
- (NSString*)fileType;
- (NSNumber*)fileOwnerAccountNumber;
- (NSNumber*)fileGroupOwnerAccountNumber;
- (NSDate*)fileModificationDate;
- (NSNumber*)filePosixPermissions;
@end


#endif /* __NSFileManager_h_GNUSTEP_BASE_INCLUDE */
