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

      case TokenType.LeftBrace || TokenType.RigthBrace:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.GreatThan || TokenType.GreatOrEqThan || TokenType.Bang:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;
      case TokenType.LessThan || TokenType.LessOrEqThan || TokenType.Equals || TokenType.NotEquals:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.Number || TokenType.StringLiteral || TokenType.InterpolableStringLiteral:
        errors.add(BadTokenAtLineStart(_currenToken, lexer.input));
        return null;

      case TokenType.RigthBracket:
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
        return _parseAssignment();

      case TokenType.LeftBracket:
        return _parseTableHeader();
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

  _Precedence _peekPrecedence() {
    return _precedences[_peekToken.type] ?? _Precedence.lowest;
  }

  _Precedence _currentPrecedence() {
    return _precedences[_currenToken.type] ?? _Precedence.lowest;
  }

  AssigmentLine? _parseAssignment() {
    assert(_currenToken.type == TokenType.Identifier);
    final identifier = Identifier(_currenToken.literal, _currenToken);

    if (!_expectPeek(TokenType.Assign)) {
      return null;
    }
    _nextToken();

    final expression = _parseExpression(_Precedence.lowest);
    if (expression == null) {
      return null;
    }

    if (!_expectPeek(TokenType.NewLine, TokenType.Eof)) {
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

    if (!_expectPeek(TokenType.NewLine, TokenType.Eof)) {
      return null;
    }

    return DeclarationLine(identifier, expression, firstToken);
  }

  TableHeaderLine? _parseTableHeader() {
    assert(_currenToken.type == TokenType.LeftBracket);

    if (!_expectPeek(TokenType.Identifier)) {
      return null;
    }

    final identifier = Identifier(_currenToken.literal, _currenToken);

    if (!_expectPeek(TokenType.RigthBracket)) {
      return null;
    }
    if (!_expectPeek(TokenType.NewLine, TokenType.Eof)) {
      return null;
    }
    return TableHeaderLine(identifier, identifier.token);
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

    while ((_peekToken.type != TokenType.NewLine || _peekToken.type != TokenType.Eof) &&
        precedence < _peekPrecedence()) {
      //
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

  static Number _parseNumber(Parser parser) {
    return Number(double.parse(parser._currenToken.literal), parser._currenToken);
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
  TokenType.Number: Parser._parseNumber,
  TokenType.Bang: Parser._parsePrefixExpression,
  TokenType.Minus: Parser._parsePrefixExpression,
  TokenType.LeftParent: Parser._parseGroupExpression,
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
