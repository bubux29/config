%{
#include <stdio.h>

#ifdef DEBUG
#define SHOW(a) printf(#a" ");
#else

#include "lvconfigparser.h"
#include "lvsparse.h"
#include "lvlog.h"

extern YYLTYPE yylloc;
#define YY_USER_init yylloc.first_line=1;

#define SHOW(a) return (a);
#endif

%}

%x CMT

%option outfile="lvcconfig_lex.c" header-file="lvcconfig_lex.h"

%%
\n		{
		#ifndef DEBUG
		yylloc.first_line++;
		int l = yyget_lineno();
		yyset_lineno(++l);
		BEGIN 0;
		#endif
		} /* just to let user have an idea */
server		SHOW(SERVER);
tcp		SHOW(TCP);
udp		SHOW(UDP);
\.type		SHOW(TYPE);
loglevel	SHOW(LOG);
\{		SHOW(OPBRK);
\}		SHOW(CLBRK);
\.port		SHOW(PORT);
\.name		SHOW(LABEL);
\.ip		SHOW(ADDR);
DEBUG		{
		#ifndef DEBUG
		yylval.u = E_LV_DEBUG;
		#endif
		SHOW(LEVEL);
		}
WARNING		{
		#ifndef DEBUG
		yylval.u = E_LV_WARNG;
		#endif
		SHOW(LEVEL);
		}
ERROR		{
		#ifndef DEBUG
		yylval.u = E_LV_ERROR;
		#endif
		SHOW(LEVEL);
		}
QUIET		{
		#ifndef DEBUG
		yylval.u = E_LV_QUIET;
		#endif
		SHOW(LEVEL);
		}
0x[0-9]+	{
		#ifndef DEBUG
		lv_getuint(&yylval.u, yytext, NULL);
		#endif
		SHOW(NUM);
		}
[0-9]+		{
		#ifndef DEBUG
		lv_getuint(&yylval.u, yytext, NULL);
		#endif
		SHOW(NUM);
		}
[[:alnum:]\.]+	{
		#ifndef DEBUG
		yylval.s = strdup(yytext);
		#endif
		SHOW(STR);
		}
[[:space:]]+	;
\/\*		{
		BEGIN CMD;
		#ifndef DEBUG
		yymore();
		#else
		printf ("Comment begins\n");
		#endif
		}
<CMD>.		yymore();
<CMD>\*\/	{
		BEGIN 0;
		}
#.*$		;
.		;
%%
