import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/tachyon.dart';

class PackageResolver {
  static ResolvedPackages resolvePackages(String projectPath) {
    final File packageConfigFile = Tachyon.fileSystem.file(path.join(
      projectPath,
      kDartToolFolderName,
      'package_config.json',
    ));

    if (!packageConfigFile.existsSync()) {
      throw const DartToolPackageConfigNotFoundException();
    }

    final Map<String, dynamic> packageFileJson = json.decode(packageConfigFile.readAsStringSync());
    final Map<String, PackageInfo> packages = <String, PackageInfo>{
      for (final Map<dynamic, dynamic> packageJson in packageFileJson['packages'])
        packageJson['name'] as String: PackageInfo.fromJson(packageJson)
    };

    return ResolvedPackages(packages: packages);
  }

  static String? getTachyonMainDartPath(String projectPath) {
    final PackageInfo? packageInfo = resolvePackages(projectPath)['tachyon'];
    if (packageInfo == null) {
      return null;
    }

    final String filePath = packageInfo.rootUri.toFilePath();
    if (path.isAbsolute(filePath)) {
      return path.join(filePath, 'bin', 'tachyon.dart');
    }

    return path.normalize(path.join(
      path.normalize(path.join(
        projectPath,
        kDartToolFolderName,
        filePath,
      )),
      'bin',
      'tachyon.dart',
    ));
  }
}

class ResolvedPackages {
  ResolvedPackages({
    required Map<String, PackageInfo> packages,
  }) : _packages = packages;

  final Map<String, PackageInfo> _packages;

  PackageInfo? operator [](String name) => _packages[name];
}

class PackageInfo {
  PackageInfo({
    required this.name,
    required this.rootUri,
    required this.packageUri,
    required this.languageVersion,
  });

  factory PackageInfo.fromJson(Map<dynamic, dynamic> json) {
    return PackageInfo(
      name: json['name'] as String,
      rootUri: Uri.parse(json['rootUri'] as String),
      packageUri: json['packageUri'] == null ? null : Uri.parse(json['packageUri'] as String),
      languageVersion: json['languageVersion'] as String,
    );
  }

  final String name;
  final Uri rootUri;
  final Uri? packageUri;
  final String languageVersion;
}
