// ignore_for_file: constant_identifier_names

enum TokenType {
  Illegal,
  Eof,
  NewLine,
  Assign,
  LeftBrace,
  RigthBrace,
  LeftBracket,
  RigthBracket,
  Number,
  StringLiteral,
  InterpolableStringLiteral,
  Comment,
  Dollar,
  Identifier,
  KwTrue,
  KwFalse;

  const TokenType();
}

class Cursor {
  final int lineNumber;
  final int offset;

  Cursor({required this.lineNumber, required this.offset});

  @override
  String toString() {
    return "$lineNumber:$offset";
  }

  @override
  bool operator ==(Object other) {
    return other is Cursor && lineNumber == other.lineNumber && offset == other.offset;
  }

  @override
  int get hashCode => Object.hashAll([lineNumber, offset]);
}

class Position {
  final String filepath;
  final Cursor start;
  final Cursor end;

  Position({required this.start, required this.end, this.filepath = ""});

  factory Position.t(
    int startLineNumber,
    int startOffset, [
    int? endLineNumber,
    int? endOffset,
    String filepath = "",
  ]) {
    return Position(
      start: Cursor(lineNumber: startLineNumber, offset: startOffset),
      end: Cursor(lineNumber: endLineNumber ?? startLineNumber, offset: endOffset ?? startOffset),
      filepath: filepath,
    );
  }

  @override
  String toString() {
    return "$filepath $start - $end";
  }

  @override
  bool operator ==(Object other) {
    return other is Position &&
        filepath == other.filepath &&
        start == other.start &&
        end == other.end;
  }

  @override
  int get hashCode => Object.hashAll([filepath, start, end]);
}

class Token {
  final TokenType type;
  final String literal;
  final Position? pos;

  const Token({required this.type, required this.literal, this.pos});

  factory Token.empty() => Token(literal: "", type: TokenType.Illegal);

  @override
  bool operator ==(Object other) {
    return other is Token &&
        type == other.type &&
        literal == other.literal &&
        switch (pos != null && other.pos != null) {
          true => pos == other.pos,
          false => true,
        };
  }

  @override
  int get hashCode => Object.hash(type, literal);

  @override
  String toString() {
    if (pos != null) {
      return "$type(${display()}) $pos";
    } else {
      return "$type(${display()})";
    }
  }

  String display() {
    return switch (type) {
      TokenType.Illegal => "**ILLEGAL**",
      TokenType.Eof => "**EOF**",
      TokenType.NewLine => "\n",
      TokenType.Dollar => "\$",
      TokenType.Assign => "=",
      TokenType.LeftBrace => "{",
      TokenType.RigthBrace => "}",
      TokenType.LeftBracket => "[",
      TokenType.RigthBracket => "]",
      TokenType.StringLiteral => "'$literal'",
      TokenType.InterpolableStringLiteral => "\"$literal\"",
      TokenType.Comment => literal,
      TokenType.Identifier => literal,
      TokenType.Number => literal,
      TokenType.KwTrue => "true",
      TokenType.KwFalse => "false",
    };
  }
}
