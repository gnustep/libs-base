/**

   <title>AGSOutput ... a class to output gsdoc source</title>
   Copyright (C) <copy>2001 Free Software Foundation, Inc.</copy>

   <author name="Richard Frith-Macdonald"></author><richard@brainstorm.co.uk>
   Created: October 2001

   This file is part of the GNUstep Project

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.
   You should have received a copy of the GNU General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

   */

#include <Foundation/Foundation.h>

@interface	AGSOutput : NSObject
{
  NSDictionary		*info;		// Not retained.
  NSCharacterSet	*identifier;	// Legit char in identifier
  NSCharacterSet	*identStart;	// Legit initial char of identifier
  NSCharacterSet	*spaces;	// All blank characters
  NSCharacterSet	*spacenl;	// Blanks excluding newline
}

- (unsigned) fitWords: (NSArray*)a
		 from: (unsigned)start
		   to: (unsigned)end
	      maxSize: (unsigned)limit
	       output: (NSMutableString*)buf;
- (NSString*) output: (NSDictionary*)d;
- (BOOL) output: (NSDictionary*)d file: (NSString*)name;
- (void) outputMethod: (NSDictionary*)d to: (NSMutableString*)str;
- (void) outputUnit: (NSDictionary*)d to: (NSMutableString*)str;
- (void) reformat: (NSString*)str
       withIndent: (unsigned)ind
	       to: (NSMutableString*)buf;
- (NSArray*) split: (NSString*)str;
@end


