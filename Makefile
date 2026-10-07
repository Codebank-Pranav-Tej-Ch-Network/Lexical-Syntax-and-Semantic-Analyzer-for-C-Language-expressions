# Makefile (lex + yacc expression parser)
#   make        build ./parser
#   make test   run the parser on inp1 .. inp4
#   make clean  remove every generated file
# LEX / YACC can be overridden, e.g.  make YACC=byacc
LEX    = lex
YACC   = yacc
CC     = gcc
CFLAGS = -Wall -O2

parser: y.tab.o lex.yy.o
        $(CC) $(CFLAGS) -o $@ y.tab.o lex.yy.o

# yacc -d writes y.tab.c and y.tab.h (token definitions for the lexer)
y.tab.c y.tab.h: expr.y
        $(YACC) -d expr.y

lex.yy.c: expr.l y.tab.h
        $(LEX) expr.l

y.tab.o: y.tab.c
        $(CC) $(CFLAGS) -c y.tab.c

lex.yy.o: lex.yy.c y.tab.h
        $(CC) $(CFLAGS) -c lex.yy.c

test: parser
        @for f in inp1 inp2 inp3 inp4; do ./parser $$f; echo; done

clean:
        rm -f parser y.tab.c y.tab.h lex.yy.c *.o

.PHONY: test clean
