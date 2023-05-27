import 'package:analyzer/dart/ast/ast.dart';

/// Data class that contains information for a changed file build
class FileChangeBuildInfo {
  FileChangeBuildInfo({
    required this.projectDirectoryPath,
    required this.targetFilePath,
    required this.compilationUnit,
  });

  /// Absolute path for the project directory
  final String projectDirectoryPath;

  /// Absolute path for the target file
  final String targetFilePath;

  /// AST for the parsed file
  final CompilationUnit compilationUnit;
}
