import 'dart:io' as io show Directory;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/dart_tool_package_info.dart';
import 'package:tachyon/src/core/tachyon_config.dart';
import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

import '../common_yaml_creators.dart';
import '../set_dart_sdk_version.dart';
import '../utils.dart';

const Logger _logger = NoOpLogger();

void main() {
  late Directory projectDir;

  setUpAll(() {
    setDartSdkVersion();
  });

  tearDown(() {
    projectDir.safelyRecursivelyDeleteSync();
  });

  group('getConfig', () {
    setUp(() {
      Tachyon.fileSystem = MemoryFileSystem.test();
      projectDir = Tachyon.fileSystem.directory(kProjectDirPath)..createSync(recursive: true);

      createCommonAnalysisOptionsYaml();
    });

    test('Returns instance from "tachyon_config.yaml"', () {
      Tachyon.fileSystem.file(path.join(kProjectDirPath, kTachyonConfigFileName))
        ..createSync()
        ..writeAsStringSync('''
generated_file_line_length: 100
file_generation_paths:
  - "lib/a.dart"
  - "lib/b.dart"
  - "lib/models/**"
        ''');

      final TachyonConfig config = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      ).getConfig();

      expect(
        config,
        isA<TachyonConfig>()
            .having(
              (TachyonConfig cfg) => cfg.generatedFileLineLength,
              'should have length 100',
              equals(100),
            )
            .having(
              (TachyonConfig cfg) => cfg.fileGenerationPaths.map((Glob glob) => glob.pattern),
              'should have 3 paths, "lib/a.dart","lib/b.dart","lib/models/**"',
              containsAll(
                <Glob>[
                  Glob('lib/a.dart'),
                  Glob('lib/b.dart'),
                  Glob('lib/models/**'),
                ].map((Glob glob) => glob.pattern),
              ),
            ),
      );
    });
  });

  group('indexProject', () {
    setUp(() {
      Tachyon.fileSystem = MemoryFileSystem.test();
      projectDir = Tachyon.fileSystem.directory(kProjectDirPath)..createSync(recursive: true);

      createCommonAnalysisOptionsYaml();
      createCommonTachyonYaml();
      createCommonPackageConfigJson();
    });

    test('Indexes 2 files in project', () async {
      Tachyon.fileSystem.directory(path.join(kProjectDirPath, 'lib')).createSync();

      Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'a.dart'))
        ..createSync()
        ..writeAsStringSync('');

      Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'b.dart'))
        ..createSync()
        ..writeAsStringSync('');

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );
      await tachyon.indexProject();

      expect(tachyon.parsedFilesPaths, hasLength(2));
    });

    test('Sets "b.dart" as dependency of "a.dart"', () async {
      Tachyon.fileSystem.directory(path.join(kProjectDirPath, 'lib')).createSync();

      final File fileA = Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'a.dart'))
        ..createSync()
        ..writeAsStringSync('''
          import 'b.dart';
        ''');

      final File fileB = Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'b.dart'))
        ..createSync()
        ..writeAsStringSync('');

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );
      await tachyon.indexProject();

      expect(tachyon.packagesDependencyGraph.hasDependency(fileA.path, fileB.path), isTrue);
      expect(
        tachyon.packagesDependencyGraph.getDependents(fileB.path),
        containsAllInOrder(<String>[fileA.path]),
      );
    });

    test('Indexes external package', () async {
      createCommonAnalysisOptionsYaml();

      createCommonTachyonYaml(
        projectPath: projectDir.path,
        externalPackages: <ExternalPackageConfig>[
          const ExternalPackageConfig(
            name: 'app',
            fileGenerationPaths: <Glob>[],
          ),
        ],
      );

      createCommonPackageConfigJson(
        projectPath: projectDir.path,
        packages: <PackageInfo>[
          PackageInfo(
            name: 'app',
            rootUri: Uri.parse('../packages/app'),
            packageUri: Uri.parse('lib/'),
            languageVersion: '3.0',
          ),
        ],
      );

      final File projectDartFile = projectDir.childDirectory('lib').childFile('a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('');

      final File externalPackageDartFile =
          projectDir
              .childDirectory('packages')
              .childDirectory('app')
              .childDirectory('lib')
              .childFile('app.dart')
            ..createSync(recursive: true)
            ..writeAsStringSync('');

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );
      await tachyon.indexProject();

      expect(tachyon.parsedFilesPaths, hasLength(2));
      expect(
        tachyon.parsedFilesPaths,
        containsAll(<String>[projectDartFile.path, externalPackageDartFile.path]),
      );
    });
  });

  group('buildProject', () {
    setUp(() {
      Tachyon.fileSystem = MemoryFileSystem.test();
      projectDir = Tachyon.fileSystem.directory(kProjectDirPath)..createSync(recursive: true);

      createCommonAnalysisOptionsYaml();
      createCommonTachyonYaml();
      createCommonPackageConfigJson();
    });

    test('Does not generate file if only the header is the content', () async {
      Tachyon.fileSystem.directory(path.join(kProjectDirPath, 'lib')).createSync();

      Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'a.dart'))
        ..createSync()
        ..writeAsStringSync('''
          import 'b.dart';
        ''');

      Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'b.dart'))
        ..createSync()
        ..writeAsStringSync('');

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );
      await tachyon.indexProject();
      await tachyon.buildProject();

      expect(
        Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'a.gen.dart')).existsSync(),
        isFalse,
      );

      expect(
        Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'b.gen.dart')).existsSync(),
        isFalse,
      );
    });

    test('Generates code using "addCodeGenerationHook" (without plugin)', () async {
      Tachyon.fileSystem.directory(path.join(kProjectDirPath, 'lib')).createSync();

      Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'a.dart'))
        ..createSync()
        ..writeAsStringSync('');

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );

      tachyon.addCodeGenerationHook(
        (CompilationUnit compilationUnit, String absoluteFilePath) async => '// THIS IS A TEST',
      );
      await tachyon.indexProject();
      await tachyon.buildProject();

      expect(
        Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'a.gen.dart')).existsSync(),
        isTrue,
      );

      expect(
        Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'a.gen.dart')).readAsStringSync(),
        equals(
          (StringBuffer()
                ..write(generateHeaderForPartFile('a.dart'))
                ..writeln('// THIS IS A TEST'))
              .toString(),
        ),
      );
    });
  });

  group('watchProject', () {
    setUp(() {
      Tachyon.resetFileSystem();
      projectDir = Tachyon.fileSystem.directory(
        path.join(io.Directory.current.path, 'test', '.tmp'),
      )..createSync(recursive: true);

      createCommonAnalysisOptionsYaml(projectPath: projectDir.path);
      createCommonTachyonYaml(projectPath: projectDir.path);
      createCommonPackageConfigJson(projectPath: projectDir.path);
    });

    test('Indexes newly created file', () async {
      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );

      await tachyon.watchProject(
        onReady: () async {
          final File fileA = Tachyon.fileSystem.file(path.join(projectDir.path, 'lib', 'a.dart'));

          tachyon.addWatchRebuildFinishedHook(
            expectAsync0(() async {
              expect(
                tachyon.parsedFilesPaths,
                containsAllInOrder(<String>[fileA.path]),
              );

              await tachyon.dispose();
            }),
          );

          fileA.createSync(recursive: true);
        },
      );
    });

    test('Deletes part file when main file is deleted', () async {
      final File fileA = Tachyon.fileSystem.file(path.join(projectDir.path, 'lib', 'a.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('');

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );

      tachyon.addCodeGenerationHook(
        (CompilationUnit compilationUnit, String absoluteFilePath) async => '// THIS IS A TEST',
      );

      await tachyon.watchProject(
        onReady: () async {
          final File fileAGen = Tachyon.fileSystem.file(
            path.join(projectDir.path, 'lib', 'a.gen.dart'),
          );
          expect(fileAGen.existsSync(), isTrue);

          tachyon.addWatchRebuildFinishedHook(
            expectAsync0(() async {
              expect(fileA.existsSync(), isFalse);
              expect(fileAGen.existsSync(), isFalse);

              await tachyon.dispose();
            }),
          );

          fileA.deleteSync();
        },
      );
    });

    test('When a new import is added, it is added as dependency', () async {
      Tachyon.fileSystem.file(path.join(projectDir.path, 'lib', 'a.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('int a = 1;');

      final File fileB = Tachyon.fileSystem.file(path.join(projectDir.path, 'lib', 'b.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('''import 'a.dart';''');

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );

      tachyon.addCodeGenerationHook(
        (CompilationUnit compilationUnit, String absoluteFilePath) async => '// THIS IS A TEST',
      );

      await tachyon.watchProject(
        onReady: () async {
          final File fileC = Tachyon.fileSystem.file(path.join(projectDir.path, 'lib', 'c.dart'))
            ..createSync(recursive: true)
            ..writeAsStringSync('');

          tachyon.addWatchRebuildFinishedHook(
            expectAsync0(() async {
              expect(
                tachyon.packagesDependencyGraph.hasDependency(fileB.path, fileC.path),
                isTrue,
              );

              await tachyon.dispose();
            }),
          );

          final IOSink fd = fileB.openWrite(mode: FileMode.append)..write("import 'c.dart';");
          await fd.flush();
          await fd.close();
        },
      );
    });
  });

  group('dispose', () {
    setUp(() {
      Tachyon.fileSystem = MemoryFileSystem.test();
      projectDir = Tachyon.fileSystem.directory(kProjectDirPath)..createSync(recursive: true);

      createCommonAnalysisOptionsYaml();
      createCommonTachyonYaml();
      createCommonPackageConfigJson();
    });

    test('Verifies that dispose hook is called', () async {
      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );

      bool isDisposeHookedCalled = false;
      tachyon.addDisposeHook(() => isDisposeHookedCalled = true);

      await tachyon.dispose();

      expect(isDisposeHookedCalled, true);
    });

    test('Clears resources', () async {
      Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'a.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('''
          import 'b.dart';
        ''');

      Tachyon.fileSystem.file(path.join(kProjectDirPath, 'lib', 'b.dart'))
        ..createSync()
        ..writeAsStringSync('');

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );
      await tachyon.indexProject();
      await tachyon.buildProject();

      expect(tachyon.packagesDependencyGraph, isNotEmpty);
      expect(tachyon.parsedFilesPaths, isNotEmpty);

      await tachyon.dispose();

      expect(tachyon.packagesDependencyGraph, isEmpty);
      expect(tachyon.parsedFilesPaths, isEmpty);
    });
  });

  group('calculateDependentsWeights', () {
    setUp(() {
      Tachyon.fileSystem = MemoryFileSystem.test();
      projectDir = Tachyon.fileSystem.directory(kProjectDirPath)..createSync(recursive: true);

      createCommonAnalysisOptionsYaml();
    });

    test('Calculates the weights for non cyclic graph', () async {
      createCommonTachyonYaml();
      createCommonPackageConfigJson();

      final File aDartFile = projectDir.childDirectory('lib').childFile('a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
import 'b.dart';
import 'd.dart';
''');

      final File bDartFile = projectDir.childDirectory('lib').childFile('b.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
import 'c.dart';
''');

      final File cDartFile = projectDir.childDirectory('lib').childFile('c.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('');

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );
      await tachyon.indexProject();

      final Map<String, int> dependents = tachyon.calculateDependentsWeights(cDartFile.path);

      expect(
        dependents,
        equals(<String, int>{
          bDartFile.path: 1,
          aDartFile.path: 1,
        }),
      );
    });

    test('Calculates the weights for a cyclic graph', () async {
      createCommonTachyonYaml();
      createCommonPackageConfigJson();

      final File aDartFile = projectDir.childDirectory('lib').childFile('a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
import 'b.dart';
import 'd.dart';
''');

      final File bDartFile = projectDir.childDirectory('lib').childFile('b.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
import 'c.dart';
''');

      final File cDartFile = projectDir.childDirectory('lib').childFile('c.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('');

      final File dDartFile = projectDir.childDirectory('lib').childFile('d.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
import 'a.dart';
import 'c.dart';
''');

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );
      await tachyon.indexProject();

      final Map<String, int> dependents = tachyon.calculateDependentsWeights(cDartFile.path);

      expect(
        dependents,
        equals(<String, int>{
          bDartFile.path: 1,
          dDartFile.path: 2,
          aDartFile.path: 2,
        }),
      );
    });
  });
}
