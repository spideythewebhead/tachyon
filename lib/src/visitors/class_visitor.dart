import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:tachyon/src/typedefs.dart';

/// An AST Visitor that collects a single [ClassDeclaration] node matched by [matcher]
class ClassAstVisitor extends RecursiveAstVisitor<void> {
  ClassAstVisitor({
    required this.matcher,
  });

  /// A convenient matcher to find a [ClassDeclaration] in a specific offset
  static ClassDeclarationNodeMatcher offsetMatcher(int offset) {
    return (ClassDeclaration node) {
      return node.offset <= offset && offset <= node.rightBracket.offset;
    };
  }

  final ClassDeclarationNodeMatcher matcher;

  ClassDeclaration? _classNode;

  /// Provides the matched [ClassDeclaration] node if any, after calling [AstNode.visitChildren]
  ClassDeclaration? get classNode => _classNode;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (matcher(node)) {
      _classNode = node;
    }

    if (_classNode != null) {
      return;
    }

    node.visitChildren(this);
  }
}
