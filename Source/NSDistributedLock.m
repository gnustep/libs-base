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

   <title>NSDistributedLock class reference</title>
   $Date$ $Revision$
   */

#include <config.h>
#include <string.h>
#include <Foundation/NSDistributedLock.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDebug.h>

#include <fcntl.h>

static NSFileManager	*mgr = nil;

@implementation NSDistributedLock

+ (void) initialize
{
  if (mgr == nil)
    {
      mgr = RETAIN([NSFileManager defaultManager]);
    }
}

/**
 * Return a distributed lock for aPath.
 * See -initWithPath: for details.
 */
+ (NSDistributedLock*) lockWithPath: (NSString*)aPath
{
  return AUTORELEASE([[self alloc] initWithPath: aPath]);
}

/**
 * Forces release of the lock whether the receiver owns it or not.<br />
 * Raises an NSGenericException if unable to remove the lock.
 */
- (void) breakLock
{
  NSDictionary	*attributes;

  DESTROY(_lockTime);
  attributes = [mgr fileAttributesAtPath: _lockPath traverseLink: YES];
  if (attributes != nil)
    {
      NSDate	*modDate = [attributes fileModificationDate];

      if ([mgr removeFileAtPath: _lockPath handler: nil] == NO)
	{
	  const char	*err = GSLastErrorStr(errno);

	  attributes = [mgr fileAttributesAtPath: _lockPath traverseLink: YES];
	  if ([modDate isEqual: [attributes fileModificationDate]] == YES)
	    {
	      [NSException raise: NSGenericException 
		      format: @"Failed to remove lock directory '%@' - %s",
		      _lockPath, err];
	    }
	}
    }
}

- (void) dealloc
{
  RELEASE(_lockPath);
  RELEASE(_lockTime);
  [super dealloc];
}

/**
 * Initialises the reciever with the specified filesystem path.<br />
 * The location in the filesystem must be accessible for this
 * to be usable.  That is, the processes using the lock must be able
 * to access, create, and destroy files at the path.<br />
 * The directory in which the last path component resides must already
 * exist ... create it using NSFileManager if you need to.
 */
- (NSDistributedLock*) initWithPath: (NSString*)aPath
{
  NSString	*lockDir;
  BOOL		isDirectory;

  _lockPath = [aPath copy];
  _lockTime = nil;

  lockDir = [_lockPath stringByDeletingLastPathComponent];
  if ([mgr fileExistsAtPath: lockDir isDirectory: &isDirectory] == NO)
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
  if ([mgr isWritableFileAtPath: lockDir] == NO)
    {
      NSLog(@"parent directory of lock file '%@' is not writable\n", _lockPath);
      RELEASE(self);
      return nil;
    }
  if ([mgr isExecutableFileAtPath: lockDir] == NO)
    {
      NSLog(@"parent directory of lock file '%@' is not accessible\n",
		_lockPath);
      RELEASE(self);
      return nil;
    }
  return self;
}

/**
 * Returns the date at which the lock was aquired by any
 * NSDistributedLock using the same path.  If nothing has
 * the lock, this returns nil.
 */
- (NSDate*) lockDate
{
  NSDictionary	*attributes;

  attributes = [mgr fileAttributesAtPath: _lockPath traverseLink: YES];
  return [attributes fileModificationDate];
}

/**
 * Attempt to aquire the lock and return YES on success, NO on failure.<br />
 * May raise an NSGenericException if a problem occurs.
 */
- (BOOL) tryLock
{
  NSMutableDictionary	*attributesToSet;
  NSDictionary		*attributes;
  BOOL			locked;

  attributesToSet = [NSMutableDictionary dictionaryWithCapacity: 1];
  [attributesToSet setObject: [NSNumber numberWithUnsignedInt: 0755]
		      forKey: NSFilePosixPermissions];
	
  locked = [mgr createDirectoryAtPath: _lockPath
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
      if ([mgr fileExistsAtPath: _lockPath isDirectory: &dir] == NO)
	{
	  locked = [mgr createDirectoryAtPath: _lockPath
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
      return NO;
    }
  else
    {
      attributes = [mgr fileAttributesAtPath: _lockPath
				traverseLink: YES];
      if (attributes == nil)
	{
	  [NSException raise: NSGenericException
		      format: @"Unable to get attributes of lock file we made"];
	}
      ASSIGN(_lockTime, [attributes fileModificationDate]);
      return YES;
    }
}

/**
 * Releases the lock.  Raises an NSGenericException if unable to release
 * the lock (for instance if the receiver does not own it or another
 * process has broken it).
 */
- (void) unlock
{
  NSDictionary	*attributes;

  if (_lockTime == nil)
    {
      [NSException raise: NSGenericException format: @"not locked by us"];
    }

  /*
   *	Don't remove the lock if it has already been broken by someone
   *	else and re-created.  Unfortunately, there is a window between
   *	testing and removing, but we do the bset we can.
   */
  attributes = [mgr fileAttributesAtPath: _lockPath traverseLink: YES];
  if (attributes == nil)
    {
      DESTROY(_lockTime);
      [NSException raise: NSGenericException
		  format: @"lock '%@' already broken", _lockPath];
    }
  if ([_lockTime isEqual: [attributes fileModificationDate]])
    {
      DESTROY(_lockTime);
      if ([mgr removeFileAtPath: _lockPath handler: nil] == NO)
	{
	  [NSException raise: NSGenericException
		      format: @"Failed to remove lock directory '%@' - %s",
			  _lockPath, GSLastErrorStr(errno)];
	}
    }
  else
    {
      DESTROY(_lockTime);
      [NSException raise: NSGenericException
		  format: @"lock '%@' already broken and in use again",
	_lockPath];
    }
  DESTROY(_lockTime);
}

@end
