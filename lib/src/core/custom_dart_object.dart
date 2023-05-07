import 'package:analyzer/dart/ast/ast.dart';
import 'package:tachyon/src/extensions/extensions.dart';

/// Helper class that allows to interact with [Annotation]
///
/// Provides convenient methods to extract positioned and named parameters values from an annotation
class AnnotationValueExtractor {
  AnnotationValueExtractor(this._annotation);

  final Annotation? _annotation;
  late final List<Expression> _arguments =
      _annotation?.arguments?.arguments ?? const <Expression>[];

  @override
  String toString() {
    return 'AnnotationValueExtractor($_arguments)';
  }

  bool get isNotNull => _annotation != null;

  Expression? getPositionedArgument(int position) {
    try {
      return _arguments[position];
    } catch (_) {
      return null;
    }
  }

  String? getPositionedString(int position) {
    final Expression? expression = getPositionedArgument(position);
    if (expression is StringLiteral) {
      return expression.stringValue;
    }
    return null;
  }

  String? getString(String fieldName) {
    final NamedExpression? argument = _findNamedExpressionByName(fieldName);
    final Expression? argumentExpression = argument?.expression;
    if (argumentExpression is SimpleStringLiteral) {
      return argumentExpression.stringValue;
    }
    return null;
  }

  bool? getBool(String fieldName) {
    final NamedExpression? argument = _findNamedExpressionByName(fieldName);
    final Expression? argumentExpression = argument?.expression;
    if (argumentExpression is BooleanLiteral) {
      return argumentExpression.value;
    }
    return null;
  }

  String? getEnumValue(String fieldName) {
    final NamedExpression? argument = _findNamedExpressionByName(fieldName);
    if (argument is NamedExpression && argument.expression is PrefixedIdentifier) {
      return (argument.expression as PrefixedIdentifier).identifier.name;
    }
    return null;
  }

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

  String getNamedConstructorName() {
    return _annotation?.name.beginToken.next?.next?.lexeme ?? '';
  }

  NamedExpression? _findNamedExpressionByName(String name) {
    return _arguments.firstWhereOrNull((Expression expression) {
      return expression is NamedExpression && expression.name.label.name == name;
    }) as NamedExpression?;
  }
}
