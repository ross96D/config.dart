// ignore_for_file: depend_on_referenced_packages

import 'dart:core' as core show Duration;
import 'dart:core';
import 'package:config/src/evaluator/evaluator.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/parser/parser.dart';
import 'package:config/src/types/duration/duration.dart';
import 'package:test/test.dart';

void main() {
  test("somthing", () {
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
      equals({
        "VAR1": "value",
        "VAR2": 12,
        "NEGATIVE": -12,
        "VAR_BOOL1": true,
        "VAR_BOOL2": false,
        "DURATION": Duration.fromDartDuration(core.Duration(hours: 12, seconds: 26)),
        "table": {"VAR4": "SOMETHINGS", "VAR5": "SOMETHINGS-value"},
        "table2": {
          "VAR4": "VAL",
          "VAR5": [1, 7, 'value'],
        },
        "map": {12: 31, "Key": "Value", true: 0, 1: false, Duration(12000): false},
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

    final program = parser.parseProgram();
    expect(parser.errors.length, equals(0), reason: parser.errors.join("\n"));

    final evaluator = Evaluator.eval(program);

    expect(evaluator.$2.length, equals(0), reason: evaluator.$2.join('\n'));

    expect(
      evaluator.$1,
      equals({"VAR1": 125.0, "VAR2": 120, "VAR3": 1}),
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
    expect(evaluator.$1, equals({"map": {"key": "val2"}}));
  });
}
