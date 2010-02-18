/* Implementation of extension methods for base additions

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

*/
#import "config.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSPathUtilities.h"
#import "Foundation/NSProcessInfo.h"
#import "GNUstepBase/NSTask+GNUstepBase.h"

@implementation	NSTask (GNUstepBase)

static	NSString*
executablePath(NSFileManager *mgr, NSString *path)
{
#if defined(__MINGW32__)
  NSString	*tmp;

  if ([mgr isExecutableFileAtPath: path])
    {
      return path;
    }
  tmp = [path stringByAppendingPathExtension: @"exe"];
  if ([mgr isExecutableFileAtPath: tmp])
    {
      return tmp;
    }
  tmp = [path stringByAppendingPathExtension: @"com"];
  if ([mgr isExecutableFileAtPath: tmp])
    {
      return tmp;
    }
  tmp = [path stringByAppendingPathExtension: @"cmd"];
  if ([mgr isExecutableFileAtPath: tmp])
    {
      return tmp;
    }
#else
  if ([mgr isExecutableFileAtPath: path])
    {
      return path;
    }
#endif
  return nil;
}

+ (NSString*) launchPathForTool: (NSString*)name
{
  NSEnumerator	*enumerator;
  NSDictionary	*env;
  NSString	*pathlist;
  NSString	*path;
  NSFileManager	*mgr;

  mgr = [NSFileManager defaultManager];

#if	defined(GNUSTEP)
  enumerator = [NSSearchPathForDirectoriesInDomains(
    GSToolsDirectory, NSAllDomainsMask, YES) objectEnumerator];
  while ((path = [enumerator nextObject]) != nil)
    {
      path = [path stringByAppendingPathComponent: name];
      if ((path = executablePath(mgr, path)) != nil)
	{
	  return path;
	}
    }
  enumerator = [NSSearchPathForDirectoriesInDomains(
    GSAdminToolsDirectory, NSAllDomainsMask, YES) objectEnumerator];
  while ((path = [enumerator nextObject]) != nil)
    {
      path = [path stringByAppendingPathComponent: name];
      if ((path = executablePath(mgr, path)) != nil)
	{
	  return path;
	}
    }
#endif

  env = [[NSProcessInfo processInfo] environment];
  pathlist = [env objectForKey:@"PATH"];
#if defined(__MINGW32__)
/* Windows 2000 and perhaps others have "Path" not "PATH" */
  if (pathlist == nil)
    {
      pathlist = [env objectForKey: @"Path"];
    }
  enumerator = [[pathlist componentsSeparatedByString: @";"] objectEnumerator];
#else
  enumerator = [[pathlist componentsSeparatedByString: @":"] objectEnumerator];
#endif
  while ((path = [enumerator nextObject]) != nil)
    {
      path = [path stringByAppendingPathComponent: name];
      if ((path = executablePath(mgr, path)) != nil)
	{
	  return path;
	}
    }
  return nil;
}
@end
