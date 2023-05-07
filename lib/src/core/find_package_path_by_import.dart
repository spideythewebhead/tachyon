import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/src/extensions/extensions.dart';

const String _dartPrefix = 'dart:';
const String _packagePrefix = 'package:';

/// Tries to find the full file path for an import/export directive that starts with
/// `package:` or is a relative import/export
///
/// `dart:` imports/exports are skipped
///
/// For this to work the function tries to analyze the `.dart_tool/package_config.json` which is
/// generated by project `pub get` on the project
///
/// Throws:
/// 1. [DartToolFolderNotFoundException] if `pub get` was not executed in this project
/// 2. [PackageNotFoundException] if the dependency is not added yet or it was removed
///     with out executing `pub get` again
Future<String?> findDartFileFromDirectiveUri({
  required String projectDirectoryPath,
  required String currentDirectoryPath,
  required String uri,
}) async {
  if (uri.startsWith(_dartPrefix)) {
    return null;
  }

  // relative directive uri
  if (!uri.startsWith(_packagePrefix)) {
    return path.normalize(path.join(
      currentDirectoryPath,
      uri.toString(),
    ));
  }

  final File packageConfigFile =
      File(path.join(projectDirectoryPath, '.dart_tool', 'package_config.json'));

  if (!await packageConfigFile.exists()) {
    throw const DartToolFolderNotFoundException();
  }

  final Map<dynamic, dynamic> packageConfigJson =
      await packageConfigFile.readAsString().then((String value) => jsonDecode(value));

  final List<PackageInfo> packages = <PackageInfo>[
    for (final Map<dynamic, dynamic> packageJson in packageConfigJson['packages'])
      PackageInfo.fromJson(packageJson)
  ];

  final String packageName = uri.substring(_packagePrefix.length, uri.indexOf('/'));
  final PackageInfo? targetPackage =
      packages.firstWhereOrNull((PackageInfo package) => package.name == packageName);

  if (targetPackage == null) {
    throw PackageNotFoundException(packageName);
  }

  String packageRootUri = targetPackage.rootUri.path;
  if (path.isRelative(packageRootUri)) {
    // This relative path starts from '.dart_tool' folder so the first back level is not needed
    packageRootUri = packageRootUri.replaceFirst('../', '');
  }

  return path.normalize(
    path.join(
      projectDirectoryPath,
      packageRootUri,
      targetPackage.packageUri.path,
      // uri format = package:package_name/path/to/file.dart
      // we need to extract the 'path/to/file.dart'
      uri.substring(1 + uri.indexOf('/')),
    ),
  );
}

/// Represents an entry for a package on `.dart_tool/package_config.json`
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
