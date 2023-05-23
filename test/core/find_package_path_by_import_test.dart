import 'package:file/memory.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/src/core/find_package_path_by_import.dart';
import 'package:test/test.dart';

const String _kProjectDir = '/home/user/project';

void main() {
  test('Returns null if package starts with "dart:"', () async {
    final String? filePath = await findDartFileFromDirectiveUri(
      projectDirectoryPath: '',
      currentDirectoryPath: '',
      uri: 'dart:io',
      fileSystem: MemoryFileSystem(),
    );
    expect(filePath, isNull);
  });

  test('Returns path from relative import', () async {
    final String? filePath = await findDartFileFromDirectiveUri(
      projectDirectoryPath: '',
      currentDirectoryPath: path.join(_kProjectDir, 'lib', 'widgets'),
      uri: '../user.dart',
      fileSystem: MemoryFileSystem(),
    );
    expect(
      filePath,
      equals(path.join(_kProjectDir, 'lib', 'user.dart')),
    );
  });

  group('package import', () {
    late MemoryFileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test();
    });

    test('Throws exception if "package_config.json" is not found', () async {
      expect(
        () {
          return findDartFileFromDirectiveUri(
            projectDirectoryPath: _kProjectDir,
            currentDirectoryPath: '',
            uri: 'package:tachyon/tachyon.dart',
            fileSystem: fs,
          );
        },
        throwsA(isA<DartToolFolderNotFoundException>()),
      );
    });

    test('Returns path from import that starts with "package:"', () async {
      fs.file(path.join(_kProjectDir, kDartToolFolderName, 'package_config.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('''
            {
              "configVersion": 2,
              "packages": [
                {
                  "name": "tachyon",
                  "rootUri": "file:///home/user/.pub-cache/hosted/pub.dev/tachyon-0.0.1",
                  "packageUri": "lib/",
                  "languageVersion": "2.17"
                }
              ]
            }
          ''');

      expect(
        await findDartFileFromDirectiveUri(
          projectDirectoryPath: _kProjectDir,
          currentDirectoryPath: '',
          uri: 'package:tachyon/tachyon.dart',
          fileSystem: fs,
        ),
        equals(path.join(
          '/home/user/.pub-cache/hosted/pub.dev/tachyon-0.0.1',
          'lib',
          'tachyon.dart',
        )),
      );
    });

    test('Returns path from import that starts with "package:" that is relative', () async {
      fs.file(path.join(_kProjectDir, kDartToolFolderName, 'package_config.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('''
            {
              "configVersion": 2,
              "packages": [
                {
                  "name": "mypackage",
                  "rootUri": "../packages/mypackage",
                  "packageUri": "lib/",
                  "languageVersion": "2.17"
                }
              ]
            }
          ''');

      expect(
        await findDartFileFromDirectiveUri(
          projectDirectoryPath: _kProjectDir,
          currentDirectoryPath: '',
          uri: 'package:mypackage/mypackage.dart',
          fileSystem: fs,
        ),
        equals(path.join(
          _kProjectDir,
          'packages',
          'mypackage',
          'lib',
          'mypackage.dart',
        )),
      );
    });

    test('Throws PackageNotFoundException', () async {
      fs.file(path.join(_kProjectDir, kDartToolFolderName, 'package_config.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('''
            {
              "configVersion": 2,
              "packages": [
              ]
            }
          ''');

      expect(
        () {
          return findDartFileFromDirectiveUri(
            projectDirectoryPath: _kProjectDir,
            currentDirectoryPath: '',
            uri: 'package:mypackage/mypackage.dart',
            fileSystem: fs,
          );
        },
        throwsA(isA<PackageNotFoundException>()),
      );
    });
  });
}
