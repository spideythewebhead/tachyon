/// A simple bi-directional dependency graph
class PackagesDependencyGraph {
  // Contains all dependencies for a single node
  final Map<String, Set<String>> _nodeDependencies = <String, Set<String>>{};
  // Contains all depedents for a single node
  final Map<String, Set<String>> _nodeDependents = <String, Set<String>>{};

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
}
