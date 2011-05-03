/* Extension functions for GNUstep
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Written by:  Sheldon Gill
   Date:    2005

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.

   <title>NSPathUtilities function reference</title>
   $Date$ $Revision$
   */

#include "config.h"
#include "GNUstepBase/preface.h"
#include "GNUstepBase/GSFunctions.h"
#include "GNUstepBase/GSCategories.h"
#include "Foundation/Foundation.h"

NSString *
GSFindNamedFile(NSArray *paths, NSString *aName, NSString *anExtension)
{
  NSFileManager *file_mgr = [NSFileManager defaultManager];
  NSString *file_name, *file_path, *path;
  NSEnumerator *enumerator;

  NSCParameterAssert(aName != nil);
  NSCParameterAssert(paths != nil);

GSOnceFLog(@"deprecated ... trivial to code directly");

  /* make up the name with extension if given */
  if (anExtension != nil)
    {
      file_name = [aName stringByAppendingPathExtension: anExtension];
    }
  else
    {
      file_name = aName;
    }

  enumerator = [paths objectEnumerator];
  while ((path = [enumerator nextObject]))
    {
      file_path = [path stringByAppendingPathComponent: file_name];

      if ([file_mgr fileExistsAtPath: file_path] == YES)
        {
          return file_path; // Found it!
        }
    }
  return nil;
}

