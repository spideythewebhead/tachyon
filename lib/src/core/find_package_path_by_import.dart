import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/src/extensions/extensions.dart';

const String _dartPrefix = 'dart:';
const String _packagePrefix = 'package:';

Future<String?> findDartFileFromUri({
  required String projectDirectoryPath,
  required String currentDirectoryPath,
  required String uri,
}) async {
  if (uri.startsWith(_dartPrefix)) {
    return null;
  }

  if (!uri.startsWith(_packagePrefix)) {
    return path.normalize(path.join(
      currentDirectoryPath,
      uri.toString(),
    ));
  }

  final List<PackageInfo> packages = <PackageInfo>[];

  final File packageConfigFile =
      File(path.join(projectDirectoryPath, '.dart_tool', 'package_config.json'));

  if (!await packageConfigFile.exists()) {
    throw const DartToolFolderNotFoundException();
  }

  final Map<dynamic, dynamic> packageConfigJson =
      await packageConfigFile.readAsString().then((String value) => jsonDecode(value));

  packages.addAll(<PackageInfo>[
    for (final Map<dynamic, dynamic> packageJson in packageConfigJson['packages'])
      PackageInfo.fromJson(packageJson)
  ]);

  final String packageName = uri.substring(_packagePrefix.length, uri.indexOf('/'));
  final PackageInfo? targetPackage =
      packages.firstWhereOrNull((PackageInfo package) => package.name == packageName);

  if (targetPackage == null) {
    throw PackageNotFoundException(packageName);
  }

  return path.normalize(
    path.join(
      path.isRelative(targetPackage.rootUri.path)
          ? projectDirectoryPath
          : targetPackage.rootUri.path,
      targetPackage.packageUri.path,
      // uri format = package:package_name/path/to/file.dart
      // we need to extract the 'path/to/file.dart'
      uri.substring(1 + uri.indexOf('/')),
    ),
  );
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
      packageUri: Uri.parse(json['packageUri'] as String),
      languageVersion: json['languageVersion'] as String,
    );
  }

  final String name;
  final Uri rootUri;
  final Uri packageUri;
  final String languageVersion;
}
