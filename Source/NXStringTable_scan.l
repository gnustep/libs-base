%{

#ifdef HAVE_FLEX
#define YY_DECL int NXtable_scan(FILE *NXscan_in, \
		FILE *NXscan_out, const char **buffer)
#endif
#define MAX_STRINGTABLE_LENGTH	1024
#define KEY	1
#define VALUE	2

#define yyterminate() {got = 0; line = 1; return YY_NULL;}
#define return_err() {got = 0; line = 1; return -1;}
#define return_ok() {return 1;}

%}

ESCAPES		[abfnrtv]

%s parse comment token

%%
    /* Lexical initialization - This gets executed before any analysis */
    char string_buf[MAX_STRINGTABLE_LENGTH];
    char *string_buf_ptr;
    static int  got;		/* Holds the type of token we just got */
    static int  line;
    #ifndef HAVE_FLEX
      extern FILE *NXscan_in;
      extern FILE *NXscan_out;
      extern char *NXscan_string;
    #endif
    if (yyin != NXscan_in) {	/* Reset */
	got = 0;
	line= 1;
    	yyin  = NXscan_in;
    }
    yyout = NXscan_out;
    #ifdef HAVE_FLEX
      *buffer = string_buf;
    #else
      NXscan_string = string_buf;
    #endif
    BEGIN(parse);

<parse>"/*"         	BEGIN(comment);

<comment>[^*\n]*        /* eat anything that's not a '*' */;
<comment>"*"+[^*/\n]*   /* eat up '*'s not followed by '/'s */;
<comment>\n		line++;
<comment>"*"+"/"        BEGIN(parse);
<comment><<EOF>>	{
			    /* error - unterminated comment */
			    fprintf(stderr, "ERROR (NXStringTable): Unterminated comment\n");
			    return_err();
			}

<parse>=		{
			    if (!got) {
			    	fprintf(stderr, "\nERROR (NXStringTable): Improper use of = (Expected a key, line %d)\n", line);
			    	return_err();
			    }
			    if (got == VALUE) {
			    	fprintf(stderr, "\nERROR (NXStringTable): Improper use of = (Expected a ;, line %d)\n", line);
			    	return_err();
			     }
			 }

<parse>;			{
			    if (!got) {
			        fprintf(stderr, "\nERROR (NXStringTable): Improper use of ; (Expected a key, line %d)\n", line);
			        return_err();
			}
			    if (got == KEY) {
			        got = 0;
			    	return_ok();
			    }
			    got  = 0;
			}

<parse>[ \t]*		/* Eat up white space between tokens */;

<parse>\n		line++;

<parse>\"		{string_buf_ptr = string_buf; BEGIN(token);}

<parse>[A-Za-z]*	{
			    fprintf(stderr, "ERROR (NXStringTable): Extra characters in table (line %d)\n", line);
			    return_err();
			}

<token>\"		{   /* saw closing quote - all done */
			    BEGIN(parse);
			    *string_buf_ptr = '\0';
			    /* return string constant token type and
			    * value to parser
			    */
			    got++;
			    if (got == KEY || got == VALUE) {
			    	return_ok();
			    } else {
			    	fprintf(stderr, "ERROR (NXStringTable): Parse error, line %d \n", line);
				return_err();
			    }
			}

<token>\n		{
			    /* error - unterminated string constant */
			    fprintf(stderr, "ERROR (NXStringTable): Unterminated string (line %d)\n", line);
			    return_err();
			}

<token><<EOF>>		{
			    /* error - unterminated string constant */
			    fprintf(stderr, "ERROR (NXStringTable): Unterminated string (line %d)\n", line);
			    return_err();
			}

<token>\\{ESCAPES}  	{*string_buf_ptr++='\\';*string_buf_ptr++ = yytext[1];}

<token>\\(.|\n)  	*string_buf_ptr++ = yytext[1];

<token>[^\\\n\"]+       {
			    char *text_ptr = yytext;
			    if (!text_ptr) {
			    	fprintf(stderr, "ERROR (NXStringTable): internal parse error\n");
				break;
			    }
			    while ( *text_ptr )
				*string_buf_ptr++ = *text_ptr++;
			}

%%

int
yywrap()
{
    return 1;
}

#ifdef NEED_MAIN
#ifndef HAVE_FLEX
    FILE *NXscan_in;
    FILE *NXscan_out;
    char *NXscan_string;
#endif
int
main(int argc, char *argv[])
{
    FILE *input;
    const char *str;
    int  ok, value = 0;
    
    if (argc > 1) {
    	if ((input = fopen(argv[1], "r")) == NULL) {
	    fprintf(stderr, "Error: Couldn't open %s\n", argv[1]);
	    exit (1);
	}
    } else
	exit(1);
    
#ifdef HAVE_FLEX
    ok = NXtable_scan( input, stdout, &str);
#else
    NXscan_in = input;
    NXscan_out = stdout;
    ok = yylex();
    str = NXscan_string;
#endif
    while (ok > 0) {
	if (value)
	    printf("Value: %s\n", str);
	else
	    printf("Key:   %s\n", str);
	value = ~value;
#ifdef HAVE_FLEX
	ok = NXtable_scan( input, stdout, &str);
#else
        ok = yylex();
#endif
    }
	
    return 0;
}
#endif
