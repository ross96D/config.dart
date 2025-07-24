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
  VAR5 = [1, 3 + 4, VAR3]
}

    """;

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final result = Evaluator.eval(program);

    expect(
      result.$1,
      equals({
        "VAR1": "value",
        "VAR2": 12,
        "VAR_BOOL1": true,
        "VAR_BOOL2": false,
        "table": {"VAR4": "SOMETHINGS", "VAR5": "SOMETHINGS-value"},
        "table2": {
          "VAR4": "VAL",
          "VAR5": [1, 7, 'value'],
        },
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

    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join('\n'));

    expect(
      evaluator.$1,
      equals({"VAR1": 125.0, "VAR2": 120, "VAR3": 1}),
      reason: program.toString(),
    );
  });

  test("schema success", () {
    final input = """
VAR1 = 'value'
VAR2 = 2
Array = [1, 3, 5, [1, 3]]
""";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    ValidatorResult<String> validator(String v) {
      return v != 'value' ? ValidatorError(NotEqualValidationError()) : ValidatorTransform(v);
    }

    ValidatorResult<List<String>> transform(List<Object> v) {
      return ValidatorTransform(v.map((e) => e.toString()).toList());
    }

    final schema = Schema(
      fields: [
        StringField("VAR1", validator: validator),
        IntegerNumberField("VAR2"),
        IntegerNumberField("VAR3", nullable: true),
        UntypedListField("Array", transform),
      ],
    );

    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join("\n"));
    expect(
      evaluator.$1,
      equals({
        "VAR1": "value",
        "VAR2": 2,
        "VAR3": null,
        "Array": ['1', '3', '5', '[1, 3]'],
      }),
    );

    expect(evaluator.$2, isEmpty);
  });

  test("schema failed", () {
    final input = "VAR1 = 'not_value'";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    ValidatorResult<String> validator(String v) {
      return v != 'value' ? ValidatorError(NotEqualValidationError()) : ValidatorTransform(v);
    }

    final schema = Schema(fields: [StringField("VAR1", validator: validator)]);
    // schema.field<String>("VAR1", validator: (v) => v != 'value' ? NotEqualValidationError() : null);
    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.$2.length, greaterThanOrEqualTo(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<NotEqualValidationError>());
  });

  test("schema default value", () {
    final input = "";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    // final schema = Schema()..field<String>("VAR1", defaultsTo: "VALUE");
    final schema = Schema(fields: [StringField("VAR1", defaultTo: "VALUE")]);
    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.$1, equals({"VAR1": "VALUE"}));
  });

  test("schema default value", () {
    final input = "";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final schema = Schema(fields: [StringField("VAR1")]);
    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.$2.length, equals(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<RequiredKeyIsMissing>());
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

    expect(evaluator.$2.length, equals(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<BlockNameDefinedAsKeyError>());
    expect(evaluator.$2[0], equals(BlockNameDefinedAsKeyError("TABLE", 0, 1, "/path/to/file")));
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

    expect(evaluator.$2.length, equals(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<DuplicatedKeyError>());
    expect(evaluator.$2[0], equals(DuplicatedKeyError("VAR", 0, 1, "/path/to/file")));
  });

  test("key not in schema", () {
    final input = "VAR = 12";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program, schema: Schema());

    expect(evaluator.$2.length, equals(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<KeyNotInSchemaError>());
    expect(evaluator.$2[0], equals(KeyNotInSchemaError("VAR", 0, "/path/to/file")));
  });

  test("type conflict", () {
    final input = "VAR = 12";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program, schema: Schema(fields: [StringField("VAR")]));

    expect(evaluator.$2.length, greaterThanOrEqualTo(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<ConflictTypeError>());
    expect(evaluator.$2[0], equals(ConflictTypeError("VAR", 0, "/path/to/file", String, int)));
  });

  test("missing required key", () {
    final input = "";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program, schema: Schema(fields: [StringField("VAR")]));

    expect(evaluator.$2.length, equals(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<RequiredKeyIsMissing>());
    expect(evaluator.$2[0], equals(RequiredKeyIsMissing("VAR")));
  });
}

class NotEqualValidationError extends ValidationError {
  @override
  String error() {
    return "NotEqualValidationError";
  }
}
