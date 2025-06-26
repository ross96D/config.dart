// ignore_for_file: depend_on_referenced_packages

import 'package:config/src/ast/ast.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/parser/parser.dart';
import 'package:test/test.dart';

void main() {
  test("error", () {
    final input = "=zzzzzzzzzzzzzzzzzzzzzzz";

    final lexer = Lexer(input);
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(1));
    expect(program.lines.length, equals(0));
    print(errors.join("\n\n"));
  });

  test("description", () {
    final input = """
VAR = 12
VAR = 12
\$VAR3 = VAR
[table]
VAR = "SOMETHINGS"
    """;

    final lexer = Lexer(input);
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    final errors = parser.errors;

    expect(errors.length, equals(0));
    expect(
      program,
      equals(
        Program([
          AssigmentLine(Identifier("VAR"), Number(12)),
          AssigmentLine(Identifier("VAR"), Number(12)),
          DeclarationLine(Identifier("VAR3"), Identifier("VAR")),
          TableHeaderLine(Identifier("table")),
          AssigmentLine(Identifier("VAR"), InterpolableStringLiteral("SOMETHINGS")),
        ]),
      ),
    );
  });
}
