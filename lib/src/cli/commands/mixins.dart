import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/core/exceptions.dart';

mixin UtilsCommandMixin on Command<dynamic> {
  Directory get directory;

  void ensureHasPubspec() {
    final bool hasPubspecYaml = directory
        .listSync() //
        .any((FileSystemEntity entity) =>
            entity is File && path.basename(entity.path) == 'pubspec.yaml');

    if (!hasPubspecYaml) {
      throw const PubspecYamlNotFoundException();
    }
  }
}
