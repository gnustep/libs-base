/* Implementation for Objective C NeXT-compatible NXStringTable object 
   Copyright (C) 1993 Free Software Foundation, Inc.

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
    StringTable - Hash table for strings in the NeXT StringTable style

    $Id$

    TODO:  Should I reject duplicate keys on readFromStream?
	   the real MAX_STRINGTABLE_LENGTH is in NXStringTable.l, even though
	   it also appears in StringTable.h
*/

#include <stdio.h>
#include <string.h>
#include <gnustep/base/preface.h>
#include <objc/NXStringTable.h>

char *
CopyStringBuffer(const char *buf)
{
    char *out;
    if (!buf)
	return NULL;
    OBJC_MALLOC(out, char, strlen(buf)+1);
    if (out)
        strcpy(out, buf);
    return out;
}

/* table_scan is a lexical parser created using flex.  It parses a string
   table and returns (1) every time it finds a token (the token is stored
   in *str. It returns (-1) on an error or (0) when finished. Tokens are
   guaranteed to alternate between Keys and Values.
*/
#if HAVE_FLEX
extern int NXtable_scan(FILE *in_stream, FILE *out_stream, const char **str);
#else
/* Variables to export to yylex */
FILE *NXscan_in;
FILE *NXscan_out;
char *NXscan_string;
#endif

@implementation NXStringTable

- init 
{
    return [super initKeyDesc: "*" valueDesc: "*"];
}

- (const char *)valueForStringKey:(const char *)aString
{
    return [super valueForKey:aString];
}
    
- readFromStream:(FILE *)stream
{
    const char *str;
    char *key = 0, *value;
    int status;
    BOOL  gotKey = NO;

#if HAVE_FLEX
    status = NXtable_scan(stream, stderr, &str);
#else
    NXscan_in = stream;
    NXscan_out = stderr;
    status = NXlex_lex();
    str    = NXscan_string;
#endif
    while (status > 0) {
	if (gotKey) {
	    value = CopyStringBuffer(str);
	    [super insertKey:key value:value];
	} else
	    key = CopyStringBuffer(str);
	gotKey = ~gotKey;
#if HAVE_FLEX
        status = NXtable_scan(stream, stderr, &str);
#else
	status = NXlex_lex();
#endif
    }
    if (gotKey) {
    	OBJC_FREE(key);
	return nil;
    }

    return (status >= 0) ? self : nil;
}

- readFromFile:(const char *)fileName
{
    id	 returnVal;
    FILE *stream;
    if ((stream = fopen(fileName, "r")) == NULL) {
	perror("Error (NXStringTable)");
	return nil;
    }
    returnVal = [self readFromStream:stream];
    fclose(stream);
    return returnVal;
}

- writeToStream:(FILE *)stream
{
    const char  *key;
	  char  *value;
    NXHashState state = [super initState];
    while ([super nextState: &state 
			key: (const void **)&key 
			value: (void **)&value])
	fprintf(stream, "\"%s\" = \"%s\";\n", key, value);
    
    return self;
}

- writeToFile:(const char *)fileName
{
    FILE *stream;
    if ((stream = fopen(fileName, "w")) == NULL) {
	perror("Error (NXStringTable)");
	return nil;
    }
    [self writeToStream:stream];
    fclose(stream);
    return self;
}

@end


