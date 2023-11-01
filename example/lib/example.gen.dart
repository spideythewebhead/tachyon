// AUTO GENERATED - DO NOT MODIFY
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, inference_failure_on_uninitialized_variable, inference_failure_on_function_return_type, inference_failure_on_untyped_parameter, deprecated_member_use_from_same_package
// coverage:ignore-file

part of 'example.dart';

class PubspecYamlException implements Exception {
  factory PubspecYamlException.notFound([String? message]) = _PubspecYamlException$notFound;
  factory PubspecYamlException.invalidFormat([String? message]) =
      _PubspecYamlException$invalidFormat;
}

class _PubspecYamlException$notFound implements PubspecYamlException {
  _PubspecYamlException$notFound([this.message]);

  final String? message;

  @override
  String toString() {
    return 'PubspecYaml.notFound(message: $message)';
  }
}

class _PubspecYamlException$invalidFormat implements PubspecYamlException {
  _PubspecYamlException$invalidFormat([this.message]);

  final String? message;

  @override
  String toString() {
    return 'PubspecYaml.invalidFormat(message: $message)';
  }
}

class FileReaderException implements Exception {
  factory FileReaderException.notFound([String? message]) = _FileReaderException$notFound;
  factory FileReaderException.permissionDenied([String? message]) =
      _FileReaderException$permissionDenied;
  factory FileReaderException.osError([String? message]) = _FileReaderException$osError;
}

class _FileReaderException$notFound implements FileReaderException {
  _FileReaderException$notFound([this.message]);

  final String? message;

  @override
  String toString() {
    return 'FileReader.notFound(message: $message)';
  }
}

class _FileReaderException$permissionDenied implements FileReaderException {
  _FileReaderException$permissionDenied([this.message]);

  final String? message;

  @override
  String toString() {
    return 'FileReader.permissionDenied(message: $message)';
  }
}

class _FileReaderException$osError implements FileReaderException {
  _FileReaderException$osError([this.message]);

  final String? message;

  @override
  String toString() {
    return 'FileReader.osError(message: $message)';
  }
}

class MyListException implements Exception {
  factory MyListException.outOfBounds([String? message]) = _MyListException$outOfBounds;
  factory MyListException.notImplemented([String? message]) = _MyListException$notImplemented;
}

class _MyListException$outOfBounds implements MyListException {
  _MyListException$outOfBounds([this.message]);

  final String? message;

  @override
  String toString() {
    return 'MyList.outOfBounds(message: $message)';
  }
}

class _MyListException$notImplemented implements MyListException {
  _MyListException$notImplemented([this.message]);

  final String? message;

  @override
  String toString() {
    return 'MyList.notImplemented(message: $message)';
  }
}
