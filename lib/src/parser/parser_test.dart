// ignore_for_file: depend_on_referenced_packages

import 'package:config/src/ast/ast.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/parser/parser.dart';
import 'package:config/src/tokens/tokens.dart';
import 'package:test/test.dart';

void main() {
  test("single line", () {
    final input = "VAR = 'value'";

    final lexer = Lexer(input);
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors, equals([]));
    expect(program.lines.length, equals(1));

    expect(program.lines[0], equals(AssigmentLine(Identifier("VAR"), StringLiteral("value"))));
  });

  test("error", () {
    final input = "VAR = 'ss' VAZ";

    final lexer = Lexer(input);
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(1));
    expect(program.lines.length, equals(0));
  });

  test("fix panic when comment is at the file start position", () {
    final input = """
# comment1
# comment2
# comment3
VAR = 'ss'
VAR2 = 'ss'
    """;

    final lexer = Lexer(input);
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(0), reason: "Errors $errors");
    expect(program.lines.length, equals(2));
  });

  test("description", () {
    final input = """
VAR = 12
VAR = 12
\$VAR3 = VAR
[table] # some comment
VAR = "SOMETHINGS"
    """;

    final lexer = Lexer(input, "path/to/file");
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(0));
    expect(
      program,
      equals(
        Program("path/to/file", [
          AssigmentLine(Identifier("VAR"), Number(12)),
          AssigmentLine(Identifier("VAR"), Number(12)),
          DeclarationLine(Identifier("VAR3"), Identifier("VAR")),
          TableHeaderLine(Identifier("table")),
          AssigmentLine(Identifier("VAR"), InterpolableStringLiteral("SOMETHINGS")),
        ]),
      ),
    );
    expect(
      program.lines[3].token.pos,
      Position(
        start: Cursor(lineNumber: 3, offset: 1),
        end: Cursor(lineNumber: 3, offset: 6),
        filepath: "path/to/file",
      ),
    );
  });
}
