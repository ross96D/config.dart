// ignore_for_file: depend_on_referenced_packages
import 'package:config/config.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:test/test.dart';

void main() {
  test("test coerce int to double", () {
    final input = "VAR2 = 2";
    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();
    final schema = Schema(fields: {"VAR2": DoubleNumberField()});
    final evaluator = Evaluator.eval(program, schema: schema);
    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join("\n"));
    expect(evaluator.$1, equals({"VAR2": 2.0}));
  });

  test("schema success", () {
    final input = """
VAR1 = 'value'
VAR2 = 2
Array = [1, 3, 5, [1, 3]]
Group {
  VAR2 = 2
}
Map = {
  12: true,
  true: "some",
  "key": "value",
}
""";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    ValidatorResult<String> validator(String v) {
      return v != 'value' ? ValidatorError(NotEqualValidationError()) : ValidatorTransform(v);
    }

    ValidatorResult<List<String>> transformList(List<Object> v) {
      return ValidatorTransform(v.map((e) => e.toString()).toList());
    }

    ValidatorResult<Map<Object, Object>> transformMap(Map<Object, Object> v) {
      return ValidatorTransform(v);
    }

    final schema = Schema(
      fields: {
        "VAR1": StringField(validator: validator),
        "VAR2": DoubleNumberField(),
        "VAR3": IntegerNumberField(nullable: true),
        "Array": UntypedListField(transformList),
        "Map": UntypedMapField(transformMap),
      },
      tables: {
        "Group": TableSchema(fields: {"VAR2": DoubleNumberField()}),
      },
    );

    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join("\n"));
    expect(
      evaluator.$1,
      equals({
        "VAR1": "value",
        "VAR2": 2.0,
        "VAR3": null,
        "Array": ['1', '3', '5', '[1, 3]'],
        "Group": {"VAR2": 2.0},
        "Map": {12: true, true: "some", "key": "value"},
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

    final schema = Schema(fields: {"VAR1": StringField(validator: validator)});
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
    final schema = Schema(fields: {"VAR1": StringField(defaultTo: "VALUE")});
    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.$1, equals({"VAR1": "VALUE"}));
  });

  test("schema default value", () {
    final input = "";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final schema = Schema(fields: {"VAR1": StringField()});
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
    expect(evaluator.$1, equals({"VAR": 12}));
  });

  test("type conflict", () {
    final input = "VAR = 12";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program, schema: Schema(fields: {"VAR": StringField()}));

    expect(evaluator.$2.length, greaterThanOrEqualTo(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<ConflictTypeError>());
    expect(evaluator.$2[0], equals(ConflictTypeError("VAR", 0, "/path/to/file", "String", "int")));
  });

  test("missing required key", () {
    final input = "";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program, schema: Schema(fields: {"VAR": StringField()}));

    expect(evaluator.$2.length, equals(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<RequiredKeyIsMissing>());
    expect(evaluator.$2[0], equals(RequiredKeyIsMissing("VAR")));
  });

  test("fix list conflict type", () {
    final input = """
VAR = ["12", "zome", "item"]
    """;

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(
      program,
      schema: Schema(fields: {"VAR": ListField(StringField())}),
    );

    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join('\n'));
    expect(
      evaluator.$1,
      equals({
        "VAR": ["12", "zome", "item"],
      }),
    );
  });

  test("MapFieldSchema", () {
    final input = """
Map = {
  "Something": "val1",
  "Something3": "val2",
}
    """;
    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();
    expect(parser.errors.length, equals(0), reason: parser.errors.join("\n"));

    final evaluator = Evaluator.eval(
      program,
      schema: Schema(fields: {"Map": MapField(StringField(), EnumField(SchemaTestEnum.values))}),
    );
    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join('\n'));
    expect(
      evaluator.$1,
      equals({
        "Map": {"Something": SchemaTestEnum.val1, "Something3": SchemaTestEnum.val2},
      }),
    );
  });

  test("Nested dynamic groups", () {
    final input = """
Group1 {
  Var1 = "val1"
  Var2 = "val2"
}
Group2 {
  Var1 = "val1"
  Var2 = "val2"
}
Group3 {
  Var1 = "val1"
  Var2 = "val2"
  GroupeNested {
    Var1 = "val1"
  }
  GroupeNested2 {}
}
""";
    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();
    expect(parser.errors.length, equals(0), reason: parser.errors.join("\n"));

    final evaluator = Evaluator.eval(
      program,
      schema: Schema(
        tables: {
          "Group1": Schema(fields: {"Var1": StringField(), "Var2": StringField()}),
          "Group4": Schema(
            fields: {"Var1": StringField(nullable: true), "Var2": StringField(nullable: true)},
            required: false,
          ),
        },
        ignoreNotInSchema: true,
      ),
    );

    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join('\n'));
    expect(
      evaluator.$1,
      equals({
        "Group1": {"Var1": "val1", "Var2": "val2"},
        "Group2": {"Var1": "val1", "Var2": "val2"},
        "Group3": {
          "Var1": "val1",
          "Var2": "val2",
          "GroupeNested": {"Var1": "val1"},
          "GroupeNested2": {},
        },
      }),
    );
  });
}

enum SchemaTestEnum { val1, val2, val3, val4, val5 }

class NotEqualValidationError extends ValidationError {
  @override
  String error() {
    return "NotEqualValidationError";
  }
}
