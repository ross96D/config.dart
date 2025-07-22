// ignore_for_file: constant_identifier_names

enum Operator {
  Mult,
  Div,
  Plus,
  Minus,

  Equals,
  NotEquals,
  GreatThan,
  GreatOrEqThan,
  LessThan,
  LessOrEqThan,

  Bang;

  @override
  String toString() {
    return switch (this) {
      Operator.Mult => "*",
      Operator.Div => "/",
      Operator.Plus => "+",
      Operator.Minus => "-",
      Operator.GreatThan => ">",
      Operator.GreatOrEqThan => ">=",
      Operator.LessThan => "<",
      Operator.LessOrEqThan => "<=",
      Operator.Bang => "!",
      Operator.Equals => "==",
      Operator.NotEquals => "!=",
    };
  }

  static Operator from(TokenType type) {
    return switch (type) {
      TokenType.Mult => Mult,
      TokenType.Div => Div,
      TokenType.Plus => Plus,
      TokenType.Minus => Minus,
      TokenType.GreatThan => GreatThan,
      TokenType.GreatOrEqThan => GreatOrEqThan,
      TokenType.LessThan => LessThan,
      TokenType.LessOrEqThan => LessOrEqThan,
      TokenType.Bang => Bang,
      TokenType.Equals => Equals,
      TokenType.NotEquals => NotEquals,
      _ => throw StateError("unreachable token type $type is not an operation"),
    };
  }
}

enum TokenType {
  Illegal,
  Eof,
  NewLine,
  Comment,

  /// Symbol: `{`
  LeftBrace,
  /// Symbol: `}`
  RigthBrace,
  /// Symbol: `[`
  LeftBracket,
  /// Symbol: `]`
  RigthBracket,
  /// Symbol: `(`
  LeftParent,
  /// Symbol: `)`
  RigthParent,

  KwTrue,
  KwFalse,

  StringLiteral,
  InterpolableStringLiteral,
  Number,
  Identifier,

  Mult,
  Div,
  Plus,
  Minus,

  Bang,

  Equals,
  NotEquals,
  GreatThan,
  GreatOrEqThan,
  LessThan,
  LessOrEqThan,

  Assign,
  Dollar;

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

  Position({required this.start, required this.end, required this.filepath});

  factory Position.start(String filepath) => Position(
    start: Cursor(lineNumber: 0, offset: 0),
    end: Cursor(lineNumber: 0, offset: 0),
    filepath: filepath,
  );

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
  bool operator ==(covariant Position other) {
    return filepath == other.filepath && start == other.start && end == other.end;
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
      return "$type(${display()}) $literal $pos";
    } else {
      return "$type(${display()}) $literal ";
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

      TokenType.Mult => "*",
      TokenType.Div => "/",
      TokenType.Plus => "+",
      TokenType.Minus => "-",

      TokenType.LeftParent => "(",
      TokenType.RigthParent => ")",

      TokenType.Equals => "==",
      TokenType.NotEquals => "!=",
      TokenType.GreatThan => ">",
      TokenType.GreatOrEqThan => ">=",
      TokenType.LessThan => "<",
      TokenType.LessOrEqThan => "<=",

      TokenType.Bang => "!",
    };
  }
}
