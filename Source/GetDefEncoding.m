/* Function to determine default c string encoding for
   GNUstep based on GNUSTEP_STRING_ENCODING environment variable.

   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: Stevo Crvenkovski <stevo@btinternet.com>
   Date: December 1997

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


#include <stdio.h>
#include <stdlib.h>
#include "config.h"
#include <Foundation/NSString.h>
#include <Foundation/NSBundle.h>

struct _strenc_ {NSStringEncoding enc; char *ename;};
const unsigned int str_encoding_table_size = 17;
const struct _strenc_ str_encoding_table[]=
{
  {NSASCIIStringEncoding,"NSASCIIStringEncoding"},
  {NSNEXTSTEPStringEncoding,"NSNEXTSTEPStringEncoding"},
  {NSJapaneseEUCStringEncoding, "NSJapaneseEUCStringEncoding"},
  {NSISOLatin1StringEncoding,"NSISOLatin1StringEncoding"},
  {NSCyrillicStringEncoding,"NSCyrillicStringEncoding"},
  {NSUTF8StringEncoding,"NSUTF8StringEncoding"},
  {NSSymbolStringEncoding,"NSSymbolStringEncoding"},
  {NSNonLossyASCIIStringEncoding,"NSNonLossyASCIIStringEncoding"},
  {NSShiftJISStringEncoding,"NSShiftJISStringEncoding"},
  {NSISOLatin2StringEncoding,"NSISOLatin2StringEncoding"},
  {NSWindowsCP1251StringEncoding,"NSWindowsCP1251StringEncoding"},
  {NSWindowsCP1252StringEncoding,"NSWindowsCP1252StringEncoding"},
  {NSWindowsCP1253StringEncoding,"NSWindowsCP1253StringEncoding"},
  {NSWindowsCP1254StringEncoding,"NSWindowsCP1254StringEncoding"},
  {NSWindowsCP1250StringEncoding,"NSWindowsCP1250StringEncoding"},
  {NSISO2022JPStringEncoding,"NSISO2022JPStringEncoding "},
  {NSUnicodeStringEncoding, "NSUnicodeStringEncoding"}
};

NSStringEncoding GetDefEncoding()
{
  char *encoding;
  unsigned int count;
  NSStringEncoding ret,tmp;
  NSStringEncoding *availableEncodings;

  availableEncodings = [NSString availableStringEncodings];

  encoding = getenv("GNUSTEP_STRING_ENCODING");
  if (encoding)
    {
      count = 0;
      while ((count < str_encoding_table_size) &&
	     strcmp(str_encoding_table[count].ename,encoding))
	{
	  count++;
	}
      if( !(count == str_encoding_table_size) )
	{
	  ret = str_encoding_table[count].enc;
	  if ((ret == NSUnicodeStringEncoding) ||
	      (ret == NSSymbolStringEncoding))
	    {
	      fprintf(stderr, "WARNING: %s - encoding not supported as default c string encoding.\n", encoding);
	      fprintf(stderr, "NSASCIIStringEncoding set as default.\n");
	      ret = NSASCIIStringEncoding;
	    }
	  else /*encoding should be supported but is it implemented?*/
	    {
	      count = 0;
	      tmp = 0;
	      while ( !(availableEncodings[count] == 0) )
		{
		  if ( !(ret == availableEncodings[count]) )
		    tmp = 0;
		  else
		    {
		      tmp = ret;
		      break;
		    }
		  count++;
		};
	      if (!tmp)
		{
		  fprintf(stderr, "WARNING: %s - encoding not yet implemented.\n", encoding);
		  fprintf(stderr, "NSASCIIStringEncoding set as default.\n");
		  ret = NSASCIIStringEncoding;
		};
	    };
	}
      else /* encoding not found */
	{
	  fprintf(stderr, "WARNING: %s - encoding not supported.\n", encoding);
	  fprintf(stderr, "NSASCIIStringEncoding set as default.\n");
	  ret = NSASCIIStringEncoding;
	}
    }
  else /* envirinment var not found */
    {
      /* This shouldn't be required. It really should be in UserDefaults - asf */
      //fprintf(stderr,"WARNING: GNUSTEP_STRING_ENCODING environment variable not found\n");
      //fprintf(stderr, "NSASCIIStringEncoding set as default.\n");
      ret = NSASCIIStringEncoding;
    }
  return ret;
};

NSString*
GetEncodingName(NSStringEncoding encoding)
{
  char* ret;
  unsigned int count=0;
  while ((count < str_encoding_table_size) &&
         !(str_encoding_table[count].enc == encoding))
    {
      count++;
    }
  if ( !(count == str_encoding_table_size) )
    ret = str_encoding_table[count].ename;
  else
    ret = "Unknown encoding";
  return [NSString stringWithCString:ret];
};
