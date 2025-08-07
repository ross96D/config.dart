import 'package:config/config.dart';
import 'package:config/src/types/duration/duration.dart';
import 'dart:core' as core;
import 'dart:core';

typedef MapperFn<Rec extends Object, Res extends Object> = ValidatorResult<Res> Function(Rec value);

sealed class Field<Rec extends Object, Res extends Object> {
  final Type typeRec;
  final Type typeRes;

  Res? get defaultTo;
  bool get nullable;

  const Field() : typeRec = Rec, typeRes = Res;

  ValidatorResult<Res> validator(Rec value);
}

class _SimpleField<Rec extends Object, Res extends Object> extends Field<Rec, Res> {
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
abstract class StringFieldAbstract<Res extends Object> extends Field<String, Res> {}

class StringFieldBase<Res extends Object> extends _SimpleField<String, Res> {
  const StringFieldBase({super.defaultTo, super.nullable, super.validator});
}

typedef StringField = StringFieldBase<String>;

/// If base class is not flexible enough you can implement this class
abstract class DurationFieldAbstract<Res extends Object> extends Field<Duration, Res> {}

class DurationFieldBase<Res extends Object> extends _SimpleField<Duration, Res> {
  const DurationFieldBase({super.defaultTo, super.nullable, super.validator});
}

/// Schema field to transform the custom package duration to a dart duration
class DurationField extends DurationFieldBase<core.Duration> {
  const DurationField({super.defaultTo, super.nullable, super.validator = _transform});

  static ValidatorResult<core.Duration> _transform(Duration dur) {
    return ValidatorTransform(dur.toDartDuration());
  }
}

/// If base class is not flexible enough you can implement this class
abstract class NumberFieldAbs<Res extends Object> extends Field<double, Res> {}

class NumberFieldBase<Rec extends num, Res extends Object> extends _SimpleField<Rec, Res> {
  const NumberFieldBase({super.defaultTo, super.nullable, super.validator});
}

typedef DoubleNumberField = NumberFieldBase<double, double>;
typedef IntegerNumberField = NumberFieldBase<int, int>;

/// If base class is not flexible enough you can implement this class
abstract class BooleanFieldAbstract<Res extends Object> extends Field<bool, Res> {}

class BooleanFieldBase<Res extends Object> extends _SimpleField<bool, Res> {
  const BooleanFieldBase({super.defaultTo, super.nullable, super.validator});
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
      return _validator(transformedList);
    }
    return ValidatorTransform(transformedList);
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
  ValidatorResult<List<T>> validator(List<Object> value) => tranformFn(value);
}

class TableSchema {
  final Map<String, Field> fields;
  final Map<String, TableSchema> tables;

  TableSchema({this.fields = const {}, this.tables = const {}});

  void apply(Map<String, dynamic> response, MapValue values, List<EvaluationError> errors) {
    for (final entry in values.value.entries) {
      if (!fields.containsKey(entry.key) && !tables.keys.contains(entry.key)) {
        errors.add(KeyNotInSchemaError(entry.key, entry.value.line, entry.value.filepath));
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
        final coerceValue = _coerceType(field.typeRec, evalValue);
        if (coerceValue == null) {
          errors.add(
            ConflictTypeError(
              key,
              evalValue.line,
              evalValue.filepath,
              field.typeRec,
              evalValue.value.runtimeType,
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
        values[key] = MapValue.empty();
      } else if (values[key] is! MapValue) {
        throw StateError(
          "Unreachable key is not MapValue when is declared as Table in Schema. "
          "Key: $key Value: ${values[key]}",
        );
      }
      response[key] = <String, dynamic>{};
      table.apply(response[key], values[key] as MapValue, errors);
    }
  }
}

class Schema extends TableSchema {
  Schema({super.fields, super.tables});
}

Object unwrapValue(Value val) {
  if (val is ListValue) {
    return val.toList();
  } else {
    return val.value;
  }
}

Value? _coerceType(Type expected, Value actual) {
  if (expected == actual.value.runtimeType) {
    return actual;
  }
  if (expected == double && actual.runtimeType == NumberIntegerValue) {
    return NumberDoubleValue(
      (actual as NumberIntegerValue).value.toDouble(),
      actual.line,
      actual.filepath,
    );
  }

  // Coerce type when list
  if (actual is ListValue) {
    if (expected == List<Object>) {
      return actual;
    }
    if (expected == List<String>) {
      final resp = ListValue([], actual.line, actual.filepath);
      for (final val in actual.value) {
        final newval = _coerceType(String, val);
        if (newval == null) {
          return null;
        }
        resp.value.add(newval);
      }
      return resp;

    } else if (expected == List<int>) {
      final resp = ListValue([], actual.line, actual.filepath);
      for (final val in actual.value) {
        final newval = _coerceType(int, val);
        if (newval == null) {
          return null;
        }
        resp.value.add(newval);
      }
      return resp;

    } else if (expected == List<double>) {
      final resp = ListValue([], actual.line, actual.filepath);
      for (final val in actual.value) {
        final newval = _coerceType(double, val);
        if (newval == null) {
          return null;
        }
        resp.value.add(newval);
      }
      return resp;

    } else if (expected == List<Duration>) {
      final resp = ListValue([], actual.line, actual.filepath);
      for (final val in actual.value) {
        final newval = _coerceType(Duration, val);
        if (newval == null) {
          return null;
        }
        resp.value.add(newval);
      }
      return resp;
    }
  }
  return null;
}
