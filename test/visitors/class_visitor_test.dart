import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

void main() {
  test('Collects a single class', () {
    final CompilationUnit compilationUnit = parseString(content: '''
class A {}
class B {}

void main() {}

class C {}
''').unit;

    final ClassAstVisitor visitor =
        ClassAstVisitor(matcher: (ClassDeclaration node) => node.name.lexeme == 'C');
    compilationUnit.visitChildren(visitor);

    expect(visitor.classNode, isNotNull);
  });
}
