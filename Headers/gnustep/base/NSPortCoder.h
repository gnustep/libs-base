/* Interface for NSPortCoder object for distributed objects
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1997

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

#ifndef __NSPortCoder_h
#define __NSPortCoder_h

#include <base/preface.h>
#include <Foundation/NSCoder.h>

@class NSConnection;
@class NSPort;

@interface NSPortCoder : NSCoder
{
}

- (NSConnection*) connection;
- (NSPort*) decodePortObject;
- (void) encodePortObject: (NSPort*)aPort;
- (BOOL) isBycopy;
- (BOOL) isByref;

@end


#endif /* __NSPortCoder_h */
