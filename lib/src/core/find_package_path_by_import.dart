import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/dart_tool_package_info.dart';
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/src/core/tachyon.dart';
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
/// 1. [DartToolPackageConfigNotFoundException] if `pub get` was not executed in this project
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

  final File packageConfigFile = Tachyon.fileSystem
      .file(path.join(projectDirectoryPath, kDartToolFolderName, 'package_config.json'));

  if (!await packageConfigFile.exists()) {
    throw const DartToolPackageConfigNotFoundException();
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

  switch (targetPackage.packageUri?.toFilePath()) {
    case String packageUriPath:
      String packageRootUri = targetPackage.rootUri.toFilePath();
      if (path.isRelative(packageRootUri)) {
        // This relative path starts from '.dart_tool' folder so the first back level is not needed
        packageRootUri = packageRootUri.replaceFirst('..${path.separator}', '');
      }

      return path.normalize(
        path.join(
          path.isRelative(packageUriPath) ? projectDirectoryPath : '',
          packageRootUri,
          packageUriPath,
          // uri format = package:package_name/path/to/file.dart
          // we need to extract the 'path/to/file.dart'
          uri.substring(1 + uri.indexOf('/')),
        ),
      );
    default:
      return null;
  }
}

/// Represents an entry for a package on `.dart_tool/package_config.json`
