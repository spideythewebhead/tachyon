import 'package:analyzer/dart/ast/ast.dart';
import 'package:tachyon/src/extensions/extensions.dart';

/// Helper class that allows to interact with [Annotation].
///
/// Provides convenient methods to extract positioned and named arguments values from an annotation.
class AnnotationValueExtractor {
  AnnotationValueExtractor(this._annotation);

  final Annotation? _annotation;
  late final List<Expression> _arguments =
      _annotation?.arguments?.arguments ?? const <Expression>[];

  /// Returns a raw [Expression] for a positioned argument
  Expression? getPositionedArgument(int position) {
    try {
      return _arguments[position];
    } catch (_) {
      return null;
    }
  }

  /// Returns a [String] at [position].
  ///
  /// Returns null if not found.
  ///
  /// Example:
  /// ```dart
  /// class HttpService {
  ///   @HttpRoute.get('/users')
  ///   Future<HttpResponse> getUsers();
  /// }
  ///
  /// final String? endpointPath = AnnotationValueExtractor(methodDeclaration.getHttpRouteAnnotation())
  ///   .getPositionedString(0);
  /// ```
  String? getPositionedString(int position) {
    final Expression? expression = getPositionedArgument(position);
    if (expression is StringLiteral) {
      return expression.stringValue;
    }
    return null;
  }

  /// Returns a [String] for a named argument.
  ///
  /// Returns null if not found.
  ///
  /// Example:
  /// ```dart
  /// @DataClass(constructorName: '_')
  /// class User { ... }
  ///
  /// final String constructorName = AnnotationValueExtractor(classDeclaration.getDataClassAnnotation())
  ///   .getString('constructorName') ?? 'ctor';
  /// ```
  String? getString(String fieldName) {
    final NamedExpression? argument = _findNamedExpressionByName(fieldName);
    final Expression? argumentExpression = argument?.expression;
    if (argumentExpression is SimpleStringLiteral) {
      return argumentExpression.stringValue;
    }
    return null;
  }

  /// Returns a [bool] value for a named argument.
  ///
  /// Returns null if not found.
  ///
  /// Example:
  /// ```dart
  /// @DataClass(fromJson: true)
  /// class User { ... }
  ///
  /// final bool shouldGenerateFromJson = AnnotationValueExtractor(classDeclaration.getDataClassAnnotation())
  ///   .getBool('fromJson') ?? false;
  /// ```
  bool? getBool(String fieldName) {
    final NamedExpression? argument = _findNamedExpressionByName(fieldName);
    final Expression? argumentExpression = argument?.expression;
    if (argumentExpression is BooleanLiteral) {
      return argumentExpression.value;
    }
    return null;
  }

  /// Returns the value of an [Enum] for a named argument.
  ///
  /// Returns null if not found.
  ///
  /// Example:
  /// ```dart
  /// class User {
  ///   @JsonKey(nameConvention: JsonKeyNameConvention.snakeCase)
  ///   String get username;
  /// }
  ///
  /// final String? namingConvention = AnnotationValueExtractor(fieldDeclaration.getJsonKeyAnnotation())
  ///   .getEnumValue('nameConvention') ?? 'camelCase';
  /// ```
  String? getEnumValue(String fieldName) {
    final NamedExpression? argument = _findNamedExpressionByName(fieldName);
    if (argument is NamedExpression && argument.expression is PrefixedIdentifier) {
      return (argument.expression as PrefixedIdentifier).identifier.name;
    }
    return null;
  }

  /// Returns the name of the [Function] for a named argument.
  ///
  /// Returns null if not found.
  ///
  /// Example:
  /// ```dart
  /// @DataClass(fromJson: true)
  /// class User { ... }
  ///
  /// final bool shouldGenerateFromJson = AnnotationValueExtractor(classDeclaration.getDataClassAnnotation())
  ///   .getBool('fromJson') ?? false;
  /// ```
  String? getFunction(String fieldName) {
    final NamedExpression? argument = _findNamedExpressionByName(fieldName);
    if (argument is NamedExpression) {
      final Expression argumentExpression = argument.expression;
      if (argumentExpression is Identifier) {
        return argumentExpression.name;
      }
    }
    return null;
  }

  /// Returns a [String] at [position].
  ///
  /// Returns null if not found.
  ///
  /// Example:
  /// ```dart
  /// class HttpService {
  ///   @HttpRoute.get('/users')
  ///   Future<HttpResponse> getUsers();
  /// }
  ///
  /// final String? endpointPath = AnnotationValueExtractor(methodDeclaration.getHttpRouteAnnotation())
  ///   .getNamedConstructorName(); // 'get'
  /// ```
  String? getNamedConstructorName() {
    final Identifier? annotationName = _annotation?.name;
    if (annotationName is PrefixedIdentifier) {
      return annotationName.identifier.name;
    }
    return null;
  }

  NamedExpression? _findNamedExpressionByName(String name) {
    return _arguments.firstWhereOrNull((Expression expression) {
      return expression is NamedExpression && expression.name.label.name == name;
    }) as NamedExpression?;
  }
}
