/* Implementation of Objective-C method-name-compatible NXProxy
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   This file is part of the GNUstep Base Library.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993
   
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

#include <remote/NXProxy.h>
#include <objc/objc-api.h>
#include <assert.h>

@implementation NXProxy

- addReference
{
  [self retain];
  return self;
}

- (unsigned) references
{
  return [self retainCount] + 1;
}

- (unsigned) nameForProxy
{
  return [self targetForProxy];
}

- freeProxy
{
  [self dealloc];
  return nil;
}

- free
{
  /* xxx Is this what we want? */
  return [self freeProxy];
}

- setProtocolForProxy: (Protocol*)aProtocol
{
  return self;
}

- encodeRemotelyFor: (NXConnection*)conn 
   freeAfterEncoding: (BOOL*)fp
   isBycopy: (BOOL)f;
{
  return self;
}

/* GNU Connection doesn't use local proxies, but in order for us to have
   compatibility with NeXT's -encodeRemotelyFor:freeAfterEncoding:isBycopy
   we have to do this ugly thing. */
+ newBogusLocal: (id)anObject
{
  NXProxy *newProxy = class_create_instance([NXProxy class]);
  newProxy->target = PTR2LONG(anObject);
  return newProxy;
}

@end



