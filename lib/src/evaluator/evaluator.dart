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

class MapValue extends Value<Map<String, Value>> {
  const MapValue(super.value);

  Map<String, Object> toMap() {
    return value.map(
      (key, value) => MapEntry(key, switch (value) {
        MapValue() => value.toMap(),
        _ => value.value,
      }),
    );
  }
}

class Evaluator {
  final Program program;
  List<String> _currentScope;

  final Map<String, Value> declarations = {};

  Evaluator(this.program) : _currentScope = [];

  void _assign(MapValue response, String key, Value value) {
    MapValue scopeToSet = response;
    for (final scope in _currentScope) {
      // if the key does not exists than we create the map
      if (!response.value.containsKey(scope)) {
        response.value[scope] = MapValue({});
      } // if the value is not a MapValue then we rewrite as a MapValue
      else if (response.value[scope] is! MapValue) {
        response.value[scope] = MapValue({});
      }
      scopeToSet = response.value[scope] as MapValue;
    }
    scopeToSet.value[key] = value;
  }

  MapValue eval() {
    final response = MapValue({});

    for (final line in program.lines) {
      switch (line) {
        case AssigmentLine():
          final value = _resolveExpr(line.expr);
          _assign(response, line.identifer.value, value);
          declarations[line.identifer.value] = value;
        case DeclarationLine():
          declarations[line.identifer.value] = _resolveExpr(line.expr);
        case TableHeaderLine():
          _currentScope = [line.identifer.value];
      }
    }

    return response;
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
