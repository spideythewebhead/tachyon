import 'package:analyzer/dart/ast/ast.dart';

/// Data class that contains
///
/// 1. The absolute file path
/// 2. The compilation unit (dart parsed content) for a file
/// 3. The last modified date
class ParsedFileData {
  ParsedFileData({
    required this.absolutePath,
    required this.compilationUnit,
    required this.lastModifiedAt,
  });

  final String absolutePath;
  final CompilationUnit compilationUnit;
  final DateTime lastModifiedAt;
}
