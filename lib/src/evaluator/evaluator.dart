import 'package:config/src/ast/ast.dart';
import 'package:config/src/compare_utils.dart';
import 'package:config/src/schema/schema.dart';
import 'package:config/src/tokens/tokens.dart';
import 'package:config/src/types/duration/duration.dart';

sealed class Value<T extends Object> {
  final T value;
  final Position position;
  const Value(this.value, this.position);

  Object toValue();

  Value copyWith({Position? position, T? value, String? filepath}) {
    return switch (this) {
      NumberDoubleValue v => NumberDoubleValue(value as double? ?? v.value, position ?? v.position),
      NumberIntegerValue v => NumberIntegerValue(value as int? ?? v.value, position ?? v.position),
      DurationValue v => DurationValue(value as Duration? ?? v.value, position ?? v.position),
      StringValue v => StringValue(value as String? ?? v.value, position ?? v.position),
      BooleanValue v => BooleanValue(value as bool? ?? v.value, position ?? v.position),
      BlockValue v => BlockValue(value as BlockValueData? ?? v.value, position ?? v.position),
      MapValue v => MapValue(value as Map<Value, Value>? ?? v.value, position ?? v.position),
      ListValue v => ListValue(value as List<Value>? ?? v.value, position ?? v.position),
    };
  }

  @override
  String toString() {
    return "$value";
  }
}

sealed class NumberValue<T extends num> extends Value<T> {
  const NumberValue(super.value, super.position);
}

class NumberDoubleValue extends NumberValue<double> {
  const NumberDoubleValue(super.value, super.position);

  @override
  double toValue() => super.value;
}

class NumberIntegerValue extends NumberValue<int> {
  const NumberIntegerValue(super.value, super.position);

  @override
  int toValue() => super.value;
}

class DurationValue extends Value<Duration> {
  const DurationValue(super.value, super.position);

  @override
  Duration toValue() => super.value;
}

class StringValue extends Value<String> {
  const StringValue(super.value, super.position);

  @override
  String toValue() => super.value;
}

class BooleanValue extends Value<bool> {
  const BooleanValue(super.value, super.position);

  @override
  bool toValue() => super.value;
}

class ListValue extends Value<List<Value>> {
  // final List<Value> _values;
  const ListValue(super.value, super.position);

  List<Object> toList() {
    return value.map((e) => e.toValue()).toList();
  }

  @override
  List<Object> toValue() => toList();
}

class MapValue extends Value<Map<Value, Value>> {
  const MapValue(super.value, super.position);

  Map<Object, Object> toMap() {
    return value.map((key, value) => MapEntry(key.toValue(), value.toValue()));
  }

  @override
  Map<Object, Object> toValue() => toMap();
}

class BlockData {
  final Map<Identifier, Object?> fields;
  final List<(Identifier, BlockData)> blocks;

  /// This is a list of all keys that where setted with defaults values
  final Set<String> defaultKeys;

  BlockData(this.fields, this.blocks, [Set<String>? defaultSettedKeys])
    : defaultKeys = defaultSettedKeys ?? {};

  const BlockData.constEmpty() : fields = const {}, blocks = const [], defaultKeys = const {};

  factory BlockData.empty() => BlockData({}, [], {});

  BlockData merge(BlockData other) {
    final response = BlockData.empty();

    // merge fields
    {
      for (final field in fields.entries) {
        if (!defaultKeys.contains(field.key.value)) {
          response.fields[field.key] = field.value;
        }
      }

      for (final field in other.fields.entries) {
        if (!response.fields.containsKey(field.key)) {
          response.fields[field.key] = field.value;
        }
      }
    }

    // merge blocks
    {
      for (final block in blocks) {
        if (!defaultKeys.contains(block.$1)) {
          response.blocks.add(block);
        }
      }

      for (final block in other.blocks) {
        // TODO: (Performance) this is very slow as its a search on a not sorted list inside a loop
        // this can get out of control very quickly
        if (!response.blockContainsKey(block.$1)) {
          response.blocks.add(block);
        }
      }
    }

    return response;
  }

  bool blockContainsKey(Identifier key) {
    return blocks.any((a) => a.$1 == key);
  }

  bool blockContainsKeyString(String key) {
    return blocks.any((a) => a.$1.value == key);
  }

  BlockData? firstBlockWith(String key) {
    for (final block in blocks) {
      if (block.$1.value == key) {
        return block.$2;
      }
    }
    return null;
  }

  Iterable<BlockData> blocksWith(String key) sync* {
    for (final block in blocks) {
      if (block.$1 == key) {
        yield block.$2;
      }
    }
  }

  Iterable<Identifier> keys() sync* {
    for (final key in fields.keys) {
      yield key;
    }
    for (final entry in blocks) {
      yield entry.$1;
    }
  }

  (Map<Identifier, Object?>, List<(Identifier, Object)>) toData() {
    return (fields, blocks.map((e) => (e.$1, e.$2.toData())).toList());
  }

  @override
  String toString() {
    return "${toData()}";
  }

  @override
  bool operator ==(covariant BlockData other) {
    return mapEquals(fields, other.fields) && listEquals(blocks, other.blocks);
  }
}

class BlockValueData {
  final Map<Identifier, Value> fields;
  final List<(Identifier, BlockValue)> blocks;

  const BlockValueData(this.fields, this.blocks);

  factory BlockValueData.empty() => BlockValueData({}, []);

  bool containsKey(Identifier key) {
    if (fields.containsKey(key)) {
      return true;
    }
    return blockContainsKey(key);
  }

  bool blockContainsKey(Identifier key) {
    return blocks.any((a) => a.$1 == key);
  }

  Iterable<({Identifier key, Value value, bool isBlock})> entries() sync* {
    for (final key in fields.keys) {
      yield (key: key, value: fields[key]!, isBlock: false);
    }
    for (final entry in blocks) {
      yield (key: entry.$1, value: entry.$2, isBlock: true);
    }
  }

  Iterable<Identifier> keys() sync* {
    for (final key in fields.keys) {
      yield key;
    }
    for (final entry in blocks) {
      yield entry.$1;
    }
  }

  Value? operator [](dynamic key) {
    if (key is String) {
      key = Identifier(key);
    }
    Value? result = fields[key];
    if (result != null) {
      return result;
    }
    // TODO maybe this should  return the last block where key is equal to the the block name
    // first we need to figure it out the access rules
    final idx = blocks.indexWhere((e) => e.$1 == key);
    if (idx != -1) {
      return blocks[idx].$2;
    }
    return null;
  }

  Identifier? lookupKey(Identifier key) {
    if (fields.containsKey(key)) {
      return fields.keys.firstWhere((k) => k.value == key.value);
    }
    final idx = blocks.indexWhere((e) => e.$1 == key);
    if (idx != -1) {
      return blocks[idx].$1;
    }
    return null;
  }

  bool get isEmpty => fields.isEmpty && blocks.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

class BlockValue extends Value<BlockValueData> {
  const BlockValue(super.value, super.position);

  factory BlockValue.empty([int line = -1, String filepath = ""]) =>
      BlockValue(BlockValueData.empty(), Position.start(filepath));

  @override
  BlockData toValue() {
    final response = BlockData.empty();
    for (final entry in super.value.fields.entries) {
      response.fields[entry.key] = entry.value.toValue();
    }
    for (final block in super.value.blocks) {
      response.blocks.add((block.$1, block.$2.toValue()));
    }
    return response;
  }

  bool get isEmpty => value.isEmpty;
}

sealed class EvaluationError {
  const EvaluationError();
  String error();

  @override
  String toString() => error();

  /// Human readable help to show to the user
  /// so they can know what to do
  String help();
}

class DuplicatedKeyError extends EvaluationError {
  final Position first;
  final Position second;
  final String keyName;

  const DuplicatedKeyError(this.keyName, this.first, this.second);

  @override
  String error() {
    return "Duplicated key $keyName";
  }

  @override
  String toString() {
    return "DuplicatedKeyError(first: $first, second: $second, keyName: $keyName)";
  }

  @override
  String help() {
    return "Remove one of the duplicate entries for '$keyName'.";
  }

  @override
  bool operator ==(covariant DuplicatedKeyError other) {
    return first == other.first && second == other.second && keyName == other.keyName;
  }

  @override
  int get hashCode => Object.hashAll([keyName, first, second]);
}

class KeyNotInSchemaError extends EvaluationError {
  final Position position;
  final String keyName;

  KeyNotInSchemaError(this.keyName, this.position);

  @override
  String error() {
    return "Provided schema does not have key $keyName";
  }

  @override
  String toString() {
    return "KeyNotInSchemaError($keyName $position)";
  }

  @override
  String help() {
    return "The key '$keyName' is not defined in the schema. "
           "Remove this key";
  }

  @override
  bool operator ==(covariant KeyNotInSchemaError other) {
    return position == other.position && keyName == other.keyName;
  }

  @override
  int get hashCode => Object.hashAll([position, keyName]);
}

class InfixOperationError extends EvaluationError {
  final Position position;
  final Value left;
  final Value rigth;
  final Operator op;

  const InfixOperationError(this.left, this.op, this.rigth, this.position);

  @override
  String error() {
    return "Operation not supported";
  }

  @override
  String help() {
    return "The operation '$op' between values of type '${left.runtimeType}' and '${rigth.runtimeType}' "
           "is not supported. Check that both operands are of compatible types "
           "for this operation";
  }
}

class ConflictTypeError extends EvaluationError {
  final Position position;
  final String keyName;
  final String typeExpected;
  final String typeActual;

  ConflictTypeError(this.keyName, this.position, this.typeExpected, this.typeActual);

  @override
  String error() {
    return "Type Error $keyName expected type is $typeExpected but found $typeActual";
  }

  @override
  String toString() {
    return "ConflictTypeError($keyName $typeExpected $typeActual $position)";
  }

  @override
  String help() {
    return "For key '$keyName' expected type '$typeExpected' but found '$typeActual'. "
           "Please provide a value of the correct type.";
  }

  @override
  bool operator ==(covariant ConflictTypeError other) {
    return position == other.position &&
        keyName == other.keyName &&
        typeExpected == other.typeExpected &&
        typeActual == other.typeActual;
  }

  @override
  int get hashCode => Object.hashAll([position, keyName, typeExpected, typeActual]);
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
  String help() {
    return "The required key '$keyName' must be provided. "
           "Please add this key with an appropriate value.";
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
  final BlockValue result;

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
    final result = BlockValue.empty();
    final errors = <EvaluationError>[];

    for (final line in block.lines) {
      try {
        switch (line) {
          case AssigmentLine():
            final key = line.identifer;
            final value = _resolveExpr(line.expr, allDeclarations);
            if (result.value.containsKey(key)) {
              // TODO: reason about only using the first element
              final first = result.value.lookupKey(key)!;
              errors.add(DuplicatedKeyError(key.value, first.token.pos!, line.identifer.token.pos!));
            }
            result.value.fields[key] = value;
            _ownDeclarations[key.value] = value;

          case DeclarationLine():
            _ownDeclarations[line.identifer.value] = _resolveExpr(line.expr, allDeclarations);

          case Block():
            final key = line.identifer;
            final position = line.identifer.token.pos!;

            if (result.value.fields.containsKey(key)) {
              final lineFirst = result.value[key]!.position;
              errors.add(DuplicatedKeyError(key.value, lineFirst, position));
              break;
            }

            final evaluator = _BlockEvaluator(line, allDeclarations);
            final res = evaluator.eval();
            errors.addAll(res.errors);
            final resVal = res.result.copyWith(position: line.token.pos!) as BlockValue;
            result.value.blocks.add((key, resVal));
            // using the last TableValue as the key definition in declarations
            // there are other stuff we can do.. like merging
            _ownDeclarations[key.value] = resVal;
        }
      } on EvaluationError catch (e) {
        errors.add(e);
      }
    }

    return _BlockEvaluation(result, errors);
  }
}

abstract final class Evaluator {
  static (BlockData values, List<EvaluationError> errors) eval(
    Program program, {
    Map<String, Value>? declarations,
    Schema? schema,
  }) {
    declarations ??= {};
    final block = program.toBlock();

    final blockEvaluator = _BlockEvaluator(block, declarations);
    final evaluation = blockEvaluator.eval();

    BlockData values = BlockData.empty();
    if (schema != null) {
      schema.apply("", values, evaluation.result, evaluation.errors);
    } else {
      values = evaluation.result.toValue();
    }
    return (values, evaluation.errors);
  }
}

Value _resolveExpr(Expression expr, Map<String, Value> declarations) {
  final pos = expr.token.pos!;
  switch (expr) {
    case Identifier():
      // TODO fail here and handle fail upper in the chain
      return (declarations[expr.value] ?? StringValue("", Position.start(""))).copyWith(
        position: pos,
      );
    case NumberDouble():
      return NumberDoubleValue(expr.value, pos);
    case StringLiteral():
      return StringValue(expr.value, pos);
    case InterpolableStringLiteral():
      return StringValue(_resolveInterpolableString(expr.value, declarations), pos);
    case Boolean():
      return BooleanValue(expr.value, pos);
    case NumberInteger():
      return NumberIntegerValue(expr.value, pos);
    case DurationExpression():
      return DurationValue(expr.value, pos);

    case PrefixExpression():
      return _resolvePrefixExpr(expr, declarations);
    case InfixExpression():
      return _infixPrefixExpr(expr, declarations);

    case ArrayExpression():
      return _resolveArray(expr, declarations);
    case MapExpression():
      return _resolveMap(expr, declarations);
  }
}

MapValue _resolveMap(MapExpression map, Map<String, Value> declarations) {
  final resp = <Value<Object>, Value<Object>>{};
  for (final entry in map.list) {
    final key = _resolveExpr(entry.key, declarations);
    final value = _resolveExpr(entry.value, declarations);
    resp[key] = value;
  }
  return MapValue(resp, map.token.pos!);
}

ListValue _resolveArray(ArrayExpression array, Map<String, Value> declarations) {
  final list = <Value>[];
  for (final expr in array.list) {
    list.add(_resolveExpr(expr, declarations));
  }
  return ListValue(list, array.token.pos!);
}

Value _resolvePrefixExpr(PrefixExpression prefexpr, Map<String, Value> declarations) {
  final rightValue = _resolveExpr(prefexpr.expr, declarations);
  switch (prefexpr.op) {
    case Operator.Minus:
      return switch (rightValue) {
        NumberDoubleValue v => NumberDoubleValue(-1 * v.value, v.position),
        NumberIntegerValue v => NumberIntegerValue(-1 * v.value, v.position),
        _ => rightValue, // TODO is this an error??? could this be avoided in the parse phase?
      };
    case Operator.Bang:
      return switch (rightValue) {
        BooleanValue v => BooleanValue(!v.value, v.position),
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
    throw InfixOperationError(left, Operator.Mult, right, token.pos!);
  }
  return switch (left) {
    NumberDoubleValue() => switch (right) {
      NumberDoubleValue() => NumberDoubleValue(left.value * right.value, left.position),
      NumberIntegerValue() => NumberDoubleValue(left.value * right.value, left.position),
    },
    NumberIntegerValue() => switch (right) {
      NumberDoubleValue() => NumberDoubleValue(left.value * right.value, left.position),
      NumberIntegerValue() => NumberIntegerValue(left.value * right.value, left.position),
    },
  };
}

Value _divide(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(left, Operator.Div, right, token.pos!);
  }
  return NumberDoubleValue(left.value / right.value, left.position);
}

Value _add(Value left, Value right, Token token) {
  if (left is NumberValue && right is NumberValue) {
    return switch (left) {
      NumberDoubleValue() => switch (right) {
        NumberDoubleValue() => NumberDoubleValue(left.value + right.value, left.position),
        NumberIntegerValue() => NumberDoubleValue(left.value + right.value, left.position),
      },
      NumberIntegerValue() => switch (right) {
        NumberDoubleValue() => NumberDoubleValue(left.value + right.value, left.position),
        NumberIntegerValue() => NumberIntegerValue(left.value + right.value, left.position),
      },
    };
  }
  if (left is StringValue && right is StringValue) {
    return StringValue(left.value + right.value, left.position);
  }
  throw InfixOperationError(left, Operator.Plus, right, token.pos!);
}

Value _sub(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(left, Operator.Minus, right, token.pos!);
  }
  return switch (left) {
    NumberDoubleValue() => switch (right) {
      NumberDoubleValue() => NumberDoubleValue(left.value - right.value, left.position),
      NumberIntegerValue() => NumberDoubleValue(left.value - right.value, left.position),
    },
    NumberIntegerValue() => switch (right) {
      NumberDoubleValue() => NumberDoubleValue(left.value - right.value, left.position),
      NumberIntegerValue() => NumberIntegerValue(left.value - right.value, left.position),
    },
  };
}

Value _eq(Value left, Value right) {
  return BooleanValue(left.value == right.value, left.position);
}

Value _neq(Value left, Value right) {
  return BooleanValue(left.value != right.value, left.position);
}

Value _gt(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(left, Operator.Minus, right, token.pos!);
  }
  return BooleanValue(left.value > right.value, left.position);
}

Value _gte(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(left, Operator.Minus, right, token.pos!);
  }
  return BooleanValue(left.value >= right.value, left.position);
}

Value _lt(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(left, Operator.Minus, right, token.pos!);
  }
  return BooleanValue(left.value < right.value, left.position);
}

Value _lte(Value left, Value right, Token token) {
  if (left is! NumberValue || right is! NumberValue) {
    throw InfixOperationError(left, Operator.Minus, right, token.pos!);
  }
  return BooleanValue(left.value <= right.value, left.position);
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
          NumberDoubleValue() => value.value.toString(),
          NumberIntegerValue() => value.value.toString(),
          DurationValue() => value.value.toString(),
          StringValue() => value.value,
          BooleanValue() => value.value.toString(),
          ListValue() => "[${value.value.join(", ")}]",
          MapValue() =>
            "{${value.value.entries.map((e) => '${e.key.value}: ${e.value.value}').join(', ')}}",
          // TODO: Handle this cases.
          BlockValue() => throw UnimplementedError(),
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

  ValidationError();
}

abstract class CustomEvaluationError extends EvaluationError {
  const CustomEvaluationError();
}
