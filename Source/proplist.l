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

#define return_nsdata(str) pllval.obj = str2data(str); return NSDATA
#define return_nsstr(str) pllval.obj = [NSString stringWithCString:strdup(str)]; return NSSTRING

char * strdup(char * src);
char * unescstr(char * src);
NSData * str2data(char * str);

extern char plinput[];
extern char *plinputptr;
extern char *plinputlim;
%}

        /* pattern definitions */
ws              [ \t]
nl              \n
wsnl            [ \t\n]
hexdigit        [0-9A-Fa-f]
hexbyte {hexdigit}{2}
hexword {hexbyte}{4}
hexnum  {hexbyte}{1,3}
qstring [^"]*\"
noquote [$./0-9A-Z_a-z]
unqstring       {noquote}+
hexdata \<{ws}*({hexword}{ws}*)*{hexnum}{0,1}{ws}*\>
        /* exclusive states */
%x QUOTE

                /* rules section */
%%
<QUOTE>{qstring}        {
                                  if(plleng==1) {
                                    BEGIN INITIAL;
                                    return_nsstr("");
                                  }
                                  if(pltext[plleng-2] == '\\') {
                                    yymore();
                                  } else {
                                    BEGIN INITIAL;
                                    return_nsstr(unescstr(pltext));
                                  }
                                }

{unqstring}     {return_nsstr(pltext);}

{hexdata}               {return_nsdata(pltext);}

\"      {BEGIN QUOTE;}

{wsnl}+ ;       /* skip whitespace */

<<EOF>> {return 0;}

.       {return pltext[0];}             /* return unmatched characters
literally*/
%%

                /* C code section */
char * strdup(char *src)
{
  char *dest=(char *)malloc(strlen(src)+5);

  strcpy(dest,src);
  return dest;
}

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

  buf=(char *)malloc(strlen(str));

  for (str_ptr=str+1, buf_ptr=buf,len=0;
       (ch = *str_ptr) != '>';
       str_ptr++)
    {
      if(ch==' ' || ch=='\n' || ch=='\t')
	continue; /* ignore whitespace */
      *buf_ptr = (char2num(ch))<<4;
      ch = *++str_ptr;
      *buf_ptr |= char2num(ch);
      len++; buf_ptr++;
  }

  return [NSData dataWithBytes:buf length:len];
}

char *
unescstr (char *src)
{
  char *dest=(char*) malloc (strlen(src));
  char *src_ptr, *dest_ptr;
  char ch;
  int num;

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
          if((ch>='0') && (ch<='7'))
	    {
	      *dest_ptr = ch & 07;
	      *dest_ptr = (num<<3) | (*(++src_ptr)&07);
	      *dest_ptr = (num<<3) | (*(++src_ptr)&07);
	    }
	  else
	    {
	      switch(ch)
		{
		case 'a' : *dest_ptr = '\a'; break;
		case 'b' : *dest_ptr = '\b'; break;
		case 't' : *dest_ptr = '\t'; break;
		case 'n' : *dest_ptr = '\n'; break;
		case 'v' : *dest_ptr = '\v'; break;
		case 'f' : *dest_ptr = '\f'; break;
		default  : *dest_ptr = *src_ptr;
		}
	    }
	}
    }

  *dest_ptr = '\0';     /* terminate dest */

  return dest;
}
