#ifndef lint
static char yysccsid[] = "@(#)yaccpar	1.9 (Berkeley) 02/21/93";
#endif
#define YYBYACC 1
#define YYMAJOR 1
#define YYMINOR 9
#define yyclearin (yychar=(-1))
#define yyerrok (yyerrflag=0)
#define YYRECOVERING (yyerrflag!=0)
#define yyparse plparse
#define yylex pllex
#define yyerror plerror
#define yychar plchar
#define yyval plval
#define yylval pllval
#define yydebug pldebug
#define yynerrs plnerrs
#define yyerrflag plerrflag
#define yyss plss
#define yyssp plssp
#define yyvs plvs
#define yyvsp plvsp
#define yylhs pllhs
#define yylen pllen
#define yydefred pldefred
#define yydgoto pldgoto
#define yysindex plsindex
#define yyrindex plrindex
#define yygindex plgindex
#define yytable pltable
#define yycheck plcheck
#define yyname plname
#define yyrule plrule
#define YYPREFIX "pl"
#line 5 "proplist.y"
#include <gnustep/base/preface.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#line 16 "proplist.y"
typedef union {
        id obj;
} YYSTYPE;
#line 47 "y.tab.c"
#define NSSTRING 257
#define NSDATA 258
#define ERROR 259
#define YYERRCODE 256
short pllhs[] = {                                        -1,
    0,    0,    0,    1,    1,    1,    1,    2,    2,    3,
    3,    4,    4,    4,    5,    5,    6,
};
short pllen[] = {                                         2,
    1,    1,    1,    1,    1,    1,    1,    3,    2,    3,
    1,    3,    4,    2,    3,    1,    3,
};
short pldefred[] = {                                      0,
    2,    4,    5,    3,    0,    0,    0,    1,    6,    7,
    9,   11,    0,    0,   14,    0,   16,    8,    0,    0,
   12,    0,   10,   17,   13,   15,
};
short pldgoto[] = {                                       7,
    8,    9,   13,   10,   16,   17,
};
short plsindex[] = {                                    -40,
    0,    0,    0,    0,  -37, -124,    0,    0,    0,    0,
    0,    0,  -33,  -52,    0,  -53,    0,    0,  -35,  -35,
    0, -123,    0,    0,    0,    0,
};
short plrindex[] = {                                      0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,
};
short plgindex[] = {                                      0,
    2,    0,    0,    0,    0,  -12,
};
#define YYTABLESIZE 223
short pltable[] = {                                       5,
   15,   25,    5,   11,    5,   22,   12,   18,   20,   26,
   19,    0,    0,    0,    0,    0,    0,    0,    0,    0,
   23,   24,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,   21,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    6,    0,    0,    6,    0,    6,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,   14,   14,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    1,    2,    3,    4,    2,
    3,    2,    3,
};
short plcheck[] = {                                      40,
  125,  125,   40,   41,   40,   59,    5,   41,   61,   22,
   44,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   19,   20,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,  125,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,  123,   -1,   -1,  123,   -1,  123,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,  257,  257,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,
   -1,   -1,   -1,   -1,   -1,  256,  257,  258,  259,  257,
  258,  257,  258,
};
#define YYFINAL 7
#ifndef YYDEBUG
#define YYDEBUG 0
#endif
#define YYMAXTOKEN 259
#if YYDEBUG
char *plname[] = {
"end-of-file",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,"'('","')'",0,0,"','",0,0,0,0,0,0,0,0,0,0,0,0,0,0,"';'",0,"'='",0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"'{'",0,"'}'",0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
"NSSTRING","NSDATA","ERROR",
};
char *plrule[] = {
"$accept : root",
"root : object",
"root : error",
"root : ERROR",
"object : NSSTRING",
"object : NSDATA",
"object : array",
"object : dictionary",
"array : '(' objlist ')'",
"array : '(' ')'",
"objlist : objlist ',' object",
"objlist : object",
"dictionary : '{' keyval_list '}'",
"dictionary : '{' keyval_list ';' '}'",
"dictionary : '{' '}'",
"keyval_list : keyval_list ';' keyval_pair",
"keyval_list : keyval_pair",
"keyval_pair : NSSTRING '=' object",
};
#endif
#ifdef YYSTACKSIZE
#undef YYMAXDEPTH
#define YYMAXDEPTH YYSTACKSIZE
#else
#ifdef YYMAXDEPTH
#define YYSTACKSIZE YYMAXDEPTH
#else
#define YYSTACKSIZE 500
#define YYMAXDEPTH 500
#endif
#endif
int yydebug;
int yynerrs;
int yyerrflag;
int yychar;
short *yyssp;
YYSTYPE *yyvsp;
YYSTYPE yyval;
YYSTYPE yylval;
short yyss[YYSTACKSIZE];
YYSTYPE yyvs[YYSTACKSIZE];
#define yystacksize YYSTACKSIZE
#line 91 "proplist.y"

                /* C code section */
int plerror(char *s)
{
  return 0;
}
#line 198 "y.tab.c"
#define YYABORT goto yyabort
#define YYREJECT goto yyabort
#define YYACCEPT goto yyaccept
#define YYERROR goto yyerrlab
int
yyparse()
{
    register int yym, yyn, yystate;
#if YYDEBUG
    register char *yys;
    extern char *getenv();

    if (yys = getenv("YYDEBUG"))
    {
        yyn = *yys;
        if (yyn >= '0' && yyn <= '9')
            yydebug = yyn - '0';
    }
#endif

    yynerrs = 0;
    yyerrflag = 0;
    yychar = (-1);

    yyssp = yyss;
    yyvsp = yyvs;
    *yyssp = yystate = 0;

yyloop:
    if (yyn = yydefred[yystate]) goto yyreduce;
    if (yychar < 0)
    {
        if ((yychar = yylex()) < 0) yychar = 0;
#if YYDEBUG
        if (yydebug)
        {
            yys = 0;
            if (yychar <= YYMAXTOKEN) yys = yyname[yychar];
            if (!yys) yys = "illegal-symbol";
            printf("%sdebug: state %d, reading %d (%s)\n",
                    YYPREFIX, yystate, yychar, yys);
        }
#endif
    }
    if ((yyn = yysindex[yystate]) && (yyn += yychar) >= 0 &&
            yyn <= YYTABLESIZE && yycheck[yyn] == yychar)
    {
#if YYDEBUG
        if (yydebug)
            printf("%sdebug: state %d, shifting to state %d\n",
                    YYPREFIX, yystate, yytable[yyn]);
#endif
        if (yyssp >= yyss + yystacksize - 1)
        {
            goto yyoverflow;
        }
        *++yyssp = yystate = yytable[yyn];
        *++yyvsp = yylval;
        yychar = (-1);
        if (yyerrflag > 0)  --yyerrflag;
        goto yyloop;
    }
    if ((yyn = yyrindex[yystate]) && (yyn += yychar) >= 0 &&
            yyn <= YYTABLESIZE && yycheck[yyn] == yychar)
    {
        yyn = yytable[yyn];
        goto yyreduce;
    }
    if (yyerrflag) goto yyinrecovery;
#ifdef lint
    goto yynewerror;
#endif
yynewerror:
    yyerror("syntax error");
#ifdef lint
    goto yyerrlab;
#endif
yyerrlab:
    ++yynerrs;
yyinrecovery:
    if (yyerrflag < 3)
    {
        yyerrflag = 3;
        for (;;)
        {
            if ((yyn = yysindex[*yyssp]) && (yyn += YYERRCODE) >= 0 &&
                    yyn <= YYTABLESIZE && yycheck[yyn] == YYERRCODE)
            {
#if YYDEBUG
                if (yydebug)
                    printf("%sdebug: state %d, error recovery shifting\
 to state %d\n", YYPREFIX, *yyssp, yytable[yyn]);
#endif
                if (yyssp >= yyss + yystacksize - 1)
                {
                    goto yyoverflow;
                }
                *++yyssp = yystate = yytable[yyn];
                *++yyvsp = yylval;
                goto yyloop;
            }
            else
            {
#if YYDEBUG
                if (yydebug)
                    printf("%sdebug: error recovery discarding state %d\n",
                            YYPREFIX, *yyssp);
#endif
                if (yyssp <= yyss) goto yyabort;
                --yyssp;
                --yyvsp;
            }
        }
    }
    else
    {
        if (yychar == 0) goto yyabort;
#if YYDEBUG
        if (yydebug)
        {
            yys = 0;
            if (yychar <= YYMAXTOKEN) yys = yyname[yychar];
            if (!yys) yys = "illegal-symbol";
            printf("%sdebug: state %d, error recovery discards token %d (%s)\n",
                    YYPREFIX, yystate, yychar, yys);
        }
#endif
        yychar = (-1);
        goto yyloop;
    }
yyreduce:
#if YYDEBUG
    if (yydebug)
        printf("%sdebug: state %d, reducing by rule %d (%s)\n",
                YYPREFIX, yystate, yyn, yyrule[yyn]);
#endif
    yym = yylen[yyn];
    yyval = yyvsp[1-yym];
    switch (yyn)
    {
case 1:
#line 25 "proplist.y"
{
                      /* want an object, followed by nothing else (<<EOF>>) */
                                  return (int)yyvsp[0].obj;
                                }
break;
case 2:
#line 30 "proplist.y"
{
                                  return (int)nil;
                                }
break;
case 3:
#line 34 "proplist.y"
{
                                  return (int)nil;
                                }
break;
case 8:
#line 46 "proplist.y"
{yyval.obj = yyvsp[-1].obj;}
break;
case 9:
#line 48 "proplist.y"
{yyval.obj = [NSArray array];}
break;
case 10:
#line 52 "proplist.y"
{
                                  yyval.obj = yyvsp[-2].obj;
                                  [yyval.obj addObject:yyvsp[0].obj];
                                }
break;
case 11:
#line 57 "proplist.y"
{
                                  yyval.obj = [[[NSMutableArray alloc]
initWithCapacity:1] autorelease];
                                  [yyval.obj addObject:yyvsp[0].obj];
                                }
break;
case 12:
#line 65 "proplist.y"
{yyval.obj = yyvsp[-1].obj;}
break;
case 13:
#line 67 "proplist.y"
{yyval.obj = yyvsp[-2].obj;}
break;
case 14:
#line 69 "proplist.y"
{yyval.obj = [NSDictionary dictionary];}
break;
case 15:
#line 72 "proplist.y"
{
                                  yyval.obj = yyvsp[-2].obj;
                                  [yyval.obj addEntriesFromDictionary:yyvsp[0].obj];
				  [yyvsp[0].obj release];
                                }
break;
case 16:
#line 78 "proplist.y"
{
                                  yyval.obj = yyvsp[0].obj;
				  [yyval.obj autorelease];
				}
break;
case 17:
#line 84 "proplist.y"
{
                                  yyval.obj = [[NSMutableDictionary alloc]
initWithCapacity:1];
                                  [yyval.obj setObject:yyvsp[0].obj forKey:yyvsp[-2].obj];
                                }
break;
#line 416 "y.tab.c"
    }
    yyssp -= yym;
    yystate = *yyssp;
    yyvsp -= yym;
    yym = yylhs[yyn];
    if (yystate == 0 && yym == 0)
    {
#if YYDEBUG
        if (yydebug)
            printf("%sdebug: after reduction, shifting from state 0 to\
 state %d\n", YYPREFIX, YYFINAL);
#endif
        yystate = YYFINAL;
        *++yyssp = YYFINAL;
        *++yyvsp = yyval;
        if (yychar < 0)
        {
            if ((yychar = yylex()) < 0) yychar = 0;
#if YYDEBUG
            if (yydebug)
            {
                yys = 0;
                if (yychar <= YYMAXTOKEN) yys = yyname[yychar];
                if (!yys) yys = "illegal-symbol";
                printf("%sdebug: state %d, reading %d (%s)\n",
                        YYPREFIX, YYFINAL, yychar, yys);
            }
#endif
        }
        if (yychar == 0) goto yyaccept;
        goto yyloop;
    }
    if ((yyn = yygindex[yym]) && (yyn += yystate) >= 0 &&
            yyn <= YYTABLESIZE && yycheck[yyn] == yystate)
        yystate = yytable[yyn];
    else
        yystate = yydgoto[yym];
#if YYDEBUG
    if (yydebug)
        printf("%sdebug: after reduction, shifting from state %d \
to state %d\n", YYPREFIX, *yyssp, yystate);
#endif
    if (yyssp >= yyss + yystacksize - 1)
    {
        goto yyoverflow;
    }
    *++yyssp = yystate;
    *++yyvsp = yyval;
    goto yyloop;
yyoverflow:
    yyerror("yacc stack overflow");
yyabort:
    return (1);
yyaccept:
    return (0);
}
