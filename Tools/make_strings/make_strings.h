/* make_strings

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Alexander Malmberg <alexander@malmberg.org>
   Created: 2002

   This file is part of the GNUstep Project

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   You should have received a copy of the GNU General Public
   License along with this program; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#ifndef make_strings_h
#define make_strings_h

@class SourceEntry;

@interface NSMutableDictionary (make_strings)
-(void) addEntry: (SourceEntry *)e  toTable: (NSString *)table;
@end

extern int verbose,aggressive_import,aggressive_match;

#endif

