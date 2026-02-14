import 'dart:io';

import 'package:file/file.dart';
import 'package:tachyon/src/dart_version.dart';
import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

import 'common_yaml_creators.dart';
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

  projectDir.childFile('pubspec.yaml').writeAsStringSync('''
name: plugins_tester
version: 1.0.0
publish_to: none

environment:
  sdk: ">=$dartSdkVersion"

$dependenciesBuffer
dev_dependencies:
  tachyon:
    path: ../..
''');

  createCommonTachyonYaml(projectPath: projectDir.path, plugins: pluginsNames);
  createCommonAnalysisOptionsYaml(projectPath: projectDir.path);

  Process.runSync(
    Platform.resolvedExecutable,
    <String>['pub', 'get'],
    workingDirectory: projectDir.path,
    runInShell: true,
  );

  return projectDir;
}
