# Lexer and Parser for C Arithmetic Expressions (lex + yacc)

## 1. Compilation and execution
Requirements: `gcc`, `make`, and the standard `lex` and `yacc` commands.

```bash
# Ubuntu / WSL (lex comes from flex; yacc from byacc or bison -y)
sudo apt update && sudo apt install -y build-essential flex byacc

make                # yacc -d expr.y ; lex expr.l ; gcc ...  -> ./parser
./parser inp1       # input file name is given on the command line
make test           # runs ./parser on inp1 .. inp4
make clean          # removes parser, y.tab.c/.h, lex.yy.c, *.o
make YACC=byacc     # optional: choose a specific yacc
```

Exit status: `0` no errors, `1` syntax/lexical error reported, `2` usage/file error.

### Output format
```
line N: OK    <S-expression>        statement accepted, parse structure shown
line N, col M: ERROR ...            syntax error at the offending token
line N, col M: lexical error ...    invalid character (skipped)
=== summary: ... ===
```
The S-expression is the fully parenthesised prefix form of the parse tree:

| Input | Output |
|---|---|
| `x = *p++;` | `(= x (deref (post++ p)))` |
| `x = (*p)++;` | `(= x (post++ (deref p)))` |
| `x = *++p;` | `(= x (deref (pre++ p)))` |

Operator names: `pre++ pre-- post++ post-- deref addr neg pos` (unary), `+ - * / % =` (binary).

## 2. Design and assumptions
- Files: `expr.l` (lex), `expr.y` (yacc), `Makefile`, `inp1`–`inp4`, `readme`.
- Input is a sequence of statements, each `expression ;`.
- Precedence/associativity is encoded in grammar layers
  (postfix > prefix/unary > `* / %` > `+ -` > `=`), not `%left/%right`; no yacc conflicts.
- Maximal munch: `a+++b` is `a ++ + b`, `a---b` is `a -- - b`; `a--b` is a syntax error, as in C.
- Left side of `=` is a unary expression (as in the ISO C grammar): `*p = ..`, `*(p+i) = ..`
  are accepted, `a + b = c` is rejected.
- Constants: `42`, `3.14`, `2.`, `.5`, `1e-3`; identifiers `[A-Za-z_][A-Za-z0-9_]*`.
- `//` comments, blanks and newlines are skipped.
- Error recovery: skip to the next `;` and continue, so several errors are reported per run.
- Invalid characters are reported by the lexer and skipped (may cause a follow-up syntax error).

## 3. Test cases
| File | Purpose |
|---|---|
| `inp1` | arithmetic: precedence, associativity, parentheses, unary `+/-`, constant forms; Aho-style `id+id*id`, `(id+id)*id`, `9-5+2` |
| `inp2` | prefix/postfix `++`/`--`, incl. maximal munch `a+++b`, `a---b` |
| `inp3` | pointers: `*p++`, `*++p`, `(*p)++`, `++*p`, `*p = a+b`, `*(p+i)`, `*p++ = *q++`, `**pp`, `&a`, `a**p` |
| `inp4` | invalid input: the assignment's three samples plus missing operands, extra `)`, adjacent operands, non-lvalue target, invalid character, unterminated last statement, and one valid line showing recovery |

## 4. Known limitations
- Purely syntactic: `5++` or `a++ = b` are accepted (C rejects them semantically).
- Statements must end with `;`; a missing final `;` is reported at end of input.
- Error messages give position and unexpected token but not the expected tokens.
- Plain yacc has no `%destructor`: some strings are not freed during error recovery.
- Only the operators in the assignment are supported; no `/* */` comments.

## 5. Acknowledgements
- Grammar layering and example expressions: Aho, Lam, Sethi, Ullman, *Compilers: Principles, Techniques, and Tools*, 2nd ed.
- lex & yacc documentation (POSIX; Levine, Mason, Brown, *lex & yacc*).
- An AI assistant (Claude) was used for guidance — keep only if accurate and permitted by the course policy.
