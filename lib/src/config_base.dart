import 'dart:io';

import 'package:config/src/evaluator/evaluator.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/parser/parser.dart';
import 'package:config/src/schema.dart';

sealed class EvaluationResult {}

class EvaluationParseError extends EvaluationResult {
  List<ParseError> errors;
  EvaluationParseError(this.errors);
}

class EvaluationValidationError extends EvaluationResult {
  final List<EvaluationError> errors;
  final Map<String, dynamic> values;
  EvaluationValidationError(this.errors, this.values);
}

class EvaluationSuccess extends EvaluationResult {
  final Map<String, dynamic> values;
  EvaluationSuccess(this.values);
}

class ConfigurationParser {
  const ConfigurationParser();

  Future<EvaluationResult> parseFromFile(
    File file, {
    Schema? schema,
    Map<String, String> predefinedDeclarations = const {},
  }) async {
    String content = await file.readAsString();
    return parseFromString(
      content,
      schema: schema,
      filepath: file.path,
      predefinedDeclarations: predefinedDeclarations,
    );
  }

  EvaluationResult parseFromFileSync(
    File file, {
    Schema? schema,
    Map<String, String> predefinedDeclarations = const {},
  }) {
    String content = file.readAsStringSync();
    return parseFromString(
      content,
      schema: schema,
      filepath: file.path,
      predefinedDeclarations: predefinedDeclarations,
    );
  }

  EvaluationResult parseFromString(
    String content, {
    Map<String, String> predefinedDeclarations = const {},
    String filepath = "",
    Schema? schema,
  }) {
    final lexer = Lexer(content, filepath);
    final parser = Parser(lexer);
    final program = parser.parseProgram();
    if (parser.errors.isNotEmpty) {
      return EvaluationParseError(parser.errors);
    }
    final result = Evaluator.eval(
      program,
      schema: schema,
      declarations: predefinedDeclarations.map(
        (key, value) => MapEntry(key, StringValue(value, -1, "")),
      ),
    );
    if (result.errors.isNotEmpty) {
      return EvaluationValidationError(result.errors, result.values);
    }
    return EvaluationSuccess(result.values);
  }
}

sealed class ValidatorResult<T extends Object> {}

class ValidatorSuccess<T extends Object> extends ValidatorResult<T> {
  final Type type;
  ValidatorSuccess() : type = T;
}

class ValidatorTransform<T extends Object> extends ValidatorResult<T> {
  final Type type;
  final T value;
  ValidatorTransform(this.value) : type = T;
}

class ValidatorError<T extends ValidationError, __ extends Object> extends ValidatorResult<__> {
  final Type type;
  final T value;
  ValidatorError(this.value) : type = T;
}
