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
VAR_BOOL1 = true
VAR_BOOL2 = false

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

    expect(
      result.toMap(),
      equals({
        "VAR1": "value",
        "VAR2": 12,
        "VAR_BOOL1": true,
        "VAR_BOOL2": false,
        "table": {"VAR4": "SOMETHINGS", "VAR5": "SOMETHINGS-value"},
        "table2": {"VAR4": "VAL"},
      }),
    );
  });

  test("schema success", () {
    final input = "VAR1 = 'value'";

    final lexer = Lexer(input);
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final schema = Schema();
    schema.field<String>("VAR1", validator: (v) => v != 'value' ? NotEqualValidationError() : null);

    final evaluator = Evaluator(program, schema);
    evaluator.eval();

    expect(evaluator.result.toMap(), equals({"VAR1": "value"}));

    expect(evaluator.errors, isEmpty);
  });

  test("schema failed", () {
    final input = "VAR1 = 'not_value'";

    final lexer = Lexer(input);
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final schema = Schema();
    schema.field<String>("VAR1", validator: (v) => v != 'value' ? NotEqualValidationError() : null);
    final evaluator = Evaluator(program, schema);
    evaluator.eval();

    expect(evaluator.errors.length, greaterThanOrEqualTo(1), reason: evaluator.errors.join('\n'));
    expect(evaluator.errors[0], isA<NotEqualValidationError>());
  });

  test("schema default value", () {
    final input = "";

    final lexer = Lexer(input);
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final schema = Schema()
      ..field<String>("VAR1", defaultsTo: "VALUE");
    final evaluator = Evaluator(program, schema);
    evaluator.eval();

    expect(evaluator.result.toMap(), equals({
      "VAR1": "VALUE"
    }));
  });

  test("schema default value", () {
    final input = "";

    final lexer = Lexer(input);
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final schema = Schema()
      ..field<String>("VAR1");
    final evaluator = Evaluator(program, schema);
    evaluator.eval();

    expect(evaluator.errors.length, equals(1), reason: evaluator.errors.join('\n'));
    expect(evaluator.errors[0], isA<RequiredKeyIsMissing>());
  });
}

class NotEqualValidationError extends ValidationError {}
