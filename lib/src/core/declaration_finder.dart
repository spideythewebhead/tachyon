import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/core/find_package_path_by_import.dart';
import 'package:tachyon/src/core/parsed_file_data.dart';
import 'package:tachyon/src/core/parsed_files_registry.dart';
import 'package:tachyon/src/core/tachyon.dart';

/// Helper class that allows to find a [ClassDeclaration] or [EnumDeclaration] in an indexed project
///
class DeclarationFinder {
  DeclarationFinder({
    required final String projectDirectoryPath,
    required final ParsedFilesRegistry parsedFilesRegistry,
  })  : _projectDirectoryPath = projectDirectoryPath,
        _parsedFilesRegistry = parsedFilesRegistry;

  final String _projectDirectoryPath;
  final ParsedFilesRegistry _parsedFilesRegistry;

  Future<FinderDeclarationMatch<NamedCompilationUnitMember>?> findClassOrEnumDeclarationByName(
    String name, {
    required String targetFilePath,
  }) async {
    if (_parsedFilesRegistry[targetFilePath] == null) {
      return null;
    }
    return await _findDeclarationByName(
      name,
      compilationUnit: _parsedFilesRegistry.getParsedFileData(targetFilePath).compilationUnit,
      targetFilePath: targetFilePath,
      currentDirectoryPath: Tachyon.fileSystem.file(targetFilePath).parent.absolute.path,
    );
  }

  Future<FinderDeclarationMatch<FunctionDeclaration>?> findFunctionDeclarationByName(
    String name, {
    required String targetFilePath,
  }) async {
    if (_parsedFilesRegistry[targetFilePath] == null) {
      return null;
    }
    return await _findDeclarationByName<FunctionDeclaration>(
      name,
      compilationUnit: _parsedFilesRegistry.getParsedFileData(targetFilePath).compilationUnit,
      targetFilePath: targetFilePath,
      currentDirectoryPath: Tachyon.fileSystem.file(targetFilePath).parent.absolute.path,
    );
  }

  Future<FinderDeclarationMatch<T>?> _findDeclarationByName<T extends NamedCompilationUnitMember>(
    String name, {
    required CompilationUnit compilationUnit,
    required String targetFilePath,
    required String currentDirectoryPath,
  }) async {
    // Check if declaration exists on the same file
    T? nodeDeclaration = _findDeclaration<T>(name: name, unit: compilationUnit);
    if (nodeDeclaration != null) {
      return FinderDeclarationMatch<T>(
        node: nodeDeclaration,
        filePath: targetFilePath,
      );
    }

    // List of parsed files from import directives that are indexed
    final List<ParsedFileData> parsedFiles = <ParsedFileData>[];

    for (final Directive directive in compilationUnit.directives) {
      String? directiveUri;

      if (directive is ImportDirective) {
        directiveUri = directive.uri.stringValue;
      }

      if (directiveUri == null) {
        continue;
      }

      final String? dartFilePath = await findDartFileFromDirectiveUri(
        projectDirectoryPath: _projectDirectoryPath,
        currentDirectoryPath: currentDirectoryPath,
        uri: directiveUri,
      );

      // If import file not found or the file is not part of the project skip
      if (dartFilePath == null || !path.isWithin(_projectDirectoryPath, dartFilePath)) {
        continue;
      }

      if (_parsedFilesRegistry.containsKey(dartFilePath)) {
        parsedFiles.add(_parsedFilesRegistry.getParsedFileData(dartFilePath));
      }
    }

    for (final ParsedFileData parsedFileData in parsedFiles) {
      // Check if declaration exists in import file
      nodeDeclaration = _findDeclaration(
        name: name,
        unit: parsedFileData.compilationUnit,
      );
      if (nodeDeclaration != null) {
        return FinderDeclarationMatch<T>(
          node: nodeDeclaration,
          filePath: parsedFileData.absolutePath,
        );
      }

      // If the declaration does not exists in the file, check if all the exports of the file
      final FinderDeclarationMatch<T>? match = await _recursivelyExploreExports(
        name,
        currentDirectoryPath:
            Tachyon.fileSystem.file(parsedFileData.absolutePath).parent.absolute.path,
        compilationUnit: parsedFileData.compilationUnit,
      );
      if (match != null) {
        return match;
      }
    }

    return null;
  }

  Future<FinderDeclarationMatch<T>?>
      _recursivelyExploreExports<T extends NamedCompilationUnitMember>(
    String name, {
    required String currentDirectoryPath,
    required CompilationUnit compilationUnit,
  }) async {
    for (final Directive directive in compilationUnit.directives) {
      if (directive is! ExportDirective) {
        continue;
      }

      final String? exportDartFilePath = await findDartFileFromDirectiveUri(
        projectDirectoryPath: _projectDirectoryPath,
        currentDirectoryPath: currentDirectoryPath,
        uri: directive.uri.stringValue!,
      );

      if (exportDartFilePath == null) {
        continue;
      }

      final ParsedFileData? parsedFileData = _parsedFilesRegistry[exportDartFilePath];
      if (parsedFileData == null) {
        continue;
      }

      // Check if declaration exists in file
      T? nodeDeclaration = _findDeclaration(name: name, unit: parsedFileData.compilationUnit);
      if (nodeDeclaration != null) {
        return FinderDeclarationMatch<T>(
          node: nodeDeclaration,
          filePath: parsedFileData.absolutePath,
        );
      }

      // If the declaration does not exists in the file, check if all the exports of the file
      final FinderDeclarationMatch<T>? match = await _recursivelyExploreExports(
        name,
        currentDirectoryPath: Tachyon.fileSystem.file(exportDartFilePath).parent.absolute.path,
        compilationUnit: parsedFileData.compilationUnit,
      );
      if (match != null) {
        return match;
      }
    }

    return null;
  }

  T? _findDeclaration<T extends NamedCompilationUnitMember>({
    required String name,
    required CompilationUnit unit,
  }) {
    for (final CompilationUnitMember declaration in unit.declarations) {
      if (declaration is T && declaration.name.lexeme == name) {
        return declaration;
      }
    }
    return null;
  }
}

final class FinderDeclarationMatch<T extends NamedCompilationUnitMember> {
  FinderDeclarationMatch({
    required this.node,
    required this.filePath,
  });

  final T node;
  final String filePath;
}
