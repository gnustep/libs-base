/* Include for GNUstep Distributed NotificationCenter
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 1998

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

#define	GDNC_SERVICE	@"GDNCServer"

@protocol	GDNCClient
- (oneway void) postNotificationName: (NSString*)name
			      object: (NSString*)object
			    userInfo: (NSData*)info
			    selector: (NSString*)aSelector
				  to: (unsigned long)observer;
@end

@protocol	GDNCProtocol
- (void) addObserver: (unsigned long)anObserver
	    selector: (NSString*)aSelector
	        name: (NSString*)notificationname
	      object: (NSString*)anObject
  suspensionBehavior: (NSNotificationSuspensionBehavior)suspensionBehavior
		 for: (id<GDNCClient>)client;

- (oneway void) postNotificationName: (NSString*)notificationName
			      object: (NSString*)anObject
			    userInfo: (NSData*)d
		  deliverImmediately: (BOOL)deliverImmediately
			         for: (id<GDNCClient>)client;

- (void) registerClient: (id<GDNCClient>)client;

- (void) removeObserver: (unsigned long)anObserver
		   name: (NSString*)notificationname
		 object: (NSString*)anObject
		    for: (id<GDNCClient>)client;

- (void) setSuspended: (BOOL)flag
		  for: (id<GDNCClient>)client;

- (void) unregisterClient: (id<GDNCClient>)client;

@end

