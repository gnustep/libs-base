/* proplist.l - for parsing NSString property lists -*- c -*- */

/* definition section */

        /* literal block */
%{
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include "proplist.tab.h"

#ifdef plwrap
#undef plwrap
#endif

int plwrap(void) {
  return 1;
}

NSString * unescstr(char * src);
NSData * str2data(char * str);

extern char plinput[];
extern char *plinputptr;
extern char *plinputlim;

static int level;
%}

        /* pattern definitions */
ws              [ \t\r]
nl              \n
wsnl            [ \t\r\n]
hexdigit        [0-9A-Fa-f]
hexbyte {hexdigit}{2}
hexword {hexbyte}{4}
hexnum  {hexbyte}{1,3}
qstring [^"]*\"
noquote [$./0-9A-Z_a-z]
unqstring       {noquote}+
hexdata \<{wsnl}*({hexword}{wsnl}*)*({hexnum}{wsnl}*)*\>
        /* exclusive states */
%x QUOTE COMMENT LINE_COMMENT

                /* rules section */
%%

"/*"		{++level; BEGIN COMMENT;}
"//"		{BEGIN LINE_COMMENT;}

<QUOTE>{qstring}        {
                                  if(plleng==1) {
                                    BEGIN INITIAL;
				    pllval.obj=[NSString stringWithCString:""];
				    return NSSTRING;
                                  }
                                  if(pltext[plleng-2] == '\\') {
                                    yymore();
                                  } else {
                                    BEGIN INITIAL;
				    pllval.obj=unescstr(pltext);
				    return NSSTRING;
                                  }
                                }

<COMMENT>"*/"		{if(!--level) BEGIN INITIAL;}
<COMMENT>.              ;
<COMMENT><<EOF>>	{return 0;}

<LINE_COMMENT>\n	{BEGIN INITIAL;}
<LINE_COMMENT>.         ;

{unqstring}		{
			  pllval.obj = [NSString stringWithCString:pltext];
			  return NSSTRING;
			}

{hexdata}               {
			  pllval.obj = str2data(pltext);
			  return NSDATA;
			}


\"      {BEGIN QUOTE;}

{wsnl}+ ;       /* skip whitespace */

<<EOF>> {return 0;}

.       {return pltext[0];}             /* return unmatched characters
literally*/
%%

                /* C code section */

#define inrange(ch,min,max) ((ch)>=(min) && (ch)<=(max))
#define char2num(ch) \
inrange(ch,'0','9') \
? ((ch)-0x30) \
: (inrange(ch,'a','f') \
? ((ch)-0x57) : ((ch)-0x37))

NSData *
str2data (char *str)
{
  char *buf, *str_ptr, *buf_ptr;
  char ch;
  int len;

  buf=(char *)objc_malloc(strlen(str));

  for (str_ptr=str+1, buf_ptr=buf,len=0;
       (ch = *str_ptr) != '>';
       str_ptr++)
    {
      if(ch==' ' || ch=='\n' || ch=='\t' || ch=='\r')
	continue; /* ignore whitespace */
      *buf_ptr = (char2num(ch))<<4;
      ch = *++str_ptr;
      *buf_ptr |= char2num(ch);
      len++; buf_ptr++;
  }

  return [NSData dataWithBytesNoCopy:buf length:len];
}

NSString*
unescstr (char *src)
{
  char *dest=(char*) objc_malloc (strlen(src));
  char *src_ptr, *dest_ptr;
  char ch;

  /* blow away that terminating quote for good measure */
  src[strlen(src)-1] = '\0';

  for (src_ptr=src,dest_ptr=dest; 
       *src_ptr;
       src_ptr++, dest_ptr++)
    {
      if(*src_ptr != '\\')
	*dest_ptr = *src_ptr;
      else
	{
          ch = *(++src_ptr);
          if((ch>='0') && (ch<='1')) /* assume next 2 chars are octal too */
	    {
	      *dest_ptr = (ch & 07) << 3;
              *dest_ptr |= (*(++src_ptr)&07)<<3;
              *dest_ptr |= *(++src_ptr)&07;
	    }
	  else
	    {
	      switch(ch)
		{
		case 'a' : *dest_ptr = '\a'; break;
		case 'b' : *dest_ptr = '\b'; break;
		case 't' : *dest_ptr = '\t'; break;
		case 'r' : *dest_ptr = '\r'; break;
		case 'n' : *dest_ptr = '\n'; break;
		case 'v' : *dest_ptr = '\v'; break;
		case 'f' : *dest_ptr = '\f'; break;
		default  : *dest_ptr = *src_ptr;
		}
	    }
	}
    }

  *dest_ptr = '\0';     /* terminate dest */

  return [[[NSString alloc] initWithCStringNoCopy: dest
					   length: dest_ptr - dest
				     freeWhenDone: YES] autorelease];
}
