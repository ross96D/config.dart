import 'package:config/config.dart';

typedef MapperFn<Rec extends Object, Res extends Object> = ValidatorResult<Res> Function(Rec value);

abstract class Field<Rec extends Object, Res extends Object> {
  final Type typeRec;
  final Type typeRes;

  String get name;
  Res? get defaultTo;
  bool get nullable;

  const Field() : typeRec = Rec, typeRes = Res;

  ValidatorResult<Res> validator(Rec value);
}

class SimpleField<Rec extends Object, Res extends Object> extends Field<Rec, Res> {
  @override
  final String name;

  @override
  final Res? defaultTo;

  @override
  final bool nullable;

  final MapperFn<Rec, Res>? _validator;

  const SimpleField(
    this.name, {
    this.defaultTo,
    this.nullable = false,
    MapperFn<Rec, Res>? validator,
  }) : assert(
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

class StringField extends SimpleField<String, String> {
  const StringField(super.name, {super.defaultTo, super.nullable, super.validator});
}

class NumberField extends SimpleField<double, double> {
  const NumberField(super.name, {super.defaultTo, super.nullable, super.validator});
}

class BooleanField extends SimpleField<bool, bool> {
  const BooleanField(super.name, {super.defaultTo, super.nullable, super.validator});
}

class InvalidStringToEnum extends ValidationError {
  @override
  String error() {
    return "InvalidStringToEnum";
  }
}

class EnumField<T extends Enum> extends Field<String, T> {
  @override
  final String name;

  @override
  final T? defaultTo;

  @override
  final bool nullable;

  final List<T> values;

  final MapperFn<T, T>? _validator;

  const EnumField(
    this.name,
    this.values, {
    this.defaultTo,
    this.nullable = false,
    MapperFn<T, T>? validator,
  }) : _validator = validator;

  @override
  ValidatorResult<T> validator(String value) {
    final transformResult = _transform(value);
    final T transformed;
    switch (transformResult) {
      case ValidatorError<ValidationError, Object>():
        return transformResult;
      case ValidatorTransform<T>():
        transformed = transformResult.value;
      case ValidatorSuccess<T>():
        throw StateError("Unreachable");
    }
    if (_validator == null) {
      return transformResult;
    }
    final validatorResult = _validator(transformed);
    return switch (validatorResult) {
      ValidatorSuccess<T>() => transformResult,
      ValidatorTransform<T>() => validatorResult,
      ValidatorError<ValidationError, Object>() => validatorResult,
    };
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

class TableSchema {
  final Map<String, Field> _fields;
  final Map<String, TableSchema> _tables;

  TableSchema({List<Field>? fields, Map<String, TableSchema>? tables})
    : _fields = fields != null ? Map.fromEntries(fields.map((e) => MapEntry(e.name, e))) : {},
      _tables = tables ?? {};

  void apply(Map<String, dynamic> response, MapValue values, List<EvaluationError> errors) {
    for (final entry in values.value.entries) {
      if (!_fields.containsKey(entry.key)) {
        errors.add(KeyNotInSchemaError(entry.key, entry.value.line, entry.value.filepath));
      }
    }

    for (final entry in _fields.entries) {
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
        if (evalValue.value.runtimeType != field.typeRec) {
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
        switch (field.validator(evalValue.value)) {
          case ValidatorSuccess<Object>():
            response[key] = evalValue.value;
          case ValidatorTransform result:
            response[key] = result.value;
          case ValidatorError result:
            result.value.original = evalValue;
            errors.add(result.value);
        }
      }
    }

    for (final entry in _tables.entries) {
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
