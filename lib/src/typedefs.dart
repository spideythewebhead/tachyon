import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:tachyon/src/core/declaration_finder.dart';

typedef ClassOrEnumDeclarationFinder = Future<ClassOrEnumDeclarationMatch?> Function(String name);

typedef ClassDeclarationNodeMatcher = bool Function(ClassDeclaration node);

typedef OnCodeGenerationHook = Future<String?> Function(
  CompilationUnit compilationUnit,
  String absoluteFilePath,
);

typedef OnDisposeHook = FutureOr<void> Function();
