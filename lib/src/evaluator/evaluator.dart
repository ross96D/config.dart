import 'package:config/src/ast/ast.dart';
import 'package:config/src/schema.dart';
import 'package:config/src/tokens/tokens.dart';

sealed class Value<T extends Object> {
  final T value;
  final int line;
  final String filepath;
  const Value(this.value, this.line, this.filepath);

  Value copyWith({int? line, T? value, String? filepath}) {
    return switch (this) {
      NumberValue v => NumberValue(
        value as double? ?? v.value,
        line ?? this.line,
        filepath ?? this.filepath,
      ),
      StringValue v => StringValue(
        value as String? ?? v.value,
        line ?? this.line,
        filepath ?? this.filepath,
      ),
      BooleanValue v => BooleanValue(
        value as bool? ?? v.value,
        line ?? this.line,
        filepath ?? this.filepath,
      ),
      MapValue v => MapValue(
        value as Map<String, Value>? ?? v.value,
        line ?? this.line,
        filepath ?? this.filepath,
      ),
    };
  }
}

class NumberValue extends Value<double> {
  const NumberValue(super.value, super.line, super.filepath);
}

class StringValue extends Value<String> {
  const StringValue(super.value, super.line, super.filepath);
}

class BooleanValue extends Value<bool> {
  const BooleanValue(super.value, super.line, super.filepath);
}

class MapValue extends Value<Map<String, Value>> {
  const MapValue(super.value, super.line, super.filepath);

  factory MapValue.empty([int line = -1, String filepath = ""]) => MapValue({}, line, filepath);

  Map<String, Object> toMap() {
    return value.map(
      (key, value) => MapEntry(key, switch (value) {
        MapValue() => value.toMap(),
        _ => value.value,
      }),
    );
  }

  Value? operator [](String key) {
    return value[key];
  }

  void operator []=(String key, Value val) {
    value[key] = val;
  }
}

sealed class EvaluationError {
  const EvaluationError();
  String error();
}

class DuplicatedKeyError extends EvaluationError {
  final int lineFirst;
  final int lineSecond;
  final String filepath;
  final String keyName;

  DuplicatedKeyError(this.keyName, this.lineFirst, this.lineSecond, this.filepath);

  @override
  String error() {
    return """
Duplicated key $keyName
first occurrence: $filepath:${lineFirst + 1}:0
second occurrence: $filepath:${lineSecond + 1}:0
""";
  }

  @override
  String toString() {
    return "DuplicatedKeyError(keyName: $keyName, lineFirst: $lineFirst, lineSecond: $lineSecond, filepath: $filepath)";
  }

  @override
  bool operator ==(covariant DuplicatedKeyError other) {
    return lineFirst == other.lineFirst &&
        lineSecond == other.lineSecond &&
        filepath == other.filepath &&
        keyName == other.keyName;
  }

  @override
  int get hashCode => Object.hashAll([keyName, lineFirst, lineSecond, filepath]);
}

class BlockNameDefinedAsKeyError extends EvaluationError {
  // TODO final Position tablePosition;
  final int keyLine;
  final int blockLine;
  final String filepath;
  final String tableName;

  BlockNameDefinedAsKeyError(this.tableName, this.keyLine, this.blockLine, this.filepath);

  @override
  String error() {
    return """
A key with the same name as the block is already defined, table $tableName could not be created
key defined here -> $filepath:${keyLine + 1}:0
block defined here -> $filepath:${blockLine + 1}:0
""";
  }

  @override
  String toString() {
    return "BlockNameDefinedAsKeyError(tableName: $tableName, keylLine: $keyLine, blockLine: $blockLine, filepath: $filepath)";
  }

  @override
  bool operator ==(covariant BlockNameDefinedAsKeyError other) {
    return keyLine == other.keyLine && blockLine == other.blockLine && tableName == other.tableName && filepath == filepath;
  }

  @override
  int get hashCode => Object.hashAll([keyLine, blockLine, tableName, filepath]);
}

class KeyNotInSchemaError extends EvaluationError {
  final int line;
  final String filepath;
  final String keyName;

  KeyNotInSchemaError(this.keyName, this.line, this.filepath);

  @override
  String error() {
    return """
  Provided schema does not have key $keyName
  $filepath:${line + 1}:0
  """;
  }

  @override
  String toString() {
    return "KeyNotInSchemaError(line: $line, keyName: $keyName, filepath: $filepath)";
  }

  @override
  bool operator ==(covariant KeyNotInSchemaError other) {
    return line == other.line && keyName == other.keyName && filepath == other.filepath;
  }

  @override
  int get hashCode => Object.hashAll([line, keyName, filepath]);
}

class InfixOperationError extends EvaluationError {
  final int line;
  final String filepath;
  final Value left;
  final Value rigth;
  final Operator op;

  const InfixOperationError(this.left, this.op, this.rigth, this.line, this.filepath);

  @override
  String error() {
    return "InfixOperationError";
  }
}

class ConflictTypeError extends EvaluationError {
  final int line;
  final String filepath;
  final String keyName;
  final Type expected;
  final Type actual;

  ConflictTypeError(this.keyName, this.line, this.filepath, this.expected, this.actual);

  @override
  String error() {
    return """
Type Error $keyName expected type is $expected but found $actual
$filepath:${line + 1}:0
""";
  }

  @override
  String toString() {
    return "ConflictTypeError(keyName: $keyName, line: $line,  filepath: $filepath, expected: $expected, actual: $actual)";
  }

  @override
  bool operator ==(covariant ConflictTypeError other) {
    return line == other.line &&
        keyName == other.keyName &&
        filepath == other.filepath &&
        expected == other.expected &&
        actual == other.actual;
  }

  @override
  int get hashCode => Object.hashAll([line, keyName, expected, actual, filepath]);
}

class RequiredKeyIsMissing extends EvaluationError {
  final String keyName;
  // TODO final List<String> scope;

  RequiredKeyIsMissing(this.keyName);

  @override
  String error() {
    return "Required key $keyName is missing";
  }

  @override
  String toString() {
    return "RequiredKeyIsMissing(keyName: $keyName)";
  }

  @override
  bool operator ==(covariant RequiredKeyIsMissing other) {
    return keyName == other.keyName;
  }

  @override
  int get hashCode => keyName.hashCode;
}

class _BlockEvaluation {
  final List<EvaluationError> errors;
  final MapValue result;

  _BlockEvaluation(this.result, this.errors);
}

class _BlockEvaluator {
  final Map<String, Value> _parentDeclarations;
  final Map<String, Value> _ownDeclarations;

  Map<String, Value> get allDeclarations => Map.from(_parentDeclarations)..addAll(_ownDeclarations);

  final Block block;

  _BlockEvaluator(this.block, [Map<String, Value>? declarations])
    : _parentDeclarations = declarations ?? {},
      _ownDeclarations = {};

  _BlockEvaluation eval() {
    final result = MapValue.empty();
    final errors = <EvaluationError>[];

    for (final line in block.lines) {
      switch (line) {
        case AssigmentLine():
          final key = line.identifer.value;
          final value = _resolveExpr(line.expr, allDeclarations);
          if (result.value.containsKey(key)) {
            final lineFirst = result.value[key]!.line;
            errors.add(DuplicatedKeyError(key, lineFirst, value.line, value.filepath));
          }
          result[key] = value;

        case DeclarationLine():
          _ownDeclarations[line.identifer.value] = _resolveExpr(line.expr, allDeclarations);

        case Block():
          final key = line.identifer.value;
          if (result.value.containsKey(key)) {
            final keyLineNum = result.value[key]!.line;
            final lineNum = line.token.pos!.start.lineNumber;
            final filepath = line.token.pos!.filepath;
            errors.add(BlockNameDefinedAsKeyError(key, keyLineNum, lineNum, filepath));
            break;
          }
          final evaluator = _BlockEvaluator(line, allDeclarations);
          final res = evaluator.eval();
          errors.addAll(res.errors);
          result[key] = res.result;
          _ownDeclarations[key] = MapValue(
            evaluator._ownDeclarations,
            line.token.pos!.start.lineNumber,
            line.token.pos!.filepath,
          );
      }
    }

    return _BlockEvaluation(result, errors);
  }
}

class EvaluationResult {
  final Map<String, dynamic> values;
  final List<EvaluationError> errors;
  const EvaluationResult(this.values, this.errors);
}

abstract final class Evaluator {
  static EvaluationResult eval(
    Program program, {
    Map<String, Value>? declarations,
    Schema? schema,
  }) {
    declarations ??= {};
    final block = program.toBlock();

    final blockEvaluator = _BlockEvaluator(block, declarations);
    final evaluation = blockEvaluator.eval();

    Map<String, dynamic> values = {};
    if (schema != null) {
      schema.apply(values, evaluation.result, evaluation.errors);
    } else {
      values = evaluation.result.toMap();
    }
    return EvaluationResult(values, evaluation.errors);
  }
}

Value _resolveExpr(Expression expr, Map<String, Value> declarations) {
  final line = expr.token.pos!.start.lineNumber;
  final filepath = expr.token.pos!.filepath;
  switch (expr) {
    case Identifier():
      // Should we fail here??
      return (declarations[expr.value] ?? StringValue("", -1, "")).copyWith(
        line: line,
        filepath: filepath,
      );
    case Number():
      return NumberValue(expr.value, line, filepath);
    case StringLiteral():
      return StringValue(expr.value, line, filepath);
    case InterpolableStringLiteral():
      return StringValue(_resolveInterpolableString(expr.value, declarations), line, filepath);
    case Boolean():
      return BooleanValue(expr.value, line, filepath);

    case PrefixExpression():
      return _resolvePrefixExpr(expr, declarations);
    case InfixExpression():
      return _infixPrefixExpr(expr, declarations);
  }
}

Value _resolvePrefixExpr(PrefixExpression prefexpr, Map<String, Value> declarations) {
  final rightValue = _resolveExpr(prefexpr.expr, declarations);
  switch (prefexpr.op) {
    case Operator.Minus:
      return switch (rightValue) {
        NumberValue v => NumberValue(-1 * v.value, v.line, v.filepath),
        _ => rightValue, // TODO is this an error??? could this be avoided in the parse phase?
      };
    case Operator.Bang:
      return switch (rightValue) {
        BooleanValue v => BooleanValue(!v.value, v.line, v.filepath),
        _ => rightValue, // TODO is this an error??? could this be avoided in the parse phase?
      };
    default:
      throw StateError("unreachable");
  }
}

Value _infixPrefixExpr(InfixExpression expr, Map<String, Value> declarations) {
  final left = _resolveExpr(expr.right, declarations);
  final rigth = _resolveExpr(expr.left, declarations);
  return switch (expr.op) {
    Operator.Mult => _multiply(left, rigth, expr.token),
    Operator.Div => _divide(left, rigth, expr.token),
    Operator.Plus => _add(left, rigth, expr.token),
    Operator.Minus => _sub(left, rigth, expr.token),
    Operator.Equals => _eq(left, rigth),
    Operator.NotEquals => _neq(left, rigth),
    Operator.GreatThan => _gt(left, rigth, expr.token),
    Operator.GreatOrEqThan => _gte(left, rigth, expr.token),
    Operator.LessThan => _lt(left, rigth, expr.token),
    Operator.LessOrEqThan => _lte(left, rigth, expr.token),
    Operator.Bang => throw StateError("unreachable"),
  };
}

Value _multiply(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(
      left,
      Operator.Mult,
      right,
      token.pos!.start.lineNumber,
      token.pos!.filepath,
    );
  }
  return NumberValue(left.value * right.value, left.line, left.filepath);
}

Value _divide(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(
      left,
      Operator.Div,
      right,
      token.pos!.start.lineNumber,
      token.pos!.filepath,
    );
  }
  return NumberValue(left.value / right.value, left.line, left.filepath);
}

Value _add(Value left, Value right, Token token) {
  if (left is NumberValue && right is NumberValue) {
    return NumberValue(left.value + right.value, left.line, left.filepath);
  }
  if (left is StringValue && right is StringValue) {
    return StringValue(left.value + right.value, left.line, left.filepath);
  }
  throw InfixOperationError(
    left,
    Operator.Plus,
    right,
    token.pos!.start.lineNumber,
    token.pos!.filepath,
  );
}

Value _sub(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(
      left,
      Operator.Minus,
      right,
      token.pos!.start.lineNumber,
      token.pos!.filepath,
    );
  }
  return NumberValue(left.value - right.value, left.line, left.filepath);
}

Value _eq(Value left, Value right) {
  return BooleanValue(left.value == right.value, left.line, left.filepath);
}

Value _neq(Value left, Value right) {
  return BooleanValue(left.value != right.value, left.line, left.filepath);
}

Value _gt(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(
      left,
      Operator.Minus,
      right,
      token.pos!.start.lineNumber,
      token.pos!.filepath,
    );
  }
  return BooleanValue(left.value > right.value, left.line, left.filepath);
}

Value _gte(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(
      left,
      Operator.Minus,
      right,
      token.pos!.start.lineNumber,
      token.pos!.filepath,
    );
  }
  return BooleanValue(left.value >= right.value, left.line, left.filepath);
}

Value _lt(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(
      left,
      Operator.Minus,
      right,
      token.pos!.start.lineNumber,
      token.pos!.filepath,
    );
  }
  return BooleanValue(left.value < right.value, left.line, left.filepath);
}

Value _lte(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(
      left,
      Operator.Minus,
      right,
      token.pos!.start.lineNumber,
      token.pos!.filepath,
    );
  }
  return BooleanValue(left.value <= right.value, left.line, left.filepath);
}

String _resolveInterpolableString(String str, Map<String, Value> declarations) {
  StringBuffer resp = StringBuffer();
  final codeUnits = str.codeUnits;
  for (int i = 0; i < codeUnits.length; i++) {
    final char = codeUnits[i];
    if (char == "\$".codeUnitAt(0)) {
      i += 1;
      final start = i;
      while (i < codeUnits.length && (_isDigit(codeUnits[i]) || _isLetterOr_(codeUnits[i]))) {
        i += 1;
      }
      final end = i;
      final name = str.substring(start, end);

      if (name.isEmpty) {
        resp.writeCharCode(codeUnits[i]);
        continue;
      }
      assert(name[name.length - 1] != " ");

      final value = declarations[name];
      if (value != null) {
        resp.write(switch (value) {
          NumberValue() => value.value.toString(),
          StringValue() => value.value,
          BooleanValue() => value.value.toString(),
          MapValue() => throw UnimplementedError(),
        });
      }
      if (i < codeUnits.length) {
        resp.writeCharCode(codeUnits[i]);
      }
    } else {
      resp.writeCharCode(char);
    }
  }
  return resp.toString();
}

bool _isDigit(int char) {
  return char >= 48 && char <= 57;
}

bool _isLetterOr_(int char) {
  return char == 95 || (char >= 65 && char <= 90) || (char >= 97 && char <= 122);
}

abstract class ValidationError extends EvaluationError {
  late Value original;
  int get line => original.line;
  String get filepath => original.filepath;

  ValidationError();
}
