void validateMcpArguments(
  Map<String, Object?> tool,
  Map<String, Object?> arguments,
) {
  void validate(Object? value, Map schema, String key) {
    final type = schema['type'];
    final valid = switch (type) {
      'string' => value is String,
      'integer' => value is int,
      'boolean' => value is bool,
      'array' => value is List,
      'object' => value is Map,
      _ => false,
    };
    if (!valid) throw ArgumentError('Invalid $key: expected $type');
    if (schema['enum'] case final List values) {
      if (!values.contains(value)) throw ArgumentError('Invalid choice: $key');
    }
    if (value is int &&
        ((schema['minimum'] is num && value < (schema['minimum'] as num)) ||
            (schema['maximum'] is num && value > (schema['maximum'] as num)))) {
      throw ArgumentError('Out of range: $key');
    }
    if (value is String &&
        value.length > (schema['maxLength'] as int? ?? 1024 * 1024)) {
      throw ArgumentError('Text too long: $key');
    }
    if (value is List) {
      if (value.length > (schema['maxItems'] as int? ?? 1000) ||
          value.length < (schema['minItems'] as int? ?? 0)) {
        throw ArgumentError('Invalid item count: $key');
      }
      for (final item in value) {
        validate(item, schema['items'] as Map, '$key item');
      }
    }
    if (value is Map) {
      final properties = schema['properties'] as Map;
      for (final required in schema['required'] as List? ?? const []) {
        if (!value.containsKey(required)) {
          throw ArgumentError('Missing argument: $required');
        }
      }
      for (final entry in value.entries) {
        if (!properties.containsKey(entry.key)) {
          throw ArgumentError('Unknown argument: ${entry.key}');
        }
        validate(entry.value, properties[entry.key] as Map, '${entry.key}');
      }
    }
  }

  validate(arguments, tool['inputSchema'] as Map, 'arguments');
}
