/* GSURLPrivate
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02111 USA.
*/ 

#ifndef __GSURLPrivate_h_
#define __GSURLPrivate_h_

/*
 * Headers needed by many URL loading classes
 */
#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSData.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSError.h"
#include "Foundation/NSException.h"
#include "Foundation/NSHTTPCookie.h"
#include "Foundation/NSHTTPCookieStorage.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSStream.h"
#include "Foundation/NSString.h"
#include "Foundation/NSURL.h"
#include "Foundation/NSURLAuthenticationChallenge.h"
#include "Foundation/NSURLCache.h"
#include "Foundation/NSURLConnection.h"
#include "Foundation/NSURLCredential.h"
#include "Foundation/NSURLCredentialStorage.h"
#include "Foundation/NSURLDownload.h"
#include "Foundation/NSURLError.h"
#include "Foundation/NSURLProtectionSpace.h"
#include "Foundation/NSURLProtocol.h"
#include "Foundation/NSURLRequest.h"
#include "Foundation/NSURLResponse.h"

/*
 * Private accessors for URL loading classes
 */

@interface	NSURLRequest (Private)
- (id) _propertyForKey: (NSString*)key;
- (void) _setProperty: (id)value forKey: (NSString*)key;
@end

#endif

