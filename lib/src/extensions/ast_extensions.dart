import 'package:analyzer/dart/ast/ast.dart';
import 'package:tachyon/src/extensions/core_extensions.dart';

extension AnnotationNodeListX on NodeList<Annotation> {
  bool hasAnnotationWithName(String name) =>
      any((Annotation annotation) => annotation.name.name == name);

  Annotation? getAnnotationWithName(String name) =>
      firstWhereOrNull((Annotation annotation) => annotation.name.name == name);
}

extension ClassDeclarationX on ClassDeclaration {
  bool hasFactory(String factoryName) {
    return null !=
        members.firstWhereOrNull((ClassMember member) {
          return member is ConstructorDeclaration &&
              member.factoryKeyword != null &&
              member.name?.lexeme == factoryName;
        });
  }

  bool hasMethod(String methodName) {
    return null !=
        members.firstWhereOrNull((ClassMember member) {
          return member is MethodDeclaration && member.name.lexeme == methodName;
        });
  }
}

extension EnumDeclarationX on EnumDeclaration {
  bool hasFactory(String factoryName) {
    return null !=
        members.firstWhereOrNull((ClassMember member) {
          return member is ConstructorDeclaration &&
              member.factoryKeyword != null &&
              member.name?.lexeme == factoryName;
        });
  }

  bool hasMethod(String methodName) {
    return null !=
        members.firstWhereOrNull((ClassMember member) {
          return member is MethodDeclaration && member.name.lexeme == methodName;
        });
  }
}
