/** Implementation for GNU Objective-C version of NSDistributedLock
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: November 1997

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

#include <config.h>
#include <string.h>
#include <Foundation/NSDistributedLock.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDebug.h>

#include <fcntl.h>

@implementation NSDistributedLock

+ (NSDistributedLock*) lockWithPath: (NSString*)aPath
{
  return AUTORELEASE([[self alloc] initWithPath: aPath]);
}

- (void) breakLock
{
  NSFileManager	*fileManager;

  fileManager = [NSFileManager defaultManager];
  if ([fileManager removeFileAtPath: _lockPath handler: nil] == NO)
    [NSException raise: NSGenericException 
		format: @"Failed to remove lock directory '%@' - %s",
		_lockPath, GSLastErrorStr(errno)];
  RELEASE(_lockTime);
  _lockTime = nil;
}

- (void) dealloc
{
  RELEASE(_lockPath);
  RELEASE(_lockTime);
  [super dealloc];
}

- (NSDistributedLock*) initWithPath: (NSString*)aPath
{
  NSFileManager	*fileManager;
  NSString	*lockDir;
  BOOL		isDirectory;

  _lockPath = [aPath copy];
  _lockTime = nil;

  fileManager = [NSFileManager defaultManager];
  lockDir = [_lockPath stringByDeletingLastPathComponent];
  if ([fileManager fileExistsAtPath: lockDir isDirectory: &isDirectory] == NO)
    {
      NSLog(@"part of the path to the lock file '%@' is missing\n", _lockPath);
      RELEASE(self);
      return nil;
    }
  if (isDirectory == NO)
    {
      NSLog(@"part of the path to the lock file '%@' is not a directory\n",
		_lockPath);
      RELEASE(self);
      return nil;
    }
  if ([fileManager isWritableFileAtPath: lockDir] == NO)
    {
      NSLog(@"parent directory of lock file '%@' is not writable\n", _lockPath);
      RELEASE(self);
      return nil;
    }
  if ([fileManager isExecutableFileAtPath: lockDir] == NO)
    {
      NSLog(@"parent directory of lock file '%@' is not accessible\n",
		_lockPath);
      RELEASE(self);
      return nil;
    }
  return self;
}

- (NSDate*) lockDate
{
  NSFileManager	*fileManager;
  NSDictionary	*attributes;

  fileManager = [NSFileManager defaultManager];
  attributes = [fileManager fileAttributesAtPath: _lockPath traverseLink: YES];
  return [attributes objectForKey: NSFileModificationDate];
}

- (BOOL) tryLock
{
  NSFileManager		*fileManager;
  NSMutableDictionary	*attributesToSet;
  NSDictionary		*attributes;
  BOOL			locked;

  fileManager = [NSFileManager defaultManager];
  attributesToSet = [NSMutableDictionary dictionaryWithCapacity: 1];
  [attributesToSet setObject: [NSNumber numberWithUnsignedInt: 0755]
		      forKey: NSFilePosixPermissions];
	
  locked = [fileManager createDirectoryAtPath: _lockPath
				   attributes: attributesToSet];
  if (locked == NO)
    {
      BOOL	dir;

      /*
       * We expect the directory creation to have failed because it already
       * exists as another processes lock.  If the directory doesn't exist,
       * then either the other process has removed it's lock (and we can retry)
       * or we have a severe problem!
       */
      if ([fileManager fileExistsAtPath: _lockPath isDirectory: &dir] == NO)
	{
	  locked = [fileManager createDirectoryAtPath: _lockPath
					   attributes: attributesToSet];
	  if (locked == NO)
	    {
	      NSLog(@"Failed to create lock directory '%@' - %s",
		    _lockPath, GSLastErrorStr(errno));
	    }
	}
    }

  if (locked == NO)
    {
      RELEASE(_lockTime);
      _lockTime = nil;
      return NO;
    }
  else
    {
      attributes = [fileManager fileAttributesAtPath: _lockPath
					traverseLink: YES];
      RELEASE(_lockTime);
      _lockTime = RETAIN([attributes objectForKey: NSFileModificationDate]);
      return YES;
    }
}

- (void) unlock
{
  NSFileManager	*fileManager;
  NSDictionary	*attributes;

  if (_lockTime == nil)
    [NSException raise: NSGenericException format: @"not locked by us"];

  /*
   *	Don't remove the lock if it has already been broken by someone
   *	else and re-created.  Unfortunately, there is a window between
   *	testing and removing, but we do the bset we can.
   */
  fileManager = [NSFileManager defaultManager];
  attributes = [fileManager fileAttributesAtPath: _lockPath traverseLink: YES];
  if ([_lockTime isEqual: [attributes objectForKey: NSFileModificationDate]])
    {
      if ([fileManager removeFileAtPath: _lockPath handler: nil] == NO)
        [NSException raise: NSGenericException
		    format: @"Failed to remove lock directory '%@' - %s",
			_lockPath, GSLastErrorStr(errno)];
    }
  else
    NSLog(@"lock '%@' already broken and in use again\n", _lockPath);

  RELEASE(_lockTime);
  _lockTime = nil;
}

@end
