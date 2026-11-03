/* Implementation of extension methods to base additions

   Copyright (C) 2026 Free Software Foundation, Inc.

   Written by:  Frederik Seiffert <frederik@algoriddim.com>

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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/

#import "common.h"
#import "Foundation/NSProgress.h"
#import "GNUstepBase/GSBoxWeak.h"
#import "GNUstepBase/NSProgress+GNUstepBase.h"

#if	defined(NeXT_Foundation_LIBRARY)

#import <objc/runtime.h>

/* GNUstep implements the delegate in NSProgress itself, without blocks.  On
 * macOS, it is implemented with handlers that send the delegate messages.
 */
@implementation NSProgress (GNUstepBase)

static char	dKey;

- (id<GSProgressDelegate>) delegate
{
  GSBoxWeak	*box = objc_getAssociatedObject(self, &dKey);

  return [box value];
}

- (void) setDelegate: (id<GSProgressDelegate>)delegate
{
  GSBoxWeak	*box = nil;
  GSBoxWeak	*progress;

  if (delegate != nil)
    {
      box = AUTORELEASE([[GSBoxWeak alloc] initWithValue: delegate]);
    }
  objc_setAssociatedObject(self, &dKey, box, OBJC_ASSOCIATION_RETAIN);
  if (delegate == nil)
    {
      [self setCancellationHandler: nil];
      [self setPausingHandler: nil];
      [self setResumingHandler: nil];
      return;
    }

  /* The handlers refer to the receiver weakly, as it retains them */
  progress = AUTORELEASE([[GSBoxWeak alloc] initWithValue: self]);
  [self setCancellationHandler: ^{
    NSProgress	*p = [progress value];
    id		d = [p delegate];

    if ([d respondsToSelector: @selector(progressCancelled:)])
      {
	[d progressCancelled: p];
      }
  }];
  [self setPausingHandler: ^{
    NSProgress	*p = [progress value];
    id		d = [p delegate];

    if ([d respondsToSelector: @selector(progressPaused:)])
      {
	[d progressPaused: p];
      }
  }];
  [self setResumingHandler: ^{
    NSProgress	*p = [progress value];
    id		d = [p delegate];

    if ([d respondsToSelector: @selector(progressResumed:)])
      {
	[d progressResumed: p];
      }
  }];
}

@end

#endif	/* NeXT_Foundation_LIBRARY */
