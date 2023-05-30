import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Helper class that allows to interact with [TypeAnnotation]
///
/// Provides convenient methods to check primitive types and get the full declared type
///
/// TODO(pantelis): support check for function type
class TachyonDartType {
  TachyonDartType({
    this.prefix,
    required this.name,
    required this.fullTypeName,
    required this.typeArguments,
  });

  factory TachyonDartType.fromTypeAnnotation(TypeAnnotation? typeAnnotation) {
    final List<TachyonDartType> typeArguments = <TachyonDartType>[];

    if (typeAnnotation is NamedType) {
      final List<TypeAnnotation> arguments =
          typeAnnotation.typeArguments?.arguments ?? const <TypeAnnotation>[];
      for (final TypeAnnotation argument in arguments) {
        typeArguments.add(argument.customDartType);
      }
    }

    Token? nameToken;
    String? prefix;

    if (typeAnnotation is NamedType) {
      if (typeAnnotation.importPrefix != null) {
        prefix = typeAnnotation.importPrefix!.name.lexeme;
        nameToken = typeAnnotation.name2;
      }
    }
    nameToken ??= typeAnnotation?.beginToken;

    return TachyonDartType(
      prefix: prefix,
      name: nameToken?.lexeme ?? 'dynamic',
      fullTypeName: typeAnnotation?.toSource() ?? 'dynamic',
      typeArguments: List<TachyonDartType>.unmodifiable(typeArguments),
    );
  }

  final String? prefix;
  final String name;
  final String fullTypeName;
  final List<TachyonDartType> typeArguments;

  static final TachyonDartType dynamic = TachyonDartType(
    name: 'dynamic',
    fullTypeName: 'dynamic',
    typeArguments: List<TachyonDartType>.unmodifiable(const <TachyonDartType>[]),
  );

  bool get isInt => name == 'int';

  bool get isDouble => name == 'double';

  bool get isDynamic => name == 'dynamic';

  bool get isNum => name == 'num';

  bool get isList => name == 'List';

  bool get isMap => name == 'Map';

  bool get isString => name == 'String';

  bool get isBool => name == 'bool';

  bool get isDuration => name == 'Duration';

  bool get isDateTime => name == 'DateTime';

  bool get isUri => name == 'Uri';

  bool get isNullable => fullTypeName.endsWith('?');

  bool get isPrimitive {
    return isString || isBool || isDouble || isInt || isNum;
  }

  bool get isCollection {
    return isList || isMap;
  }

  bool get isVoid => name == 'void';
}

extension TachyonDartTypeAstTypeAnnotationExtension on TypeAnnotation? {
  TachyonDartType get customDartType => TachyonDartType.fromTypeAnnotation(this);
}
