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

  test("test groups and arrays", () {
    final input = """
VAR = 12
VAR = 12.3
\$VAR3 = VAR
group { # some comment
  VAR = "SOMETHINGS"
  VAR2 = "SOMETHINGS"
  group {
    VAR = "SOMETHINGS"
    VAR2 = "SOMETHINGS"
  }
}
array = [1, 2 + 3, 3 * VAR3]
array2 = [1]
array3 = [
  1,
  2,
  3
]
array4 = [
  1,
  2,
  3,
]
map1 = {
  1: 12,
}
mapEmpty = {}
    """;

    final lexer = Lexer(input, "path/to/file");
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(0), reason: errors.join("\n"));
    expect(
      program,
      equals(
        Program("path/to/file", [
          AssigmentLine(Identifier("VAR"), NumberInteger(12)),
          AssigmentLine(Identifier("VAR"), NumberDouble(12.3)),
          DeclarationLine(Identifier("VAR3"), Identifier("VAR")),
          Block(Identifier("group"), [
            AssigmentLine(Identifier("VAR"), InterpolableStringLiteral("SOMETHINGS")),
            AssigmentLine(Identifier("VAR2"), InterpolableStringLiteral("SOMETHINGS")),
            Block(Identifier("group"), [
              AssigmentLine(Identifier("VAR"), InterpolableStringLiteral("SOMETHINGS")),
              AssigmentLine(Identifier("VAR2"), InterpolableStringLiteral("SOMETHINGS")),
            ]),
          ]),
          AssigmentLine(
            Identifier("array"),
            ArrayExpression([
              NumberInteger(1),
              InfixExpression(NumberInteger(2), Operator.Plus, NumberInteger(3)),
              InfixExpression(NumberInteger(3), Operator.Mult, Identifier("VAR3")),
            ]),
          ),
          AssigmentLine(Identifier("array2"), ArrayExpression([NumberInteger(1)])),
          AssigmentLine(
            Identifier("array3"),
            ArrayExpression([NumberInteger(1), NumberInteger(2), NumberInteger(3)]),
          ),
          AssigmentLine(
            Identifier("array4"),
            ArrayExpression([NumberInteger(1), NumberInteger(2), NumberInteger(3)]),
          ),
          AssigmentLine(
            Identifier("map1"),
            MapExpression({EntryExpression(NumberInteger(1), NumberInteger(12))}),
          ),
          AssigmentLine(Identifier("mapEmpty"), MapExpression({})),
        ]),
      ),
    );
    expect(
      program.lines[3].token.pos,
      Position(
        start: Cursor(lineNumber: 3, offset: 0),
        end: Cursor(lineNumber: 3, offset: 5),
        filepath: "path/to/file",
      ),
      reason: "${program.lines[3]}",
    );
  });

  test("parse prefix operators", () {
    final tests = [("var = -5", Operator.Minus, 5), ("var = !true", Operator.Bang, true)];
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
                double v => NumberDouble(v),
                bool v => Boolean(v),
                int v => NumberInteger(v),
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
      ("var = 4 - 5", 4, Operator.Minus, 5),
      ("var = 3 * 2.3", 3, Operator.Mult, 2.3),
      ("var = 3 / 2", 3, Operator.Div, 2),
      ("var = identifer + 2", "identifer", Operator.Plus, 2),
      ("var = 3.1 < 2.123", 3.1, Operator.LessThan, 2.123),
      ("var = 3 <= 2", 3, Operator.LessOrEqThan, 2),
      ("var = 3 > 2", 3, Operator.GreatThan, 2),
      ("var = 3 >= 2", 3, Operator.GreatOrEqThan, 2),
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
                  double v => NumberDouble(v),
                  String v => Identifier(v),
                  int v => NumberInteger(v),
                  _ => throw StateError("unreachable"),
                },
                t.$3,
                switch (t.$4) {
                  double v => NumberDouble(v),
                  int v => NumberInteger(v),
                },
              ),
            ),
          ]),
        ),
      );
    }
  });

  test("precedence operator", () {
    final tests = [
      ("-a * b", "((-a) * b)"),
      ("!-a", "(!(-a))"),
      ("a + b + c", "((a + b) + c)"),
      ("a + b - c", "((a + b) - c)"),
      ("a * b * c", "((a * b) * c)"),
      ("a * b / c", "((a * b) / c)"),
      ("a + b / c", "(a + (b / c))"),
      ("a + b * c + d / e - f", "(((a + (b * c)) + (d / e)) - f)"),
      ("5 > 4 == 3 < 4", "((5 > 4) == (3 < 4))"),
      ("5 < 4 != 3 > 4", "((5 < 4) != (3 > 4))"),
      ("3 + 4 * 5 == 3 * 1 + 4 * 5", "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))"),
      ("3 + 4 * 5 == 3 * 1 + 4 * 5", "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))"),
      // grouped expressions
      ("(5 + 5) * 2", "((5 + 5) * 2)"),
      ("2 / (5 + 5)", "(2 / (5 + 5))"),
      ("-(5 + 5)", "(-(5 + 5))"),
      ("!(true == true)", "(!(true == true))"),
    ];
    for (final t in tests) {
      final parser = Parser(Lexer("var = ${t.$1}"));
      final program = parser.parseProgram();
      expect(parser.errors.length, equals(0), reason: parser.errors.join("\n"));
      expect(program.toString(), equals("var = ${t.$2}"));
    }
  });

  test("line end in semmicolon", () {
    final input = """
;;;;;
var1 = 1;
var2 = 2;
""";
    final lexer = Lexer(input, "path/to/file");
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(0), reason: errors.join("\n"));

    expect(
      program,
      equals(
        Program("path/to/file", [
          AssigmentLine(Identifier("var1"), NumberInteger(1)),
          AssigmentLine(Identifier("var2"), NumberInteger(2)),
        ]),
      ),
    );
  });

  test("Nested blocks", () {
    final input = """
Group {
  Group {
    var = 1
  }
}
""";
    final lexer = Lexer(input, "path/to/file");
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(0), reason: errors.join("\n"));

    expect(
      program,
      equals(
        Program("path/to/file", [
          Block(Identifier("Group"), [
            Block(Identifier("Group"), [AssigmentLine(Identifier("var"), NumberInteger(1))]),
          ]),
        ]),
      ),
    );
  });

  test("Single line block without semmicolon end", () {
    final input = """
Group { var = 1 }
""";
    final lexer = Lexer(input, "path/to/file");
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(0), reason: errors.join("\n"));

    expect(
      program,
      equals(
        Program("path/to/file", [
          Block(Identifier("Group"), [AssigmentLine(Identifier("var"), NumberInteger(1))]),
        ]),
      ),
    );
  });

  test("Single line block", () {
    final input = """
var1 = 1; var2 = 2
Group { var = 1; }
Group2 { var1 = 1; var2 = 2; }
""";
    final lexer = Lexer(input, "path/to/file");
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(0), reason: errors.join("\n"));

    expect(
      program,
      equals(
        Program("path/to/file", [
          AssigmentLine(Identifier("var1"), NumberInteger(1)),
          AssigmentLine(Identifier("var2"), NumberInteger(2)),
          Block(Identifier("Group"), [AssigmentLine(Identifier("var"), NumberInteger(1))]),
          Block(Identifier("Group2"), [
            AssigmentLine(Identifier("var1"), NumberInteger(1)),
            AssigmentLine(Identifier("var2"), NumberInteger(2)),
          ]),
        ]),
      ),
    );
  });

  test("Empty named block syntax", () {
    final input = """
GroupWithBraces {}
GroupWithoutBraces
""";

    final lexer = Lexer(input, "path/to/file");
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(0), reason: errors.join("\n"));

    expect(
      program,
      equals(
        Program("path/to/file", [
          Block(Identifier("GroupWithBraces"), []),
          Block(Identifier("GroupWithoutBraces"), []),
        ]),
      ),
    );
  });
}
