/* Implementation of NSLog() error loging functions for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: Nov 1995
   
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

`void NSLog(NSString *format,...'
     ) Writes to stderr an error message of the form:

     ª \i time processName processID format\i0 º. The format argument
     to `NSLog()' is a format string in the style of the standard C
     function `printf()', followed by an arbitrary number of arguments
     that match conversion specifications (such as %s or %d) in the
     format string. (You can pass an object in the list of arguments by
     specifying % in the format stringÐthis conversion specification
     gets replaced by the string that the object's description method
     returns.)

void
NSLogv(NSString* format, va_list args)
{
  fprintf(stderr, "", );
  vfprintf(stderr, [[NSString stringWithFormat:format
		     arguments:args] cString]);
}
