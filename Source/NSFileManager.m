/** 
   NSFileManager.m

   Copyright (C) 1997-1999 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: Feb 1997
   Updates and fixes: Richard Frith-Macdonald

   Author: Nicola Pero <n.pero@mi.flashnet.it>
   Date: Apr 2001
   Rewritten NSDirectoryEnumerator

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

   <title>NSFileManager class reference</title>
   $Date$ $Revision$
*/

#include <config.h>
#include <string.h>
#include <base/preface.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSProcessInfo.h>

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

#if HAVE_UNISTD_H
#include <unistd.h>
#endif
#if HAVE_WINDOWS_H
#  include <windows.h>
#endif

#if	defined(__MINGW__)
#define	WIN32ERR	((DWORD)0xFFFFFFFF)
#endif

/* determine filesystem max path length */

#if defined(_POSIX_VERSION) || defined(__WIN32__)
# include <limits.h>			/* for PATH_MAX */
# if defined(__MINGW32__)
#   include <sys/utime.h>
# else
#   include <utime.h>
# endif
#else
# if HAVE_SYS_PARAM_H
#  include <sys/param.h>		/* for MAXPATHLEN */
# endif
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

#if HAVE_SYS_MOUNT_H
#include <sys/mount.h>
#endif

#include <errno.h>

#ifdef HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif

#include <fcntl.h>
#if HAVE_PWD_H
#include <pwd.h>     /* For struct passwd */
#endif
#if HAVE_GRP_H
#include <grp.h>     /* For struct group */
#endif
#if HAVE_UTIME_H
# include <utime.h>
#endif

/*
 * On systems that have the O_BINARY flag, use it for a binary copy.
 */
#if defined(O_BINARY)
#define	GSBINIO	O_BINARY
#else
#define	GSBINIO	0
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
- (BOOL) _copyFile: (NSString*)source
	    toFile: (NSString*)destination
	   handler: (id)handler;

/* Recursively copies the contents of source directory to destination. */
- (BOOL) _copyPath: (NSString*)source
	    toPath: (NSString*)destination
	   handler: (id)handler;

- (NSDictionary*) _attributesAtPath: (NSString*)path
		       traverseLink: (BOOL)traverse
			    forCopy: (BOOL)copy;
@end /* NSFileManager (PrivateMethods) */

@interface NSDirectoryEnumerator (PrivateMethods)
- (NSDictionary*) _attributesForCopy;
@end


/*
 * NSFileManager implementation
 */

@implementation NSFileManager

// Getting the default manager

static NSFileManager* defaultManager = nil;

+ (NSFileManager*) defaultManager
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

- (void) dealloc
{
  TEST_RELEASE(_lastError);
  [super dealloc];
}

// Directory operations

- (BOOL) changeCurrentDirectoryPath: (NSString*)path
{
  const char* cpath = [self fileSystemRepresentationWithPath: path];
    
#if defined(__MINGW__)
  return SetCurrentDirectory(cpath) == TRUE ? YES : NO;
#else
  return (chdir(cpath) == 0);
#endif
}

- (BOOL) createDirectoryAtPath: (NSString*)path
		    attributes: (NSDictionary*)attributes
{
#if defined(__MINGW__)
  NSEnumerator *paths = [[path pathComponents] objectEnumerator];
  NSString *subPath;
  NSString *completePath = nil;

  while ((subPath = [paths nextObject]))
    {
      BOOL isDir = NO;
      if (completePath == nil)
	completePath = subPath;
      else
	completePath = [completePath stringByAppendingPathComponent:subPath];

      if ([self fileExistsAtPath:completePath isDirectory:&isDir]) 
	{
	  if (!isDir) 
	    NSLog(@"WARNING: during creation of directory %@:"
		  @" sub path %@ exists, but is not a directory !",
		  path, completePath);
        }
      else 
	{
	  const char *cpath;
	  cpath = [self fileSystemRepresentationWithPath: completePath];
	  if (CreateDirectory(cpath, NULL) == FALSE)
	    return NO;
        }
    }

  // change attributes of last directory
  return [self changeFileAttributes: attributes atPath: path];

#else
  const char	*cpath;
  char		dirpath[PATH_MAX+1];
  struct stat	statbuf;
  int		len, cur;
  NSDictionary	*needChown = nil;
    
  /*
   * If there is no file owner specified, and we are running setuid to
   * root, then we assume we need to change ownership to correct user.
   */
  if ([attributes objectForKey: NSFileOwnerAccountName] == nil 
    && [attributes objectForKey: NSFileOwnerAccountNumber] == nil 
    && geteuid() == 0 && [@"root" isEqualToString: NSUserName()] == NO)
    {
      needChown = [NSDictionary dictionaryWithObjectsAndKeys: 
			NSFileOwnerAccountName, NSUserName(), nil];
    }

  cpath = [self fileSystemRepresentationWithPath: path];
  len = strlen(cpath);
  if (len > PATH_MAX) // name too long
    {
      ASSIGN(_lastError, @"Could not create directory - name too long");
      return NO;
    }
    
  if (strcmp(cpath, "/") == 0 || len == 0) // cannot use "/" or ""
    {
      ASSIGN(_lastError, @"Could not create directory - no name given");
      return NO;
    }
    
  strcpy(dirpath, cpath);
  dirpath[len] = '\0';
  if (dirpath[len-1] == '/')
    dirpath[len-1] = '\0';
  cur = 0;
    
  do
    {
      // find next '/'
      while (dirpath[cur] != '/' && cur < len)
	cur++;
      // if first char is '/' then again; (cur == len) -> last component
      if (cur == 0)
	{
	  cur++;
	  continue;
	}
      // check if path from 0 to cur is valid
      dirpath[cur] = '\0';
      if (stat(dirpath, &statbuf) == 0)
	{
	  if (cur == len)
	    {
	      ASSIGN(_lastError, @"Could not create directory - already exists");
	      return NO;
	    }
	}
      else
	{
	  // make new directory
	  if (mkdir(dirpath, 0777) != 0)
	    {
	      NSString	*s;

	      s = [NSString stringWithFormat: @"Could not create '%s' - '%s'",
		dirpath, GSLastErrorStr(errno)];
	      ASSIGN(_lastError, s);
	      return NO;
	    }
	  // if last directory and attributes then change
	  if (cur == len && attributes)
	    {
	      if ([self changeFileAttributes: attributes 
		atPath: [self stringWithFileSystemRepresentation: dirpath
			length: cur]] == NO)
		return NO;
	      if (needChown)
		{
		  if ([self changeFileAttributes: needChown 
		    atPath: [self stringWithFileSystemRepresentation: dirpath
		      length: cur]] == NO)
		    {
		      NSLog(@"Failed to change ownership of '%s' to '%@'",
			      dirpath, NSUserName());
		    }
		}
	      return YES;
	    }
	}
      dirpath[cur] = '/';
      cur++;
    }
  while (cur < len);

  return YES;
#endif /* !MINGW */
}

- (NSString*) currentDirectoryPath
{
  char path[PATH_MAX];

#if defined(__MINGW__)
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
#endif /* !MINGW */

  return [self stringWithFileSystemRepresentation: path length: strlen(path)];
}

// File operations

- (BOOL) copyPath: (NSString*)source
	   toPath: (NSString*)destination
	  handler: handler
{
  BOOL		fileExists;
  NSDictionary	*attrs;
  NSString	*fileType;

  attrs = [self _attributesAtPath: source traverseLink: NO forCopy: YES];
  if (attrs == nil)
    {
      return NO;
    }
  fileExists = [self fileExistsAtPath: destination];
  if (fileExists)
    {
      return NO;
    }
  fileType = [attrs objectForKey: NSFileType];
  if ([fileType isEqualToString: NSFileTypeDirectory] == YES)
    {
      /* If destination directory is a descendant of source directory copying
	  isn't possible. */
      if ([[destination stringByAppendingString: @"/"]
	hasPrefix: [source stringByAppendingString: @"/"]])
	{
	  return NO;
	}

      [handler fileManager: self willProcessPath: destination];
      if ([self createDirectoryAtPath: destination attributes: attrs] == NO)
	{
	  if (handler)
	    {
	      NSDictionary* errorInfo
		= [NSDictionary dictionaryWithObjectsAndKeys: 
		  destination, @"Path", _lastError, @"Error", nil];
	      return [handler fileManager: self
		  shouldProceedAfterError: errorInfo];
	    }
	  else
	    {
	      return NO;
	    }
	}

      if ([self _copyPath: source toPath: destination handler: handler] == NO)
	{
	  return NO;
	}
    }
  else if ([fileType isEqualToString: NSFileTypeSymbolicLink] == YES)
    {
      NSString	*path;
      BOOL	result;

      [handler fileManager: self willProcessPath: source];
      path = [self pathContentOfSymbolicLinkAtPath: source];
      result = [self createSymbolicLinkAtPath: destination pathContent: path];
      if (result == NO)
	{
	  if (handler != nil)
	    {
	      NSDictionary	*errorInfo
		= [NSDictionary dictionaryWithObjectsAndKeys: 
		  source, @"Path", destination, @"ToPath",
			  @"cannot link to file", @"Error",
			  nil];
	      result = [handler fileManager: self
		    shouldProceedAfterError: errorInfo];
	    }
	  if (result == NO)
	    {
	      return NO;
	    }
	}
    }
  else
    {
      [handler fileManager: self willProcessPath: source];
      if ([self _copyFile: source toFile: destination handler: handler] == NO)
	{
	  return NO;
	}
    }
  [self changeFileAttributes: attrs atPath: destination];
  return YES;
}

- (BOOL) movePath: (NSString*)source
	   toPath: (NSString*)destination 
	  handler: handler
{
  BOOL sourceIsDir, fileExists;
  const char* sourcePath = [self fileSystemRepresentationWithPath: source];
  const char* destPath = [self fileSystemRepresentationWithPath: destination];
  NSString* destinationParent;
  unsigned int sourceDevice, destinationDevice;

  fileExists = [self fileExistsAtPath: source isDirectory: &sourceIsDir];
  if (!fileExists)
    return NO;

  fileExists = [self fileExistsAtPath: destination];
  if (fileExists)
    return NO;

  /* Check to see if the source and destination's parent are on the same
     physical device so we can perform a rename syscall directly. */
  sourceDevice = [[[self fileSystemAttributesAtPath: source]
			  objectForKey: NSFileSystemNumber]
			  unsignedIntValue];
  destinationParent = [destination stringByDeletingLastPathComponent];
  if ([destinationParent isEqual: @""])
    destinationParent = @".";
  destinationDevice
    = [[[self fileSystemAttributesAtPath: destinationParent]
		objectForKey: NSFileSystemNumber]
		unsignedIntValue];

  if (sourceDevice != destinationDevice)
    {
      /* If destination directory is a descendant of source directory moving
	  isn't possible. */
      if (sourceIsDir && [[destination stringByAppendingString: @"/"]
	hasPrefix: [source stringByAppendingString: @"/"]])
	return NO;

      if ([self copyPath: source toPath: destination handler: handler])
	{
	  NSDictionary* attributes;

	  attributes = [self _attributesAtPath: source
				  traverseLink: NO
				       forCopy: YES];
	  [self changeFileAttributes: attributes atPath: destination];
	  return [self removeFileAtPath: source handler: handler];
	}
      else
	return NO;
    }
  else
    {
      /* source and destination are on the same device so we can simply
	 invoke rename on source. */
      [handler fileManager: self willProcessPath: source];
      if (rename (sourcePath, destPath) == -1)
	{
	  if (handler)
	    {
	      NSDictionary* errorInfo
		  = [NSDictionary dictionaryWithObjectsAndKeys: 
		      source, @"Path",
		      destination, @"ToPath",
		      @"cannot move file", @"Error",
		      nil];
	      if ([handler fileManager: self
		shouldProceedAfterError: errorInfo])
		return YES;
	    }
	  return NO;
	}
      return YES;
    }

  return NO;
}

- (BOOL) linkPath: (NSString*)source
	   toPath: (NSString*)destination
	  handler: handler
{
  // TODO
  [self notImplemented: _cmd];
  return NO;
}

- (BOOL) removeFileAtPath: (NSString*)path
		  handler: handler
{
  BOOL		is_dir;
  const char	*cpath;

  if ([path isEqualToString: @"."] || [path isEqualToString: @".."])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to remove illegal path"];
    }

  if (handler != nil)
    {
      [handler fileManager: self willProcessPath: path];
    }
  cpath = [self fileSystemRepresentationWithPath: path];
  if (cpath == 0 || *cpath == '\0')
    {
      return NO;
    }
  else
    {
#if defined(__MINGW__)
      DWORD res;

      res = GetFileAttributes(cpath);
      if (res == WIN32ERR)
	return NO;

      if (res & FILE_ATTRIBUTE_DIRECTORY)
	is_dir = YES;
      else
	is_dir = NO;
#else
      struct stat statbuf;

      if (lstat(cpath, &statbuf) != 0)
	return NO;
    
      is_dir = ((statbuf.st_mode & S_IFMT) == S_IFDIR);
#endif /* MINGW */
    }

  if (!is_dir)
    {
#if defined(__MINGW__)
      if (DeleteFile(cpath) == FALSE)
#else
      if (unlink(cpath) < 0)
#endif
	{
	  BOOL	result;

	  if (handler)
	    {
	      NSMutableDictionary	*info;

	      info = [[NSMutableDictionary alloc] initWithCapacity: 3];
	      [info setObject: path forKey: @"Path"];
	      [info setObject: [NSString stringWithCString:
		GSLastErrorStr(errno)]
		       forKey: @"Error"];
	      result = [handler fileManager: self
		    shouldProceedAfterError: info];
	      RELEASE(info);
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
      NSArray   *contents = [self directoryContentsAtPath: path];
      unsigned	count = [contents count];
      unsigned	i;

      for (i = 0; i < count; i++)
	{
	  NSString		*item;
	  NSString		*next;
	  BOOL			result;
	  CREATE_AUTORELEASE_POOL(arp);

	  item = [contents objectAtIndex: i];
	  next = [path stringByAppendingPathComponent: item];
	  result = [self removeFileAtPath: next handler: handler];
	  RELEASE(arp);
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
	      [info setObject: [NSString stringWithCString:
		GSLastErrorStr(errno)]
		       forKey: @"Error"];
	      result = [handler fileManager: self
		    shouldProceedAfterError: info];
	      RELEASE(info);
	    }
	  else
	    result = NO;
	  return result;
	}
      else
	return YES;
    }
}

- (BOOL) createFileAtPath: (NSString*)path
		 contents: (NSData*)contents
	       attributes: (NSDictionary*)attributes
{
  const char	*cpath = [self fileSystemRepresentationWithPath: path];

#if	defined(__MINGW__)
  HANDLE fh;
  DWORD	written = 0;
  DWORD	len = [contents length];

  fh = CreateFile(cpath, GENERIC_WRITE, 0, 0, CREATE_ALWAYS,
    FILE_ATTRIBUTE_NORMAL, 0);
  if (fh == INVALID_HANDLE_VALUE)
    {
      return NO;
    }
  else
    {

      if (len > 0)
	{
	  WriteFile(fh, [contents bytes], len, &written, NULL);
	}
      CloseHandle(fh);
      if ([self changeFileAttributes: attributes atPath: path] == NO)
	{
	  return NO;
	}
    }
#else
  int	fd;
  int		len;
  int		written;

  fd = open(cpath, GSBINIO|O_WRONLY|O_TRUNC|O_CREAT, 0644);
  if (fd < 0)
    {
      return NO;
    }
  if ([self changeFileAttributes: attributes atPath: path] == NO)
    {
      close (fd);
      return NO;
    }

  /*
   * If there is no file owner specified, and we are running setuid to
   * root, then we assume we need to change ownership to correct user.
   */
  if ([attributes objectForKey: NSFileOwnerAccountName] == nil 
    && [attributes objectForKey: NSFileOwnerAccountNumber] == nil 
    && geteuid() == 0 && [@"root" isEqualToString: NSUserName()] == NO)
    {
      attributes = [NSDictionary dictionaryWithObjectsAndKeys: 
			NSFileOwnerAccountName, NSUserName(), nil];
      if (![self changeFileAttributes: attributes atPath: path])
	{
	  NSLog(@"Failed to change ownership of '%@' to '%@'",
		path, NSUserName());
	}
    }

  len = [contents length];
  if (len > 0)
    {
      written = write(fd, [contents bytes], len);
    }
  else
    {
      written = 0;
    }
  close (fd);
#endif
  return written == len;
}

// Getting and comparing file contents

- (NSData*) contentsAtPath: (NSString*)path
{
  return [NSData dataWithContentsOfFile: path];
}

- (BOOL) contentsEqualAtPath: (NSString*)path1 andPath: (NSString*)path2
{
  NSDictionary	*d1;
  NSDictionary	*d2;
  NSString	*t;

  if ([path1 isEqual: path2])
    return YES;
  d1 = [self fileAttributesAtPath: path1 traverseLink: NO];
  d2 = [self fileAttributesAtPath: path2 traverseLink: NO];
  t = [d1 objectForKey: NSFileType];
  if ([t isEqual: [d2 objectForKey: NSFileType]] == NO)
    return NO;
  if ([t isEqual: NSFileTypeRegular])
    {
      id	s1 = [d1 objectForKey: NSFileSize];
      id	s2 = [d2 objectForKey: NSFileSize];

      if ([s1 isEqual: s2] == YES)
	{
	  NSData	*c1 = [NSData dataWithContentsOfFile: path1];
	  NSData	*c2 = [NSData dataWithContentsOfFile: path2];

	  if ([c1 isEqual: c2])
	    return YES;
	}
      return NO;
    }
  else if ([t isEqual: NSFileTypeDirectory])
    {
      NSArray	*a1 = [self directoryContentsAtPath: path1];
      NSArray	*a2 = [self directoryContentsAtPath: path2];
      unsigned	index, count = [a1 count];
      BOOL	ok = YES;

      if ([a1 isEqual: a2] == NO)
	return NO;

      for (index = 0; ok == YES && index < count; index++)
	{
	  NSString	*n = [a1 objectAtIndex: index];
	  NSString	*p1;
	  NSString	*p2;
	  CREATE_AUTORELEASE_POOL(pool);

	  p1 = [path1 stringByAppendingPathComponent: n];
	  p2 = [path2 stringByAppendingPathComponent: n];
	  d1 = [self fileAttributesAtPath: p1 traverseLink: NO];
	  d2 = [self fileAttributesAtPath: p2 traverseLink: NO];
	  t = [d1 objectForKey: NSFileType];
	  if ([t isEqual: [d2 objectForKey: NSFileType]] == NO)
	    {
	      ok = NO;
	    }
	  else if ([t isEqual: NSFileTypeDirectory])
	    {
	      ok = [self contentsEqualAtPath: p1 andPath: p2];
	    }
	  RELEASE(pool);
	}
      return ok;
    }
  else
    return YES;
}

// Determining access to files

- (BOOL) fileExistsAtPath: (NSString*)path
{
  return [self fileExistsAtPath: path isDirectory: NULL];
}

- (BOOL) fileExistsAtPath: (NSString*)path isDirectory: (BOOL*)isDirectory
{
  const char* cpath = [self fileSystemRepresentationWithPath: path];

  if (cpath == 0 || *cpath == '\0')
    {
      return NO;
    }
  else
    {
#if defined(__MINGW__)
      DWORD res;

      res = GetFileAttributes(cpath);
      if (res == WIN32ERR)
	{
	  return NO;
	}
      if (isDirectory != 0)
	{
	  if (res & FILE_ATTRIBUTE_DIRECTORY)
	    {
	      *isDirectory = YES;
	    }
	  else
	    {
	      *isDirectory = NO;
	    }
	}
      return YES;
#else
      struct stat statbuf;

      if (stat(cpath, &statbuf) != 0)
	return NO;
    
      if (isDirectory)
	{
	  *isDirectory = ((statbuf.st_mode & S_IFMT) == S_IFDIR);
	}
    
      return YES;
#endif /* MINGW */
    }
}

- (BOOL) isReadableFileAtPath: (NSString*)path
{
  const char* cpath = [self fileSystemRepresentationWithPath: path];

  if (cpath == 0 || *cpath == '\0')
    return NO;
  else
    {
#if defined(__MINGW__)
      DWORD res= GetFileAttributes(cpath);

      if (res == WIN32ERR)
        return NO;
      return YES;
#else
      return (access(cpath, R_OK) == 0);
#endif
    }
}

- (BOOL) isWritableFileAtPath: (NSString*)path
{
  const char* cpath = [self fileSystemRepresentationWithPath: path];

  if (cpath == 0 || *cpath == '\0')
    return NO;
  else
    {
#if defined(__MINGW__)
      DWORD res= GetFileAttributes(cpath);

      if (res == WIN32ERR)
        return NO;
      return (res & FILE_ATTRIBUTE_READONLY) ? NO : YES;
#else
      return (access(cpath, W_OK) == 0);
#endif
    }
}

- (BOOL) isExecutableFileAtPath: (NSString*)path
{
  const char* cpath = [self fileSystemRepresentationWithPath: path];

  if (cpath == 0 || *cpath == '\0')
    return NO;
  else
    {
#if defined(__MINGW__)
      DWORD res= GetFileAttributes(cpath);
      int len = strlen(cpath);

      if (res == WIN32ERR)
        return NO;
      if (len > 4 && strcmp(&cpath[len-4], ".exe") == 0)
	return YES;
      /* FIXME: On unix, directory accessable == executable, so we simulate that
	 here for Windows. Is there a better check for directory access? */
      if (res & FILE_ATTRIBUTE_DIRECTORY)
	return YES;
      return NO;
#else
      return (access(cpath, X_OK) == 0);
#endif
    }
}

- (BOOL) isDeletableFileAtPath: (NSString*)path
{
  const char* cpath = [self fileSystemRepresentationWithPath: path];

  if (cpath == 0 || *cpath == '\0')
    return NO;
  else
    {
      // TODO - handle directories
#if defined(__MINGW__)
      DWORD res= GetFileAttributes(cpath);

      if (res == WIN32ERR)
        return NO;
      return (res & FILE_ATTRIBUTE_READONLY) ? NO : YES;
#else
      cpath = [self fileSystemRepresentationWithPath: 
	[path stringByDeletingLastPathComponent]];
    
      return  (access(cpath, X_OK || W_OK) != 0);
#endif
    }
}

- (NSDictionary*) fileAttributesAtPath: (NSString*)path traverseLink: (BOOL)flag
{
  return [self _attributesAtPath: path traverseLink: flag forCopy: NO];
}

- (NSDictionary*) fileSystemAttributesAtPath: (NSString*)path
{
#if defined(__MINGW__)
  unsigned long long totalsize, freesize;
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
    &BytesPerSector, &NumberFreeClusters, &TotalNumberClusters))
    return nil;

  totalsize = (unsigned long long)TotalNumberClusters
    * (unsigned long long)SectorsPerCluster
    * (unsigned long long)BytesPerSector;
  freesize = (unsigned long long)NumberFreeClusters
    * (unsigned long long)SectorsPerCluster
    * (unsigned long long)BytesPerSector;
  
  values[0] = [NSNumber numberWithUnsignedLongLong: totalsize];
  values[1] = [NSNumber numberWithUnsignedLongLong: freesize];
  values[2] = [NSNumber numberWithLong: LONG_MAX];
  values[3] = [NSNumber numberWithLong: LONG_MAX];
  values[4] = [NSNumber numberWithUnsignedInt: 0];
  
  return [NSDictionary dictionaryWithObjects: values forKeys: keys count: 5];
  
#else
#if HAVE_SYS_VFS_H || HAVE_SYS_STATFS_H || HAVE_SYS_MOUNT_H
  struct stat statbuf;
#if HAVE_STATVFS
  struct statvfs statfsbuf;
#else
  struct statfs statfsbuf;
#endif
  unsigned long long totalsize, freesize;
  const char* cpath = [self fileSystemRepresentationWithPath: path];
  
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

  totalsize = (unsigned long long) statfsbuf.f_bsize
    * (unsigned long long) statfsbuf.f_blocks;
  freesize = (unsigned long long) statfsbuf.f_bsize
    * (unsigned long long) statfsbuf.f_bavail;
  
  values[0] = [NSNumber numberWithUnsignedLongLong: totalsize];
  values[1] = [NSNumber numberWithUnsignedLongLong: freesize];
  values[2] = [NSNumber numberWithLong: statfsbuf.f_files];
  values[3] = [NSNumber numberWithLong: statfsbuf.f_ffree];
  values[4] = [NSNumber numberWithUnsignedLong: statbuf.st_dev];
  
  return [NSDictionary dictionaryWithObjects: values forKeys: keys count: 5];
#else
  return nil;
#endif
#endif /* MINGW */
}

- (BOOL) changeFileAttributes: (NSDictionary*)attributes atPath: (NSString*)path
{
  const char	*cpath = [self fileSystemRepresentationWithPath: path];
  NSNumber	*num;
  NSString	*str;
  NSDate	*date;
  BOOL		allOk = YES;

#ifndef __MINGW__
  num = [attributes objectForKey: NSFileOwnerAccountNumber];
  if (num)
    {
      if (chown(cpath, [num intValue], -1) != 0)
	{
	  allOk = NO;
	  str = [NSString stringWithFormat:
	    @"Unable to change NSFileOwnerAccountNumber to '%@'", num];
	  ASSIGN(_lastError, str);
	}
    }
  else
    {
      if ((str = [attributes objectForKey: NSFileOwnerAccountName]) != nil)
	{
	  BOOL	ok = NO;
#if HAVE_PWD_H	
	  struct passwd *pw = getpwnam([str cString]);

	  if (pw)
	    {
	      ok = (chown(cpath, pw->pw_uid, -1) == 0);
	      chown(cpath, -1, pw->pw_gid);
	    }
#endif
	  if (ok == NO)
	    {
	      allOk = NO;
	      str = [NSString stringWithFormat:
		@"Unable to change NSFileOwnerAccountName to '%@'", str];
	      ASSIGN(_lastError, str);
	    }
	}
    }

  num = [attributes objectForKey: NSFileGroupOwnerAccountNumber];
  if (num)
    {
      if (chown(cpath, -1, [num intValue]) != 0)
	{
	  allOk = NO;
	  str = [NSString stringWithFormat:
	    @"Unable to change NSFileGroupOwnerAccountNumber to '%@'", num];
	  ASSIGN(_lastError, str);
	}
    }
  else if ((str=[attributes objectForKey: NSFileGroupOwnerAccountName]) != nil)
    {
      BOOL	ok = NO;
#if HAVE_GRP_H
      struct group *gp = getgrnam([str cString]);

      if (gp)
	{
	  if (chown(cpath, -1, gp->gr_gid) == 0)
	    ok = YES;
	}
#endif
      if (ok == NO)
	{
	  allOk = NO;
	  str = [NSString stringWithFormat:
	    @"Unable to change NSFileGroupOwnerAccountName to '%@'", str];
	  ASSIGN(_lastError, str);
	}
    }
#endif	/* __MINGW__ */

  num = [attributes objectForKey: NSFilePosixPermissions];
  if (num)
    {
      if (chmod(cpath, [num intValue]) != 0)
	{
	  allOk = NO;
	  str = [NSString stringWithFormat:
	    @"Unable to change NSFilePosixPermissions to '%o'", [num intValue]];
	  ASSIGN(_lastError, str);
	}
    }
    
  date = [attributes objectForKey: NSFileModificationDate];
  if (date)
    {
      BOOL	ok = NO;
      struct stat sb;
#if  defined(__WIN32__) || defined(_POSIX_VERSION)
      struct utimbuf ub;
#else
      time_t ub[2];
#endif

      if (stat(cpath, &sb) != 0)
	{
	  ok = NO;
	}
#if  defined(__WIN32__)
      else if (sb.st_mode & _S_IFDIR)
	{
	  ok = YES;	// Directories don't have modification times.
	}
#endif
      else
	{
#if  defined(__WIN32__) || defined(_POSIX_VERSION)
	  ub.actime = sb.st_atime;
	  ub.modtime = [date timeIntervalSince1970];
	  ok = (utime(cpath, &ub) == 0);
#else
	  ub[0] = sb.st_atime;
	  ub[1] = [date timeIntervalSince1970];
	  ok = (utime((char*)cpath, ub) == 0);
#endif
	}
      if (ok == NO)
	{
	  allOk = NO;
	  str = [NSString stringWithFormat:
	    @"Unable to change NSFileModificationDate to '%@'", date];
	  ASSIGN(_lastError, str);
	}
    }
    
  return allOk;
}

// Discovering directory contents

- (NSArray*) directoryContentsAtPath: (NSString*)path
{
  NSDirectoryEnumerator	*direnum;
  NSMutableArray	*content;
  IMP			nxtImp;
  IMP			addImp;
  BOOL			is_dir;

  /*
   * See if this is a directory (don't follow links).
   */
  if ([self fileExistsAtPath: path isDirectory: &is_dir] == NO || is_dir == NO)
    return nil;

  /* We initialize the directory enumerator with justContents == YES, 
     which tells the NSDirectoryEnumerator code that we only enumerate 
     the contents non-recursively once, and exit.  NSDirectoryEnumerator 
     can perform some optms using this assumption. */
  direnum = [[NSDirectoryEnumerator alloc] initWithDirectoryPath: path 
					   recurseIntoSubdirectories: NO
					   followSymlinks: NO
					   justContents: YES];
  content = [NSMutableArray arrayWithCapacity: 128];

  nxtImp = [direnum methodForSelector: @selector(nextObject)];
  addImp = [content methodForSelector: @selector(addObject:)];

  while ((path = (*nxtImp)(direnum, @selector(nextObject))) != nil)
    (*addImp)(content, @selector(addObject:), path);

  RELEASE(direnum);

  return content;
}

- (NSDirectoryEnumerator*) enumeratorAtPath: (NSString*)path
{
  return AUTORELEASE([[NSDirectoryEnumerator alloc]
		       initWithDirectoryPath: path 
		       recurseIntoSubdirectories: YES
		       followSymlinks: NO
		       justContents: NO]);
}

- (NSArray*) subpathsAtPath: (NSString*)path
{
  NSDirectoryEnumerator	*direnum;
  NSMutableArray	*content;
  BOOL			isDir;
  IMP			nxtImp;
  IMP			addImp;
  
  if (![self fileExistsAtPath: path isDirectory: &isDir] || !isDir)
    return nil;

  direnum = [[NSDirectoryEnumerator alloc] initWithDirectoryPath: path 
					   recurseIntoSubdirectories: YES
					   followSymlinks: NO
					   justContents: NO];
  content = [NSMutableArray arrayWithCapacity: 128];
  
  nxtImp = [direnum methodForSelector: @selector(nextObject)];
  addImp = [content methodForSelector: @selector(addObject:)];
  
  while ((path = (*nxtImp)(direnum, @selector(nextObject))) != nil)
    {
      (*addImp)(content, @selector(addObject:), path);
    }
  
  RELEASE(direnum);

  return content;
}

// Symbolic-link operations

- (BOOL) createSymbolicLinkAtPath: (NSString*)path
		      pathContent: (NSString*)otherPath
{
#if HAVE_SYMLINK
  const char* newpath = [self fileSystemRepresentationWithPath: path];
  const char* oldpath = [self fileSystemRepresentationWithPath: otherPath];
    
  return (symlink(oldpath, newpath) == 0);
#else
  return NO;
#endif
}

- (NSString*) pathContentOfSymbolicLinkAtPath: (NSString*)path
{
#if HAVE_READLINK
  char  lpath[PATH_MAX];
  const char* cpath = [self fileSystemRepresentationWithPath: path];
  int   llen = readlink(cpath, lpath, PATH_MAX-1);
    
  if (llen > 0)
    return [self stringWithFileSystemRepresentation: lpath length: llen];
  else
    return nil;
#else
  return nil;
#endif
}

// Converting file-system representations

- (const char*) fileSystemRepresentationWithPath: (NSString*)path
{
#ifdef __MINGW__
  /*
   * If path is in Unix format, transmorgrify it so Windows functions
   * can handle it
   */  
  NSString	*newpath = path;
  const char	*c_path = [path cString];
  int		len = [path length];

  if (c_path == 0)
    {
      return 0;
    }
  if (len >= 3 && c_path[0] == '/' && c_path[1] == '/' && isalpha(c_path[2]))
    {
      if (len == 3 || c_path[3] == '/')
        {
          /* Cygwin "//c/" type absolute path */
          newpath = [NSString stringWithFormat: @"%c:%s", c_path[2],
	    &c_path[3]];
          newpath = [newpath stringByReplacingString: @"/" withString: @"\\"];
        }
      else
        {
	  /* Windows absolute UNC path "//name/" */
          newpath = [newpath stringByReplacingString: @"/" withString: @"\\"];
        }
    }
  else if (isalpha(c_path[0]) && c_path[1] == ':')
    {
      /* Unix absolute path */
      newpath = [newpath stringByReplacingString: @"/" withString: @"\\"];
    }
  else if (c_path[0] == '/')
    {
      NSDictionary	*env;
      NSString		*cyghome;

      env = [[NSProcessInfo processInfo] environment];
      cyghome = [env objectForKey: @"CYGWIN_HOME"];
      if (cyghome != nil)
        {
          /* FIXME: Find cygwin drive? */
	  newpath = cyghome;
          newpath = [newpath stringByAppendingPathComponent: path];
          newpath = [newpath stringByReplacingString: @"/" withString: @"\\"];
        }
    }
  /* FIXME: Should we translate relative paths? */
  return [newpath cString];
#else
  return [path cString];
#endif
}

- (NSString*) stringWithFileSystemRepresentation: (const char*)string
					  length: (unsigned int)len
{
  return [NSString stringWithCString: string length: len];
}

@end /* NSFileManager */

/*
 * NSDirectoryEnumerator implementation
 *
 * The Objective-C interface hides a traditional C implementation.
 * This was the only way I could get near the speed of standard unix
 * tools for big directories.
 */

/* A directory to enumerate.  We keep a stack of the directories we
   still have to enumerate.  We start by putting the top-level
   directory into the stack, then we start reading files from it
   (using readdir).  If we find a file which is actually a directory,
   and if we have to recurse into it, we create a new
   GSEnumeratedDirectory struct for the subdirectory, open its DIR
   *pointer for reading, and put it on top of the stack, so next time
   -nextObject is called, it will read from that directory instead of
   the top level one.  Once all the subdirectory is read, it is
   removed from the stack, so the top of the stack if the top
   directory again, and enumeration continues in there.  */
typedef	struct	_GSEnumeratedDirectory {
  char *path;
  DIR *pointer;
} GSEnumeratedDirectory;


inline void gsedRelease(GSEnumeratedDirectory X)
{
  free(X.path);
  closedir(X.pointer);
}

#define GSI_ARRAY_TYPES	0
#define GSI_ARRAY_TYPE	GSEnumeratedDirectory
#define GSI_ARRAY_RELEASE(A, X)   gsedRelease(X.ext)
#define GSI_ARRAY_RETAIN(A, X)

#include <base/GSIArray.h>

/* Portable replacement for strdup - return a copy of original.  */
inline char *custom_strdup (const char *original)
{
  char *result;
  unsigned length = sizeof(char) * (strlen (original) + 1);
  
  result = NSZoneMalloc(NSDefaultMallocZone(), length);
  memcpy(result, original, length);
  return result;
}

/* The return value of this function is to be freed by using NSZoneFree().
   The function takes for granted that path and file are correct
   filesystem paths; that path does not end with a path separator, and
   file does not begin with a path separator. */
inline char *append_file_to_path (const char *path, const char *file)
{
  unsigned path_length = strlen(path);
  unsigned file_length = strlen(file);
  unsigned total_length = path_length + 1 + file_length;
  char *result;

  if (path_length == 0)
    {
      return custom_strdup(file);
    }

  result = NSZoneMalloc(NSDefaultMallocZone(), 
			sizeof(char) * total_length  + 1);
  
  memcpy(result, path, sizeof(char) * path_length);
  
#ifdef __MINGW__
  result[path_length] = '\\';
#else
  result[path_length] = '/';
#endif

  memcpy(&result[path_length + 1], file, sizeof(char) * file_length);
  
  result[total_length] = '\0';

  return result;  
}

static SEL swfsSel = 0;

@implementation NSDirectoryEnumerator

+ (void) initialize
{
  if (self == [NSDirectoryEnumerator class])
    {
      /* Initialize the default manager which we access directly */
      [NSFileManager defaultManager];
      swfsSel = @selector(stringWithFileSystemRepresentation:length:);
    }
}

// Initializing

- (id) initWithDirectoryPath: (NSString*)path 
   recurseIntoSubdirectories: (BOOL)recurse
	      followSymlinks: (BOOL)follow
		justContents: (BOOL)justContents
{
  DIR *dir_pointer;
  const char *topPath;
  
  _stringWithFileSysImp = (NSString *(*)(id, SEL, char *, unsigned))
    [defaultManager methodForSelector: swfsSel];
  
  _stack = NSZoneMalloc([self zone], sizeof(GSIArray_t));
  GSIArrayInitWithZoneAndCapacity(_stack, [self zone], 64);
  
  _flags.isRecursive = recurse;
  _flags.isFollowing = follow;
  _flags.justContents = justContents;
  topPath = [defaultManager fileSystemRepresentationWithPath: path];
  _top_path = custom_strdup(topPath);
  
  dir_pointer = opendir(_top_path);
  
  if (dir_pointer)
    {
      GSIArrayItem item;
      
      item.ext.path = custom_strdup("");
      item.ext.pointer = dir_pointer;
      
      GSIArrayAddItem(_stack, item);
    }
  else
    {
      NSLog(@"Failed to recurse into directory '%@' - %s", path, 
	    GSLastErrorStr(errno));
    }
  
  return self;
}

- (void) dealloc
{
  GSIArrayEmpty(_stack);
  NSZoneFree([self zone], _stack);
  NSZoneFree(NSDefaultMallocZone(), _top_path);
  if (_current_file_path != NULL)
    {
      NSZoneFree(NSDefaultMallocZone(), _current_file_path);
    }
  [super dealloc];
}

// Getting attributes

- (NSDictionary*) directoryAttributes
{
  NSString *topPath;
  
  topPath = _stringWithFileSysImp(defaultManager, swfsSel, _top_path, 
				  strlen(_top_path));

  return [defaultManager fileAttributesAtPath: topPath
			 traverseLink: _flags.isFollowing];
}

- (NSDictionary*) fileAttributes
{
  NSString *currentFilePath;
  
  currentFilePath = _stringWithFileSysImp(defaultManager, swfsSel, 
					  _current_file_path, 
					  strlen(_current_file_path));

  return [defaultManager fileAttributesAtPath: currentFilePath
			 traverseLink: _flags.isFollowing];
}

// Skipping subdirectories

- (void) skipDescendents
{
  if (GSIArrayCount(_stack) > 0)
    {
      GSIArrayRemoveLastItem(_stack);
      if (_current_file_path != NULL)
	{
	  NSZoneFree(NSDefaultMallocZone(), _current_file_path);
	  _current_file_path = NULL;
	}
    }
}

// Enumerate next

- (id) nextObject
{
  /*
    finds the next file according to the top enumerator
    - if there is a next file it is put in currentFile
    - if the current file is a directory and if isRecursive calls 
    recurseIntoDirectory: currentFile
    - if the current file is a symlink to a directory and if isRecursive 
    and isFollowing calls recurseIntoDirectory: currentFile
    - if at end of current directory pops stack and attempts to
    find the next entry in the parent
    - sets currentFile to nil if there are no more files to enumerate
  */
  char *return_file_name = NULL;

  if (_current_file_path != NULL)
    {
      NSZoneFree(NSDefaultMallocZone(), _current_file_path);
      _current_file_path = NULL;
    }

  while (GSIArrayCount(_stack) > 0)
    {
      GSEnumeratedDirectory dir = GSIArrayLastItem(_stack).ext;
      struct dirent *dirbuf;
      struct stat statbuf;
      
      dirbuf = readdir(dir.pointer);
      if (dirbuf)
	{
	  /* Skip "." and ".." directory entries */
	  if (strcmp(dirbuf->d_name, ".") == 0 
	      || strcmp(dirbuf->d_name, "..") == 0)
	    continue;
	  
	  /* Name of file to return  */
	  return_file_name = append_file_to_path(dir.path, dirbuf->d_name);
	  
	  /* TODO - can this one can be removed ? */
	  if (!_flags.justContents)
	    {
	      _current_file_path = append_file_to_path(_top_path, 
						       return_file_name);
	    }
  	  if (_flags.isRecursive == YES)
	    {
	      // Do not follow links
#ifdef S_IFLNK
	      if (!_flags.isFollowing)
		{
		  if (lstat(_current_file_path, &statbuf) != 0)
		    break;
		  // If link then return it as link
		  if (S_IFLNK == (S_IFMT & statbuf.st_mode)) 
		    break;
		}
	      else
#endif
		{
		  if (stat(_current_file_path, &statbuf) != 0)
		    break;
		}
	      if (S_IFDIR == (S_IFMT & statbuf.st_mode))
		{
		  DIR*  dir_pointer;
		  
		  dir_pointer = opendir(_current_file_path);
		  
		  if (dir_pointer)
		    {
		      GSIArrayItem item;
		      
		      item.ext.path = custom_strdup(return_file_name);
		      item.ext.pointer = dir_pointer;
      
		      GSIArrayAddItem(_stack, item);
		    }
		  else
		    {
		      NSLog(@"Failed to recurse into directory '%s' - %s",
			_current_file_path, GSLastErrorStr(errno));
		    }
		}
	    }
	  break;	// Got a file name - break out of loop
	}
      else
	{
	  GSIArrayRemoveLastItem(_stack);
	  if (_current_file_path != NULL)
	    {
	      NSZoneFree(NSDefaultMallocZone(), _current_file_path);
	      _current_file_path = NULL;
	    }
	}
    }
  if (return_file_name == NULL)
    {
      return nil;
    }
  else
    {
      NSString *result = _stringWithFileSysImp(defaultManager, swfsSel, 
					       return_file_name, 
					       strlen(return_file_name));
      NSZoneFree(NSDefaultMallocZone(), return_file_name);
      return result;
    }
}

@end /* NSDirectoryEnumerator */

@implementation NSDirectoryEnumerator (PrivateMethods)
- (NSDictionary*) _attributesForCopy
{
  NSString *currentFilePath;
  
  currentFilePath = _stringWithFileSysImp(defaultManager, swfsSel, 
					  _current_file_path, 
					  strlen(_current_file_path));

  return [defaultManager _attributesAtPath: currentFilePath
			 traverseLink: _flags.isFollowing
			 forCopy: YES];
}
@end

/*
 * Attributes dictionary access
 */

@implementation NSDictionary(NSFileAttributes)
- (unsigned long long) fileSize
{
  return [[self objectForKey: NSFileSize] unsignedLongLongValue];
}

- (NSString*) fileType
{
  return [self objectForKey: NSFileType];
}

- (NSString*) fileOwnerAccountName
{
  return [self objectForKey: NSFileOwnerAccountName];
}

- (unsigned long) fileOwnerAccountNumber
{
  return [[self objectForKey: NSFileOwnerAccountNumber] unsignedIntValue];
}

- (NSString*) fileGroupOwnerAccountName
{
  return [self objectForKey: NSFileGroupOwnerAccountName];
}

- (unsigned long) fileGroupOwnerAccountNumber
{
  return [[self objectForKey: NSFileGroupOwnerAccountNumber] unsignedIntValue];
}

- (NSDate*) fileModificationDate
{
  return [self objectForKey: NSFileModificationDate];
}

- (unsigned long) filePosixPermissions
{
  return [[self objectForKey: NSFilePosixPermissions] unsignedLongValue];
}

- (unsigned long) fileSystemNumber
{
  return [[self objectForKey: NSFileSystemNumber] unsignedLongValue];
}

- (unsigned long) fileSystemFileNumber
{
  return [[self objectForKey: NSFileSystemFileNumber] unsignedLongValue];
}
@end

@implementation NSFileManager (PrivateMethods)

- (BOOL) _copyFile: (NSString*)source
	    toFile: (NSString*)destination
	   handler: (id)handler
{
#if defined(__MINGW__)
  if (CopyFile([self fileSystemRepresentationWithPath: source],
    [self fileSystemRepresentationWithPath: destination], NO))
    {
      return YES;
    }
  if (handler != nil)
    {
      NSDictionary	*errorInfo
	= [NSDictionary dictionaryWithObjectsAndKeys:
                       source, @"Path",
                       @"cannot copy file", @"Error",
                       destination, @"ToPath",
                       nil];
      return [handler fileManager: self
	  shouldProceedAfterError: errorInfo];
    }
  else
    {
      return NO;
    }
#else
  NSDictionary	*attributes;
  int		i;
  int		bufsize = 8096;
  int		sourceFd;
  int		destFd;
  int		fileSize;
  int		fileMode;
  int		rbytes;
  int		wbytes;
  char		buffer[bufsize];

  /* Assumes source is a file and exists! */
  NSAssert1 ([self fileExistsAtPath: source],
    @"source file '%@' does not exist!", source);

  attributes = [self _attributesAtPath: source traverseLink: NO forCopy: YES];
  NSAssert1 (attributes, @"could not get the attributes for file '%@'",
    source);

  fileSize = [[attributes objectForKey: NSFileSize] intValue];
  fileMode = [[attributes objectForKey: NSFilePosixPermissions] intValue];

  /* Open the source file. In case of error call the handler. */
  sourceFd = open([self fileSystemRepresentationWithPath: source],
    GSBINIO|O_RDONLY);
  if (sourceFd < 0)
    {
      if (handler != nil)
	{
	  NSDictionary	*errorInfo
	    = [NSDictionary dictionaryWithObjectsAndKeys: 
		      source, @"Path",
		      @"cannot open file for reading", @"Error",
		      nil];
	  return [handler fileManager: self
	      shouldProceedAfterError: errorInfo];
	}
      else
	{
	  return NO;
	}
    }

  /* Open the destination file. In case of error call the handler. */
  destFd = open([self fileSystemRepresentationWithPath: destination],
    GSBINIO|O_WRONLY|O_CREAT|O_TRUNC, fileMode);
  if (destFd < 0)
    {
      if (handler != nil)
	{
	  NSDictionary	*errorInfo
	    = [NSDictionary dictionaryWithObjectsAndKeys: 
		      destination, @"ToPath",
		      @"cannot open file for writing", @"Error",
		      nil];
	  close (sourceFd);
	  return [handler fileManager: self
	      shouldProceedAfterError: errorInfo];
	}
      else
	{
	  return NO;
	}
    }

  /* Read bufsize bytes from source file and write them into the destination
     file. In case of errors call the handler and abort the operation. */
  for (i = 0; i < fileSize; i += rbytes)
    {
      rbytes = read (sourceFd, buffer, bufsize);
      if (rbytes < 0)
	{
	  if (handler != nil)
	    {
	      NSDictionary	*errorInfo
		= [NSDictionary dictionaryWithObjectsAndKeys: 
			  source, @"Path",
			  @"cannot read from file", @"Error",
			  nil];
	      close (sourceFd);
	      close (destFd);
	      return [handler fileManager: self
		  shouldProceedAfterError: errorInfo];
	    }
	  else
	    {
	      return NO;
	    }
	}

      wbytes = write (destFd, buffer, rbytes);
      if (wbytes != rbytes)
	{
	  if (handler != nil)
	    {
	      NSDictionary	*errorInfo
		= [NSDictionary dictionaryWithObjectsAndKeys: 
			  source, @"Path",
			  destination, @"ToPath",
			  @"cannot write to file", @"Error",
			  nil];
	      close (sourceFd);
	      close (destFd);
	      return [handler fileManager: self
		  shouldProceedAfterError: errorInfo];
	    }
	  else
	    {
	      return NO;
	    }
	}
    }
  close (sourceFd);
  close (destFd);

  return YES;
#endif
}

- (BOOL) _copyPath: (NSString*)source
	    toPath: (NSString*)destination
	   handler: handler
{
  NSDirectoryEnumerator	*enumerator;
  NSString		*dirEntry;
  CREATE_AUTORELEASE_POOL(pool);

  enumerator = [self enumeratorAtPath: source];
  while ((dirEntry = [enumerator nextObject]))
    {
      NSString		*sourceFile;
      NSString		*fileType;
      NSString		*destinationFile;
      NSDictionary	*attributes;

      attributes = [enumerator _attributesForCopy];
      fileType = [attributes objectForKey: NSFileType];
      sourceFile = [source stringByAppendingPathComponent: dirEntry];
      destinationFile
	= [destination stringByAppendingPathComponent: dirEntry];

      [handler fileManager: self willProcessPath: sourceFile];
      if ([fileType isEqual: NSFileTypeDirectory])
	{
	  if (![self createDirectoryAtPath: destinationFile
				attributes: attributes])
	    {
	      if (handler)
		{
		  NSDictionary	*errorInfo;

		  errorInfo = [NSDictionary dictionaryWithObjectsAndKeys: 
		    destinationFile, @"Path",
		    _lastError, @"Error", nil];
		  if (![handler fileManager: self
		    shouldProceedAfterError: errorInfo])
		    return NO;
		}
	      else
		return NO;
	    }
	  else
	    {
	      [enumerator skipDescendents];
	      if (![self _copyPath: sourceFile
			    toPath: destinationFile
			   handler: handler])
		return NO;
	    }
	}
      else if ([fileType isEqual: NSFileTypeRegular])
	{
	  if (![self _copyFile: sourceFile
			toFile: destinationFile
		       handler: handler])
	    return NO;
	}
      else if ([fileType isEqual: NSFileTypeSymbolicLink])
	{
	  if (![self createSymbolicLinkAtPath: destinationFile
				  pathContent: sourceFile])
	    {
	      if (handler)
		{
		  NSDictionary	*errorInfo
		    = [NSDictionary dictionaryWithObjectsAndKeys: 
			      sourceFile, @"Path",
			      destinationFile, @"ToPath",
			      @"cannot create symbolic link", @"Error",
			      nil];
		  if (![handler fileManager: self
		    shouldProceedAfterError: errorInfo])
		    return NO;
		}
	      else
		return NO;
	    }
	}
      else
	{
	  NSString	*s;

	  s = [NSString stringWithFormat: @"cannot copy file type '%@'",
	    fileType];
	  ASSIGN(_lastError, s);
	  NSLog(@"%@: %@", sourceFile, s);
	  continue;
	}
      [self changeFileAttributes: attributes atPath: destinationFile];
    }
  RELEASE(pool);

  return YES;
}

#if (defined(sparc) && defined(DEBUG))
static int sparc_warn = 0;
#endif

- (NSDictionary*) _attributesAtPath: (NSString*)path
		       traverseLink: (BOOL)traverse
			    forCopy: (BOOL)copy
{
  struct stat statbuf;
  const char* cpath = [self fileSystemRepresentationWithPath: path];
  int mode;
  int count;
  id values[12];
  id keys[12] = {
    NSFileSize,
    NSFileModificationDate,
    NSFileReferenceCount,
    NSFileSystemNumber,
    NSFileSystemFileNumber,
    NSFileDeviceIdentifier,
    NSFilePosixPermissions,
    NSFileType,
    NSFileOwnerAccountName,
    NSFileGroupOwnerAccountName,
    NSFileOwnerAccountNumber,
    NSFileGroupOwnerAccountNumber
  };

#if defined(__MINGW__)
  if (stat(cpath, &statbuf) != 0)
    {
      return nil;
    }
#else /* !(__MINGW__) */
  if (traverse)
    {
      if (stat(cpath, &statbuf) != 0)
	{
	  return nil;
	}
    }
#ifdef S_IFLNK
  else
    {
      if (lstat(cpath, &statbuf) != 0)
	{
	  return nil;
	}
    }
#endif /* (S_IFLNK) */
#endif /* (__MINGW__) */
    
  values[0] = [NSNumber numberWithUnsignedLongLong: statbuf.st_size];
  values[1] = [NSDate dateWithTimeIntervalSince1970: statbuf.st_mtime];
  values[2] = [NSNumber numberWithUnsignedInt: statbuf.st_nlink];
  values[3] = [NSNumber numberWithUnsignedLong: statbuf.st_dev];
  values[4] = [NSNumber numberWithUnsignedLong: statbuf.st_ino];
  values[5] = [NSNumber numberWithUnsignedInt: statbuf.st_dev];
  values[6] = [NSNumber numberWithUnsignedInt: statbuf.st_mode];
  
  mode = statbuf.st_mode & S_IFMT;

  if (mode == S_IFREG)
    values[7] = NSFileTypeRegular;
  else if (mode == S_IFDIR)
    values[7] = NSFileTypeDirectory;
  else if (mode == S_IFCHR)
    values[7] = NSFileTypeCharacterSpecial;
  else if (mode == S_IFBLK)
    values[7] = NSFileTypeBlockSpecial;
#ifdef S_IFLNK
  else if (mode == S_IFLNK)
    values[7] = NSFileTypeSymbolicLink;
#endif
  else if (mode == S_IFIFO)
    values[7] = NSFileTypeFifo;
#ifdef S_IFSOCK
  else if (mode == S_IFSOCK)
    values[7] = NSFileTypeSocket;
#endif
  else
    values[7] = NSFileTypeUnknown;

  if (copy == NO)
    {
#if HAVE_PWD_H	
      {
	struct passwd *pw;

	pw = getpwuid(statbuf.st_uid);

	if (pw)
	  {
	    values[8] = [NSString stringWithCString: pw->pw_name];
	  }
	else
	  {
	    values[8] = @"UnknownUser";
	  }
      }
#else
      values[8] = @"UnknownUser";
#endif /* HAVE_PWD_H */

#if defined(HAVE_GRP_H) && !(defined(sparc) && defined(DEBUG))
      {
	struct group *gp;

	setgrent();
	while ((gp = getgrent()) != 0)
	  {
	    if (gp->gr_gid == statbuf.st_gid)
	      {
		break;
	      }
	  }
	if (gp)
	  {
	    values[9] = [NSString stringWithCString: gp->gr_name];
	  }
	else
	  {
	    values[9] = @"UnknownGroup";
	  }
	endgrent();
      }
#else
#if (defined(sparc) && defined(DEBUG))
      if (sparc_warn == 0)
	{
	  sparc_warn = 1;
	  /* Can't be NSLog - causes recursion in [NSUser -synchronize] */
          fprintf(stderr, "WARNING (NSFileManager): Disabling group enums (setgrent, etc) since this crashes gdb on sparc machines\n");
	}
#endif
      values[9] = @"UnknownGroup";
#endif
      values[10] = [NSNumber numberWithUnsignedInt: statbuf.st_uid];
      values[11] = [NSNumber numberWithUnsignedInt: statbuf.st_gid];
      count = 12;
    }
  else
    {
      NSString	*u = NSUserName();

      count = 8;	/* No ownership details needed.	*/
      /*
       * If we are running setuid to root - we need to specify the user
       * to be the owner of copied files.
       */
#if HAVE_GETEUID
      if (geteuid() == 0 && [@"root" isEqualToString: u] == NO)
	{
	  values[count++] = u;
	}
#endif
    }

  return [NSDictionary dictionaryWithObjects: values
				     forKeys: keys
				       count: count];
}

@end /* NSFileManager (PrivateMethods) */
