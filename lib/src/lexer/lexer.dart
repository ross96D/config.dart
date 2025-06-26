import 'package:config/src/tokens/tokens.dart';

class Lexer {
  final String input;

  int _position = 0;

  int _readPosition = 0;

  int _char = 0;
  int get char => _char;

  int _lineNumber = 0;
  int _lineStartPosition = 0;

  Lexer(this.input) {
    _readChar();
  }

  void _readChar() {
    if (_readPosition >= input.length) {
      _char = 0;
    } else {
      _char = input.codeUnitAt(_readPosition);
    }
    _position = _readPosition;
    _readPosition += 1;

    if (_isPreviousNewLine()) {
      _lineNumber += 1;
      _lineStartPosition = _position;
    }
  }

  Cursor _currentCursor([int offset = 0]) =>
      Cursor(lineNumber: _lineNumber, offset: _position - _lineStartPosition + offset);

  Position _getPostion(int offset) {
    return Position(start: _currentCursor(), end: _currentCursor(1));
  }

  Token _tokenFromCurrent(TokenType type) {
    final charstr = String.fromCharCode(char);
    return Token(type: type, literal: charstr, pos: _getPostion(1));
  }

  Token nextToken() {
    _skipWhitespaces();

    if (char == 0) {
      final resp = Token(
        type: TokenType.Eof,
        literal: "",
        pos: Position(
          start: Cursor(lineNumber: _lineNumber, offset: _position - _lineStartPosition),
          end: Cursor(lineNumber: _lineNumber, offset: _position - _lineStartPosition),
        ),
      );
      _readChar();
      return resp;
    }

    final resp = switch (String.fromCharCode(char)) {
      "=" => _tokenFromCurrent(TokenType.Assign),
      "]" => _tokenFromCurrent(TokenType.RigthBracket),
      "[" => _tokenFromCurrent(TokenType.LeftBracket),
      "}" => _tokenFromCurrent(TokenType.RigthBrace),
      "{" => _tokenFromCurrent(TokenType.LeftBrace),
      "\$" => _tokenFromCurrent(TokenType.Dollar),
      "\n" => Token(
        type: TokenType.NewLine,
        literal: "\n",
        pos: Position(
          start: _currentCursor(),
          end: Cursor(lineNumber: _lineNumber + 1, offset: 0),
        ),
      ),
      "\"" => _readString('"'),
      "'" => _readString("'"),
      _ => _readLiteral(),
    };
    switch (resp.type) {
      case TokenType.Assign ||
          TokenType.RigthBracket ||
          TokenType.LeftBracket ||
          TokenType.RigthBrace ||
          TokenType.LeftBrace ||
          TokenType.NewLine ||
          TokenType.Dollar ||
          TokenType.Illegal:
        _readChar();
      default:
    }
    return resp;
  }

  Token _readString(String readUntil) {
    final type = switch (readUntil) {
      '"' => TokenType.InterpolableStringLiteral,
      "'" => TokenType.StringLiteral,
      _ => throw ArgumentError(
        "invalid readUntil expected `\"` or `'` got `$readUntil`",
        "readUntil",
      ),
    };

    final startCursor = _currentCursor();

    _readChar();
    final start = _position;
    while (String.fromCharCode(char) != readUntil && !_isNewLineOrEOF()) {
      _readChar();
    }
    final end = _position;
    _readChar(); // consume readUntil char

    final endCursor = _currentCursor();

    return Token(
      type: type,
      literal: input.substring(start, end),
      pos: Position(start: startCursor, end: endCursor),
    );
  }

  Token _readLiteral() {
    return switch (char) {
      >= 48 && <= 57 => _readNumber(),
      95 => _readIdentifier(),
      >= 65 && <= 90 => _readIdentifier(),
      >= 97 && <= 122 => _readIdentifier(),
      _ => Token(type: TokenType.Illegal, literal: String.fromCharCode(char), pos: _getPostion(1)),
    };
  }

  bool _isPreviousNewLine() {
    if (_position != 0 && _position <= input.length) {
      return input.codeUnitAt(_position - 1) == 10;
    } else {
      return false;
    }
  }

  bool _isNewLineOrEOF() {
    return char == 0 || char == 10;
  }

  bool _isDigit() {
    return char >= 48 && char <= 57;
  }

  bool _isLetterOr_() {
    return char == 95 || (char >= 65 && char <= 90) || (char >= 97 && char <= 122);
  }

  Token _readNumber() {
    assert(_isDigit(), "number must start with a digit");
    final type = TokenType.Number;

    final startCursor = _currentCursor();
    final start = _position;
    while (_isDigit()) {
      _readChar();
    }
    final endCursor = _currentCursor();
    final end = _position;
    return Token(
      type: type,
      literal: input.substring(start, end),
      pos: Position(start: startCursor, end: endCursor),
    );
  }

  Token _readIdentifier() {
    assert(_isLetterOr_(), "identifier must start with a letter or a _");
    final type = TokenType.Identifier;

    final startCursor = _currentCursor();
    final start = _position;
    while (_isLetterOr_() || _isDigit()) {
      _readChar();
    }
    final endCursor = _currentCursor();
    final end = _position;
    return Token(
      type: type,
      literal: input.substring(start, end),
      pos: Position(start: startCursor, end: endCursor),
    );
  }

  void _skipWhitespaces() {
    while (char == 32) {
      _readChar();
    }
  }
}
