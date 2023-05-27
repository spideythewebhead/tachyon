import 'dart:io';

import 'package:file/file.dart';
import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

import 'utils.dart';

Directory testProjectCreator({
  required List<String> pluginsNames,
}) {
  final FileSystem fs = Tachyon.fileSystem;

  final Directory projectDir = fs.currentDirectory
      .childDirectory('.test_tmp')
      .childDirectory('plugins_tester');
  addTearDown(projectDir.parent.safelyRecursivelyDeleteSync);

  projectDir.childDirectory('lib').createSync(recursive: true);

  StringBuffer dependenciesBuffer = StringBuffer()..writeln('dependencies:');
  for (final String pluginName in pluginsNames) {
    dependenciesBuffer.writeln('''
  $pluginName:
    path: ../$pluginName
''');
  }

  StringBuffer tachyonPluginsBuffer = StringBuffer()..writeln('plugins:');
  for (final String pluginName in pluginsNames) {
    tachyonPluginsBuffer.writeln('''
  - $pluginName
''');
  }

  projectDir.childFile('pubspec.yaml').writeAsStringSync('''
name: plugins_tester
version: 1.0.0
publish_to: none

environment:
  sdk: ">=2.19.6"

$dependenciesBuffer
dev_dependencies:
  tachyon:
    path: ../..
''');

  projectDir.childFile('tachyon_config.yaml')
    ..createSync()
    ..writeAsStringSync('''
file_generation_paths:
  - "lib/**"

$tachyonPluginsBuffer
''');

  Process.runSync(
    'dart',
    <String>['pub', 'get'],
    workingDirectory: projectDir.path,
    runInShell: true,
  );

  return projectDir;
}
