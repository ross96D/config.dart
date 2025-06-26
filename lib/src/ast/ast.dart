
import 'package:config/src/tokens/tokens.dart';

abstract class Node {
  final Token token;

  Node([Token? token]) : token = Token.empty();

  String tokenLiteral() {
    return token.literal;
  }
}

sealed class Line extends Node {
  Line([super.token]);
}

sealed class Expression extends Node {
  Expression([super.token]);
}

// VAR = <EXPR>
class AssigmentLine extends Line {
  final Identifier identifer;
  final Expression expr;

  AssigmentLine(this.identifer, this.expr, [super.token]);

  factory AssigmentLine.test(Identifier identifier, Expression expr) {
    return AssigmentLine(identifier, expr, Token.empty());
  }

  @override
  bool operator ==(Object other) {
    return other is AssigmentLine && identifer == other.identifer && expr == other.expr;
  }

  @override
  int get hashCode => Object.hash(identifer, expr);


  @override
  String toString() {
    return "$identifer = $expr";
  }
}

// $VAR = <EXPR>
class DeclarationLine extends Line {
  final Identifier identifer;
  final Expression expr;

  DeclarationLine(this.identifer, this.expr, [super.token]);

  factory DeclarationLine.test(Identifier identifier, Expression expr) {
    return DeclarationLine(identifier, expr, Token.empty());
  }

  @override
  bool operator ==(Object other) {
    return other is DeclarationLine && identifer == other.identifer && expr == other.expr;
  }

  @override
  int get hashCode => Object.hash(identifer, expr);

  @override
  String toString() {
    return "\$$identifer = $expr";
  }
}

// [table]
class TableHeaderLine extends Line {
  final Identifier identifer;

  TableHeaderLine(this.identifer, [super.token]);

  @override
  bool operator ==(Object other) {
    return other is TableHeaderLine && identifer == other.identifer;
  }

  @override
  int get hashCode => identifer.hashCode;


  @override
  String toString() {
    return "[$identifer]";
  }
}

class Identifier extends Expression {
  final String value;

  Identifier(this.value, [super.token]);

  @override
  bool operator ==(Object other) {
    return other is Identifier && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return value;
  }
}

class Number extends Expression {
  final double value;

  Number(this.value, [super.token]);

  @override
  bool operator ==(Object other) {
    return other is Number && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return "$value";
  }
}

class StringLiteral extends Expression {
  final String value;

  StringLiteral(this.value, [super.token]);

  @override
  bool operator ==(Object other) {
    return other is StringLiteral && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;


  @override
  String toString() {
    return "'$value'";
  }
}

class InterpolableStringLiteral extends Expression {
  final String value;

  InterpolableStringLiteral(this.value, [super.token]);

  @override
  bool operator ==(Object other) {
    return other is InterpolableStringLiteral && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return '"$value"';
  }
}

class Program {
  final List<Line> lines;

  Program([List<Line>? lines]) : lines = lines ?? [];

  String tokenLiteral() {
    return lines.map((e) => e.tokenLiteral()).join("\n");
  }

  @override
  bool operator ==(Object other) {
    if (other is! Program) {
      return false;
    }
    if (other.lines.length != lines.length) {
      return false;
    }
    for (int i = 0; i < lines.length; i++) {
      if (lines[i] != other.lines[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(lines);


  @override
  String toString() {
    return lines.join("\n");
  }
}
