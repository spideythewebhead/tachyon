import 'package:analyzer/dart/ast/ast.dart';

/// Data holder for a field declaration
///
/// This is a helper class so plugins can use it as a base class instead of using [FieldDeclaration]
/// directly in the code generators
class DeclarationInfo {
  DeclarationInfo({
    required this.name,
    required this.type,
    required this.metadata,
    required this.isNamed,
    required this.isRequired,
    required this.isPositional,
  });

  final String name;
  final TypeAnnotation? type;
  final List<Annotation> metadata;
  final bool isNamed;
  final bool isRequired;
  final bool isPositional;

  bool get isRequiredNamed => isRequired && isNamed;
  bool get isRequiredPositional => isRequired && isPositional;
}
