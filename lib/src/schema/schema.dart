// ignore_for_file: type_literal_in_constant_pattern

import 'package:config/config.dart';
import 'package:config/src/ast/ast.dart';
import 'package:config/src/types/duration/duration.dart';
import 'dart:core' as core;
import 'dart:core';

typedef MapperFn<Rec extends Object, Res extends Object> = ValidatorResult<Res> Function(Rec value);

sealed class _TypeRec {
  const _TypeRec();

  factory _TypeRec.fromType(Type t) {
    return switch (t) {
      String => const _String(),
      int => const _Int(),
      double => const _Double(),
      Duration => const _Duration(),
      Type() => throw UnimplementedError(),
    };
  }

  Type get innerType;

  @override
  String toString() {
    return switch (this) {
      _Any _ => "Object",
      _String _ => "String",
      _Int _ => "int",
      _Double _ => "double",
      _Boolean _ => "bool",
      _Duration _ => "Duration",
      _List v => "List<${v.inner}>",
      _Map v => "Map<${v.key}, ${v.value}>",
    };
  }
}

final class _Any extends _TypeRec {
  const _Any();

  @override
  Type get innerType => Object;
}

final class _String extends _TypeRec {
  const _String();

  @override
  Type get innerType => String;
}

final class _Int extends _TypeRec {
  const _Int();

  @override
  Type get innerType => int;
}

final class _Double extends _TypeRec {
  const _Double();

  @override
  Type get innerType => double;
}

final class _Boolean extends _TypeRec {
  const _Boolean();

  @override
  Type get innerType => bool;
}

final class _Duration extends _TypeRec {
  const _Duration();

  @override
  Type get innerType => Duration;
}

final class _List extends _TypeRec {
  final _TypeRec inner;
  const _List(this.inner);

  @override
  Type get innerType => List;
}

final class _Map extends _TypeRec {
  final _TypeRec key;
  final _TypeRec value;

  const _Map(this.key, this.value);
  // _Map.from(Type keyRec, Type valueRec)
  //   : key = _TypeRec.fromType(keyRec),
  //     value = _TypeRec.fromType(valueRec);

  @override
  Type get innerType => Map;
}

sealed class Field<Rec extends Object, Res extends Object> {
  // ignore: unused_field TODO maybe this field could be deleted
  final Type _typeRes;

  Res? get defaultTo;
  bool get nullable;

  const Field() : _typeRes = Res;

  _TypeRec get _typeRec;

  ValidatorResult<Res> validator(Rec value);
}

abstract class _SimpleField<Rec extends Object, Res extends Object> extends Field<Rec, Res> {
  @override
  final Res? defaultTo;

  @override
  final bool nullable;

  final MapperFn<Rec, Res>? _validator;

  const _SimpleField({this.defaultTo, this.nullable = false, MapperFn<Rec, Res>? validator})
    : assert(
        Rec == Res || validator != null,
        'If the Res object type is different than the Rec type, a validator must be provided',
      ),
      _validator = validator;

  @override
  ValidatorResult<Res> validator(Rec value) {
    if (_validator == null) return ValidatorSuccess();
    return _validator(value);
  }
}

/// If base class is not flexible enough you can implement this class
abstract class StringFieldAbstract<Res extends Object> extends Field<String, Res> {
  const StringFieldAbstract();
  @override
  _TypeRec get _typeRec => const _String();
}

class StringFieldBase<Res extends Object> extends _SimpleField<String, Res> {
  const StringFieldBase({super.defaultTo, super.nullable, super.validator});
  @override
  _TypeRec get _typeRec => const _String();
}

typedef StringField = StringFieldBase<String>;

/// If base class is not flexible enough you can implement this class
abstract class DurationFieldAbstract<Res extends Object> extends Field<Duration, Res> {
  const DurationFieldAbstract();
  @override
  _TypeRec get _typeRec => const _Duration();
}

class DurationFieldBase<Res extends Object> extends _SimpleField<Duration, Res> {
  const DurationFieldBase({super.defaultTo, super.nullable, super.validator});
  @override
  _TypeRec get _typeRec => const _Duration();
}

/// Schema field to transform the custom package duration to a dart duration
class DurationField extends DurationFieldBase<core.Duration> {
  const DurationField({super.defaultTo, super.nullable, super.validator = _transform});

  static ValidatorResult<core.Duration> _transform(Duration dur) {
    return ValidatorTransform(dur.toDartDuration());
  }
}

/// If base class is not flexible enough you can implement this class
abstract class NumberFieldAbs<Rec extends num, Res extends Object> extends Field<double, Res> {
  const NumberFieldAbs();
  @override
  _TypeRec get _typeRec => switch (Rec) {
    int => const _Int(),
    double => const _Double(),
    _ => throw UnimplementedError(),
  };
}

class NumberFieldBase<Rec extends num, Res extends Object> extends _SimpleField<Rec, Res> {
  NumberFieldBase({super.defaultTo, super.nullable, super.validator});
  @override
  _TypeRec get _typeRec => switch (Rec) {
    int => const _Int(),
    double => const _Double(),
    _ => throw UnimplementedError(),
  };
}

class DoubleNumberField extends _SimpleField<double, double> {
  const DoubleNumberField({super.defaultTo, super.nullable, super.validator});
  @override
  _TypeRec get _typeRec => const _Double();
}

class IntegerNumberField extends _SimpleField<int, int> {
  const IntegerNumberField({super.defaultTo, super.nullable, super.validator});
  @override
  _TypeRec get _typeRec => const _Int();
}

/// If base class is not flexible enough you can implement this class
abstract class BooleanFieldAbstract<Res extends Object> extends Field<bool, Res> {
  const BooleanFieldAbstract();
  @override
  _TypeRec get _typeRec => const _Boolean();
}

class BooleanFieldBase<Res extends Object> extends _SimpleField<bool, Res> {
  const BooleanFieldBase({super.defaultTo, super.nullable, super.validator});
  @override
  _TypeRec get _typeRec => const _Boolean();
}

typedef BooleanField = BooleanFieldBase<bool>;

class InvalidStringToEnum extends ValidationError {
  @override
  String error() {
    return "InvalidStringToEnum";
  }

  @override
  String help() {
    return "This string does not convert to a valid enum";
  }
}

class EnumField<T extends Enum> extends Field<String, T> {
  @override
  final T? defaultTo;

  @override
  final bool nullable;

  final List<T> values;

  const EnumField(this.values, {this.defaultTo, this.nullable = false});

  @override
  _TypeRec get _typeRec => const _String();

  @override
  ValidatorResult<T> validator(String value) {
    final transformResult = _transform(value);
    return transformResult;
  }

  ValidatorResult<T> _transform(String v) {
    for (final e in values) {
      if (v == e.name) {
        return ValidatorTransform<T>(e);
      }
    }
    return ValidatorError(InvalidStringToEnum());
  }
}

class ListField<Rec extends Object, Res extends Object> extends Field<List<Rec>, List<Res>> {
  final Field<Rec, Res> singleField;

  @override
  final List<Res>? defaultTo;

  @override
  final bool nullable;

  final MapperFn<List<Res>, List<Res>>? _validator;

  const ListField(
    this.singleField, {
    this.defaultTo,
    this.nullable = false,
    MapperFn<List<Res>, List<Res>>? validator,
  }) : _validator = validator;

  @override
  _TypeRec get _typeRec => _List(_TypeRec.fromType(Rec));

  @override
  ValidatorResult<List<Res>> validator(List<Object> originalList) {
    final transformedList = <Res>[];
    for (final originalItem in originalList) {
      final itemValidatorResult = singleField.validator(originalItem as Rec);
      // TODO: 2 how should inner field options (.nullable ; .defaultTo) be applied, if at all?
      switch (itemValidatorResult) {
        case ValidatorSuccess():
          transformedList.add(originalItem as Res);
        case ValidatorTransform<Res> transformResult:
          transformedList.add(transformResult.value);
        case ValidatorError<ValidationError, Object> transformError:
          // TODO: 2 implement proper error management for each inner item error
          return ValidatorError(transformError.value);
      }
    }
    if (_validator != null) {
      final customValidatorResult = _validator(transformedList);
      if (customValidatorResult is! ValidatorSuccess) {
        return customValidatorResult;
      }
    }
    return ValidatorTransform(transformedList);
  }
}

class MapField<Key extends Object, Val extends Object, ResKey extends Object, ResVal extends Object>
    extends Field<Map<Key, Val>, Map<ResKey, ResVal>> {
  final Field<Key, ResKey> keyField;
  final Field<Val, ResVal> valField;

  @override
  final Map<ResKey, ResVal>? defaultTo;

  @override
  final bool nullable;

  final MapperFn<Map<ResKey, ResVal>, Map<ResKey, ResVal>>? _validator;

  const MapField(
    this.keyField,
    this.valField, {
    this.defaultTo,
    this.nullable = false,
    MapperFn<Map<ResKey, ResVal>, Map<ResKey, ResVal>>? validator,
  }) : _validator = validator;

  @override
  _TypeRec get _typeRec => _Map(_TypeRec.fromType(Key), _TypeRec.fromType(Val));

  @override
  ValidatorResult<Map<ResKey, ResVal>> validator(Map<Object, Object> originalMap) {
    final transformedMap = <ResKey, ResVal>{};

    for (final originalItem in originalMap.entries) {
      final originalKey = originalItem.key;
      final originalVal = originalItem.value;
      final keyValidatorResult = keyField.validator(originalKey as Key);

      ResKey key;
      switch (keyValidatorResult) {
        case ValidatorSuccess<ResKey> _:
          key = originalKey as ResKey;
        case ValidatorTransform<ResKey> transformResult:
          key = transformResult.value;
        case ValidatorError<ValidationError, core.Object> transformError:
          // TODO: 2 implement proper error management for each inner item error
          return ValidatorError(transformError.value);
      }

      final valValidatorResult = valField.validator(originalVal as Val);
      ResVal val;
      switch (valValidatorResult) {
        case ValidatorSuccess<ResVal> _:
          val = originalVal as ResVal;
        case ValidatorTransform<ResVal> transformResult:
          val = transformResult.value;
        case ValidatorError<ValidationError, core.Object> transformError:
          // TODO: 2 implement proper error management for each inner item error
          return ValidatorError(transformError.value);
      }

      transformedMap[key] = val;
    }
    if (_validator != null) {
      final customValidatorResult = _validator(transformedMap);
      if (customValidatorResult is! ValidatorSuccess) {
        return customValidatorResult;
      }
    }
    return ValidatorTransform(transformedMap);
  }
}

/// Class that receieves an untyped list object as parameter
/// The object can have type of double, string, bool or list
class UntypedListField<T extends Object> extends Field<List<Object>, List<T>> {
  @override
  final List<T>? defaultTo;

  @override
  final bool nullable;

  final MapperFn<List<Object>, List<T>> tranformFn;

  const UntypedListField(this.tranformFn, {this.defaultTo, this.nullable = false});

  @override
  _TypeRec get _typeRec => const _List(_Any());

  @override
  ValidatorResult<List<T>> validator(List<Object> value) => tranformFn(value);
}

class UntypedMapField<K extends Object, V extends Object>
    extends Field<Map<Object, Object>, Map<K, V>> {
  @override
  final Map<K, V>? defaultTo;

  @override
  final bool nullable;

  final MapperFn<Map<Object, Object>, Map<K, V>> tranformFn;

  const UntypedMapField(this.tranformFn, {this.defaultTo, this.nullable = false});

  @override
  _TypeRec get _typeRec => const _Map(_Any(), _Any());

  @override
  ValidatorResult<Map<K, V>> validator(Map<Object, Object> value) => tranformFn(value);
}

class BlockSchema {
  /// Field that has field validations
  final Map<String, Field> fields;

  /// Field that has nested schemas validations
  final Map<String, BlockSchema> blocks;

  /// List with all the shchemas that can be missing. The string must match
  /// with a key in tables
  ///
  /// A schema that can be missing means that if the key is not found then
  /// will not be included in the final output and apply function will not be called
  final Set<String> canBeMissingSchemas;

  /// List with all the shchemas that cannot be repeated. The string must match
  /// with a key in tables
  final Set<String> dontRepeted;

  /// If true then KeyNotInSchemaError will not be emited
  final bool ignoreNotInSchema;

  /// Use this function to validate or transform the final values of
  /// the schema.
  final void Function(BlockData values, List<EvaluationError> errors)? validator;

  const BlockSchema({
    this.fields = const {},
    this.blocks = const {},
    this.validator,
    this.ignoreNotInSchema = false,
    this.dontRepeted = const {},
    this.canBeMissingSchemas = const {},
  });

  void apply(String key, BlockData response, BlockValue values, List<EvaluationError> errors) {
    // fields
    {
      for (final entry in values.value.fields.entries) {
        final key = entry.key;
        if (!fields.containsKey(key.value)) {
          if (!ignoreNotInSchema) {
            errors.add(KeyNotInSchemaError(key.value, entry.key.token.pos!));
          }
          response.fields[key] = entry.value.toValue();
        } else {
          // sets a default value here so i can keep insertion order from original data
          response.fields[key] = fields[key.value]!.defaultTo;
        }
      }

      for (final entry in fields.entries) {
        final field = entry.value;
        final key = entry.key;

        if (!values.value.fields.containsKey(Identifier(key))) {
          if (field.defaultTo == null && !field.nullable) {
            errors.add(RequiredKeyIsMissing(key, values.name?.value, values.name?.token.pos));
          } else {
            response.defaultKeys.add(key);
            response.fields[Identifier(key)] = field.defaultTo;
          }
        } else {
          final keyIdent = values.value.fields.keys.firstWhere((e) => e.value == key);
          final evalValue = values.value.fields[keyIdent]!;
          final coerceValue = _coerceType(field._typeRec, evalValue);
          if (coerceValue == null) {
            final start = keyIdent.token.pos!.startOffset;
            final end = evalValue.position.startOffset + evalValue.position.length;
            errors.add(
              ConflictTypeError(
                key,
                Position.t(start, end - start, evalValue.position.filepath),
                "${field._typeRec}",
                "${evalValue.value.runtimeType}",
              ),
            );
            continue;
          }

          switch (field.validator(unwrapValue(coerceValue))) {
            case ValidatorSuccess<Object>():
              response.fields[Identifier(key)] = coerceValue.value;
            case ValidatorTransform result:
              response.fields[Identifier(key)] = result.value;
            case ValidatorError result:
              result.value.original = coerceValue;
              errors.add(result.value);
          }
        }
      }
    }

    // blocks
    {
      for (final block in values.value.blocks) {
        final key = block.$1;
        final schema = blocks[key.value];
        if (schema == null) {
          if (!ignoreNotInSchema) {
            errors.add(KeyNotInSchemaError(key.value, block.$2.position));
          }
          response.blocks.add((key, block.$2.toValue()));
          continue;
        }
        // sets a default value here so i can keep insertion order from original data
        if (dontRepeted.contains(key.value) && response.blockContainsKey(key)) {
          errors.add(RepeatedBlockError(key.value));
          continue;
        }
        response.blocks.add((key, BlockData.empty()));
        schema.apply(key.value, response.blocks.last.$2, block.$2, errors);
      }

      /// Add blocks that cannot be missing
      for (final entry in blocks.entries) {
        final schema = entry.value;
        final key = entry.key;

        if (!values.value.blockContainsKey(Identifier(key))) {
          if (!canBeMissingSchemas.contains(key)) {
            response.defaultKeys.add(key);
            response.blocks.add((Identifier(key), BlockData.empty()));
            schema.apply(key, response.blocks.last.$2, BlockValue.empty(Identifier(key)), errors);
          } else {
            continue;
          }
        }
      }
    }

    validator?.call(response, errors);
  }
}

typedef Schema = BlockSchema;

class LazySchema extends BlockSchema {
  LazySchema({
    super.fields = const {},
    super.validator,
    super.ignoreNotInSchema = false,
    super.dontRepeted = const {},
    this.canBeMissingSchemasGetter,
    this.blocksGetter,
  }) : super(
         // TODO: 2 if there was a BlockSchema interface, we wouldn't need to do this
         blocks: const {},
         canBeMissingSchemas: const {},
       );

  /// the function should always return the same result, because it will be cached
  final Map<String, BlockSchema> Function()? blocksGetter;

  Map<String, BlockSchema>? _blocks;

  @override
  Map<String, BlockSchema> get blocks {
    if (blocksGetter == null) {
      return const {};
    }
    _blocks ??= blocksGetter!();
    return _blocks!;
  }

  final Set<String> Function()? canBeMissingSchemasGetter;
  Set<String>? _canBeMissingSchemas;

  @override
  Set<String> get canBeMissingSchemas {
    if (canBeMissingSchemasGetter == null) {
      return const {};
    }
    _canBeMissingSchemas ??= canBeMissingSchemasGetter!();
    return _canBeMissingSchemas!;
  }
}

Object unwrapValue(Value val) {
  if (val is ListValue) {
    return val.toList();
  } else if (val is MapValue) {
    return val.toMap();
  } else {
    return val.value;
  }
}

Value? _coerceType(_TypeRec expected, Value actual) {
  if (expected.innerType == actual.value.runtimeType) {
    return actual;
  }
  if (expected.innerType == double && actual.runtimeType == NumberIntegerValue) {
    return NumberDoubleValue((actual as NumberIntegerValue).value.toDouble(), actual.position);
  }

  // Coerce type when list
  if (actual is ListValue) {
    if (expected is! _List) {
      return null;
    }
    return _coerceList(expected, actual);
  }
  if (actual is MapValue) {
    if (expected is! _Map) {
      return null;
    }
    return _coerceMap(expected, actual);
  }
  return null;
}

ListValue? _coerceList(_List expected, ListValue actual) {
  if (expected.inner is _Any) {
    return actual;
  }
  final resp = ListValue([], actual.position);
  for (final val in actual.value) {
    final newval = _coerceType(expected.inner, val);
    if (newval == null) {
      return null;
    }
    resp.value.add(newval);
  }
  return resp;
}

MapValue? _coerceMap(_Map expected, MapValue actual) {
  if (expected.key is _Any && expected.value is _Any) {
    return actual;
  }
  final resp = MapValue({}, actual.position);
  for (final entry in actual.value.entries) {
    final key = _coerceType(expected.key, entry.key);
    if (key == null) {
      return null;
    }
    final value = _coerceType(expected.value, entry.value);
    if (value == null) {
      return null;
    }
    resp.value[key] = value;
  }
  return resp;
}

class RepeatedBlockError extends CustomEvaluationError {
  final String key;

  const RepeatedBlockError(this.key);

  @override
  String error() {
    return "Block with name $key is repeated but was not allowed";
  }

  @override
  String help() {
    return "Remove or change the name of the block";
  }
}
