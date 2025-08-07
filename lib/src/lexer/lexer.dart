import 'package:config/src/tokens/tokens.dart';
import 'package:config/src/types/duration/duration.dart';

class Lexer {
  final String filepath;
  final String input;

  int _position = 0;

  int _readPosition = 0;

  int _char = 0;
  int get char => _char;
  int get nexChar {
    return _readPosition < input.length ? input.codeUnitAt(_readPosition) : 0;
  }

  int _lineNumber = 0;
  int _lineStartPosition = 0;

  Lexer(this.input, [this.filepath = ""]) {
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
    return Position(start: _currentCursor(), end: _currentCursor(offset), filepath: filepath);
  }

  Token _tokenFromCurrent(TokenType type) {
    final charstr = String.fromCharCode(char);
    final resp = Token(type: type, literal: charstr, pos: _getPostion(1));
    _readChar();
    return resp;
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
          filepath: filepath,
        ),
      );
      _readChar();
      return resp;
    }

    final resp = switch (String.fromCharCode(char)) {
      "]" => _tokenFromCurrent(TokenType.RigthBracket),
      "[" => _tokenFromCurrent(TokenType.LeftBracket),
      "}" => _tokenFromCurrent(TokenType.RigthBrace),
      "{" => _tokenFromCurrent(TokenType.LeftBrace),
      "\$" => _tokenFromCurrent(TokenType.Dollar),
      "*" => _tokenFromCurrent(TokenType.Mult),
      "/" => _tokenFromCurrent(TokenType.Div),
      "+" => _tokenFromCurrent(TokenType.Plus),
      "-" => _tokenFromCurrent(TokenType.Minus),
      "(" => _tokenFromCurrent(TokenType.LeftParent),
      ")" => _tokenFromCurrent(TokenType.RigthParent),
      "," => _tokenFromCurrent(TokenType.Comma),
      ":" => _tokenFromCurrent(TokenType.Colon),
      "!" => _readBang(),
      "\n" => _newLine(),
      "=" => _readEqual(),
      ">" => _readGreatThan(),
      "<" => _readLessThan(),
      "\"" => _readString('"'),
      "'" => _readString("'"),
      "#" => _readComment(),
      _ => _readLiteral(),
    };
    return resp;
  }

  Token _newLine() {
    final resp = Token(
      type: TokenType.NewLine,
      literal: "\n",
      pos: Position(
        start: _currentCursor(),
        end: Cursor(lineNumber: _lineNumber + 1, offset: 0),
        filepath: filepath,
      ),
    );
    _readChar();
    return resp;
  }

  Token _illegal() {
    final resp = Token(
      type: TokenType.Illegal,
      literal: String.fromCharCode(char),
      pos: _getPostion(1),
    );
    _readChar();
    return resp;
  }

  Token _readEqual() {
    if (String.fromCharCode(nexChar) == "=") {
      final resp = Token(literal: ">=", type: TokenType.Equals, pos: _getPostion(2));
      _readChar();
      _readChar();
      return resp;
    } else {
      return _tokenFromCurrent(TokenType.Assign);
    }
  }

  Token _readBang() {
    if (String.fromCharCode(nexChar) == "=") {
      final resp = Token(literal: "!=", type: TokenType.NotEquals, pos: _getPostion(2));
      _readChar();
      _readChar();
      return resp;
    } else {
      return _tokenFromCurrent(TokenType.Bang);
    }
  }

  Token _readGreatThan() {
    if (String.fromCharCode(nexChar) == "=") {
      final resp = Token(literal: ">=", type: TokenType.GreatOrEqThan, pos: _getPostion(2));
      _readChar();
      _readChar();
      return resp;
    } else {
      return _tokenFromCurrent(TokenType.GreatThan);
    }
  }

  Token _readLessThan() {
    if (String.fromCharCode(nexChar) == "=") {
      final resp = Token(literal: "<=", type: TokenType.LessOrEqThan, pos: _getPostion(2));
      _readChar();
      _readChar();
      return resp;
    } else {
      return _tokenFromCurrent(TokenType.LessThan);
    }
  }

  Token _readComment() {
    assert(String.fromCharCode(char) == "#");

    final startCursor = _currentCursor();
    final start = _position;
    while (!_isNewLineOrEOF()) {
      _readChar();
    }
    final end = _position;
    final endCursor = _currentCursor();

    return Token(
      type: TokenType.Comment,
      literal: input.substring(start, end),
      pos: Position(start: startCursor, end: endCursor, filepath: filepath),
    );
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
      pos: Position(start: startCursor, end: endCursor, filepath: filepath),
    );
  }

  Token _readLiteral() {
    return switch (char) {
      >= 48 && <= 57 => _readNumber(),
      95 => _readIdentifier(),
      >= 65 && <= 90 => _readIdentifier(),
      >= 97 && <= 122 => _readIdentifier(),
      _ => _illegal(),
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
    {
      final lengthDuration = Duration.lexerString(input.substring(_position));
      if (lengthDuration != null) {
        final start = _position;
        final startCursor = _currentCursor();
        for (int i = 0; i < lengthDuration; i++) {
          _readChar();
        }
        final endCursor = _currentCursor();
        return Token(
          literal: input.substring(start, _position),
          type: TokenType.Duration,
          pos: Position(start: startCursor, end: endCursor, filepath: filepath),
        );
      }
    }

    var type = TokenType.Integer;

    final startCursor = _currentCursor();
    final start = _position;
    bool seePoint = false;
    while (_isDigit() || (char == 46 && !seePoint)) {
      if (char == 46) {
        type = TokenType.Double;
        seePoint = true;
      }
      _readChar();
    }
    final endCursor = _currentCursor();
    final end = _position;
    return Token(
      type: type,
      literal: input.substring(start, end),
      pos: Position(start: startCursor, end: endCursor, filepath: filepath),
    );
  }

  Token _readIdentifier() {
    assert(_isLetterOr_(), "identifier must start with a letter or a _");

    final startCursor = _currentCursor();
    final start = _position;
    while (_isLetterOr_() || _isDigit()) {
      _readChar();
    }
    final endCursor = _currentCursor();
    final end = _position;

    final literal = input.substring(start, end);
    final position = Position(start: startCursor, end: endCursor, filepath: filepath);
    Token? token = checkIfKeyword(literal, position);
    token ??= Token(type: TokenType.Identifier, literal: literal, pos: position);
    return token;
  }

  Token? checkIfKeyword(String literal, [Position? pos]) {
    return switch (literal) {
      "true" => Token(literal: literal, type: TokenType.KwTrue, pos: pos),
      "false" => Token(literal: literal, type: TokenType.KwFalse, pos: pos),
      _ => null,
    };
  }

  void _skipWhitespaces() {
    while (char == 32) {
      _readChar();
    }
  }
}
