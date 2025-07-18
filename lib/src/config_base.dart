import 'dart:io';

import 'package:config/config.dart';
import 'package:config/src/lexer/lexer.dart';

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
    final evaluator = Evaluator(program);
    evaluator.declarations.addAll(
      predefinedDeclarations.map((k, v) => MapEntry(k, StringValue(v, -1, ""))),
    );
    evaluator.eval();
    return (EvaluationResult(evaluator.result, evaluator.errors), null);
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
    final evaluator = Evaluator(program, schema);
    evaluator.declarations.addAll(
      predefinedDeclarations.map((k, v) => MapEntry(k, StringValue(v, -1, ""))),
    );
    evaluator.eval();
    return (EvaluationResult(evaluator.result, evaluator.errors), null);
  }
}
