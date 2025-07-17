import 'dart:io';

import 'package:config/src/evaluator/evaluator.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/parser/parser.dart';

class ConfigurationParser {
  static (MapValue?, List<ParseError>?) parseFromFile(
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
      predefinedDeclarations.map((k, v) => MapEntry(k, StringValue(v))),
    );
    return (evaluator.eval(), null);
  }

  static (MapValue?, List<ParseError>?) parseFromString(
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
      predefinedDeclarations.map((k, v) => MapEntry(k, StringValue(v))),
    );
    return (evaluator.eval(), null);
  }
}
