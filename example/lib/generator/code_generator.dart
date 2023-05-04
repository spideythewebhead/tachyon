import 'dart:async';

import 'package:tachyon/tachyon.dart';

const String _kProvideExceptionsAnnotationName = 'ProvideExceptions';

class MyCustomCodeGenerator extends TachyonPluginCodeGenerator {
  @override
  FutureOr<String> generate(
    // BuildInfo provides the following
    // 1. Project directory
    // 2. Target file absolute path
    // 3. Compilation unit of the current file
    BuildInfo buildInfo,
    // TachyonDeclarationFinder is a helper that lets you find a class or an enum through the indexed project
    TachyonDeclarationFinder declarationFinder,
    Logger logger,
  ) {
    // CodeWriter is a helper class that lets you write a big content of strings
    final CodeWriter codeWriter = CodeWriter.stringBuffer();

    // Find all the classes that have the annotation 'ProvideExceptions'
    final List<ClassDeclaration> matchingClasses = buildInfo.compilationUnit.declarations
        .where((CompilationUnitMember member) =>
            member is ClassDeclaration &&
            // hasAnnotationWithName is a helper extension
            member.metadata.hasAnnotationWithName(_kProvideExceptionsAnnotationName))
        .cast<ClassDeclaration>()
        .toList(growable: false);

    for (final ClassDeclaration clazz in matchingClasses) {
      final String className = clazz.name.lexeme;
      // AnnotationValueExtractor let's you manipulate an annotation and get the content for different fields
      final AnnotationValueExtractor annotationValueExtractor = AnnotationValueExtractor(
          clazz.metadata.getAnnotationWithName(_kProvideExceptionsAnnotationName));

      final Expression? expression = annotationValueExtractor.getPositionedArgument(0);
      if (expression is! ListLiteral) {
        continue;
      }

      codeWriter.writeln('class ${className}Exception implements Exception {');
      for (final CollectionElement element in expression.elements) {
        if (element is! StringLiteral) {
          continue;
        }
        codeWriter.writeln(
            'factory ${className}Exception.${element.stringValue}([String? message]) = _${className}Exception\$${element.stringValue};');
      }
      codeWriter
        ..writeln('}')
        ..writeln();

      for (final CollectionElement element in expression.elements) {
        if (element is! StringLiteral) {
          continue;
        }
        codeWriter
          ..writeln(
              'class _${className}Exception\$${element.stringValue} implements ${className}Exception {')
          ..writeln('_${className}Exception\$${element.stringValue}([this.message]);')
          ..writeln()
          ..writeln('final String? message;')
          ..writeln()
          ..writeln('@override')
          ..writeln('String toString() {')
          ..writeln("return '$className.${element.stringValue}(message: \$message)';")
          ..writeln('}')
          ..writeln()
          ..writeln('}');
      }
    }

    return codeWriter.content;
  }
}
