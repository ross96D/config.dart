import 'package:config/src/ast/ast.dart';
import 'package:config/src/tokens/tokens.dart';

class EvaluationResult {
  final MapValue values;
  final List<EvaluationError> errors;
  const EvaluationResult(this.values, this.errors);
}

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

class TableNameDefinedAsKeyError extends EvaluationError {
  // TODO final Position tablePosition;
  final int line;
  final String filepath;
  final String tableName;

  TableNameDefinedAsKeyError(this.tableName, this.line, this.filepath);

  @override
  String error() {
    return """
A key with the same name as the table is already defined, table $tableName could not be created
$filepath:${line + 1}:0
""";
  }

  @override
  String toString() {
    return "TableNameDefinedAsKeyError(tableName: $tableName, line: $line, filepath: $filepath)";
  }

  @override
  bool operator ==(covariant TableNameDefinedAsKeyError other) {
    return line == other.line && tableName == other.tableName && filepath == filepath;
  }

  @override
  int get hashCode => Object.hashAll([line, tableName, filepath]);
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

class Evaluator {
  final Program program;
  final Schema? schema;
  List<String> _currentScope;

  bool _programEvaluated = false;
  late MapValue result;
  late List<EvaluationError> errors;

  final Map<String, Value> declarations = {};

  Evaluator(this.program, [this.schema]) : _currentScope = [];

  bool _assign(String key, Value value) {
    MapValue scopeToSet = result;

    for (final scope in _currentScope) {
      if (result.value.containsKey(scope)) {
        if (result.value[scope] is! MapValue) {
          errors.add(TableNameDefinedAsKeyError(scope, result.value[scope]!.line, value.filepath));
          return false;
        }
      } else {
        // TODO this should not be created here, instead should be created when
        // the tableHeader is found. In here we have no way to get the position
        //
        // If we do as above then having !result.value.containsKey(scope) is an invalid state
        result.value[scope] = MapValue.empty();
      }

      scopeToSet = result.value[scope] as MapValue;
    }
    if (scopeToSet.value.containsKey(key)) {
      errors.add(DuplicatedKeyError(key, scopeToSet.value[key]!.line, value.line, value.filepath));
      return false;
    }
    if (schema != null) {
      final error = schema!._validate(key, _currentScope, value);
      switch (error) {
        case _MissingKey():
          errors.add(KeyNotInSchemaError(key, value.line, value.filepath));
        case _TypeError v:
          errors.add(ConflictTypeError(key, value.line, value.filepath, v.expected, v.actual));
          return false;
        case _ValidationError():
          errors.add(error.error);
          return false;
        case null:
      }
    }
    scopeToSet.value[key] = value;
    return true;
  }

  MapValue eval() {
    if (_programEvaluated) {
      return result;
    } else {
      _programEvaluated = true;
    }
    result = MapValue.empty();
    errors = [];

    for (final line in program.lines) {
      switch (line) {
        case AssigmentLine():
          final value = _resolveExpr(line.expr);
          // if assign was succesfully performed add value to declarations
          if (_assign(line.identifer.value, value)) {
            declarations[line.identifer.value] = value;
          }
        case DeclarationLine():
          declarations[line.identifer.value] = _resolveExpr(line.expr);
        case TableHeaderLine():
          _currentScope = [line.identifer.value];
      }
    }

    // assign defautls
    if (schema != null) {
      schema!._defaultAndRequired(result, errors);
    }

    return result;
  }

  Value _resolveExpr(Expression expr) {
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
        return StringValue(_resolveInterpolableString(expr.value), line, filepath);
      case Boolean():
        return BooleanValue(expr.value, line, filepath);

      case PrefixExpression():
        return _resolvePrefixExpr(expr);
      case InfixExpression():
        return _infixPrefixExpr(expr);
    }
  }

  Value _resolvePrefixExpr(PrefixExpression prefexpr) {
    final rightValue = _resolveExpr(prefexpr.expr);
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

  Value _infixPrefixExpr(InfixExpression expr) {
    final left = _resolveExpr(expr.right);
    final rigth = _resolveExpr(expr.left);
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

  String _resolveInterpolableString(String str) {
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
}

bool _isDigit(int char) {
  return char >= 48 && char <= 57;
}

bool _isLetterOr_(int char) {
  return char == 95 || (char >= 65 && char <= 90) || (char >= 97 && char <= 122);
}

typedef ValidatorFn<T extends Object> = ValidationError? Function(T value);

abstract class ValidationError extends EvaluationError {
  const ValidationError();
}

class _Item<T extends Object> {
  final String name;
  final Type type;
  final ValidatorFn<T>? _validator;
  final T? defaultTo;

  const _Item(this.name, this._validator, this.defaultTo) : type = T;

  ValidationError? validator(Object value) {
    if (_validator == null) {
      return null;
    }
    return _validator(value as T);
  }
}

class TableSchema {
  final Map<String, _Item> _fields;
  final Map<String, TableSchema> _tables;

  TableSchema() : _fields = {}, _tables = {};

  void field<T extends Object>(String name, {ValidatorFn<T>? validator, T? defaultsTo}) {
    _fields[name] = _Item<T>(name, validator, defaultsTo);
  }

  void table(String tableName, TableSchema table) {
    _tables[tableName] = table;
  }

  void _defaultAndRequired(MapValue result, List<EvaluationError> errors) {
    for (final entry in _fields.entries) {
      if (entry.value.defaultTo == null) {
        if (result[entry.key] == null) {
          errors.add(RequiredKeyIsMissing(entry.key));
        }
        continue;
      }

      if (result[entry.key] == null) {
        switch (entry.value.type) {
          case const (double):
            result[entry.key] = NumberValue(entry.value.defaultTo as double, -1, "");

          case const (String):
            result[entry.key] = StringValue(entry.value.defaultTo as String, -1, "");

          case const (bool):
            result[entry.key] = BooleanValue(entry.value.defaultTo as bool, -1, "");

          default:
            throw StateError("unreachable");
        }
      }
    }

    for (final entry in _tables.entries) {
      if (result[entry.key] == null) {
        result[entry.key] = MapValue.empty();
      } else if (result[entry.key] is! MapValue) {
        throw StateError(
          "Unreachable key is not MapValue when is declared as Table in Schema. "
          "Key: ${entry.key} Value: ${result[entry.key]}",
        );
      }
      entry.value._defaultAndRequired(result[entry.key] as MapValue, errors);
    }
  }
}

sealed class _SchemaValidationResult {
  const _SchemaValidationResult();
}

class _MissingKey extends _SchemaValidationResult {
  const _MissingKey();
}

class _TypeError extends _SchemaValidationResult {
  final Type expected;
  final Type actual;

  const _TypeError(this.actual, this.expected);
}

class _ValidationError extends _SchemaValidationResult {
  final ValidationError error;
  const _ValidationError(this.error);
}

class Schema extends TableSchema {
  _Item? _getField(String key, List<String> tables) {
    Map<String, TableSchema> tablesMap = _tables;
    Map<String, _Item<Object>> fieldsMap = _fields;
    for (final tableName in tables) {
      if (!tablesMap.containsKey(tableName)) {
        return null;
      }
      tablesMap = tablesMap[tableName]!._tables;
      fieldsMap = tablesMap[tableName]!._fields;
    }
    return fieldsMap[key];
  }

  _SchemaValidationResult? _validate(String key, List<String> tables, Value value) {
    final field = _getField(key, tables);
    if (field == null) {
      return _MissingKey();
    }
    switch (value) {
      case NumberValue():
        if (field.type != double) {
          return _TypeError(double, field.type);
        }
        final error = field.validator(value.value);
        if (error != null) {
          return _ValidationError(error);
        }

      case StringValue():
        if (field.type != String) {
          return _TypeError(String, field.type);
        }
        final error = field.validator(value.value);
        if (error != null) {
          return _ValidationError(error);
        }
      case BooleanValue():
        if (field.type != bool) {
          return _TypeError(bool, field.type);
        }
        final error = field.validator(value.value);
        if (error != null) {
          return _ValidationError(error);
        }
      case MapValue():
        throw UnimplementedError("handling map type as key value is not supported");
    }

    return null;
  }
}
