/* Interface for Objective C NeXT-compatible NXStringTable object 
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Adam Fedor <adam@bastille.rmnug.org>

   This file is part of the GNU Objective-C Collection library.

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

/*
    StringTable.h - Hash table for strings in the NeXT StringTable style
    
*/

#ifndef __NXStringTable_h_INCLUDE_GNU
#define __NXStringTable_h_INCLUDE_GNU

#include <objc/HashTable.h>

#define MAX_NXSTRINGTABLE_LENGTH	1024

@interface NXStringTable: HashTable

- init;
    
- (const char *)valueForStringKey:(const char *)aString;
    
- readFromStream:(FILE *)stream;
- readFromFile:(const char *)fileName;

- writeToStream:(FILE *)stream;
- writeToFile:(const char *)fileName;

@end

static inline const char *STRVAL(NXStringTable *table, const char *key) {
    return [table valueForStringKey:key];
}

#endif /* __NXStringTable_h_INCLUDE_GNU */
