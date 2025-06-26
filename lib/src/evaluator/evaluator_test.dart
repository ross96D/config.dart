// ignore_for_file: depend_on_referenced_packages

import 'package:config/src/evaluator/evaluator.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/parser/parser.dart';
import 'package:test/test.dart';

void main() {
  test("somthing", () {
    final input = """
VAR1 = 'value'
VAR2 = 12
\$VAR3 = VAR1

[table]
VAR4 = "SOMETHINGS"
VAR5 = "SOMETHINGS-\$VAR3"

[table2]
VAR4 = "VAL"

    """;

    final lexer = Lexer(input);
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final result = Evaluator(program).eval();

    expect(result.toMap(), equals({
      "VAR1": "value",
      "VAR2": 12,
      "table": {
        "VAR4": "SOMETHINGS",
        "VAR5": "SOMETHINGS-value",
      },
      "table2": {
        "VAR4": "VAL"
      },
    },));
  });
}
