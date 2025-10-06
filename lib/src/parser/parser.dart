import 'dart:collection';

import 'package:config/src/ast/ast.dart';
import 'package:config/src/lexer/lexer.dart';
import 'package:config/src/tokens/tokens.dart';
import 'package:config/src/types/duration/duration.dart';

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
    final markerLength = (endCol - startCol).clamp(0, line.length - startCol + 1);

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
  static List<TokenType> _filterNull(List<TokenType?> tokens) {
    List<TokenType> result = [];
    for (final token in tokens) {
      if (token != null) {
        result.add(token);
      }
    }
    return result;
  }

  final List<TokenType> expected;

  ExpectedToken(List<TokenType> expected, super.token, super.input)
    : expected = _filterNull(expected);

  factory ExpectedToken.withNulls(List<TokenType?> expected, Token token, String input) {
    return ExpectedToken(_filterNull(expected), token, input);
  }

  @override
  String _display() {
    return "Expected token ${expected.join(" or ")} found ${token.type}";
  }
}

class Parser {
  final Lexer lexer;
  final List<ParseError> errors = [];
  final String filepath;
  final Queue<TokenType> _additionalLineEnds = Queue();

  bool _alreadyParsed = false;

  late Token _currenToken;
  late Token _peekToken;

  Parser(this.lexer) : filepath = lexer.filepath {
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
    assert(
      _peekToken.type != TokenType.Comment,
      "two consecutives TokenType.Comment are imposibles",
    );
  }

  Program parseProgram() {
    assert(() {
      final resp = _alreadyParsed == false;
      _alreadyParsed = true;
      return resp;
    }(), "can only call parseProgram once");

    final response = Program(filepath);
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

  /// returns true if the line end was from additional line end
  bool _moveToLineEnd() {
    // we do not use additional line end here because the function that setted
    // the additional line exepect the token at the end
    while (!_isLineEnd(_currenToken.type, _additionalLineEnds.safeLast)) {
      _nextToken();
    }
    return _currenToken.type == _additionalLineEnds.safeLast;
  }

  static bool _isLineEnd(TokenType type, [TokenType? additionalLineEnd]) {
    return type == TokenType.NewLine ||
        type == TokenType.Eof ||
        type == TokenType.Semicolon ||
        type == additionalLineEnd;
  }

  Line? _parseLine() {
    if (_currenToken.type == _additionalLineEnds.safeLast) {
      return null;
    }
    switch (_currenToken.type) {
      case TokenType.Comment:
        throw StateError("unreachable");
      case TokenType.Eof:
        throw StateError("unreachable");
      case TokenType.NewLine || TokenType.Semicolon:
        return null;
      case TokenType.Illegal:
        errors.add(IlegalTokenFound(_currenToken, lexer.input));
        return null;
      case TokenType.Assign || TokenType.Comma || TokenType.Colon:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.LeftBrace || TokenType.RigthBrace:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.GreatThan || TokenType.GreatOrEqThan || TokenType.Bang:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;
      case TokenType.LessThan || TokenType.LessOrEqThan || TokenType.Equals || TokenType.NotEquals:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.StringLiteral || TokenType.InterpolableStringLiteral:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.Integer || TokenType.Double || TokenType.Duration:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.LeftBracket || TokenType.RigthBracket:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.LeftParent || TokenType.RigthParent:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.KwTrue || TokenType.KwFalse:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.Mult || TokenType.Div || TokenType.Plus || TokenType.Minus:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.Dollar:
        return _parseDeclaration();

      case TokenType.Identifier:
        return _parseIdentifierStart();
    }
  }

  bool _expectPeek(TokenType type, [TokenType? typeOr]) {
    if (_peekToken.type != type && _peekToken.type != typeOr) {
      errors.add(ExpectedToken.withNulls([type, typeOr], _peekToken, lexer.input));
      return false;
    }
    _nextToken();
    return true;
  }

  bool _expectPeekLineEnd() {
    if (!_isLineEnd(_peekToken.type, _additionalLineEnds.safeLast)) {
      errors.add(
        ExpectedToken.withNulls(
          [TokenType.NewLine, TokenType.Eof, TokenType.Semicolon, ?_additionalLineEnds.safeLast],
          _peekToken,
          lexer.input,
        ),
      );
      return false;
    }
    // when additional line end is set and the token is the line end we cannot call nextToken
    // because the function that setted the additional line exepect the token at the end
    if (_peekToken.type != _additionalLineEnds.safeLast) {
      _nextToken();
    }
    return true;
  }

  _Precedence _peekPrecedence() {
    return _precedences[_peekToken.type] ?? _Precedence.lowest;
  }

  _Precedence _currentPrecedence() {
    return _precedences[_currenToken.type] ?? _Precedence.lowest;
  }

  void _ignoreWhilePeek(TokenType type) {
    while (_peekToken.type == type) {
      _nextToken();
    }
  }

  Line? _parseIdentifierStart() {
    assert(_currenToken.type == TokenType.Identifier);
    final identifier = Identifier(_currenToken.literal, _currenToken);
    // allows EmptyBlockWithOutbraces syntax
    if (_isLineEnd(_peekToken.type, _additionalLineEnds.safeLast)) {
      return Block(identifier, [], identifier.token);
    }
    if (!_expectPeek(TokenType.Assign, TokenType.LeftBrace)) {
      return null;
    }
    if (_currenToken.type == TokenType.LeftBrace) {
      return _parseBlock(identifier);
    } else {
      return _parseAssignment(identifier);
    }
  }

  Block _parseBlock(Identifier identifier) {
    assert(_currenToken.type == TokenType.LeftBrace);
    _nextToken();
    _additionalLineEnds.add(TokenType.RigthBrace);

    List<Line> lines = [];
    while (_currenToken.type != TokenType.RigthBrace && _currenToken.type != TokenType.Eof) {
      final line = _parseLine();
      if (line != null) {
        lines.add(line);
      }
      // just make sure to move to line end
      if (!_moveToLineEnd()) {
        _nextToken();
      }
    }
    if (_currenToken.type != TokenType.RigthBrace) {
      errors.add(ExpectedToken([TokenType.RigthBrace], _currenToken, lexer.input));
    }
    _additionalLineEnds.removeLast();
    _nextToken();
    return Block(identifier, lines, identifier.token);
  }

  AssigmentLine? _parseAssignment(Identifier identifier) {
    assert(_currenToken.type == TokenType.Assign);
    _nextToken();

    final expression = _parseExpression(_Precedence.lowest);
    if (expression == null) {
      return null;
    }

    if (!_expectPeekLineEnd()) {
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

    final expression = _parseExpression(_Precedence.lowest);
    if (expression == null) {
      return null;
    }

    if (!_expectPeekLineEnd()) {
      return null;
    }

    return DeclarationLine(identifier, expression, firstToken);
  }

  Expression? _parseExpression(_Precedence precedence) {
    final prefix = _prefixParseFn[_currenToken.type];
    if (prefix == null) {
      errors.add(
        ExpectedToken(_prefixParseFn.keys.toList(growable: false), _currenToken, lexer.input),
      );
      return null;
    }

    Expression? leftExpr = prefix(this);

    while (!_isLineEnd(_peekToken.type, _additionalLineEnds.safeLast) &&
        precedence < _peekPrecedence()) {
      final infix = _infixParseFn[_peekToken.type];
      if (infix == null) {
        return leftExpr;
      }
      _nextToken();
      leftExpr = infix(this, leftExpr!);
      if (leftExpr == null) {
        return null;
      }
    }

    return leftExpr;
  }

  static Identifier _parseIdentifier(Parser parser) {
    return Identifier(parser._currenToken.literal, parser._currenToken);
  }

  static NumberDouble _parseNumberDouble(Parser parser) {
    return NumberDouble(double.parse(parser._currenToken.literal), parser._currenToken);
  }

  static NumberInteger _parseNumberInteger(Parser parser) {
    return NumberInteger(int.parse(parser._currenToken.literal), parser._currenToken);
  }

  static DurationExpression _parseDuration(Parser parser) {
    return DurationExpression(Duration.parse(parser._currenToken.literal), parser._currenToken);
  }

  static StringLiteral _parseStringLiteral(Parser parser) {
    return StringLiteral(parser._currenToken.literal, parser._currenToken);
  }

  static InterpolableStringLiteral _parseInterpolableStringLiteral(Parser parser) {
    return InterpolableStringLiteral(parser._currenToken.literal, parser._currenToken);
  }

  static Boolean _parseBooleanTrue(Parser parser) {
    return Boolean(true, parser._currenToken);
  }

  static Boolean _parseBooleanFalse(Parser parser) {
    return Boolean(false, parser._currenToken);
  }

  static PrefixExpression _parsePrefixExpression(Parser parser) {
    final op = Operator.from(parser._currenToken.type);
    final token = parser._currenToken;
    parser._nextToken();
    return PrefixExpression(op, parser._parseExpression(_Precedence.prefix)!, token);
  }

  static InfixExpression? _parseInfixExpression(Parser parser, Expression left) {
    final token = parser._currenToken;
    final op = Operator.from(parser._currenToken.type);

    final precedence = parser._currentPrecedence();
    parser._nextToken();
    final right = parser._parseExpression(precedence);
    if (right == null) {
      return null;
    }

    return InfixExpression(left, op, right, token);
  }

  static Expression? _parseGroupExpression(Parser parser) {
    parser._nextToken();
    final expr = parser._parseExpression(_Precedence.lowest);
    if (expr == null) {
      return null;
    }
    if (!parser._expectPeek(TokenType.RigthParent)) {
      return null;
    }
    return expr;
  }

  static ArrayExpression _parseArray(Parser parser) {
    final token = parser._currenToken;
    final list = _parseExpressionList(parser, TokenType.RigthBracket);

    return ArrayExpression(list, token);
  }

  static List<Expression> _parseExpressionList(Parser parser, TokenType end) {
    final list = <Expression>[];
    parser._ignoreWhilePeek(TokenType.NewLine);

    if (parser._peekToken.type == end) {
      parser._nextToken();
      return list;
    }

    parser._nextToken();
    Expression? exp = parser._parseExpression(_Precedence.lowest);
    if (exp == null) {
      return list;
    }
    list.add(exp);

    while (parser._peekToken.type == TokenType.Comma || parser._peekToken.type == TokenType.NewLine) {
      // advance last token of expression
      parser._nextToken();
      // ignore all new line tokens (allow multiline statements)
      parser._ignoreWhilePeek(TokenType.NewLine);
      // this allow trailing comma
      if (parser._peekToken.type == end) {
        break;
      }
      parser._nextToken(); // get to the actual token of the expression so _parseExpression works

      exp = parser._parseExpression(_Precedence.lowest);
      if (exp == null) {
        return list;
      }
      list.add(exp);
    }

    parser._ignoreWhilePeek(TokenType.NewLine);
    parser._expectPeek(end);
    return list;
  }

  static MapExpression _parserMapExpression(Parser parser) {
    assert(parser._currenToken.type == TokenType.LeftBrace);
    final token = parser._currenToken;
    parser._ignoreWhilePeek(TokenType.NewLine);

    final response = MapExpression({}, token);
    while (parser._peekToken.type != TokenType.RigthBrace) {
      // parse key
      parser._ignoreWhilePeek(TokenType.NewLine); // allow multiline
      parser._nextToken(); // advance to the expression actual token
      final key = parser._parseExpression(_Precedence.lowest);
      if (key == null) {
        return response;
      }
      parser._ignoreWhilePeek(TokenType.NewLine); // allow multiline
      if (!parser._expectPeek(TokenType.Colon)) {
        return response;
      }

      // parse value
      parser._ignoreWhilePeek(TokenType.NewLine); // allow multiline
      parser._nextToken(); // advance to the expression actual token
      final value = parser._parseExpression(_Precedence.lowest);
      if (value == null) {
        return response;
      }
      // this gibberish is to update the set value
      if (!response.list.add(EntryExpression(key, value))) {
        response.list.remove(EntryExpression(key, value));
        response.list.add(EntryExpression(key, value));
      }

      // `parse` comma
      if (parser._peekToken.type == TokenType.RigthBrace) {
        break;
      }
      if (!parser._expectPeek(TokenType.Comma, TokenType.NewLine)) {
        return response;
      }
      parser._ignoreWhilePeek(TokenType.NewLine); // allow multiline
    }
    parser._expectPeek(TokenType.RigthBrace);
    return response;
  }
}

enum _Precedence {
  lowest,
  equals,
  lessGreater,
  sum,
  product,
  prefix;

  bool operator <(_Precedence other) {
    return index < other.index;
  }

  bool operator <=(_Precedence other) {
    return index <= other.index;
  }

  bool operator >(_Precedence other) {
    return index > other.index;
  }

  bool operator >=(_Precedence other) {
    return index >= other.index;
  }
}

const _prefixParseFn = {
  TokenType.KwTrue: Parser._parseBooleanTrue,
  TokenType.KwFalse: Parser._parseBooleanFalse,
  TokenType.Identifier: Parser._parseIdentifier,
  TokenType.StringLiteral: Parser._parseStringLiteral,
  TokenType.InterpolableStringLiteral: Parser._parseInterpolableStringLiteral,
  TokenType.Double: Parser._parseNumberDouble,
  TokenType.Integer: Parser._parseNumberInteger,
  TokenType.Duration: Parser._parseDuration,
  TokenType.Bang: Parser._parsePrefixExpression,
  TokenType.Minus: Parser._parsePrefixExpression,
  TokenType.LeftParent: Parser._parseGroupExpression,
  TokenType.LeftBracket: Parser._parseArray,
  TokenType.LeftBrace: Parser._parserMapExpression,
};

const _infixParseFn = {
  TokenType.Plus: Parser._parseInfixExpression,
  TokenType.Minus: Parser._parseInfixExpression,
  TokenType.Div: Parser._parseInfixExpression,
  TokenType.Mult: Parser._parseInfixExpression,
  TokenType.Equals: Parser._parseInfixExpression,
  TokenType.NotEquals: Parser._parseInfixExpression,
  TokenType.LessThan: Parser._parseInfixExpression,
  TokenType.LessOrEqThan: Parser._parseInfixExpression,
  TokenType.GreatThan: Parser._parseInfixExpression,
  TokenType.GreatOrEqThan: Parser._parseInfixExpression,
};

const _precedences = {
  TokenType.Equals: _Precedence.equals,
  TokenType.NotEquals: _Precedence.equals,
  TokenType.LessThan: _Precedence.lessGreater,
  TokenType.LessOrEqThan: _Precedence.lessGreater,
  TokenType.GreatThan: _Precedence.lessGreater,
  TokenType.GreatOrEqThan: _Precedence.lessGreater,
  TokenType.Plus: _Precedence.sum,
  TokenType.Minus: _Precedence.sum,
  TokenType.Mult: _Precedence.product,
  TokenType.Div: _Precedence.product,
};

extension<T> on Queue<T> {
  T? get safeLast {
    if (isEmpty) return null;
    return last;
  }
}
