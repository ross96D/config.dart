import 'package:config/src/ast/ast.dart';

sealed class Value<T extends Object> {
  final T value;
  const Value(this.value);
}

class NumberValue extends Value<double> {
  const NumberValue(super.value);
}

class StringValue extends Value<String> {
  const StringValue(super.value);
}

class BooleanValue extends Value<bool> {
  const BooleanValue(super.value);
}

class MapValue extends Value<Map<String, Value>> {
  const MapValue(super.value);

  factory MapValue.empty() => MapValue({});

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

sealed class EvaluationErrors {}

class DuplicatedKeyError extends EvaluationErrors {}

class TableNameDefinedAsKeyError extends EvaluationErrors {}

class KeyNotInSchemaError extends EvaluationErrors {}

class ConflictTypeError extends EvaluationErrors {}

class RequiredKeyIsMissing extends EvaluationErrors {}

class Evaluator {
  final Program program;
  final Schema? schema;
  List<String> _currentScope;

  bool _programEvaluated = false;
  late MapValue result;
  late List<EvaluationErrors> errors;

  final Map<String, Value> declarations = {};

  Evaluator(this.program, [this.schema]) : _currentScope = [];

  bool _assign(String key, Value value) {
    MapValue scopeToSet = result;

    for (final scope in _currentScope) {
      if (result.value.containsKey(scope)) {
        if (result.value[scope] is! MapValue) {
          errors.add(TableNameDefinedAsKeyError());
          return false;
        }
      } else {
        result.value[scope] = MapValue.empty();
      }

      scopeToSet = result.value[scope] as MapValue;
    }
    if (scopeToSet.value.containsKey(key)) {
      errors.add(DuplicatedKeyError());
      return false;
    }
    if (schema != null) {
      final error = schema!._validate(key, _currentScope, value);
      switch (error) {
        case _MissingKey():
          errors.add(KeyNotInSchemaError());
        case _TypeError():
          errors.add(ConflictTypeError());
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
    switch (expr) {
      case Identifier():
        // Should we fail here??
        return declarations[expr.value] ?? StringValue("");
      case Number():
        return NumberValue(expr.value);
      case StringLiteral():
        return StringValue(expr.value);
      case InterpolableStringLiteral():
        return StringValue(_resolveInterpolableString(expr.value));
      case Boolean():
        return BooleanValue(expr.value);
    }
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

abstract class ValidationError extends EvaluationErrors {}

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

  void _defaultAndRequired(MapValue result, List<EvaluationErrors> errors) {
    for (final entry in _fields.entries) {
      if (entry.value.defaultTo == null) {
        if (result[entry.key] == null) {
          errors.add(RequiredKeyIsMissing());
        }
        continue;
      }

      if (result[entry.key] == null) {
        switch (entry.value.type) {
          case const (double):
            result[entry.key] = NumberValue(entry.value.defaultTo as double);

          case const (String):
            result[entry.key] = StringValue(entry.value.defaultTo as String);

          case const (bool):
            result[entry.key] = BooleanValue(entry.value.defaultTo as bool);

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
  const _TypeError();
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
          return _TypeError();
        }
        final error = field.validator(value.value);
        if (error != null) {
          return _ValidationError(error);
        }

      case StringValue():
        if (field.type != String) {
          return _TypeError();
        }
        final error = field.validator(value.value);
        if (error != null) {
          return _ValidationError(error);
        }
      case BooleanValue():
        if (field.type != bool) {
          return _TypeError();
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
