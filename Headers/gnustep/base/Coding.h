/* Protocol for GNU Objective-C objects that can write/read to a coder
   Copyright (C) 1993,1994 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
   This file is part of the GNU Objective C Class Library.

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

#ifndef __Coding_h
#define __Coding_h

#include <objects/stdobjects.h>

@class Coder;

@protocol Coding

- (void) encodeWithCoder: (Coder*)anEncoder;
+ newWithCoder: (Coder*)aDecoder;

/* xxx To avoid conflict with OpenStep, change names to:
   encodeOnCoder: ?

   encodeToCoder:
   newFromCoder:
*/

/* NOTE:  

   This is +newWithCoder: and not -initWithCoder: because many classes
   keep track of their instances and only allow one instance of each
   configuration.  For example, see the designated initializers of
   SocketPort, Connection, and Proxy.

   Making this +new.. instead of -init.. prevents us from having to
   waste the effort of allocating space for an object to be decoded,
   then immediately deallocating that space because we're just
   returning a pre-existing object.

   I also like it because it makes very clear that this method is
   expected to return the decoded object.  This requirement would have
   also been present in an -init... implementation, but the
   requirement may not have been 100 percent clear by the method name.

   -mccallum  */

@end

#endif /* __Coding_h */
