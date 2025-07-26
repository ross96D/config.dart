import 'dart:core' as core;
import 'dart:core';

class Duration {
  final int microseconds;

  Duration(this.microseconds);

  factory Duration.fromDartDuration(core.Duration dur) {
    return Duration(dur.inMicroseconds);
  }

  core.Duration toDartDuration() {
    return core.Duration(microseconds: microseconds);
  }

  static Duration parse(String dur) {
    return _Parser(_Lexer(dur)).parse();
  }

  static int? lexerString(String dur) {
    try {
      final lexer = _Lexer(dur);
      _Parser(lexer).parse();
      return lexer._position;
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() {
    return "${(microseconds/1000000).floor()}s${microseconds%1000000}us";
  }

  @override
  bool operator ==(covariant Duration other) {
    return microseconds == other.microseconds;
  }

  @override
  core.int get hashCode => microseconds.hashCode;
}

bool _isDigit(int char) {
  return char >= 48 && char <= 57;
}

bool _isLetter(int char) {
  return (char >= 65 && char <= 90) || (char >= 97 && char <= 122);
}

enum _Units {
  us(1),
  ms(1),
  s(2),
  m(3),
  h(4);

  final int value;
  const _Units(this.value);
}

class _Parser {
  final _Lexer lexer;

  _Parser(this.lexer);

  Duration parse() {
    _Token token = lexer.nextToken();
    if (token.type != _TokenType.number) {
      throw Exception("Invalid duration");
    }
    int hours = 0;
    int minutes = 0;
    int seconds = 0;
    int milliseconds = 0;
    int microseconds = 0;

    int number = 0;
    int allowedUnits = 5; // hour + 1;
    bool seeUnit = false;
    while (true) {
      switch (token.type) {
        case _TokenType.unit:
          seeUnit = true;
          switch (token.literal) {
            case "us":
              if (allowedUnits <= _Units.us.value) {
                throw Exception("Microseconds not allowed here");
              }
              allowedUnits = _Units.us.value;
              microseconds = number;
            case "ms":
              if (allowedUnits <= _Units.ms.value) {
                throw Exception("Milliseconds not allowed here");
              }
              allowedUnits = _Units.ms.value;
              milliseconds = number;
            case "s":
              if (allowedUnits <= _Units.s.value) {
                throw Exception("Seconds not allowed here");
              }
              allowedUnits = _Units.s.value;
              seconds = number;
            case "m":
              if (allowedUnits <= _Units.m.value) {
                throw Exception("Minutes not allowed here");
              }
              allowedUnits = _Units.m.value;
              minutes = number;
            case "h":
              if (allowedUnits <= _Units.h.value) {
                throw Exception("Hours not allowed here");
              }
              allowedUnits = _Units.h.value;
              hours = number;
            default:
              throw Exception("Invalid unit ${token.literal}");
          }

        case _TokenType.number:
          number = int.parse(token.literal);

        case _TokenType.eof:
          if (!seeUnit) {
            throw Exception("Duration cannot be number only");
          }
          return Duration(
            microseconds +
                (milliseconds * core.Duration.microsecondsPerMillisecond) +
                (seconds * core.Duration.microsecondsPerSecond) +
                (minutes * core.Duration.microsecondsPerMinute) +
                (hours * core.Duration.microsecondsPerHour),
          );
      }
      token = lexer.nextToken();
    }
  }
}

enum _TokenType { unit, number, eof }

class _Token {
  String literal;
  _TokenType type;
  _Token(this.literal, this.type);
}

class _Lexer {
  final String input;

  int _char = 0;
  int _position = 0;
  int _readPosition = 0;

  _Lexer(this.input) {
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
  }

  _Token nextToken() {
    if (_char == 0) {
      return _Token("", _TokenType.eof);
    }
    if (_isDigit(_char)) {
      return _readNumber();
    } else if (_isLetter(_char)) {
      return _readString();
    } else {
      return _Token("", _TokenType.eof);
    }
  }

  _Token _readNumber() {
    final start = _position;
    while (_isDigit(_char)) {
      _readChar();
    }
    final end = _position;
    return _Token(input.substring(start, end), _TokenType.number);
  }

  _Token _readString() {
    final start = _position;
    while (_isLetter(_char)) {
      _readChar();
    }
    final end = _position;
    return _Token(input.substring(start, end), _TokenType.unit);
  }
}
