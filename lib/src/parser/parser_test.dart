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

  test("parse prefix operators", () {
    final tests = [("var = -5", Operator.Minus, 5.0), ("var = !true", Operator.Bang, true)];
    for (final t in tests) {
      final lexer = Lexer(t.$1);
      final parser = Parser(lexer);
      final program = parser.parseProgram();

      expect(parser.errors.length, equals(0), reason: parser.errors.join("\n"));
      expect(program.lines.length, equals(1));
      expect(
        program,
        equals(
          Program("", [
            AssigmentLine(
              Identifier("var"),
              PrefixExpression(t.$2, switch (t.$3) {
                double v => Number(v),
                bool v => Boolean(v),
                _ => throw StateError("unreachable"),
              }),
            ),
          ]),
        ),
      );
    }
  });

  test("parse infix operators", () {
    final tests = [
      ("var = 4 - 5", 4.0, Operator.Minus, 5.0),
      ("var = 3 * 2", 3.0, Operator.Mult, 2.0),
      ("var = identifer + 2", "identifer", Operator.Plus, 2.0),
      ("var = 3 < 2", 3.0, Operator.LessThan, 2.0),
      ("var = 3 <= 2", 3.0, Operator.LessOrEqThan, 2.0),
      ("var = 3 > 2", 3.0, Operator.GreatThan, 2.0),
      ("var = 3 >= 2", 3.0, Operator.GreatOrEqThan, 2.0),
    ];
    for (final t in tests) {
      final lexer = Lexer(t.$1);
      final parser = Parser(lexer);
      final program = parser.parseProgram();

      expect(parser.errors.length, equals(0), reason: parser.errors.join("\n"));
      expect(program.lines.length, equals(1));
      expect(
        program,
        equals(
          Program("", [
            AssigmentLine(
              Identifier("var"),
              InfixExpression(
                switch (t.$2) {
                  double v => Number(v),
                  String v => Identifier(v),
                  _ => throw StateError("unreachable"),
                },
                t.$3,
                Number(t.$4),
              ),
            ),
          ]),
        ),
      );
    }
  });
}
