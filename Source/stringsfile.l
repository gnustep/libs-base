%{
#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include "stringsfile.tab.h"

#ifdef sfwrap
#undef sfwrap
#endif

int sfwrap()
{
return 1;
}

%}


quote		\"
semicolen	\;
equals		\=
label		[a-zA-Z][a-zA-Z0-9_]*
quoted		[^"]*\"
whitespace	[ \t\n]
startComment	\/\*
endComment	\*\/


%x QUOTE COMMENT


%%

<COMMENT>{endComment} { BEGIN INITIAL; }

<COMMENT>. ;

<QUOTE>{quoted} {	
			if (sfleng == 1)
			{
				BEGIN INITIAL;
				sflval.obj = [[[NSString alloc] init] autorelease];
				return QUOTED;
			}
			
			if (sftext[sfleng - 2] == '\\')
				yymore();
			else
			{
				BEGIN INITIAL;
				sflval.obj = [[[NSString alloc] initWithCString: sftext length: sfleng - 1] autorelease];
				return QUOTED;	
			}
		}

{quote}		{BEGIN QUOTE;}

{startComment}	{BEGIN COMMENT;}

{label}		{
			sflval.obj = [NSString stringWithCString: sftext];
			return LABEL;
		}

{semicolen}	{return SEMICOLEN;}

{equals}	{return EQUALS;}

{whitespace}+	;


.		{ return ERROR; }

%%

%{
#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include "stringsfile.tab.h"

#ifdef sfwrap
#undef sfwrap
#endif

int sfwrap()
{
return 1;
}

%}


quote		\"
semicolen	\;
equals		\=
label		[a-zA-Z][a-zA-Z0-9_]*
quoted		[^"]*\"
whitespace	[ \t\n]
startComment	\/\*
endComment	\*\/


%x QUOTE COMMENT


%%

<COMMENT>{endComment} { BEGIN INITIAL; }

<COMMENT>. ;

<QUOTE>{quoted} {	
			if (sfleng == 1)
			{
				BEGIN INITIAL;
				sflval.obj = [[[NSString alloc] init] autorelease];
				return QUOTED;
			}
			
			if (sftext[sfleng - 2] == '\\')
				yymore();
			else
			{
				BEGIN INITIAL;
				sflval.obj = [[[NSString alloc] initWithCString: sftext length: sfleng - 1] autorelease];
				return QUOTED;	
			}
		}

{quote}		{BEGIN QUOTE;}

{startComment}	{BEGIN COMMENT;}

{label}		{
			sflval.obj = [NSString stringWithCString: sftext];
			return LABEL;
		}

{semicolen}	{return SEMICOLEN;}

{equals}	{return EQUALS;}

{whitespace}+	;


.		{ return ERROR; }

%%

