/* Implementation of abstract superclass port for use with NSConnection
   Copyright (C) 1997, 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: August 1997

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
   */

#include <config.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSPortNameServer.h>
#include <Foundation/NSAutoreleasePool.h>

NSString*	NSPortDidBecomeInvalidNotification
= @"NSPortDidBecomeInvalidNotification";

NSString *NSPortTimeoutException
= @"NSPortTimeoutException";

@implementation NSPort

+ (NSPort*) port
{
  return AUTORELEASE([NSPort new]);
}

+ (NSPort*) portWithMachPort: (int)machPort
{
  return AUTORELEASE([[NSPort alloc] initWithMachPort: machPort]);
}

- (id) copyWithZone: (NSZone*)aZone
{
  return RETAIN(self);
}

- (id) delegate
{
  return delegate;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
}

- (id) init
{
  self = [super init];
  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithMachPort: (int)machPort
{
  [self shouldNotImplement: _cmd];
  return nil;
}

/*
 *	subclasses should override this method and call [super invalidate]
 *	in their versions of the method.
 */
- (void) invalidate
{
  [[NSPortNameServer defaultPortNameServer] removePort: self];
  is_valid = NO;
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSPortDidBecomeInvalidNotification
		  object: self];
}

- (BOOL) isValid
{
  return is_valid;
}

- (int) machPort
{
  [self shouldNotImplement: _cmd];
  return 0;
}

- (void) release
{
  if (is_valid && [self retainCount] == 1)
    {
      NSAutoreleasePool	*arp;

      /*
       *	If the port is about to have a final release deallocate it
       *	we must invalidate it.  Use a local autorelease pool when
       *	invalidating so that we know that anything refering to this
       *	port during the invalidation process is released immediately.
       *	Also - bracket with retain/release pair to prevent recursion.
       */
      [super retain];
      arp = [NSAutoreleasePool new];
      [self invalidate];
      [arp release];
      [super release];
    }
  [super release];
}

- (void) setDelegate: anObject
{
  NSAssert([anObject respondsToSelector: @selector(handlePortMessage:)],
	NSInvalidArgumentException);
  delegate = anObject;
}

- (void) addConnection: (NSConnection*)aConnection
             toRunLoop: (NSRunLoop*)aLoop
               forMode: (NSString*)aMode
{
  [self subclassResponsibility: _cmd];
}

- (void) removeConnection: (NSConnection*)aConnection
              fromRunLoop: (NSRunLoop*)aLoop
                  forMode: (NSString*)aMode
{
  [self subclassResponsibility: _cmd];
}

- (unsigned) reservedSpaceLength
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (BOOL) sendBeforeDate: (NSDate*)when
             components: (NSArray*)components
                   from: (NSPort*)receivingPort
               reserved: (unsigned) length
{
  [self subclassResponsibility: _cmd];
  return YES;
}

@end

