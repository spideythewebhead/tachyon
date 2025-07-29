import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/dart_tool_package_info.dart';
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

const String _kProjectDirPath = '/home/user/project';

void main() {
  late Directory projectDir;

  group(PackageResolver, () {
    setUp(() {
      Tachyon.fileSystem = MemoryFileSystem.test();
      projectDir = Tachyon.fileSystem.directory(_kProjectDirPath)..createSync(recursive: true);
    });

    tearDown(() {
      Tachyon.resetFileSystem();
    });

    group('.resolvePackages', () {
      test(
        'Throws "DartToolPackageConfigNotFoundException" if "package_config.json" is not found',
        () {
          expect(
            () => PackageResolver.resolvePackages(projectDir.path),
            throwsA(isA<DartToolPackageConfigNotFoundException>()),
          );
        },
      );

      test('Successfully parses packages', () {
        projectDir.childDirectory(kDartToolFolderName)
          ..createSync()
          ..childFile('package_config.json').writeAsStringSync(
            json.encode(<String, Object>{
              'configVersion': 2,
              'packages': <Map<String, String>>[
                <String, String>{
                  'name': 'package_1',
                  'rootUri': 'file://${projectDir.path}/package_1',
                  'packageUri': 'lib/',
                  'languageVersion': '3.0'
                },
                <String, String>{
                  'name': 'app_utils',
                  'rootUri': '../../packages/app_utils',
                  'packageUri': 'lib/',
                  'languageVersion': '3.0'
                },
              ]
            }),
          );

        final ResolvedPackages resolvedPackages = PackageResolver.resolvePackages(_kProjectDirPath);
        expect(resolvedPackages, hasLength(2));

        expect(
          resolvedPackages['package_1'],
          PackageInfo(
            name: 'package_1',
            rootUri: Uri.parse('file://${projectDir.path}/package_1'),
            packageUri: Uri.parse('lib/'),
            languageVersion: '3.0',
          ),
        );

        expect(
          resolvedPackages['app_utils'],
          PackageInfo(
            name: 'app_utils',
            rootUri: Uri.parse('../../packages/app_utils'),
            packageUri: Uri.parse('lib/'),
            languageVersion: '3.0',
          ),
        );
      });
    });

    group('getTachyonMainDartPath', () {
      test('Returns null due to missing package', () {
        projectDir.childDirectory(kDartToolFolderName)
          ..createSync()
          ..childFile('package_config.json').writeAsStringSync(
            json.encode(<String, Object>{
              'configVersion': 2,
              'packages': <Map<String, String>>[],
            }),
          );

        expect(PackageResolver.getTachyonMainDartPath(projectDir.path), isNull);
      });

      test('Returns null due to missing package', () {
        projectDir.childDirectory(kDartToolFolderName)
          ..createSync()
          ..childFile('package_config.json').writeAsStringSync(
            json.encode(<String, Object>{
              'configVersion': 2,
              'packages': <Map<String, String>>[],
            }),
          );

        expect(PackageResolver.getTachyonMainDartPath(projectDir.path), isNull);
      });

      test('Returns path when tachyon is available from an absolute path', () {
        projectDir.childDirectory(kDartToolFolderName)
          ..createSync()
          ..childFile('package_config.json').writeAsStringSync(
            json.encode(<String, Object>{
              'configVersion': 2,
              'packages': <Map<String, String>>[
                <String, String>{
                  'name': 'tachyon',
                  'rootUri': 'file:///home/pub.dev/tachyon',
                  'packageUri': 'lib/',
                  'languageVersion': '3.0',
                }
              ],
            }),
          );

        expect(
          PackageResolver.getTachyonMainDartPath(projectDir.path),
          '/home/pub.dev/tachyon/bin/tachyon.dart',
        );
      });

      test('Returns path when tachyon is available from a relative path', () {
        projectDir.childDirectory(kDartToolFolderName)
          ..createSync()
          ..childFile('package_config.json').writeAsStringSync(
            json.encode(<String, Object>{
              'configVersion': 2,
              'packages': <Map<String, String>>[
                <String, String>{
                  'name': 'tachyon',
                  'rootUri': '../../tachyon',
                  'packageUri': 'lib/',
                  'languageVersion': '3.0',
                }
              ],
            }),
          );

        expect(
          PackageResolver.getTachyonMainDartPath(projectDir.path),
          projectDir.parent
              .childDirectory('tachyon')
              .childDirectory('bin')
              .childFile('tachyon.dart')
              .path,
        );
      });
    });
  });
}
