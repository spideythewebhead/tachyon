import 'package:analyzer/dart/ast/ast.dart';

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
