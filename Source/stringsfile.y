
%{
#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
static NSMutableDictionary *properties;

%}


%token <obj> QUOTED LABEL
%token SEMICOLEN EQUALS ERROR

%union {
	id obj;
}

%type <obj> value

%%

file:		asignments
		{
			return 1;
		}
		| error
		{
			return 0;
		}
		| ERROR
		{
			return 0;
		};


asignments:	asignment
		| asignments asignment
                ;

asignment:	value EQUALS value SEMICOLEN
		{
			[(NSMutableDictionary *)properties setObject: $3 forKey: (NSString *) $1];
		}
		;

value:		LABEL
		{
			$$ = $1;
		}
                | QUOTED
		{
			$$ = $1;
		};

%%

int sferror(char *s)
{
  return 0;
}

void
sfSetDict(NSMutableDictionary *aDict)
{
  properties = aDict;
}

