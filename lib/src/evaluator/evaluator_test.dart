// ignore_for_file: depend_on_referenced_packages

import 'dart:core' as core show Duration;
import 'dart:core';
import 'package:config/src/evaluator/evaluator.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/parser/parser.dart';
import 'package:config/src/ast/ast.dart';
import 'package:config/src/tokens/tokens.dart';
import 'package:config/src/types/duration/duration.dart';
import 'package:test/test.dart';

void main() {
  test("something", () {
    final input = """
VAR1 = 'value'
VAR2 = 12
NEGATIVE = -12
\$VAR3 = 'value'
VAR_BOOL1 = true
VAR_BOOL2 = false
DURATION = 12h26s

table {
  VAR4 = "SOMETHINGS"
  VAR5 = "SOMETHINGS-\$VAR3"
}

table2 {
  VAR4 = "VAL"
  VAR5 = [1, 3 + 4, VAR3]
}

map = {
  12: 31,
  "Key": "Value",
  true: 0,
  1: false,
  12ms: false,
  # "Not": false,
}

    """;

    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);
    final program = parser.parseProgram();

    final result = Evaluator.eval(program);

    expect(
      result.$1,
      equals(
        BlockData(
          {
            Identifier("VAR1"): "value",
            Identifier("VAR2"): 12,
            Identifier("NEGATIVE"): -12,
            Identifier("VAR_BOOL1"): true,
            Identifier("VAR_BOOL2"): false,
            Identifier("DURATION"): Duration.fromDartDuration(
              core.Duration(hours: 12, seconds: 26),
            ),
            Identifier("map"): {12: 31, "Key": "Value", true: 0, 1: false, Duration(12000): false},
          },
          [
            (
              Identifier("table"),
              BlockData({
                Identifier("VAR4"): "SOMETHINGS",
                Identifier("VAR5"): "SOMETHINGS-value",
              }, []),
            ),
            (
              Identifier("table2"),
              BlockData({
                Identifier("VAR4"): "VAL",
                Identifier("VAR5"): [1, 7, 'value'],
              }, []),
            ),
          ],
        ),
      ),
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

    final program = parser.parseProgram();
    expect(parser.errors.length, equals(0), reason: parser.errors.join("\n"));

    final evaluator = Evaluator.eval(program);

    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join('\n'));

    expect(
      evaluator.$1,
      equals(
        BlockData({Identifier("VAR1"): 125.0, Identifier("VAR2"): 120, Identifier("VAR3"): 1}, []),
      ),
      reason: program.toString(),
    );
  });

  test("duplicated map values", () {
    final input = """
    map = {
      "key": "val",
      "key": "val2",
    }
    """;
    final lexer = Lexer(input, "/path/to/file");
    final parser = Parser(lexer);

    final program = parser.parseProgram();
    expect(parser.errors.length, equals(0), reason: parser.errors.join("\n"));
    final evaluator = Evaluator.eval(program);

    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join('\n'));
    expect(
      evaluator.$1,
      equals(
        BlockData({
          Identifier("map"): {"key": "val2"},
        }, []),
      ),
    );
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
    expect(
      evaluator.$2[0],
      equals(
        DuplicatedKeyError(
          "VAR",
          Position.t(0, 3, "/path/to/file"),
          Position.t(9, 3, "/path/to/file"),
        ),
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

    final evaluator = Evaluator.eval(program);

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

  test("BlockData merge", () {
    final defaults = BlockData(
      {Identifier("V1"): 12, Identifier("V2"): 15},
      [
        (Identifier("B1"), BlockData({Identifier("V1"): 12, Identifier("V2"): 15}, [], {})),
      ],
    );

    final override = BlockData(
      {Identifier("V1"): 10, Identifier("V2"): 10},
      [
        (Identifier("B2"), BlockData({Identifier("V1"): 12, Identifier("V2"): 15}, [], {})),
      ],
      {"V2"},
    );

    expect(
      override.merge(defaults),
      BlockData(
        {Identifier("V1"): 10, Identifier("V2"): 15},
        [
          (Identifier("B2"), BlockData({Identifier("V1"): 12, Identifier("V2"): 15}, [], {})),
          (Identifier("B1"), BlockData({Identifier("V1"): 12, Identifier("V2"): 15}, [], {})),
        ],
      ),
    );
  });
}
