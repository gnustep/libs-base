                /* definition section */

        /* literal block */
%{
#include <gnustep/base/preface.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
%}

        /* token declarations */
%token <obj> NSSTRING NSDATA ERROR

%union {
        id obj;
}

%type <obj> root object array objlist dictionary keyval_list keyval_pair

                /* rules section */
%%
root:           object
                                {
                      /* want an object, followed by nothing else (<<EOF>>) */
                                  return (int)$1;
                                }
                |       error
                                {
                                  return (int)nil;
                                }
                |       ERROR
                                {
                                  return (int)nil;
                                }
                ;

object:         NSSTRING
                |       NSDATA
                |       array
                |       dictionary
                ;

array:          '(' objlist ')'
                                {$$ = $2;}
                |       '(' ')'
                                {$$ = [NSArray array];}
                ;

objlist:                objlist ',' object
                                {
                                  $$ = $1;
                                  [$$ addObject:$3];
                                }
                |       object
                                {
                                  $$ = [[[NSMutableArray alloc]
initWithCapacity:1] autorelease];
                                  [$$ addObject:$1];
                                }
                ;

dictionary:     '{' keyval_list '}'
                                {$$ = $2;}
		|	'{' keyval_list ';' '}'
                                {$$ = $2;}
                |       '{' '}'
                                {$$ = [NSDictionary dictionary];}
                ;
keyval_list:    keyval_list ';' keyval_pair
                                {
                                  $$ = $1;
                                  [$$ addEntriesFromDictionary:$3];
				  [$3 release];
                                }
                |       keyval_pair
				{
                                  $$ = $1;
				  [$$ autorelease];
				}
                ;
keyval_pair:    NSSTRING '=' object
                                {
                                  $$ = [[NSMutableDictionary alloc]
initWithCapacity:1];
                                  [$$ setObject:$3 forKey:$1];
                                }
                ;
%%

                /* C code section */
int plerror(char *s)
{
  return 0;
}
