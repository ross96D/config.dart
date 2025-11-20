// ignore_for_file: depend_on_referenced_packages
import 'package:config/config.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:test/test.dart';
import 'package:config/src/ast/ast.dart';

void main() {
  test("test coerce int to double", () {
    final input = "VAR2 = 2";
    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();
    final schema = Schema(fields: {"VAR2": DoubleNumberField()});
    final evaluator = Evaluator.eval(program, schema: schema);
    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join("\n"));
    expect(evaluator.$1, equals(BlockData({Identifier("VAR2"): 2.0}, [])));
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
      blocks: {
        "Group": BlockSchema(fields: {"VAR2": DoubleNumberField()}),
      },
    );

    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join("\n"));
    expect(
      evaluator.$1,
      equals(
        BlockData(
          {
            Identifier("VAR1"): "value",
            Identifier("VAR2"): 2.0,
            Identifier("VAR3"): null,
            Identifier("Array"): ['1', '3', '5', '[1, 3]'],
            Identifier("Map"): {12: true, true: "some", "key": "value"},
          },
          [
            (Identifier("Group"), BlockData({Identifier("VAR2"): 2.0}, [])),
          ],
        ),
      ),
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

    expect(evaluator.$1, equals(BlockData({Identifier("VAR1"): "VALUE"}, [])));
  });

  test("schema require value", () {
    final input = "";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final schema = Schema(fields: {"VAR1": StringField()});
    final evaluator = Evaluator.eval(program, schema: schema);

    expect(evaluator.$2.length, equals(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<RequiredKeyIsMissing>());
  });

  test("key not in schema", () {
    final input = "VAR = 12";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program, schema: Schema());

    expect(evaluator.$2.length, equals(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<KeyNotInSchemaError>());
    expect(evaluator.$2[0], equals(KeyNotInSchemaError("VAR", Position.t(0, 3, "/path/to/file"))));
    expect(evaluator.$1, equals(BlockData({Identifier("VAR"): 12}, [])));
  });

  test("type conflict", () {
    final input = "VAR = 12";

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(program, schema: Schema(fields: {"VAR": StringField()}));

    expect(evaluator.$2.length, greaterThanOrEqualTo(1), reason: evaluator.$2.join('\n'));
    expect(evaluator.$2[0], isA<ConflictTypeError>());
    expect(
      evaluator.$2[0],
      equals(ConflictTypeError("VAR", Position.t(0, 8, "/path/to/file"), "String", "int")),
    );
  });

  test("missing required key", () {
    {
      final input = "";

      final lexer = Lexer(input, "/path/to/file");
      final parser = Parser(lexer);
      final program = parser.parseProgram();

      final evaluator = Evaluator.eval(program, schema: Schema(fields: {"VAR": StringField()}));

      expect(evaluator.$2.length, equals(1), reason: evaluator.$2.join('\n'));
      expect(evaluator.$2[0], isA<RequiredKeyIsMissing>());
      expect(evaluator.$2[0], equals(RequiredKeyIsMissing("VAR", null, null)));
    }
    {
      final input = """
Block {}
""";

      final lexer = Lexer(input, "/path/to/file");
      final parser = Parser(lexer);
      final program = parser.parseProgram();

      final evaluator = Evaluator.eval(
        program,
        schema: Schema(
          blocks: {
            "Block": BlockSchema(fields: {"VAR": StringField()}),
          },
        ),
      );

      expect(evaluator.$2.length, equals(1), reason: evaluator.$2.join('\n'));
      expect(evaluator.$2[0], isA<RequiredKeyIsMissing>());
      expect(evaluator.$2[0], equals(RequiredKeyIsMissing("VAR", "Block", Position.t(0, 5, "/path/to/file"))));
    }
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
      equals(
        BlockData({
          Identifier("VAR"): ["12", "zome", "item"],
        }, []),
      ),
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
      equals(
        BlockData({
          Identifier("Map"): {"Something": SchemaTestEnum.val1, "Something3": SchemaTestEnum.val2},
        }, []),
      ),
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
        blocks: {
          "Group1": Schema(fields: {"Var1": StringField(), "Var2": StringField()}),
          "Group4": Schema(
            fields: {"Var1": StringField(nullable: true), "Var2": StringField(nullable: true)},
          ),
          "Group3": Schema(
            ignoreNotInSchema: true,
            blocks: {
              "GroupeNested2": Schema(fields: {"k1": StringField(defaultTo: "v1")}),
              "GroupeNested3": Schema(fields: {"k1": StringField(defaultTo: "v1")}),
            },
            canBeMissingSchemas: {"GroupeNested2", "GroupeNested3"},
          ),
        },
        canBeMissingSchemas: {"Group4", "GroupeNested2", "GroupeNested3"},
        ignoreNotInSchema: true,
      ),
    );

    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join('\n'));
    expect(
      evaluator.$1,
      equals(
        BlockData({}, [
          (
            Identifier("Group1"),
            BlockData({Identifier("Var1"): "val1", Identifier("Var2"): "val2"}, []),
          ),
          (
            Identifier("Group2"),
            BlockData({Identifier("Var1"): "val1", Identifier("Var2"): "val2"}, []),
          ),
          (
            Identifier("Group3"),
            BlockData(
              {Identifier("Var1"): "val1", Identifier("Var2"): "val2"},
              [
                (Identifier("GroupeNested"), BlockData({Identifier("Var1"): "val1"}, [])),
                (Identifier("GroupeNested"), BlockData({Identifier("Var1"): "val1"}, [])),
                (Identifier("GroupeNested2"), BlockData({Identifier("k1"): "v1"}, [])),
              ],
            ),
          ),
        ]),
      ),
    );
  });

  test("keep insertion order", () {
    final input = """
VAR2 = 12
VAR = 12
VAR5 = 12
Group3 {}
Group1 {}
Group2 {}
Group3 {}
      """;

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final evaluator = Evaluator.eval(
      program,
      schema: Schema(
        fields: {
          "VAR": IntegerNumberField(),
          "VAR2": IntegerNumberField(),
          "VAR5": IntegerNumberField(),
        },
        blocks: {"Group1": Schema(), "Group2": Schema(), "Group3": Schema()},
      ),
    );

    final keys = evaluator.$1.keys().iterator;
    expect(keys.moveNext(), equals(true));
    expect(keys.current, equals(Identifier("VAR2")));
    expect(keys.moveNext(), equals(true));
    expect(keys.current, equals(Identifier("VAR")));
    expect(keys.moveNext(), equals(true));
    expect(keys.current, equals(Identifier("VAR5")));

    expect(keys.moveNext(), equals(true));
    expect(keys.current, equals(Identifier("Group3")));
    expect(keys.moveNext(), equals(true));
    expect(keys.current, equals(Identifier("Group1")));
    expect(keys.moveNext(), equals(true));
    expect(keys.current, equals(Identifier("Group2")));
    expect(keys.moveNext(), equals(true));
    expect(keys.current, equals(Identifier("Group3")));
    expect(keys.moveNext(), equals(false));
  });
}

enum SchemaTestEnum { val1, val2, val3, val4, val5 }

class NotEqualValidationError extends ValidationError {
  @override
  String error() {
    return "NotEqualValidationError";
  }

  @override
  String help() => "";
}
