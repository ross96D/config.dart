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
\$VAR3 = 'value'
VAR_BOOL1 = true
VAR_BOOL2 = false

table {
  VAR4 = "SOMETHINGS"
  VAR5 = "SOMETHINGS-\$VAR3"
}

table2 {
  VAR4 = "VAL"
}

    """;

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final result = Evaluator.eval(program);

    expect(
      result.values,
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

    final evaluator = Evaluator.eval(program);

    expect(evaluator.errors.length, equals(0), reason: evaluator.errors.join('\n'));

    expect(
      evaluator.values,
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


    Result<String> _validator(String v) {
      return v != 'value' ? Failure(NotEqualValidationError()) : Success(v);
    }

    final schema = Schema(
      fields: [
        StringField(
          "VAR1",
          transform: _validator,
        ),
        NumberField("VAR2"),
        NumberField("VAR3", nullable: true),
      ],
    );

    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.errors.length, equals(0), reason: evaluator.errors.join("\n"));
    expect(evaluator.values, equals({"VAR1": "value", "VAR2": 2.0, "VAR3": null}));

    expect(evaluator.errors, isEmpty);
  });

  test("schema failed", () {
    final input = "VAR1 = 'not_value'";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    Result<String> _validator(String v) {
      return v != 'value' ? Failure(NotEqualValidationError()) : Success(v);
    }


    final schema = Schema(
      fields: [
        StringField(
          "VAR1",
          transform: _validator,
        ),
      ],
    );
    // schema.field<String>("VAR1", validator: (v) => v != 'value' ? NotEqualValidationError() : null);
    final evaluator = Evaluator.eval(program, schema: schema);

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
    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.values, equals({"VAR1": "VALUE"}));
  });

  test("schema default value", () {
    final input = "";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final schema = Schema(fields: [StringField("VAR1")]);
    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.errors.length, equals(1), reason: evaluator.errors.join('\n'));
    expect(evaluator.errors[0], isA<RequiredKeyIsMissing>());
  });

  test("table name already define as variable", () {
    final input = """
TABLE = 12
TABLE {
  VAR = 12
}
      """;
    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program);

    expect(evaluator.errors.length, equals(1), reason: evaluator.errors.join('\n'));
    expect(evaluator.errors[0], isA<BlockNameDefinedAsKeyError>());
    expect(evaluator.errors[0], equals(BlockNameDefinedAsKeyError("TABLE", 0, 1, "/path/to/file")));
  });

  test("duplicated key error", () {
    final input = """
VAR = 12
VAR = 12
      """;
    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program);

    expect(evaluator.errors.length, equals(1), reason: evaluator.errors.join('\n'));
    expect(evaluator.errors[0], isA<DuplicatedKeyError>());
    expect(evaluator.errors[0], equals(DuplicatedKeyError("VAR", 0, 1, "/path/to/file")));
  });

  test("key not in schema", () {
    final input = "VAR = 12";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program, schema: Schema());

    expect(evaluator.errors.length, equals(1), reason: evaluator.errors.join('\n'));
    expect(evaluator.errors[0], isA<KeyNotInSchemaError>());
    expect(evaluator.errors[0], equals(KeyNotInSchemaError("VAR", 0, "/path/to/file")));
  });

  test("type conflict", () {
    final input = "VAR = 12";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program, schema: Schema(fields: [StringField("VAR")]));

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

    final evaluator = Evaluator.eval(program, schema: Schema(fields: [StringField("VAR")]));

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
