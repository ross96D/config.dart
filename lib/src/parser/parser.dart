import 'package:config/src/ast/ast.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/tokens/tokens.dart';

sealed class ParseError {
  final Token token;
  final String input;
  const ParseError(this.token, this.input);

  String _diagnosticHelper() {
    if (token.pos == null) {
      return "";
    }

    final pos = token.pos!;
    final lines = input.split('\n');
    final lineNo = pos.start.lineNumber;
    if (lineNo < 0 || lineNo > lines.length) {
      return "";
    }

    final line = lines[lineNo];
    final startCol = pos.start.offset;
    final endCol = (pos.end.lineNumber == lineNo)
        ? pos.end.offset.clamp(1, line.length + 1)
        : line.length + 1;
    final markerLength = (endCol - startCol).clamp(1, line.length - startCol + 1);

    final fileLocation = pos.filepath.isEmpty ? ' ' : ' ${pos.filepath}:';
    final location = ' -->$fileLocation${pos.start.lineNumber}:${pos.start.offset}';
    final codeLine = '$lineNo | $line';
    final marker =
        '${' ' * (lineNo.toString().length)} | ${' ' * (startCol - 1)}${'^' * markerLength}';

    return '$location\n$codeLine\n$marker';
  }

  String _display();

  @override
  String toString() => "error: ${_display()}\n${_diagnosticHelper()}";
}

class IlegalTokenFound extends ParseError {
  const IlegalTokenFound(super.token, super.input);

  @override
  String _display() {
    return "Found illegal token at ${token.pos}";
  }
}

class BadTokenAtLineStart extends ParseError {
  const BadTokenAtLineStart(super.token, super.input);

  @override
  String _display() {
    return "Bad token at line start $token";
  }
}

class ExpectedToken extends ParseError {
  final List<TokenType> expected;
  const ExpectedToken(this.expected, super.token, super.input);

  @override
  String _display() {
    return "Expected token ${expected.join(" or ")} found ${token.type}";
  }
}

class Parser {
  final Lexer lexer;
  final List<ParseError> errors = [];

  bool _alreadyParsed = false;

  late Token _currenToken;
  late Token _peekToken;

  // Parser(this.lexer) {
  //   _currenToken = lexer.nextToken();
  //   _peekToken = lexer.nextToken();
  // }

  Parser(this.lexer) {
    _currenToken = lexer.nextToken();
    while (_currenToken.type == TokenType.Comment) {
      _currenToken = lexer.nextToken();
    }
    _peekToken = lexer.nextToken();
    while (_peekToken.type == TokenType.Comment) {
      _peekToken = lexer.nextToken();
    }
  }

  void _nextToken() {
    _currenToken = _peekToken;
    _peekToken = lexer.nextToken();
    // ignore comments in the parser
    if (_peekToken.type == TokenType.Comment) {
      _peekToken = lexer.nextToken();
    }
    assert(_peekToken.type != TokenType.Comment, "two consecutives TokenType.Comment are imposibles");
  }

  Program parseProgram() {
    assert(() {
      final resp = _alreadyParsed == false;
      _alreadyParsed = true;
      return resp;
    }(), "can only call parseProgram once");

    final response = Program();
    while (_currenToken.type != TokenType.Eof) {
      final line = _parseLine();
      if (line != null) {
        response.lines.add(line);
      }
      _moveToLineEnd(); // just make sure to move to line end
      _nextToken();
    }
    return response;
  }

  void _moveToLineEnd() {
    while (_currenToken.type != TokenType.NewLine && _currenToken.type != TokenType.Eof) {
      _nextToken();
    }
  }

  Line? _parseLine() {
    switch (_currenToken.type) {
      case TokenType.Comment:
        throw StateError("unreachable");
      case TokenType.Eof:
        throw StateError("unreachable");
      case TokenType.NewLine:
        return null;
      case TokenType.Illegal:
        errors.add(IlegalTokenFound(_currenToken, lexer.input));
        return null;
      case TokenType.Assign:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;
      case TokenType.LeftBrace:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;
      case TokenType.RigthBrace:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;
      case TokenType.Number:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;
      case TokenType.RigthBracket:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.StringLiteral:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;
      case TokenType.InterpolableStringLiteral:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.Dollar:
        return _parseDeclaration();

      case TokenType.Identifier:
        return _parseAssignment();

      case TokenType.LeftBracket:
        return _parseTableHeader();
    }
  }

  bool _expectPeek(TokenType type) {
    if (_peekToken.type != type) {
      errors.add(ExpectedToken([type], _peekToken, lexer.input));
      return false;
    }
    _nextToken();
    return true;
  }

  AssigmentLine? _parseAssignment() {
    assert(_currenToken.type == TokenType.Identifier);
    final identifier = Identifier(_currenToken.literal, _currenToken);

    if (!_expectPeek(TokenType.Assign)) {
      return null;
    }
    _nextToken();

    final expression = _parseExpression();
    if (expression == null) {
      return null;
    }

    if (!_expectPeek(TokenType.NewLine)) {
      return null;
    }

    return AssigmentLine(identifier, expression, identifier.token);
  }

  DeclarationLine? _parseDeclaration() {
    assert(_currenToken.type == TokenType.Dollar);
    final firstToken = _currenToken;
    if (!_expectPeek(TokenType.Identifier)) {
      return null;
    }
    final identifier = Identifier(_currenToken.literal, _currenToken);

    if (!_expectPeek(TokenType.Assign)) {
      return null;
    }
    _nextToken();

    final expression = _parseExpression();
    if (expression == null) {
      return null;
    }

    if (!_expectPeek(TokenType.NewLine)) {
      return null;
    }

    return DeclarationLine(identifier, expression, firstToken);
  }

  TableHeaderLine? _parseTableHeader() {
    assert(_currenToken.type == TokenType.LeftBracket);
    final firstToken = _currenToken;

    if (!_expectPeek(TokenType.Identifier)) {
      return null;
    }

    final identifier = Identifier(_currenToken.literal, _currenToken);

    if (!_expectPeek(TokenType.RigthBracket)) {
      return null;
    }
    if (!_expectPeek(TokenType.NewLine)) {
      return null;
    }

    return TableHeaderLine(identifier, firstToken);
  }

  Expression? _parseExpression() {
    switch (_currenToken.type) {
      case TokenType.Illegal ||
          TokenType.Eof ||
          TokenType.NewLine ||
          TokenType.Assign ||
          TokenType.RigthBrace ||
          TokenType.RigthBracket ||
          TokenType.Dollar:
        errors.add(
          ExpectedToken(
            [
              TokenType.Identifier,
              TokenType.RigthBrace,
              TokenType.LeftBracket,
              TokenType.Number,
              TokenType.StringLiteral,
              TokenType.InterpolableStringLiteral,
            ],
            _currenToken,
            lexer.input,
          ),
        );
        return null;
      case TokenType.Identifier:
        return Identifier(_currenToken.literal, _currenToken);

      case TokenType.Number:
        return Number(double.parse(_currenToken.literal), _currenToken);

      case TokenType.StringLiteral:
        return StringLiteral(_currenToken.literal, _currenToken);

      case TokenType.InterpolableStringLiteral:
        return InterpolableStringLiteral(_currenToken.literal, _currenToken);

      // Expresion that create Object values
      case TokenType.LeftBrace:
        throw UnimplementedError();

      // Expression that create Array values
      case TokenType.LeftBracket:
        throw UnimplementedError();

      case TokenType.Comment:
        throw StateError("Comments are not handled in the parser");
    }
  }
}
