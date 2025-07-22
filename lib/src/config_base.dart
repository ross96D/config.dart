import 'dart:io';

import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/schema.dart';
import 'package:config/src/evaluator/evaluator.dart';
import 'package:config/src/parser/parser.dart';

class ConfigurationParser {
  static (EvaluationResult?, List<ParseError>?) parseFromFile(
    File file, {
    Schema? schema,
    Map<String, String> predefinedDeclarations = const {},
  }) {
    String content = file.readAsStringSync();
    final lexer = Lexer(content, file.path);
    final parser = Parser(lexer);
    final program = parser.parseProgram();
    if (parser.errors.isNotEmpty) {
      return (null, parser.errors);
    }
    final result = Evaluator.eval(
      program,
      schema: schema,
      declarations: predefinedDeclarations.map(
        (key, value) => MapEntry(key, StringValue(value, -1, "")),
      ),
    );
    return (result, null);
  }

  static (EvaluationResult?, List<ParseError>?) parseFromString(
    String content, {
    Map<String, String> predefinedDeclarations = const {},
    String filepath = "",
    Schema? schema,
  }) {
    final lexer = Lexer(content, filepath);
    final parser = Parser(lexer);
    final program = parser.parseProgram();
    if (parser.errors.isNotEmpty) {
      return (null, parser.errors);
    }
    final result = Evaluator.eval(
      program,
      schema: schema,
      declarations: predefinedDeclarations.map(
        (key, value) => MapEntry(key, StringValue(value, -1, "")),
      ),
    );
    return (result, null);
  }
}

sealed class Result<T extends Object> {}

class Success<T extends Object> extends Result<T> {
  final Type type;
  final T value;
  Success(this.value) : type = T;
}

class Failure<T extends ValidationError, __ extends Object> extends Result<__> {
  final Type type;
  final T value;
  Failure(this.value) : type = T;
}
