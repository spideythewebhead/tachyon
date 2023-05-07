import 'dart:collection';

import 'package:tachyon/src/core/parsed_file_data.dart';

/// A [Map] that maps an absolute file path to [ParsedFileData]
class ParsedFilesRegistry with MapMixin<String, ParsedFileData> {
  ParsedFilesRegistry();

  ParsedFilesRegistry.fromMap(Map<String, ParsedFileData> registry) {
    _registry.addAll(registry);
  }

  final Map<String, ParsedFileData> _registry = <String, ParsedFileData>{};

  @override
  Iterable<String> get keys => _registry.keys;

  @override
  ParsedFileData? operator [](Object? key) => _registry[key];

  @override
  void operator []=(String key, ParsedFileData value) => _registry[key] = value;

  @override
  ParsedFileData? remove(Object? key) => _registry.remove(key);

  @override
  void clear() {
    _registry.clear();
  }
}
