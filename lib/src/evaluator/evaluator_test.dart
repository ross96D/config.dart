// ignore_for_file: depend_on_referenced_packages

import 'package:config/src/config_base.dart';
import 'package:config/src/evaluator/evaluator.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/parser/parser.dart';
import 'package:config/src/schema.dart';
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

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final result = Evaluator(program).eval();

    expect(
      result,
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

  test("operators", () {
    final input = """
VAR1 = (12 + 13) * 5
VAR2 = 10 * 12
VAR3 = 12 / 12
    """;
    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    expect(parser.errors.length, equals(0), reason: parser.errors.join("\n"));

    final program = parser.parseProgram();

    final evaluator = Evaluator(program);
    evaluator.eval();

    expect(evaluator.errors.length, equals(0), reason: evaluator.errors.join('\n'));

    expect(
      evaluator.result.toMap(),
      equals({"VAR1": 125.0, "VAR2": 120, "VAR3": 1}),
      reason: program.toString(),
    );
  });

  test("schema success", () {
    final input = """
VAR1 = 'value'
VAR2 = 2
""";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final schema = Schema(
      fields: [
        StringField(
          "VAR1",
          transform: (v) => v != 'value' ? Failure(NotEqualValidationError()) : Success(v),
        ),
        NumberField("VAR2"),
        NumberField("VAR3", nullable: true),
      ],
    );

    final evaluator = Evaluator(program, schema);
    final result = evaluator.eval();

    expect(evaluator.errors.length, equals(0), reason: evaluator.errors.join("\n"));
    expect(result, equals({"VAR1": "value", "VAR2": 2.0, "VAR3": null}));

    expect(evaluator.errors, isEmpty);
  });

  test("schema failed", () {
    final input = "VAR1 = 'not_value'";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final schema = Schema(
      fields: [
        StringField(
          "VAR1",
          transform: (v) => v != 'value' ? Failure(NotEqualValidationError()) : Success(v),
        ),
      ],
    );
    // schema.field<String>("VAR1", validator: (v) => v != 'value' ? NotEqualValidationError() : null);
    final evaluator = Evaluator(program, schema);
    evaluator.eval();

    expect(evaluator.errors.length, greaterThanOrEqualTo(1), reason: evaluator.errors.join('\n'));
    expect(evaluator.errors[0], isA<NotEqualValidationError>());
  });

  test("schema default value", () {
    final input = "";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    // final schema = Schema()..field<String>("VAR1", defaultsTo: "VALUE");
    final schema = Schema(fields: [StringField("VAR1", defaultTo: "VALUE")]);
    final evaluator = Evaluator(program, schema);
    final resp = evaluator.eval();

    expect(resp, equals({"VAR1": "VALUE"}));
  });

    test("schema default value", () {
      final input = "";

      final lexer = Lexer(input, "/path/to/file");
      final parser = Parser(lexer);
      final program = parser.parseProgram();

      final schema = Schema(fields: [StringField("VAR1")]);
      final evaluator = Evaluator(program, schema);
      evaluator.eval();

      expect(evaluator.errors.length, equals(1), reason: evaluator.errors.join('\n'));
      expect(evaluator.errors[0], isA<RequiredKeyIsMissing>());
    });

    test("table name already define as variable", () {
      final input = """
  TABLE = 12
  [TABLE]
  VAR = 12
      """;
      final lexer = Lexer(input, "/path/to/file");
      final parser = Parser(lexer);
      final program = parser.parseProgram();

      final evaluator = Evaluator(program);
      evaluator.eval();

      expect(evaluator.errors.length, equals(1), reason: evaluator.errors.join('\n'));
      expect(evaluator.errors[0], isA<TableNameDefinedAsKeyError>());
      expect(evaluator.errors[0], equals(TableNameDefinedAsKeyError("TABLE", 0, "")));
    });

    test("duplicated key error", () {
      final input = """
  VAR = 12
  VAR = 12
      """;
      final lexer = Lexer(input, "/path/to/file");
      final parser = Parser(lexer);
      final program = parser.parseProgram();

      final evaluator = Evaluator(program);
      evaluator.eval();

      expect(evaluator.errors.length, equals(1), reason: evaluator.errors.join('\n'));
      expect(evaluator.errors[0], isA<DuplicatedKeyError>());
      expect(evaluator.errors[0], equals(DuplicatedKeyError("VAR", 0, 1, "/path/to/file")));
      print(evaluator.errors[0].error());
    });

    test("key not in schema", () {
      final input = "VAR = 12";

      final lexer = Lexer(input, "/path/to/file");
      final parser = Parser(lexer);
      final program = parser.parseProgram();

      final evaluator = Evaluator(program, Schema());
      evaluator.eval();

      expect(evaluator.errors.length, equals(1), reason: evaluator.errors.join('\n'));
      expect(evaluator.errors[0], isA<KeyNotInSchemaError>());
      expect(evaluator.errors[0], equals(KeyNotInSchemaError("VAR", 0, "/path/to/file")));
    });

    test("type conflict", () {
      final input = "VAR = 12";

      final lexer = Lexer(input, "/path/to/file");
      final parser = Parser(lexer);
      final program = parser.parseProgram();

      final evaluator = Evaluator(program, Schema(fields: [StringField("VAR")]));
      evaluator.eval();

      expect(evaluator.errors.length, greaterThanOrEqualTo(1), reason: evaluator.errors.join('\n'));
      expect(evaluator.errors[0], isA<ConflictTypeError>());
      expect(
        evaluator.errors[0],
        equals(ConflictTypeError("VAR", 0, "/path/to/file", String, double)),
      );
    });

    test("missing required key", () {
      final input = "";

      final lexer = Lexer(input, "/path/to/file");
      final parser = Parser(lexer);
      final program = parser.parseProgram();

      final evaluator = Evaluator(program, Schema(fields: [StringField("VAR")]));
      evaluator.eval();

      expect(evaluator.errors.length, equals(1), reason: evaluator.errors.join('\n'));
      expect(evaluator.errors[0], isA<RequiredKeyIsMissing>());
      expect(evaluator.errors[0], equals(RequiredKeyIsMissing("VAR")));
    });
}

class NotEqualValidationError extends ValidationError {
  @override
  String error() {
    return "NotEqualValidationError";
  }
}
