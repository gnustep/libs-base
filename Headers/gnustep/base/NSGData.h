/* Interface to concrete implementation of NSData based on MemoryStream class
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: April 1995
   
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

#ifndef __NSGData_h_GNUSTEP_BASE_INCLUDE
#define __NSGData_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <Foundation/NSData.h>
#include <gnustep/base/MemoryStream.h>

@interface NSGData : NSData
{
  /* For now, these must match the instance variables in 
     gnustep/base/MemoryStream.h.
     This will change. */
  int type;
  char *buffer;
  int size;
  int eofPosition;
  int prefix;
  int position;
}

@end

@interface NSGData (GNU) <MemoryStreaming>
@end

@interface NSGMutableData : NSMutableData
{
  /* For now, these must match the instance variables in 
     gnustep/base/MemoryStream.h.
     This will change. */
  int type;
  char *buffer;
  int size;
  int eofPosition;
  int prefix;
  int position;
}

@end

@interface NSGMutableData (GNU) <MemoryStreaming>
@end

#endif /* __NSGData_h_GNUSTEP_BASE_INCLUDE */
