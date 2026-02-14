import 'dart:convert';

import 'package:glob/glob.dart';
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/dart_tool_package_info.dart';
import 'package:tachyon/src/core/tachyon_config.dart';
import 'package:tachyon/tachyon.dart';

const String kProjectDirPath = '/home/user/project';

void createCommonTachyonYaml({
  String projectPath = kProjectDirPath,
  List<String> plugins = const <String>[],
  List<ExternalPackageConfig> externalPackages = const <ExternalPackageConfig>[],
}) {
  // json is valid syntax for YAML so this makes life easier
  Tachyon.fileSystem.directory(projectPath).childFile(kTachyonConfigFileName)
    ..createSync(recursive: true)
    ..writeAsStringSync(
      json.encode(
        TachyonConfig(
          fileGenerationPaths: <Glob>[Glob('lib/**')],
          generatedFileLineLength: 100,
          plugins: plugins,
          externalPackages: <String, ExternalPackageConfig>{
            for (final ExternalPackageConfig package in externalPackages) package.name: package,
          },
        ).toJson(),
      ),
    );
}

void createCommonPackageConfigJson({
  String projectPath = kProjectDirPath,
  List<PackageInfo> packages = const <PackageInfo>[],
}) {
  Tachyon.fileSystem
      .directory(projectPath)
      .childDirectory(kDartToolFolderName)
      .childFile('package_config.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      json.encode(<String, Object>{
        'configVersion': 2,
        'packages': packages,
      }),
    );
}

void createCommonAnalysisOptionsYaml({
  String projectPath = kProjectDirPath,
}) {
  Tachyon.fileSystem.directory(projectPath).childFile('analysis_options.yaml')
    ..createSync(recursive: true)
    ..writeAsStringSync('''
include: package:lints/recommended.yaml
''');
}
