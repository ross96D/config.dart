import 'package:config/src/tokens/tokens.dart';

abstract class Node {
  final Token token;

  Node([Token? token]) : token = token ?? Token.empty();

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

sealed class _GenericExpression<T extends Object> extends Expression {
  final T value;
  _GenericExpression(this.value, [super.token]);

  @override
  bool operator ==(covariant _GenericExpression<T> other) {
    return value == other.value;
  }

  @override
  int get hashCode => this.value.hashCode;
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

class Block extends Line {
  final Identifier identifer;
  final List<Line> lines;

  Block(this.identifer, this.lines, [super.token]);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(identifer.toString());
    buffer.write(" {\n");
    for (final line in lines) {
      final linesplit = line.toString().split("\n");
      for (final split in linesplit) {
        buffer.write("\t$split");
        buffer.write("\n");
      }
    }
    buffer.write("}");

    return buffer.toString();
  }

  @override
  bool operator ==(covariant Block other) {
    if (identifer != other.identifer) {
      return false;
    }
    if (lines.length != other.lines.length) {
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
  int get hashCode => Object.hashAll([identifer, ...lines]);
}

class Identifier extends _GenericExpression<String> {
  Identifier(super.value, [super.token]);

  @override
  String toString() {
    return value;
  }
}

class Boolean extends _GenericExpression<bool> {
  Boolean(super.value, [super.token]);

  @override
  String toString() {
    return "$value";
  }
}

class NumberDouble extends _GenericExpression<double> {
  NumberDouble(super.value, [super.token]);

  @override
  String toString() {
    return "$value";
  }
}

class NumberInteger extends _GenericExpression<int> {
  NumberInteger(super.value, [super.token]);

  @override
  String toString() {
    return "$value";
  }
}

class StringLiteral extends _GenericExpression<String> {
  StringLiteral(super.value, [super.token]);

  @override
  String toString() {
    return "'$value'";
  }
}

class InterpolableStringLiteral extends _GenericExpression<String> {
  InterpolableStringLiteral(super.value, [super.token]);

  @override
  String toString() {
    return '"$value"';
  }
}

class PrefixExpression extends Expression {
  final Operator op;
  final Expression expr;

  PrefixExpression(this.op, this.expr, [super.token]);

  @override
  String toString() {
    return '($op$expr)';
  }

  @override
  bool operator ==(covariant PrefixExpression other) {
    return op == other.op && expr == other.expr;
  }

  @override
  int get hashCode => Object.hashAll([op, expr]);
}

class InfixExpression extends Expression {
  final Expression left;
  final Expression right;
  final Operator op;

  InfixExpression(this.left, this.op, this.right, [super.token]);

  @override
  String toString() {
    return '($left $op $right)';
  }

  @override
  bool operator ==(covariant InfixExpression other) {
    return left == other.left && op == other.op && right == other.right;
  }

  @override
  int get hashCode => Object.hashAll([left, op, right]);
}

class Array extends Expression {
  final List<Expression> list;
  Array(this.list, [super.token]);

  @override
  String toString() {
    return "[${list.join(", ")}]";
  }

  @override
  bool operator ==(covariant Array other) {
    if (list.length != other.list.length) {
      return false;
    }
    for (int i = 0; i < list.length; i++) {
      if (list[i] != other.list[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(list);
}

class Program {
  final List<Line> lines;
  final String filepath;

  Program(this.filepath, [List<Line>? lines]) : lines = lines ?? [];

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

  Block toBlock() {
    final token = Token(type: TokenType.Identifier, literal: "", pos: Position.t(0, 0, 0, 0, ""));
    return Block(Identifier("", token), lines, token);
  }

  @override
  int get hashCode => Object.hashAll(lines);

  @override
  String toString() {
    return lines.join("\n");
  }
}
