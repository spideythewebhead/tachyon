import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/tachyon.dart';

class PackageResolver {
  /// If successful returns [ResolvedPackages]
  ///
  /// This method throws
  static ResolvedPackages resolvePackages(String projectPath) {
    final File packageConfigFile = Tachyon.fileSystem.file(
      path.join(
        projectPath,
        kDartToolFolderName,
        'package_config.json',
      ),
    );

    if (!packageConfigFile.existsSync()) {
      throw const DartToolPackageConfigNotFoundException();
    }

    final Map<String, dynamic> packageFileJson = json.decode(packageConfigFile.readAsStringSync());
    final Map<String, PackageInfo> packages = <String, PackageInfo>{
      for (final Map<dynamic, dynamic> packageJson in packageFileJson['packages'])
        packageJson['name'] as String: PackageInfo.fromJson(packageJson),
    };

    return ResolvedPackages(packages: packages);
  }

  static String? getTachyonDirectoryPath(String projectPath) {
    final PackageInfo? packageInfo = resolvePackages(projectPath)['tachyon'];
    if (packageInfo == null) {
      return null;
    }

    final String filePath = packageInfo.rootUri.toFilePath();
    if (path.isAbsolute(filePath)) {
      return filePath;
    }

    return path.normalize(
      path.join(
        path.normalize(
          path.join(
            projectPath,
            kDartToolFolderName,
            filePath,
          ),
        ),
      ),
    );
  }

  static String? getTachyonMainDartPath(String projectPath) {
    final String? directoryPath = getTachyonDirectoryPath(projectPath);

    if (directoryPath == null) {
      return null;
    }

    return path.join(directoryPath, 'bin', 'tachyon.dart');
  }
}

class ResolvedPackages with IterableMixin<PackageInfo> {
  ResolvedPackages({
    required Map<String, PackageInfo> packages,
  }) : _packages = packages;

  final Map<String, PackageInfo> _packages;

  PackageInfo? operator [](String name) => _packages[name];

  @override
  Iterator<PackageInfo> get iterator => _packages.values.iterator;
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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PackageInfo &&
            runtimeType == other.runtimeType &&
            name == other.name &&
            rootUri == other.rootUri &&
            packageUri == other.packageUri &&
            languageVersion == languageVersion;
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      name,
      rootUri,
      packageUri,
      languageVersion,
    );
  }

  /// Returns the absolute path for this package
  ///
  /// If [rootUri] is relative then is resolved against [projectPath]
  String resolveAbsolutePath({required String projectPath}) {
    String rootUriPath = rootUri.toFilePath();

    if (path.isRelative(rootUriPath)) {
      // relative paths also include ".dart_tool" so we need to delete 1 level
      rootUriPath = rootUriPath.replaceFirst('..${path.separator}', '');
      return path.join(projectPath, rootUriPath);
    }

    return rootUriPath;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'rootUri': rootUri.toString(),
      'packageUri': packageUri.toString(),
      'languageVersion': languageVersion,
    };
  }
}
