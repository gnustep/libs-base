/* Implementation of Objective-C NeXT-compatible NXProtocolChecker object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@cs.rochester.edu>
   Dept. of Computer Science, U. of Rochester, Rochester, NY  14627
   
   This file is part of the Gnustep Base Library.

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

#include <objc/Object.h>
#include <machkit/NXProtocolChecker.h>

@implementation NXProtocolChecker
{
  id target;
  id protocol;
}

- initWithObject: anObj forProtocol: aProtocol
{
  [super init];
  target = anObj;
  protocol = aProtocol;
  return self;
}

- (BOOL) conformsTo: aProtocol
{
  return [protocol conformsTo:aProtocol];
}

- (struct objc_method_description *) descriptionForMethod: (SEL)aSel
{
  return [protocol descriptionForMethod:aSel];
}

- forward: (SEL)aSel :(arglist_t)frame
{
  if ([protocol descriptionForMethod:aSel])
    return [target performv:aSel :frame];
  /* Fix this */
  return nil;
}

@end
