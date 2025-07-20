import 'package:config/config.dart';

typedef MapperFn<Rec extends Object, Res extends Object> = Result<Res> Function(Rec value);

class Field<Rec extends Object, Res extends Object> {
  final String name;
  final Type typeRec;
  final Type typeRes;
  final MapperFn<Rec, Res> _map;
  final Res? defaultTo;
  final bool nullable;

  const Field(this.name, this._map, this.defaultTo, this.nullable) : typeRec = Rec, typeRes = Res;

  Result validator(Object value) {
    return _map(value as Rec);
  }
}

class StringField extends Field<String, String> {
  StringField(
    String name, {
    String? defaultTo,
    MapperFn<String, String>? transform,
    bool nullable = false,
  }) : super(name, transform ?? _noTransform, defaultTo, nullable);

  static Result<String> _noTransform(String v) => Success(v);
}

class NumberField extends Field<double, double> {
  NumberField(
    String name, {
    double? defaultTo,
    MapperFn<double, double>? transform,
    bool nullable = false,
  }) : super(name, transform ?? _noTransform, defaultTo, nullable);

  static Result<double> _noTransform(double v) => Success(v);
}

class BooleanField extends Field<bool, bool> {
  BooleanField(
    String name, {
    bool? defaultTo,
    MapperFn<bool, bool>? transform,
    bool nullable = false,
  }) : super(name, transform ?? _noTransform, defaultTo, nullable);

  static Result<bool> _noTransform(bool v) => Success(v);
}

class InvalidStringToEnum extends ValidationError {
  @override
  String error() {
    return "InvalidStringToEnum";
  }
}

class EnumField<T extends Enum> extends Field<String, T> {
  EnumField(String name, MapperFn<String, T> transform, {T? defaultTo, bool nullable = false})
    : super(name, transform, defaultTo, nullable);

  static Result<T> Function(String) transform<T extends Enum>(List<T> values) {
    return (v) {
      for (final e in values) {
        if (v == e.name) {
          return Success<T>(e);
        }
      }
      return Failure(InvalidStringToEnum());
    };
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
          case Success result:
            response[key] = result.value;
          case Failure result:
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
