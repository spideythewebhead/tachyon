import 'package:tachyon/src/core/packages_dependency_graph.dart';
import 'package:test/test.dart';

void main() {
  group('hasDependency', () {
    test('Checks if "a" has dependency on "b" and returns true', () {
      final PackagesDependencyGraph depGraph = PackagesDependencyGraph();
      depGraph.add('a', 'b');
      expect(depGraph.hasDependency('a', 'b'), isTrue);
    });

    test('Checks if "a" has dependency on "c" and returns false', () {
      final PackagesDependencyGraph depGraph = PackagesDependencyGraph();
      depGraph.add('a', 'b');
      expect(depGraph.hasDependency('a', 'c'), isFalse);
    });
  });

  group('getDependents', () {
    test('Gets dependents of "b" and should contain "a" and "c"', () {
      final PackagesDependencyGraph depGraph = PackagesDependencyGraph();
      depGraph
        ..add('a', 'b')
        ..add('c', 'b');

      expect(
        depGraph.getDependents('b'),
        containsAll(<String>['a', 'c']),
      );
    });
  });

  group('clear', () {
    test('Clears dependencies and dependants', () {
      final PackagesDependencyGraph depGraph = PackagesDependencyGraph();
      depGraph
        ..add('a', 'b')
        ..add('c', 'b');

      expect(
        depGraph.getDependents('b'),
        containsAll(<String>['a', 'c']),
      );
      expect(depGraph.hasDependency('a', 'b'), isTrue);

      depGraph.clear();

      expect(depGraph.getDependents('b'), isEmpty);
      expect(depGraph.hasDependency('a', 'b'), isFalse);
    });
  });
}
