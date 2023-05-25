/// A simple bi-directional dependency graph
class PackagesDependencyGraph {
  // Contains all dependencies for a single node
  final Map<String, Set<String>> _nodeDependencies = <String, Set<String>>{};
  // Contains all depedents for a single node
  final Map<String, Set<String>> _nodeDependents = <String, Set<String>>{};

  bool get isEmpty => _nodeDependencies.isEmpty && _nodeDependents.isEmpty;
  bool get isNotEmpty => !isEmpty;

  void add(String nodeName, String dependencyName) {
    (_nodeDependencies[nodeName] ??= <String>{}).add(dependencyName);
    (_nodeDependents[dependencyName] ??= <String>{}).add(nodeName);
  }

  List<String> getDependents(String nodeName) {
    return _nodeDependents[nodeName]?.toList(growable: false) ?? const <String>[];
  }

  bool hasDependency(String nodeName, String dependencyName) {
    return _nodeDependencies[nodeName]?.contains(dependencyName) ?? false;
  }

  void clear() {
    _nodeDependents.clear();
    _nodeDependencies.clear();
  }

  PackagesDependencyGraph getCopy() {
    return PackagesDependencyGraph()
      .._nodeDependencies.addAll(Map<String, Set<String>>.unmodifiable(_nodeDependencies))
      .._nodeDependents.addAll(Map<String, Set<String>>.unmodifiable(_nodeDependents));
  }
}
