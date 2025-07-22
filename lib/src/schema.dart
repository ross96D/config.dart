import 'package:config/config.dart';

typedef MapperFn<Rec extends Object, Res extends Object> = ValidatorResult<Res> Function(Rec value);

sealed class Field<Rec extends Object, Res extends Object> {
  final Type typeRec;
  final Type typeRes;

  String get name;
  Res? get defaultTo;
  bool get nullable;

  const Field() : typeRec = Rec, typeRes = Res;

  ValidatorResult<Res> validator(Rec value);
}

class _SimpleField<Rec extends Object, Res extends Object> extends Field<Rec, Res> {
  @override
  final String name;

  @override
  final Res? defaultTo;

  @override
  final bool nullable;

  final MapperFn<Rec, Res>? _validator;

  const _SimpleField(
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

/// If base class is not flexible enough you can implement this class
abstract class StringFieldAbstract<Res extends Object> extends Field<String, Res> {}

class StringFieldBase<Res extends Object> extends _SimpleField<String, Res> {
  const StringFieldBase(super.name, {super.defaultTo, super.nullable, super.validator});
}

typedef StringField = StringFieldBase<String>;

/// If base class is not flexible enough you can implement this class
abstract class NumberFieldAbs<Res extends Object> extends Field<double, Res> {}

class NumberFieldBase<Res extends Object> extends _SimpleField<double, Res> {
  const NumberFieldBase(super.name, {super.defaultTo, super.nullable, super.validator});
}

typedef NumberField = NumberFieldBase<double>;

/// If base class is not flexible enough you can implement this class
abstract class BooleanFieldAbstract<Res extends Object> extends Field<bool, Res> {}

class BooleanFieldBase<Res extends Object> extends _SimpleField<bool, Res> {
  const BooleanFieldBase(super.name, {super.defaultTo, super.nullable, super.validator});
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
  final String name;

  @override
  final T? defaultTo;

  @override
  final bool nullable;

  final List<T> values;

  const EnumField(
    this.name,
    this.values, {
    this.defaultTo,
    this.nullable = false,
  });

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

class TableSchema {
  final Map<String, Field> fields;
  final Map<String, TableSchema> tables;

  TableSchema({List<Field>? fields, Map<String, TableSchema>? tables})
    : fields = fields != null ? Map.fromEntries(fields.map((e) => MapEntry(e.name, e))) : {},
      tables = tables ?? {};

  void apply(Map<String, dynamic> response, MapValue values, List<EvaluationError> errors) {
    for (final entry in values.value.entries) {
      if (!fields.containsKey(entry.key)) {
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
