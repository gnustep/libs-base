/* 
   NSFileManager.m

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

#include <config.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSLock.h>

#include <stdio.h>

/* determine directory reading files */

#if defined(HAVE_DIRENT_H)
# include <dirent.h>
#elif defined(HAVE_SYS_DIR_H)
# include <sys/dir.h>
#elif defined(HAVE_SYS_NDIR_H)
# include <sys/ndir.h>
#elif defined(HAVE_NDIR_H)
# include <ndir.h>
#endif

#include <unistd.h>

#if !defined(_POSIX_VERSION)
# if defined(NeXT)
#  define DIR_enum_item struct direct
# endif
#endif

#if !defined(DIR_enum_item)
# define DIR_enum_item struct dirent
#endif

#define DIR_enum_state DIR

/* determine filesystem max path length */

#ifdef _POSIX_VERSION
# include <limits.h>			/* for PATH_MAX */
# include <utime.h>
#else
#ifndef __WIN32__
# include <sys/param.h>			/* for MAXPATHLEN */
#endif
#endif

#ifndef PATH_MAX
# ifdef _POSIX_VERSION
#  define PATH_MAX _POSIX_PATH_MAX
# else
#  ifdef MAXPATHLEN
#   define PATH_MAX MAXPATHLEN
#  else
#   define PATH_MAX 1024
#  endif
# endif
#endif

/* determine if we have statfs struct and function */

#ifdef HAVE_SYS_VFS_H
# include <sys/vfs.h>
# ifdef HAVE_SYS_STATVFS_H
#  include <sys/statvfs.h>
# endif
#endif

#ifdef HAVE_SYS_STATFS_H
# include <sys/statfs.h>
#endif

#if HAVE_SYS_FILE_H
#include <sys/file.h>
#endif

#include <errno.h>

#ifdef HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif

#include <fcntl.h>

#if HAVE_UTIME_H
# include <utime.h>
#endif

/* include usual headers */

#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSFileManager.h>

@interface NSFileManager (PrivateMethods)

/* Copies the contents of source file to destination file. Assumes source
   and destination are regular files or symbolic links. */
- (BOOL)_copyFile:(NSString*)source toFile:(NSString*)destination
  handler:handler;

/* Recursively copies the contents of source directory to destination. */
- (BOOL)_copyPath:(NSString*)source toPath:(NSString*)destination
  handler:handler;

@end /* NSFileManager (PrivateMethods) */

/*
 * NSFileManager implementation
 */

@implementation NSFileManager

// Getting the default manager

static NSFileManager* defaultManager = nil;

+ (NSFileManager*)defaultManager
{
  if (!defaultManager)
    {
      NS_DURING
	{
	  [gnustep_global_lock lock];
	  defaultManager = [[self alloc] init];
	  [gnustep_global_lock unlock];
	}
      NS_HANDLER
	{
	  // unlock then re-raise the exception
	  [gnustep_global_lock unlock];
	  [localException raise];
	}
      NS_ENDHANDLER
    }
  return defaultManager;
}

// Directory operations

- (BOOL)changeCurrentDirectoryPath:(NSString*)path
{
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    
#if defined(__WIN32__) || defined(_WIN32)
    return SetCurrentDirectory(cpath);
#else
    return (chdir(cpath) == 0);
#endif
}

- (BOOL)createDirectoryAtPath:(NSString*)path
  attributes:(NSDictionary*)attributes
{
#if defined(__WIN32__) || defined(_WIN32)
  return CreateDirectory([path cString], NULL);
#else
    const char* cpath;
    char dirpath[PATH_MAX+1];
    struct stat statbuf;
    int len, cur;
    
    cpath = [self fileSystemRepresentationWithPath:path];
    len = strlen(cpath);
    if (len > PATH_MAX)
	// name too long
	return NO;
    
    if (strcmp(cpath, "/") == 0 || len == 0)
	// cannot use "/" or "" as a new dir path
	return NO; 
    
    strcpy(dirpath, cpath);
    dirpath[len] = '\0';
    if (dirpath[len-1] == '/')
	dirpath[len-1] = '\0';
    cur = 0;
    
    do {
	// find next '/'
	while (dirpath[cur] != '/' && cur < len)
	    cur++;
	// if first char is '/' then again; (cur == len) -> last component
	if (cur == 0) {
	    cur++;
	    continue;
	}
	// check if path from 0 to cur is valid
	dirpath[cur] = '\0';
	if (stat(dirpath, &statbuf) == 0) {
	    if (cur == len)
		return NO; // already existing last path
	}
	else {
	    // make new directory
	    if (mkdir(dirpath, 0777) != 0)
	      return NO; // could not create component
	    // if last directory and attributes then change
	    if (cur == len && attributes)
		return [self changeFileAttributes:attributes 
		    atPath:[self stringWithFileSystemRepresentation:dirpath
			length:cur]];
	}
	dirpath[cur] = '/';
	cur++;
    } while (cur < len);

    return YES;
#endif /* WIN32 */
}

- (NSString*)currentDirectoryPath
{
    char path[PATH_MAX];

#if defined(__WIN32__) || defined(_WIN32)
    if (GetCurrentDirectory(PATH_MAX, path) > PATH_MAX)
      return nil;
#else
#ifdef HAVE_GETCWD
    if (getcwd(path, PATH_MAX-1) == NULL)
	return nil;
#else
    if (getwd(path) == NULL)
	return nil;
#endif /* HAVE_GETCWD */
#endif /* WIN32 */

    return [self stringWithFileSystemRepresentation:path length:strlen(path)];
}

// File operations

- (BOOL)copyPath:(NSString*)source toPath:(NSString*)destination
  handler:handler
{
    BOOL sourceIsDir, fileExists;
    NSDictionary* attributes;

    fileExists = [self fileExistsAtPath:source isDirectory:&sourceIsDir];
    if (!fileExists)
	return NO;

    fileExists = [self fileExistsAtPath:destination];
    if (fileExists)
	return NO;

    attributes = [self fileAttributesAtPath:source traverseLink:NO];

    if (sourceIsDir) {
	/* If destination directory is a descendant of source directory copying
	    isn't possible. */
	if ([[destination stringByAppendingString:@"/"]
			    hasPrefix:[source stringByAppendingString:@"/"]])
	    return NO;

	[handler fileManager:self willProcessPath:destination];
	if (![self createDirectoryAtPath:destination attributes:attributes]) {
	    if (handler) {
		NSDictionary* errorInfo
		    = [NSDictionary dictionaryWithObjectsAndKeys:
			destination, @"Path",
			@"cannot create directory", @"Error",
			nil];
		return [handler fileManager:self
				shouldProceedAfterError:errorInfo];
	    }
	    else
		return NO;
	}
    }

    if (sourceIsDir) {
	if (![self _copyPath:source toPath:destination handler:handler])
	    return NO;
	else {
	    [self changeFileAttributes:attributes atPath:destination];
	    return YES;
	}
    }
    else {
	[handler fileManager:self willProcessPath:source];
	if (![self _copyFile:source toFile:destination handler:handler])
	    return NO;
	else {
	    [self changeFileAttributes:attributes atPath:destination];
	    return YES;
	}
    }

    return NO;
}

- (BOOL)movePath:(NSString*)source toPath:(NSString*)destination 
  handler:handler
{
    BOOL sourceIsDir, fileExists;
    const char* sourcePath = [self fileSystemRepresentationWithPath:source];
    const char* destPath = [self fileSystemRepresentationWithPath:destination];
    NSString* destinationParent;
    unsigned int sourceDevice, destinationDevice;

    fileExists = [self fileExistsAtPath:source isDirectory:&sourceIsDir];
    if (!fileExists)
	return NO;

    fileExists = [self fileExistsAtPath:destination];
    if (fileExists)
	return NO;

    /* Check to see if the source and destination's parent are on the same
       physical device so we can perform a rename syscall directly. */
    sourceDevice = [[[self fileSystemAttributesAtPath:source]
			    objectForKey:NSFileSystemNumber]
			    unsignedIntValue];
    destinationParent = [destination stringByDeletingLastPathComponent];
    if ([destinationParent isEqual:@""])
	destinationParent = @".";
    destinationDevice
	= [[[self fileSystemAttributesAtPath:destinationParent]
		  objectForKey:NSFileSystemNumber]
		  unsignedIntValue];

    if (sourceDevice != destinationDevice) {
	/* If destination directory is a descendant of source directory moving
	    isn't possible. */
	if (sourceIsDir && [[destination stringByAppendingString:@"/"]
			    hasPrefix:[source stringByAppendingString:@"/"]])
	    return NO;

	if ([self copyPath:source toPath:destination handler:handler]) {
	    NSDictionary* attributes;

	    attributes = [self fileAttributesAtPath:source traverseLink:NO];
	    [self changeFileAttributes:attributes atPath:destination];
	    return [self removeFileAtPath:source handler:handler];
	}
	else
	    return NO;
    }
    else {
	/* source and destination are on the same device so we can simply
	   invoke rename on source. */
	[handler fileManager:self willProcessPath:source];
	if (rename (sourcePath, destPath) == -1) {
	    if (handler) {
		NSDictionary* errorInfo
		    = [NSDictionary dictionaryWithObjectsAndKeys:
			source, @"Path",
			destination, @"ToPath",
			@"cannot move file", @"Error",
			nil];
		if ([handler fileManager:self
			     shouldProceedAfterError:errorInfo])
		    return YES;
	    }
	    return NO;
	}
	return YES;
    }

    return NO;
}

- (BOOL)linkPath:(NSString*)source toPath:(NSString*)destination
  handler:handler
{
    // TODO
    [self notImplemented:_cmd];
    return NO;
}

- (BOOL)removeFileAtPath: (NSString*)path
		 handler: handler
{
  NSArray	*contents;

  if (handler)
    [handler fileManager: self willProcessPath: path];

  contents = [self directoryContentsAtPath: path];
  if (contents == nil)
    {
      if (unlink([path fileSystemRepresentation]) < 0)
	{
	  BOOL	result;

	  if (handler)
	    {
	      NSMutableDictionary	*info;

	      info = [[NSMutableDictionary alloc] initWithCapacity: 3];
	      [info setObject: path forKey: @"Path"];
	      [info setObject: [NSString stringWithCString: strerror(errno)]
		       forKey: @"Error"];
	      result = [handler fileManager: self
		    shouldProceedAfterError: info];
	      [info release];
	    }
	  else
	    result = NO;
	  return result;
	}
      else
	return YES;
    }
  else
    {
      int	i;

      contents = [self directoryContentsAtPath: path];
      for (i = 0; i < [contents count]; i++)
	{
	  NSAutoreleasePool	*arp;
	  NSString		*item;
	  NSString		*next;
	  BOOL			result;

	  arp = [[NSAutoreleasePool alloc] init];
	  item = [contents objectAtIndex: i];
	  next = [path stringByAppendingPathComponent: item];
	  result = [self removeFileAtPath: next handler: handler];
	  [arp release];
	  if (result == NO)
	    return NO;
	}

      if (rmdir([path fileSystemRepresentation]) < 0)
	{
	  BOOL	result;

	  if (handler)
	    {
	      NSMutableDictionary	*info;

	      info = [[NSMutableDictionary alloc] initWithCapacity: 3];
	      [info setObject: path forKey: @"Path"];
	      [info setObject: [NSString stringWithCString: strerror(errno)]
		       forKey: @"Error"];
	      result = [handler fileManager: self
		    shouldProceedAfterError: info];
	      [info release];
	    }
	  else
	    result = NO;
	  return result;
	}
      else
	return YES;
    }
}

- (BOOL)createFileAtPath:(NSString*)path contents:(NSData*)contents
  attributes:(NSDictionary*)attributes
{
    int fd, len, written;

    fd = open ([self fileSystemRepresentationWithPath:path],
                O_WRONLY|O_TRUNC|O_CREAT, 0644);
    if (fd < 0)
        return NO;

    if (![self changeFileAttributes:attributes atPath:path]) {
        close (fd);
        return NO;
    }

    len = [contents length];
    if (len)
        written = write (fd, [contents bytes], len);
    else
        written = 0;
    close (fd);

    return written == len;
}

// Getting and comparing file contents

- (NSData*)contentsAtPath:(NSString*)path
{
    // TODO
    [self notImplemented:_cmd];
    return nil;
}

- (BOOL)contentsEqualAtPath:(NSString*)path1 andPath:(NSString*)path2
{
    // TODO
    [self notImplemented:_cmd];
    return NO;
}

// Detemining access to files

- (BOOL)fileExistsAtPath:(NSString*)path
{
    return [self fileExistsAtPath:path isDirectory:NULL];
}

- (BOOL)fileExistsAtPath:(NSString*)path isDirectory:(BOOL*)isDirectory
{
#if defined(__WIN32__) || defined(_WIN32)
  DWORD res = GetFileAttributes([path cString]);
  if (res == -1)
    return NO;

  if (isDirectory)
    {
      if (res & FILE_ATTRIBUTE_DIRECTORY)
	*isDirectory = YES;
      else
	*isDirectory = NO;
    }
  return YES;
#else
    struct stat statbuf;
    const char* cpath = [self fileSystemRepresentationWithPath:path];

    if (stat(cpath, &statbuf) != 0)
	return NO;
    
    if (isDirectory) {
	*isDirectory = ((statbuf.st_mode & S_IFMT) == S_IFDIR);
    }
    
    return YES;
#endif /* WIN32 */
}

- (BOOL)isReadableFileAtPath:(NSString*)path
{
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    
    return (access(cpath, R_OK) == 0);
}

- (BOOL)isWritableFileAtPath:(NSString*)path
{
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    
    return (access(cpath, W_OK) == 0);
}

- (BOOL)isExecutableFileAtPath:(NSString*)path
{
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    
    return (access(cpath, X_OK) == 0);
}

- (BOOL)isDeletableFileAtPath:(NSString*)path
{
    // TODO - handle directories
    const char* cpath;
    
    cpath = [self fileSystemRepresentationWithPath:
	[path stringByDeletingLastPathComponent]];
    
    if (access(cpath, X_OK || W_OK) != 0)
	return NO;

    cpath = [self fileSystemRepresentationWithPath:
	[path stringByDeletingLastPathComponent]];
    
    return  (access(cpath, X_OK || W_OK) != 0);
}

- (NSDictionary*)fileAttributesAtPath:(NSString*)path traverseLink:(BOOL)flag
{
    struct stat statbuf;
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    int mode;
    
    id  values[9];
    id	keys[9] = {
	    NSFileSize,
	    NSFileModificationDate,
	    NSFileOwnerAccountNumber,
	    NSFileGroupOwnerAccountNumber,
	    NSFileReferenceCount,
	    NSFileIdentifier,
	    NSFileDeviceIdentifier,
	    NSFilePosixPermissions,
	    NSFileType
	};

    if (stat(cpath, &statbuf) != 0)
	return nil;
    
    values[0] = [NSNumber numberWithUnsignedLongLong:statbuf.st_size];
    values[1] = [NSDate dateWithTimeIntervalSince1970:statbuf.st_mtime];
    values[2] = [NSNumber numberWithUnsignedInt:statbuf.st_uid];
    values[3] = [NSNumber numberWithUnsignedInt:statbuf.st_gid];
    values[4] = [NSNumber numberWithUnsignedInt:statbuf.st_nlink];
    values[5] = [NSNumber numberWithUnsignedLong:statbuf.st_ino];
    values[6] = [NSNumber numberWithUnsignedInt:statbuf.st_dev];
    values[7] = [NSNumber numberWithUnsignedInt:statbuf.st_mode];
    
    mode = statbuf.st_mode & S_IFMT;

    if      (mode == S_IFREG)
	values[8] = NSFileTypeRegular;
    else if (mode == S_IFDIR)
	values[8] = NSFileTypeDirectory;
    else if (mode == S_IFCHR)
	values[8] = NSFileTypeCharacterSpecial;
    else if (mode == S_IFBLK)
	values[8] = NSFileTypeBlockSpecial;
#ifdef S_IFLNK
    else if (mode == S_IFLNK)
	values[8] = NSFileTypeSymbolicLink;
#endif
    else if (mode == S_IFIFO)
	values[8] = NSFileTypeFifo;
#ifdef S_IFSOCK
    else if (mode == S_IFSOCK)
	values[8] = NSFileTypeSocket;
#endif
    else
	values[8] = NSFileTypeUnknown;

    return [[[NSDictionary alloc]
	initWithObjects:values forKeys:keys count:5]
	autorelease];
}

- (NSDictionary*)fileSystemAttributesAtPath:(NSString*)path
{
#if defined(__WIN32__) || defined(_WIN32)
    long long totalsize, freesize;
    id  values[5];
    id	keys[5] = {
	    NSFileSystemSize,
	    NSFileSystemFreeSize,
	    NSFileSystemNodes,
	    NSFileSystemFreeNodes,
	    NSFileSystemNumber
	};
    DWORD SectorsPerCluster, BytesPerSector, NumberFreeClusters;
    DWORD TotalNumberClusters;
    const char *cpath = [self fileSystemRepresentationWithPath: path];

    if (!GetDiskFreeSpace(cpath, &SectorsPerCluster,
			  &BytesPerSector, &NumberFreeClusters,
			  &TotalNumberClusters))
      return nil;

    totalsize = TotalNumberClusters * SectorsPerCluster * BytesPerSector;
    freesize = NumberFreeClusters * SectorsPerCluster * BytesPerSector;
    
    values[0] = [NSNumber numberWithLongLong: totalsize];
    values[1] = [NSNumber numberWithLongLong: freesize];
    values[2] = [NSNumber numberWithLong: LONG_MAX];
    values[3] = [NSNumber numberWithLong: LONG_MAX];
    values[4] = [NSNumber numberWithUnsignedInt: 0];
    
    return [[[NSDictionary alloc]
	initWithObjects:values forKeys:keys count:5]
	autorelease];
    
#else
#if HAVE_SYS_VFS_H || HAVE_SYS_STATFS_H
    struct stat statbuf;
#if HAVE_STATVFS
    struct statvfs statfsbuf;
#else
    struct statfs statfsbuf;
#endif
    long long totalsize, freesize;
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    
    id  values[5];
    id	keys[5] = {
	    NSFileSystemSize,
	    NSFileSystemFreeSize,
	    NSFileSystemNodes,
	    NSFileSystemFreeNodes,
	    NSFileSystemNumber
	};
    
    if (stat(cpath, &statbuf) != 0)
	return nil;

#if HAVE_STATVFS
    if (statvfs(cpath, &statfsbuf) != 0)
	return nil;
#else
    if (statfs(cpath, &statfsbuf) != 0)
	return nil;
#endif

    totalsize = statfsbuf.f_bsize * statfsbuf.f_blocks;
    freesize = statfsbuf.f_bsize * statfsbuf.f_bfree;
    
    values[0] = [NSNumber numberWithLongLong:totalsize];
    values[1] = [NSNumber numberWithLongLong:freesize];
    values[2] = [NSNumber numberWithLong:statfsbuf.f_files];
    values[3] = [NSNumber numberWithLong:statfsbuf.f_ffree];
    values[4] = [NSNumber numberWithUnsignedInt:statbuf.st_dev];
    
    return [[[NSDictionary alloc]
	initWithObjects:values forKeys:keys count:5]
	autorelease];
#else
    return nil;
#endif
#endif /* WIN32 */
}

- (BOOL)changeFileAttributes:(NSDictionary*)attributes atPath:(NSString*)path
{
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    NSNumber* num;
    NSDate* date;
    BOOL allOk = YES;

#ifndef __WIN32__
    num = [attributes objectForKey:NSFileOwnerAccountNumber];
    if (num) {
	allOk &= (chown(cpath, [num intValue], -1) == 0);
    }
    
    num = [attributes objectForKey:NSFileGroupOwnerAccountNumber];
    if (num) {
	allOk &= (chown(cpath, -1, [num intValue]) == 0);
    }
#endif
    
    num = [attributes objectForKey:NSFilePosixPermissions];
    if (num) {
	allOk &= (chmod(cpath, [num intValue]) == 0);
    }
    
    date = [attributes objectForKey:NSFileModificationDate];
    if (date) {
	struct stat sb;
#ifdef  _POSIX_VERSION
	struct utimbuf ub;
#else
	time_t ub[2];
#endif

	if (stat(cpath, &sb) != 0)
	    allOk = NO;
	else {
#ifdef  _POSIX_VERSION
	    ub.actime = sb.st_atime;
	    ub.modtime = [date timeIntervalSince1970];
	    allOk &= (utime(cpath, &ub) == 0);
#else
	    ub[0] = sb.st_atime;
	    ub[1] = [date timeIntervalSince1970];
	    allOk &= (utime((char*)cpath, ub) == 0);
#endif
	}
    }
    
    return allOk;
}

// Discovering directory contents

- (NSArray*)directoryContentsAtPath:(NSString*)path
{
    NSDirectoryEnumerator* direnum;
    NSMutableArray* content;
    BOOL isDir;
    
    if (![self fileExistsAtPath:path isDirectory:&isDir] || !isDir)
	return nil;
    
    direnum = [[NSDirectoryEnumerator alloc]
	initWithDirectoryPath:path 
	recurseIntoSubdirectories:NO
	followSymlinks:NO
	prefixFiles:NO];
    content = [[[NSMutableArray alloc] init] autorelease];
    
    while ((path = [direnum nextObject]))
	[content addObject:path];

    [direnum release];

    return content;
}

- (NSDirectoryEnumerator*)enumeratorAtPath:(NSString*)path
{
    return [[[NSDirectoryEnumerator alloc]
	initWithDirectoryPath:path 
	recurseIntoSubdirectories:YES
	followSymlinks:NO
	prefixFiles:YES] autorelease];
}

- (NSArray*)subpathsAtPath:(NSString*)path
{
    NSDirectoryEnumerator* direnum;
    NSMutableArray* content;
    BOOL isDir;
    
    if (![self fileExistsAtPath:path isDirectory:&isDir] || !isDir)
	return nil;
    
    direnum = [[NSDirectoryEnumerator alloc]
	initWithDirectoryPath:path 
	recurseIntoSubdirectories:YES
	followSymlinks:NO
	prefixFiles:YES];
    content = [[[NSMutableArray alloc] init] autorelease];
    
    while ((path = [direnum nextObject]))
	[content addObject:path];

    [direnum release];

    return content;
}

// Symbolic-link operations

- (BOOL)createSymbolicLinkAtPath:(NSString*)path
  pathContent:(NSString*)otherPath
{
    const char* lpath = [self fileSystemRepresentationWithPath:path];
    const char* npath = [self fileSystemRepresentationWithPath:otherPath];
    
#ifdef __WIN32__
    return NO;
#else
    return (symlink(lpath, npath) == 0);
#endif
}

- (NSString*)pathContentOfSymbolicLinkAtPath:(NSString*)path
{
    char  lpath[PATH_MAX];
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    int   llen = readlink(cpath, lpath, PATH_MAX-1);
    
    if (llen > 0)
	return [self stringWithFileSystemRepresentation:lpath length:llen];
    else
	return nil;
}

// Converting file-system representations

- (const char*)fileSystemRepresentationWithPath:(NSString*)path
{
#if defined(__WIN32__) || defined(_WIN32)
  char cpath[4];
  char *fspath = [path cString];

  // Check if path specifies drive number or is current drive
  if (fspath[0] && (fspath[1] == ':'))
    {
      cpath[0] = fspath[0];
      cpath[1] = fspath[1];
      cpath[2] = '\\';
      cpath[3] = '\0';
    }
  else
    {
      cpath[0] = '\\';
      cpath[1] = '\0';
    }
  return [[NSString stringWithCString: cpath] cString];
#else
    return [[[path copy] autorelease] cString];
#endif
}

- (NSString*)stringWithFileSystemRepresentation:(const char*)string
  length:(unsigned int)len
{
    return [NSString stringWithCString:string length:len];
}

@end /* NSFileManager */

/*
 * NSDirectoryEnumerator implementation
 */

@implementation NSDirectoryEnumerator

// Implementation dependent methods

/* 
  recurses into directory `path' 
	- pushes relative path (relative to root of search) on pathStack
	- pushes system dir enumerator on enumPath 
*/
- (void)recurseIntoDirectory:(NSString*)path relativeName:(NSString*)name
{
#ifdef __WIN32__
#else
    const char* cpath;
    DIR*  dir;
    
    cpath = [[NSFileManager defaultManager]
	fileSystemRepresentationWithPath:path];
    
    dir = opendir(cpath);
    
    if (dir) {
	[pathStack addObject:name];
	[enumStack addObject:[NSValue valueWithPointer:dir]];
    }
#endif
}

/*
  backtracks enumeration to the previous dir
  	- pops current dir relative path from pathStack
	- pops system dir enumerator from enumStack
	- sets currentFile* to nil
*/
- (void)backtrack
{
#ifdef __WIN32__
#else
    closedir((DIR*)[[enumStack lastObject] pointerValue]);
#endif
    [enumStack removeLastObject];
    [pathStack removeLastObject];
    [currentFileName release];
    [currentFilePath release];
    currentFileName = currentFilePath = nil;
}

/*
  finds the next file according to the top enumerator
  	- if there is a next file it is put in currentFile
	- if the current file is a directory and if isRecursive calls 
	    recurseIntoDirectory:currentFile
	- if the current file is a symlink to a directory and if isRecursive 
	    and isFollowing calls recurseIntoDirectory:currentFile
	- if at end of current directory pops stack and attempts to
	    find the next entry in the parent
	- sets currentFile to nil if there are no more files to enumerate
*/
- (void)findNextFile
{
#ifdef __WIN32__
#else
    NSFileManager*	manager = [NSFileManager defaultManager];
    DIR_enum_state*  	dir;
    DIR_enum_item*	dirbuf;
    struct stat		statbuf;
    const char*		cpath;
    
    [currentFileName release];
    [currentFilePath release];
    currentFileName = currentFilePath = nil;
    
    while ([pathStack count]) {
	dir = (DIR*)[[enumStack lastObject] pointerValue];
	dirbuf = readdir(dir);
	if (dirbuf) {
	    /* Skip "." and ".." directory entries */
	    if (strcmp(dirbuf->d_name, ".") == 0 || 
	        strcmp(dirbuf->d_name, "..") == 0)
		    continue;
	    // Name of current file
	    currentFileName = [manager
		   stringWithFileSystemRepresentation:dirbuf->d_name
		   length:strlen(dirbuf->d_name)];
	    currentFileName = [[[pathStack lastObject]
		stringByAppendingPathComponent:currentFileName] retain];
	    // Full path of current file
	    currentFilePath = [[topPath
		stringByAppendingPathComponent:currentFileName] retain];
	    // Check if directory
	    cpath = [manager fileSystemRepresentationWithPath:currentFilePath];
	    // Do not follow links
	    if (!flags.isFollowing) {
		if (!lstat(cpath, &statbuf))
		    break;
		// If link then return it as link
		if (S_IFLNK == (S_IFMT & statbuf.st_mode)) 
		    break;
	    }
	    // Follow links - check for directory
	    if (!stat(cpath, &statbuf))
		break;
	    if (S_IFDIR == (S_IFMT & statbuf.st_mode)) {
		[self recurseIntoDirectory:currentFilePath 
		    relativeName:currentFileName];
		break;
	    }
	}
	else
	    [self backtrack];
    }
#endif
}

// Initializing

- initWithDirectoryPath:(NSString*)path 
  recurseIntoSubdirectories:(BOOL)recurse
  followSymlinks:(BOOL)follow
  prefixFiles:(BOOL)prefix
{
    pathStack = [NSMutableArray new];
    enumStack = [NSMutableArray new];
    flags.isRecursive = recurse;
    flags.isFollowing = follow;
    
    topPath = [path retain];
    [self recurseIntoDirectory:path relativeName:@""];
    
    return self;
}

- (void)dealloc
{
    while ([pathStack count])
	[self backtrack];
    
    [pathStack release];
    [enumStack release];
    [currentFileName release];
    [currentFilePath release];
    [topPath release];
}

// Getting attributes

- (NSDictionary*)directoryAttributes
{
    return [[NSFileManager defaultManager]
	fileAttributesAtPath:currentFilePath
	traverseLink:flags.isFollowing];
}

- (NSDictionary*)fileAttributes
{
    return [[NSFileManager defaultManager]
	fileAttributesAtPath:currentFilePath
	traverseLink:flags.isFollowing];
}

// Skipping subdirectories

- (void)skipDescendents
{
    if ([pathStack count])
	[self backtrack];
}

// Enumerate next

- nextObject
{
    [self findNextFile];
    return currentFileName;
}

@end /* NSDirectoryEnumerator */

/*
 * Attributes dictionary access
 */

@implementation NSDictionary(NSFileAttributes)
- (NSNumber*)fileSize
  {return [self objectForKey:NSFileSize];}
- (NSString*)fileType;
  {return [self objectForKey:NSFileType];}
- (NSNumber*)fileOwnerAccountNumber;
  {return [self objectForKey:NSFileOwnerAccountNumber];}
- (NSNumber*)fileGroupOwnerAccountNumber;
  {return [self objectForKey:NSFileGroupOwnerAccountNumber];}
- (NSDate*)fileModificationDate;
  {return [self objectForKey:NSFileModificationDate];}
- (NSNumber*)filePosixPermissions;
  {return [self objectForKey:NSFilePosixPermissions];}


@implementation NSFileManager (PrivateMethods)

- (BOOL)_copyFile:(NSString*)source toFile:(NSString*)destination
  handler:handler
{
    NSDictionary* attributes;
    int i, bufsize = 8096;
    int sourceFd, destFd, fileSize, fileMode;
    int rbytes, wbytes;
    char buffer[bufsize];

    /* Assumes source is a file and exists! */
    NSAssert1 ([self fileExistsAtPath:source],
		@"source file '%@' does not exist!", source);

    attributes = [self fileAttributesAtPath:source traverseLink:NO];
    NSAssert1 (attributes, @"could not get the attributes for file '%@'",
		source);

    fileSize = [[attributes objectForKey:NSFileSize] intValue];
    fileMode = [[attributes objectForKey:NSFilePosixPermissions] intValue];

    /* Open the source file. In case of error call the handler. */
    sourceFd = open ([self fileSystemRepresentationWithPath:source], O_RDONLY);
    if (sourceFd < 0) {
	if (handler) {
	    NSDictionary* errorInfo
		= [NSDictionary dictionaryWithObjectsAndKeys:
			source, @"Path",
			@"cannot open file for reading", @"Error",
			nil];
	    return [handler fileManager:self
			    shouldProceedAfterError:errorInfo];
	}
	else
	    return NO;
    }

    /* Open the destination file. In case of error call the handler. */
    destFd = open ([self fileSystemRepresentationWithPath:destination],
		   O_WRONLY|O_CREAT|O_TRUNC, fileMode);
    if (destFd < 0) {
	if (handler) {
	    NSDictionary* errorInfo
		= [NSDictionary dictionaryWithObjectsAndKeys:
			destination, @"ToPath",
			@"cannot open file for writing", @"Error",
			nil];
	    close (sourceFd);
	    return [handler fileManager:self
			    shouldProceedAfterError:errorInfo];
	}
	else
	    return NO;
    }

    /* Read bufsize bytes from source file and write them into the destination
       file. In case of errors call the handler and abort the operation. */
    for (i = 0; i < fileSize; i += rbytes) {
	rbytes = read (sourceFd, buffer, bufsize);
	if (rbytes < 0) {
	    if (handler) {
		NSDictionary* errorInfo
		    = [NSDictionary dictionaryWithObjectsAndKeys:
			    source, @"Path",
			    @"cannot read from file", @"Error",
			    nil];
		close (sourceFd);
		close (destFd);
		return [handler fileManager:self
				shouldProceedAfterError:errorInfo];
	    }
	    else
		return NO;
	}

	wbytes = write (destFd, buffer, rbytes);
	if (wbytes != rbytes) {
	    if (handler) {
		NSDictionary* errorInfo
		    = [NSDictionary dictionaryWithObjectsAndKeys:
			    source, @"Path",
			    destination, @"ToPath",
			    @"cannot write to file", @"Error",
			    nil];
		close (sourceFd);
		close (destFd);
		return [handler fileManager:self
				shouldProceedAfterError:errorInfo];
	    }
	    else
		return NO;
	}
    }
    close (sourceFd);
    close (destFd);

    return YES;
}

- (BOOL)_copyPath:(NSString*)source
  toPath:(NSString*)destination
  handler:handler
{
    NSDirectoryEnumerator* enumerator;
    NSString* dirEntry;
    NSString* sourceFile;
    NSString* fileType;
    NSString* destinationFile;
    NSDictionary* attributes;
    NSAutoreleasePool* pool;

    pool = [NSAutoreleasePool new];
    enumerator = [self enumeratorAtPath:source];
    while ((dirEntry = [enumerator nextObject])) {
	attributes = [enumerator fileAttributes];
	fileType = [attributes objectForKey:NSFileType];
	sourceFile = [source stringByAppendingPathComponent:dirEntry];
	destinationFile
		= [destination stringByAppendingPathComponent:dirEntry];

	[handler fileManager:self willProcessPath:sourceFile];
	if ([fileType isEqual:NSFileTypeDirectory]) {
	    if (![self createDirectoryAtPath:destinationFile
			attributes:attributes]) {
		if (handler) {
		    NSDictionary* errorInfo
			= [NSDictionary dictionaryWithObjectsAndKeys:
				destinationFile, @"Path",
				@"cannot create directory", @"Error",
				nil];
		    if (![handler fileManager:self
				  shouldProceedAfterError:errorInfo])
			return NO;
		}
		else
		    return NO;
	    }
	    else {
		[enumerator skipDescendents];
		if (![self _copyPath:sourceFile toPath:destinationFile
			    handler:handler])
		    return NO;
	    }
	}
	else if ([fileType isEqual:NSFileTypeRegular]) {
	    if (![self _copyFile:sourceFile toFile:destinationFile
			handler:handler])
		return NO;
	}
	else if ([fileType isEqual:NSFileTypeSymbolicLink]) {
	    if (![self createSymbolicLinkAtPath:destinationFile
			pathContent:sourceFile]) {
		if (handler) {
		    NSDictionary* errorInfo
			= [NSDictionary dictionaryWithObjectsAndKeys:
				sourceFile, @"Path",
				destinationFile, @"ToPath",
				@"cannot create symbolic link", @"Error",
				nil];
		    if (![handler fileManager:self
				  shouldProceedAfterError:errorInfo])
			return NO;
		}
		else
		    return NO;
	    }
	}
	else {
	    NSLog(@"cannot copy file '%@' of type '%@'", sourceFile, fileType);
	}
	[self changeFileAttributes:attributes atPath:destinationFile];
    }
    [pool release];

    return YES;
}

@end /* NSFileManager (PrivateMethods) */
