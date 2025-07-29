import 'dart:async';

import 'package:tachyon/tachyon.dart';

class MyCustomCodeGenerator extends TachyonPluginCodeGenerator {
  @override
  FutureOr<String> generate(
    // BuildInfo provides the following
    // 1. Project directory
    // 2. Target file absolute path
    // 3. Compilation unit of the current file
    FileChangeBuildInfo buildInfo,
    // TachyonDeclarationFinder is a helper that lets you find a class or an enum through the indexed project
    TachyonDeclarationFinder declarationFinder,
    Logger logger,
  ) async {
    // CodeWriter is a helper class that lets you write a big content of strings
    final CodeWriter codeWriter = CodeWriter.stringBuffer();

    const List<String> listOfClasses = <String>['User', 'Address'];

    for (final String className in listOfClasses) {
      final FinderDeclarationMatch<NamedCompilationUnitMember>? userClassMatch =
          await declarationFinder.findClassOrEnum(className);

      if (userClassMatch == null) {
        continue;
      }

      final NamedCompilationUnitMember clazz = userClassMatch.node;
      if (clazz is! ClassDeclaration) {
        continue;
      }

      codeWriter.writeln('extension ${className}CopyWithExtension on $className {');

      codeWriter.write('$className copyWith({');

      for (final ClassMember member in clazz.members) {
        if (member is! FieldDeclaration) {
          continue;
        }

        if (!member.fields.isFinal) {
          continue;
        }

        final TachyonDartType type = TachyonDartType.fromTypeAnnotation(member.fields.type);
        for (final VariableDeclaration variable in member.fields.variables) {
          codeWriter.write(type.fullTypeName);

          final String variableName = variable.name.lexeme;
          if (type.isNullable) {
            codeWriter.write(' ');
          } else {
            codeWriter.write('? ');
          }

          codeWriter
            ..write(variableName)
            ..write(',');
        }
      }

      codeWriter.write('}) { return $className(');

      for (final ClassMember member in clazz.members) {
        if (member is! FieldDeclaration) {
          continue;
        }

        if (!member.fields.isFinal) {
          continue;
        }

        for (final VariableDeclaration variable in member.fields.variables) {
          final String variableName = variable.name.lexeme;

          codeWriter
            ..write(variableName)
            ..write(': ')
            ..write(variableName)
            ..write(' ?? ')
            ..write('this.')
            ..write(variableName)
            ..write(',');
        }
      }

      codeWriter
        ..write(');')
        ..write('}')
        ..writeln('}');
    }

    return codeWriter.content;
  }
}
