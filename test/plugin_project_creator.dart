import 'dart:io';

import 'package:file/src/interface/directory.dart';
import 'package:file/src/interface/file_system.dart';
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

import 'utils.dart';

Directory pluginProjectCreator({
  required String pluginName,
  required String annotationName,
  required String generatorName,
}) {
  final FileSystem fs = Tachyon.fileSystem;

  final Directory projectDir = fs.currentDirectory
      .childDirectory('.test_tmp')
      .childDirectory(pluginName);
  addTearDown(projectDir.parent.safelyRecursivelyDeleteSync);

  projectDir.childDirectory('lib').createSync(recursive: true);

  projectDir.childFile('pubspec.yaml').writeAsStringSync('''
name: $pluginName
version: 1.0.0
publish_to: none

environment:
  sdk: ">=2.19.6"

dependencies:
  tachyon:
    path: ../..
''');

  projectDir
      .childDirectory('lib')
      .childDirectory('src')
      .childFile('generator.dart')
    ..createSync(recursive: true)
    ..writeAsStringSync('''
import 'dart:async';

import 'package:tachyon/tachyon.dart';

class $generatorName extends TachyonPluginCodeGenerator {
  @override
  FutureOr<String> generate(
    FileChangeBuildInfo buildInfo,
    TachyonDeclarationFinder declarationFinder,
    Logger logger,
  ) {
    return '// Plugin $pluginName registered';
  }
}
''');

  projectDir.childFile(kTachyonPluginConfigFileName).writeAsStringSync('''
name: $pluginName
code_generator:
  file: src/generator.dart
  className: $generatorName
annotations:
  - $annotationName
''');

  projectDir
      .childDirectory('lib')
      .childFile('$pluginName.dart')
      .writeAsStringSync('''
library;

class MyAnnotation {
  const MyAnnotation();
}
''');

  Process.runSync(
    'dart',
    <String>['pub', 'get'],
    workingDirectory: projectDir.path,
    runInShell: true,
  );

  return projectDir;
}
