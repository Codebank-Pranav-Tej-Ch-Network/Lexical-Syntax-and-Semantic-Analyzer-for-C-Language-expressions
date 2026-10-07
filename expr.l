/*
 * expr.l -- Lexical analyser (lex) for C arithmetic expressions
 *
 * Written in plain lex
 *
 * Tokens recognised
 *   ID      identifiers          [A-Za-z_][A-Za-z0-9_]*
 *   NUM     numeric constants    42, 3.14, 2., .5, 1e-3, 6.02E23
 *   INC     "++"                 DEC  "--"
 *   SEMI    ";"  (carries its line number for the parser's report)
 *   single-character tokens      + - * / % & = ( )
 *
 * lex always takes the LONGEST match, so "a+++b" is scanned as
 * a ++ + b, exactly as a C compiler does.
 *
 * Whether '*', '&', '+', '-', "++", "--" are prefix, postfix, unary or
 * binary is NOT decided here; the lexer only returns the token.  The
 * grammar in expr.y decides from the token's position.
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "y.tab.h"            /* token codes and YYSTYPE from yacc -d  */

/* Silence "unused function" warnings if the lex in use is flex. */
#define YY_NO_UNPUT
#define YY_NO_INPUT

/* Position keeping, shared with expr.y (plain lex has no yylineno
 * or location support, so I used my own). */
int  lineno     = 1;          /* current line (1-based)                    */
int  col        = 1;          /* current column (1-based)                  */
int  tok_line   = 1;          /* line   of the most recent token           */
int  tok_col    = 1;          /* column of the most recent token           */
char tok_text[64] = "";       /* text   of the most recent token           */
int  tok_eof    = 0;          /* set when the end of input is reached      */
int  lex_errors = 0;          /* number of invalid characters seen         */

/* Call at the start of every token action. */
#define TRACK  do {                                              \
        tok_line = lineno;                                       \
        tok_col  = col;                                          \
        col     += yyleng;                                       \
        strncpy(tok_text, yytext, sizeof(tok_text) - 1);         \
        tok_text[sizeof(tok_text) - 1] = '\0';                   \
    } while (0)
%}

DIGIT   [0-9]
IDENT   [A-Za-z_][A-Za-z0-9_]*
EXP     [eE][+-]?{DIGIT}+

%%

[ \t\r]+                 { col += yyleng;            /* skip blanks            */ }
\n                       { lineno++; col = 1;        /* new line               */ }
"//".*                   { col += yyleng;            /* skip // comments       */ }

"++"                     { TRACK; return INC; }
"--"                     { TRACK; return DEC; }
";"                      { TRACK; yylval.line = lineno; return SEMI; }

{DIGIT}+(\.{DIGIT}*)?({EXP})?  |
\.{DIGIT}+({EXP})?       { TRACK; yylval.str = strdup(yytext); return NUM; }

{IDENT}                  { TRACK; yylval.str = strdup(yytext); return ID; }

[-+*/%&=()]              { TRACK; return yytext[0]; }

.                        { /* anything else: lexical error; report and skip */
                           printf("line %d, col %d: lexical error: invalid character '%s'\n",
                                  lineno, col, yytext);
                           col += yyleng;
                           lex_errors++; }

%%

/* Called by lex at end of input. It is understood that EOF was reached so the
 * parser can word its error message properly, then stop scanning. */
int yywrap(void)
{
    tok_eof = 1;
    return 1;
}
