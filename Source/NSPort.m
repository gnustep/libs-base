/* Implementation of abstract superclass port for use with Connection
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: July 1994

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

#include <Foundation/NSString.h>
#include <Foundation/NSPort.h>

NSString*	NSPortDidBecomeInvalidNotification
= @"NSPortDidBecomeInvalidNotification";

NSString *NSPortTimeoutException
= @"NSPortTimeoutException";

@implementation NSPort

+ (NSPort*) port
{
    return [[[NSPort alloc] init] autorelease];
}

+ (NSPort*) portWithMachPort: (int)machPort
{
    return [[[NSPort alloc] initWithMachPort:machPort] autorelease];
}

- copyWithZone: (NSZone*)aZone
{
    return [super copyWithZone:aZone];
}

- delegate
{
    return delegate;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    [super encodeWithCoder: aCoder];
}

- init
{
    self = [super init];
    return self;
}

- initWithCoder: (NSCoder*)aCoder
{
    self = [super initWithCoder: aCoder];
    return self;
}

- initWithMachPort: (int)machPort
{
    [self notImplemented: _cmd];
    return nil;
}

- (void) invalidate
{
    [self subclassResponsibility: _cmd];
}

- (BOOL) isValid
{
    return is_valid;
}

- machPort
{
    [self notImplemented: _cmd];
    return nil;
}

- (void) setDelegate: anObject
{
    delegate = anObject;
}

@end


