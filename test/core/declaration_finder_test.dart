import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:tachyon/src/core/declaration_finder.dart';
import 'package:tachyon/src/core/parse_file_extension.dart';
import 'package:tachyon/src/core/parsed_file_data.dart';
import 'package:tachyon/src/core/parsed_files_registry.dart';
import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

import '../utils.dart';

const String _kProjectDirPath = '/home/user/project';

void main() {
  late Directory projectDir;

  setUp(() {
    Tachyon.fileSystem = MemoryFileSystem.test();
    projectDir = Tachyon.fileSystem.directory(_kProjectDirPath)..createSync(recursive: true);
  });

  tearDownAll(() {
    projectDir.safelyRecursivelyDeleteSync();
  });

  group('findClassOrEnumDeclarationByName', () {
    test('Finds class in the same file', () async {
      final ParsedFilesRegistry parsedFilesRegistry = ParsedFilesRegistry();
      final DeclarationFinder declarationFinder = DeclarationFinder(
        projectDirectoryPath: projectDir.path,
        parsedFilesRegistry: parsedFilesRegistry,
      );

      final File mainDartFile = projectDir.childFile('main.dart');
      mainDartFile.writeAsStringSync('''
class A {}

class B {}

class C {}
''');

      parsedFilesRegistry[mainDartFile.path] = ParsedFileData(
        absolutePath: mainDartFile.path,
        compilationUnit: mainDartFile.path.parseDart().unit,
        lastModifiedAt: mainDartFile.lastModifiedSync(),
      );

      final ClassOrEnumDeclarationMatch? match =
          await declarationFinder.findClassOrEnumDeclarationByName(
        'B',
        targetFilePath: mainDartFile.path,
      );

      expect(
        match,
        isA<ClassOrEnumDeclarationMatch>()
            .having(
          (ClassOrEnumDeclarationMatch node) => node.filePath,
          'match absolute file path',
          mainDartFile.path,
        )
            .having(
          (ClassOrEnumDeclarationMatch m) {
            final NamedCompilationUnitMember node = m.node;
            if (node is! ClassDeclaration) {
              return null;
            }
            return node.name.lexeme;
          },
          'node name is "B"',
          'B',
        ),
      );
    });

    test('Finds class in a different file', () async {
      final ParsedFilesRegistry parsedFilesRegistry = ParsedFilesRegistry();
      final DeclarationFinder declarationFinder = DeclarationFinder(
        projectDirectoryPath: projectDir.path,
        parsedFilesRegistry: parsedFilesRegistry,
      );

      final File mainDartFile = projectDir.childFile('main.dart');
      mainDartFile.writeAsStringSync("import './user.dart';");

      final File userDartFile = projectDir.childFile('user.dart')
        ..writeAsStringSync('class User {}');

      parsedFilesRegistry
        ..[mainDartFile.path] = ParsedFileData(
          absolutePath: mainDartFile.path,
          compilationUnit: mainDartFile.path.parseDart().unit,
          lastModifiedAt: mainDartFile.lastModifiedSync(),
        )
        ..[userDartFile.path] = ParsedFileData(
          absolutePath: userDartFile.path,
          compilationUnit: userDartFile.path.parseDart().unit,
          lastModifiedAt: userDartFile.lastModifiedSync(),
        );

      final ClassOrEnumDeclarationMatch? match =
          await declarationFinder.findClassOrEnumDeclarationByName(
        'User',
        targetFilePath: mainDartFile.path,
      );

      expect(
        match,
        isA<ClassOrEnumDeclarationMatch>()
            .having(
          (ClassOrEnumDeclarationMatch m) => m.filePath,
          'match absolute file path',
          userDartFile.path,
        )
            .having(
          (ClassOrEnumDeclarationMatch m) {
            final NamedCompilationUnitMember node = m.node;
            if (node is! ClassDeclaration) {
              return null;
            }
            return node.name.lexeme;
          },
          'node name is "User"',
          'User',
        ),
      );
    });

    test('Fails to find class in project', () async {
      final ParsedFilesRegistry parsedFilesRegistry = ParsedFilesRegistry();
      final DeclarationFinder declarationFinder = DeclarationFinder(
        projectDirectoryPath: projectDir.path,
        parsedFilesRegistry: parsedFilesRegistry,
      );

      final File mainDartFile = projectDir.childFile('main.dart')..createSync();
      final File userDartFile = projectDir.childFile('user.dart')..createSync();

      parsedFilesRegistry
        ..[mainDartFile.path] = ParsedFileData(
          absolutePath: mainDartFile.path,
          compilationUnit: mainDartFile.path.parseDart().unit,
          lastModifiedAt: mainDartFile.lastModifiedSync(),
        )
        ..[userDartFile.path] = ParsedFileData(
          absolutePath: userDartFile.path,
          compilationUnit: userDartFile.path.parseDart().unit,
          lastModifiedAt: userDartFile.lastModifiedSync(),
        );

      final ClassOrEnumDeclarationMatch? match =
          await declarationFinder.findClassOrEnumDeclarationByName(
        'NonExistent',
        targetFilePath: mainDartFile.path,
      );

      expect(match, isNull);
    });

    test('Fails to find class in the same file', () async {
      final ParsedFilesRegistry parsedFilesRegistry = ParsedFilesRegistry();
      final DeclarationFinder declarationFinder = DeclarationFinder(
        projectDirectoryPath: projectDir.path,
        parsedFilesRegistry: parsedFilesRegistry,
      );

      final File mainDartFile = projectDir.childFile('main.dart')..createSync();

      parsedFilesRegistry[mainDartFile.path] = ParsedFileData(
        absolutePath: mainDartFile.path,
        compilationUnit: mainDartFile.path.parseDart().unit,
        lastModifiedAt: mainDartFile.lastModifiedSync(),
      );

      final ClassOrEnumDeclarationMatch? match =
          await declarationFinder.findClassOrEnumDeclarationByName(
        'NonExistent',
        targetFilePath: mainDartFile.path,
      );

      expect(match, isNull);
    });

    test('Fails to find class if path is not found on files registry', () async {
      final ParsedFilesRegistry parsedFilesRegistry = ParsedFilesRegistry();
      final DeclarationFinder declarationFinder = DeclarationFinder(
        projectDirectoryPath: projectDir.path,
        parsedFilesRegistry: parsedFilesRegistry,
      );

      final File mainDartFile = projectDir.childFile('main.dart')..createSync();

      final ClassOrEnumDeclarationMatch? match =
          await declarationFinder.findClassOrEnumDeclarationByName(
        'MyClass',
        targetFilePath: mainDartFile.path,
      );

      expect(match, isNull);
    });
  });
}
