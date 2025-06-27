import 'dart:io';

import 'package:config/src/evaluator/evaluator.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/parser/parser.dart';

class ConfigurationParser {
  static (MapValue?, List<ParseError>?) parseFromFile(
    File file, [
    Map<String, String> predefinedDeclarations = const {},
  ]) {
    String content = file.readAsStringSync();
    final lexer = Lexer(content);
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
}
