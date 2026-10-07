/*
 * expr.y -- Parser (yacc) for C arithmetic expressions
 *
 * Written in plain yacc
 *
 * C precedence (high -> low) for the operators in this assignment:
 *
 *   level  operators                          assoc.         grammar rule
 *   -----  ---------------------------------  -------------  ---------------
 *    1     postfix  ++ --  ( )                left-to-right  postfix_expr
 *    2     prefix ++ --, unary + - * &        right-to-left  unary_expr
 *    3     binary * / %                       left-to-right  mul_expr
 *    4     binary + -                         left-to-right  add_expr
 *    5     =                                  right-to-left  assign_expr
 *
 * Instead of %left/%right declarations the precedence is encoded in the
 * grammar layers themselves (one non-terminal per level), as in the
 * Textbook (Aho, Lam, Sethi, Ullman, Sec. 4.1-4.3).  The grammar is
 * conflict-free under LALR(1).
 *
 * "*p++"   -> *(p++)  because postfix binds tighter than prefix/unary '*'
 * "(*p)++" -> ( *p )++ because parentheses force the dereference first
 *
 * Output: for each valid statement the parser prints its structure as a
 * fully parenthesised prefix (S-expression) form, e.g.
 *      x = *p++;   ->   (= x (deref (post++ p)))
 * so that the chosen parse is visible and easy to check.
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int  yylex(void);
void yyerror(const char *msg);

extern FILE *yyin;
extern int   lineno;              /* these are all maintained by expr.l */
extern int   tok_line, tok_col, tok_eof, lex_errors;
extern char  tok_text[];

static int stmt_count    = 0;     /* statements accepted        */
static int syntax_errors = 0;     /* syntax errors reported     */

/* Build "(op a)" / "(op a b)"; frees the child strings. */
static char *mk1(const char *op, char *a)
{
    size_t n = strlen(op) + strlen(a) + 4;
    char *s = malloc(n);
    if (!s) { perror("malloc"); exit(2); }
    snprintf(s, n, "(%s %s)", op, a);
    free(a);
    return s;
}
static char *mk2(const char *op, char *a, char *b)
{
    size_t n = strlen(op) + strlen(a) + strlen(b) + 5;
    char *s = malloc(n);
    if (!s) { perror("malloc"); exit(2); }
    snprintf(s, n, "(%s %s %s)", op, a, b);
    free(a);
    free(b);
    return s;
}
%}

%union { char *str; int line; }

%token <str>  ID NUM
%token <line> SEMI
%token INC DEC

%type <str> expr assign_expr add_expr mul_expr unary_expr postfix_expr primary_expr

%start program

%%

program
    : /* empty */
    | program statement
    ;

/* A statement is terminated by ';'.  On a syntax error the
 * parser discards tokens up to the next ';' and carries on, so several
 * errors can be reported in one run.  (Strings held by discarded stack
 * entries are not freed: plain yacc has no %destructor.  The program is
 * short-lived, so this is harmless.) */
statement
    : expr SEMI     { stmt_count++;
                      printf("line %d: OK    %s\n", $2, $1);
                      free($1); }
    | error SEMI    { yyerrok; }
    ;

expr
    : assign_expr                       { $$ = $1; }
    ;

/* Right-associative: a = b = c  ==  a = (b = c).
 * The left side must be a unary_expr (an lvalue-like form such as
 * p, *p, *(p+i), (*p)); this is also how C grammar is written. */
assign_expr
    : add_expr                          { $$ = $1; }
    | unary_expr '=' assign_expr        { $$ = mk2("=", $1, $3); }
    ;

add_expr
    : mul_expr                          { $$ = $1; }
    | add_expr '+' mul_expr             { $$ = mk2("+", $1, $3); }
    | add_expr '-' mul_expr             { $$ = mk2("-", $1, $3); }
    ;

mul_expr
    : unary_expr                        { $$ = $1; }
    | mul_expr '*' unary_expr           { $$ = mk2("*", $1, $3); }
    | mul_expr '/' unary_expr           { $$ = mk2("/", $1, $3); }
    | mul_expr '%' unary_expr           { $$ = mk2("%", $1, $3); }
    ;

/* Prefix / unary operators: right-associative, so  - - a, **p, ++*p  work. */
unary_expr
    : postfix_expr                      { $$ = $1; }
    | INC unary_expr                    { $$ = mk1("pre++", $2); }
    | DEC unary_expr                    { $$ = mk1("pre--", $2); }
    | '&' unary_expr                    { $$ = mk1("addr",  $2); }
    | '*' unary_expr                    { $$ = mk1("deref", $2); }
    | '+' unary_expr                    { $$ = mk1("pos",   $2); }
    | '-' unary_expr                    { $$ = mk1("neg",   $2); }
    ;

/* Postfix operators bind tighter than every prefix operator. */
postfix_expr
    : primary_expr                      { $$ = $1; }
    | postfix_expr INC                  { $$ = mk1("post++", $1); }
    | postfix_expr DEC                  { $$ = mk1("post--", $1); }
    ;

primary_expr
    : ID                                { $$ = $1; }
    | NUM                               { $$ = $1; }
    | '(' expr ')'                      { $$ = $2; }
    ;

%%

/* Called by the generated parser on a syntax error.  The offending token
 * is the most recent one returned by yylex, whose position and text the
 * lexer recorded in tok_line / tok_col / tok_text. */
void yyerror(const char *msg)
{
    (void)msg;                       /* generic text differs between yaccs */
    syntax_errors++;
    if (tok_eof)
        printf("line %d: ERROR syntax error: unexpected end of input (missing ';' ?)\n",
               lineno);
    else
        printf("line %d, col %d: ERROR syntax error: unexpected '%s'\n",
               tok_line, tok_col, tok_text);
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: %s <input-file>\n", argv[0]);
        return 2;
    }
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror(argv[1]);
        return 2;
    }

    printf("Parsing %s\n", argv[1]);
    yyparse();
    fclose(yyin);

    printf("Summary: %d valid statement(s), %d syntax error(s), %d lexical error(s)\n",
           stmt_count, syntax_errors, lex_errors);
    return (syntax_errors || lex_errors) ? 1 : 0;
}
