// ignore_for_file: depend_on_referenced_packages

import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/tokens/tokens.dart';
import 'package:test/test.dart';

void main() {
  group("testing lexer", () {
    test("intitial", () {
      final input = "[]{}=</!=,:\t-;";

      final tests = [
        Token(type: TokenType.LeftBracket, literal: "["),
        Token(type: TokenType.RigthBracket, literal: "]"),
        Token(type: TokenType.LeftBrace, literal: "{"),
        Token(type: TokenType.RigthBrace, literal: "}"),
        Token(type: TokenType.Assign, literal: "="),
        Token(type: TokenType.LessThan, literal: "<"),
        Token(type: TokenType.Div, literal: "/"),
        Token(type: TokenType.NotEquals, literal: "!="),
        Token(type: TokenType.Comma, literal: ","),
        Token(type: TokenType.Colon, literal: ":"),
        Token(type: TokenType.Minus, literal: "-"),
        Token(type: TokenType.Semicolon, literal: ";"),
        Token(type: TokenType.Eof, literal: ""),
      ];
      final lexer = Lexer(input);
      for (final expectedToken in tests) {
        final token = lexer.nextToken();
        expect(token, equals(expectedToken));
      }
    });

    test("test to fix infinite loop when ilegal character", () {
      final input = "${String.fromCharCode(14)}q";
      final tests = [
      Token(type: TokenType.Illegal, literal: String.fromCharCode(14)),
        Token(type: TokenType.Identifier, literal: "q"),
        Token(type: TokenType.Eof, literal: ""),
      ];
      final lexer = Lexer(input);
      for (final expectedToken in tests) {
        final token = lexer.nextToken();
        expect(token, equals(expectedToken));
      }
    });

    test("positions", () {
      final input = """
VAR = 2
VAR = 3.0
VAR1=VAR
[table]
VAR2=4h23s
""";
      final tests = [
        Token(type: TokenType.Identifier, literal: "VAR", pos: Position.t(0, 3)),
        Token(type: TokenType.Assign, literal: "=", pos: Position.t(4, 1)),
        Token(type: TokenType.Integer, literal: "2", pos: Position.t(6, 1)),
        Token(type: TokenType.NewLine, literal: "\n", pos: Position.t(7, 1)),

        Token(type: TokenType.Identifier, literal: "VAR", pos: Position.t(8, 3)),
        Token(type: TokenType.Assign, literal: "=", pos: Position.t(12, 1)),
        Token(type: TokenType.Double, literal: "3.0", pos: Position.t(14, 3)),
        Token(type: TokenType.NewLine, literal: "\n", pos: Position.t(17, 1)),

        Token(type: TokenType.Identifier, literal: "VAR1", pos: Position.t(18, 4)),
        Token(type: TokenType.Assign, literal: "=", pos: Position.t(22, 1)),
        Token(type: TokenType.Identifier, literal: "VAR", pos: Position.t(23, 3)),
        Token(type: TokenType.NewLine, literal: "\n", pos: Position.t(26, 1)),

        Token(type: TokenType.LeftBracket, literal: "[", pos: Position.t(27, 1)),
        Token(type: TokenType.Identifier, literal: "table", pos: Position.t(28, 5)),
        Token(type: TokenType.RigthBracket, literal: "]", pos: Position.t(33, 1)),
        Token(type: TokenType.NewLine, literal: "\n", pos: Position.t(34, 1)),


        Token(type: TokenType.Identifier, literal: "VAR2", pos: Position.t(35, 4)),
        Token(type: TokenType.Assign, literal: "=", pos: Position.t(39, 1)),
        Token(type: TokenType.Duration, literal: "4h23s", pos: Position.t(40, 5)),
        Token(type: TokenType.NewLine, literal: "\n", pos: Position.t(45, 1)),

        Token(type: TokenType.Eof, literal: "", pos: Position.t(46, 0)),
      ];
      final lexer = Lexer(input);
      for (final expectedToken in tests) {
        final token = lexer.nextToken();
        expect(token, equals(expectedToken));
      }
    });

    test("more complex one", () {
      final input = """
VAR = "SOMESTRING"
\$VAR2 = 12
key = VAR2

# comment
[table] # table comment
key1 = "value"
key2 = 32
key3 = 32 <= 42
key4 = 32 < (42 * 21) + 12 - 10
key5 = {'foo': 'bar'}
      """;

      final tests = [
        Token(type: TokenType.Identifier, literal: "VAR"),
        Token(type: TokenType.Assign, literal: "="),
        Token(type: TokenType.InterpolableStringLiteral, literal: "SOMESTRING"),
        Token(type: TokenType.NewLine, literal: "\n"),

        Token(type: TokenType.Dollar, literal: "\$"),
        Token(type: TokenType.Identifier, literal: "VAR2"),
        Token(type: TokenType.Assign, literal: "="),
        Token(type: TokenType.Integer, literal: "12"),
        Token(type: TokenType.NewLine, literal: "\n"),

        Token(type: TokenType.Identifier, literal: "key"),
        Token(type: TokenType.Assign, literal: "="),
        Token(type: TokenType.Identifier, literal: "VAR2"),
        Token(type: TokenType.NewLine, literal: "\n"),
        Token(type: TokenType.NewLine, literal: "\n"),

        Token(type: TokenType.Comment, literal: "# comment"),
        Token(type: TokenType.NewLine, literal: "\n"),

        Token(type: TokenType.LeftBracket, literal: "["),
        Token(type: TokenType.Identifier, literal: "table"),
        Token(type: TokenType.RigthBracket, literal: "]"),
        Token(type: TokenType.Comment, literal: "# table comment"),
        Token(type: TokenType.NewLine, literal: "\n"),

        Token(type: TokenType.Identifier, literal: "key1"),
        Token(type: TokenType.Assign, literal: "="),
        Token(type: TokenType.InterpolableStringLiteral, literal: "value"),
        Token(type: TokenType.NewLine, literal: "\n"),

        Token(type: TokenType.Identifier, literal: "key2"),
        Token(type: TokenType.Assign, literal: "="),
        Token(type: TokenType.Integer, literal: "32"),
        Token(type: TokenType.NewLine, literal: "\n"),

        Token(type: TokenType.Identifier, literal: "key3"),
        Token(type: TokenType.Assign, literal: "="),
        Token(type: TokenType.Integer, literal: "32"),
        Token(type: TokenType.LessOrEqThan, literal: "<="),
        Token(type: TokenType.Integer, literal: "42"),
        Token(type: TokenType.NewLine, literal: "\n"),

        Token(type: TokenType.Identifier, literal: "key4"),
        Token(type: TokenType.Assign, literal: "="),
        Token(type: TokenType.Integer, literal: "32"),
        Token(type: TokenType.LessThan, literal: "<"),
        Token(type: TokenType.LeftParent, literal: "("),
        Token(type: TokenType.Integer, literal: "42"),
        Token(type: TokenType.Mult, literal: "*"),
        Token(type: TokenType.Integer, literal: "21"),
        Token(type: TokenType.RigthParent, literal: ")"),
        Token(type: TokenType.Plus, literal: "+"),
        Token(type: TokenType.Integer, literal: "12"),
        Token(type: TokenType.Minus, literal: "-"),
        Token(type: TokenType.Integer, literal: "10"),
        Token(type: TokenType.NewLine, literal: "\n"),

        Token(type: TokenType.Identifier, literal: "key5"),
        Token(type: TokenType.Assign, literal: "="),
        Token(type: TokenType.LeftBrace, literal: "{"),
        Token(type: TokenType.StringLiteral, literal: "foo"),
        Token(type: TokenType.Colon, literal: ":"),
        Token(type: TokenType.StringLiteral, literal: "bar"),
        Token(type: TokenType.RigthBrace, literal: "}"),
        Token(type: TokenType.NewLine, literal: "\n"),

        Token(type: TokenType.Eof, literal: ""),
      ];
      final lexer = Lexer(input);
      for (int i = 0; i < tests.length; i++) {
        final expectedToken = tests[i];
        final token = lexer.nextToken();
        try {
          expect(token, equals(expectedToken));
        } catch (e) {
          print("Fail with index $i");
          rethrow;
        }
      }
    });
  });
}
