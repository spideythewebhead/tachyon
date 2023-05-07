import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:tachyon/src/typedefs.dart';

/// An AST Visitor that collects all the [ClassDeclaration] nodes matched by [matcher]
class ClassCollectorAstVisitor extends GeneralizingAstVisitor<void> {
  ClassCollectorAstVisitor({
    required this.matcher,
  });

  final ClassDeclarationNodeMatcher matcher;

  final List<ClassDeclaration> _matchesNodes = <ClassDeclaration>[];

  /// Provides all the matched [ClassDeclaration] nodes after calling [AstNode.visitChildren]
  List<ClassDeclaration> get matchedNodes => List<ClassDeclaration>.unmodifiable(_matchesNodes);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (matcher(node)) {
      _matchesNodes.add(node);
      return;
    }
    node.visitChildren(this);
  }
}
