import 'dart:io';

import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/tokens/tokens.dart';

void main() {
  var lines = <String>[];
  while (true) {
    final line = stdin.readLineSync();
    if (line == null) {
      break;
    }
    if (line == ":print") {
      final lexer = Lexer(lines.join("\n"));
      while(true) {
        final token = lexer.nextToken();
        print(token);
        if (token.type == TokenType.Eof) {
          break;
        }
      }
      lines = [];
    } else {
      lines.add(line);
    }
  }
}
