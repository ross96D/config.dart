// ignore_for_file: type_literal_in_constant_pattern

import 'package:config/config.dart';
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

class TableSchema {
  /// Field that has field validations
  final Map<String, Field> fields;

  /// Field that has nested schemas validations
  final Map<String, TableSchema> tables;

  /// Do not call apply when parent key was missing
  ///
  /// ej: Schema(tables: {"KeyNotFound": Schema(required: false)})
  /// this does not affect the final output if required was true
  /// then the final output would be {"KeyNotFound": {}}
  ///
  /// This means that a this field is ignored on root schema
  final bool required;

  /// If this is true then KeyNotInSchemaError will not be emited
  final bool ignoreNotInSchema;

  /// Use this function to validate or transform the final values of
  /// the schema.
  final Function(
    Map<String, dynamic> values,
    List<EvaluationError> errors,
  )?
  validator;

  const TableSchema({
    this.fields = const {},
    this.tables = const {},
    this.validator,
    this.required = true,
    this.ignoreNotInSchema = false,
  });

  void apply(Map<String, dynamic> response, TableValue values, List<EvaluationError> errors) {
    for (final entry in values.value.entries) {
      if (!fields.containsKey(entry.key) && !tables.keys.contains(entry.key)) {
        if (!ignoreNotInSchema) {
          errors.add(KeyNotInSchemaError(entry.key, entry.value.line, entry.value.filepath));
        }
        response[entry.key] = entry.value.toValue();
      }
    }

    for (final entry in fields.entries) {
      final field = entry.value;
      final key = entry.key;

      if (values[key] == null) {
        if (field.defaultTo == null && !field.nullable) {
          errors.add(RequiredKeyIsMissing(key));
        } else {
          response[key] = field.defaultTo;
        }
      } else {
        final evalValue = values[key]!;
        final coerceValue = _coerceType(field._typeRec, evalValue);
        if (coerceValue == null) {
          errors.add(
            ConflictTypeError(
              key,
              evalValue.line,
              evalValue.filepath,
              "${field._typeRec}",
              "${evalValue.value.runtimeType}",
            ),
          );
          continue;
        }

        switch (field.validator(unwrapValue(coerceValue))) {
          case ValidatorSuccess<Object>():
            response[key] = coerceValue.value;
          case ValidatorTransform result:
            response[key] = result.value;
          case ValidatorError result:
            result.value.original = coerceValue;
            errors.add(result.value);
        }
      }
    }

    for (final entry in tables.entries) {
      final table = entry.value;
      final key = entry.key;

      if (values[key] == null) {
        values[key] = TableValue.empty();
      } else if (values[key] is! TableValue) {
        throw StateError(
          "Unreachable key is not MapValue when is declared as Table in Schema. "
          "Key: $key Value: ${values[key]}",
        );
      }
      // if values are not empty call table.apply, otherwise only call table.apply if table is required
      if (!(values[key] as TableValue).isEmpty || table.required) {
        response[key] = <String, dynamic>{};
        table.apply(response[key], values[key] as TableValue, errors);
      }
    }

    validator?.call(response, errors);
  }
}

typedef Schema = TableSchema;

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
    return NumberDoubleValue(
      (actual as NumberIntegerValue).value.toDouble(),
      actual.line,
      actual.filepath,
    );
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
  final resp = ListValue([], actual.line, actual.filepath);
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
  final resp = MapValue({}, actual.line, actual.filepath);
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
