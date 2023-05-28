import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

void main() {
  test('Collects 3 classes', () {
    final CompilationUnit compilationUnit = parseString(content: '''
class A {}
class B {}

void main() {}

class C {}
''').unit;

    final ClassCollectorAstVisitor visitor =
        ClassCollectorAstVisitor(matcher: (ClassDeclaration node) => true);
    compilationUnit.visitChildren(visitor);

    expect(visitor.matchedNodes, hasLength(3));
  });
}
