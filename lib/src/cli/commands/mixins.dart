import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/exceptions.dart';

mixin UtilsCommandMixin on Command<dynamic> {
  Directory get directory;

  void ensureHasPubspec() {
    final bool hasPubspecYaml =
        _hasFileInDirectory((File file) => path.basename(file.path) == kPubspecYamlFileName);
    if (!hasPubspecYaml) {
      throw const PubspecYamlNotFoundException();
    }
  }

  void ensureHasTachyonConfig() {
    final bool hasTachyonConfig =
        _hasFileInDirectory((File file) => path.basename(file.path) == kTachyonConfigFileName);
    if (!hasTachyonConfig) {
      throw const TachyonConfigNotFoundException();
    }
  }

  bool _hasFileInDirectory(bool Function(File file) predicate) {
    return directory
        .listSync() //
        .any((FileSystemEntity entity) => entity is File && predicate(entity));
  }
}
