import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_style/dart_style.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/code_writer.dart';
import 'package:tachyon/src/core/declaration_finder.dart';
import 'package:tachyon/src/core/find_package_path_by_import.dart';
import 'package:tachyon/src/core/generate_header_for_part_file.dart';
import 'package:tachyon/src/core/packages_dependency_graph.dart';
import 'package:tachyon/src/core/parse_file_extension.dart';
import 'package:tachyon/src/core/parsed_file_data.dart';
import 'package:tachyon/src/core/parsed_files_registry.dart';
import 'package:tachyon/src/core/tachyon_config.dart';
import 'package:tachyon/src/extensions/extensions.dart';
import 'package:tachyon/src/logger/console_logger.dart';
import 'package:tachyon/src/logger/logger.dart';
import 'package:tachyon/src/typedefs.dart';
import 'package:watcher/watcher.dart';
import 'package:yaml/yaml.dart';

final RegExp _dartFileNameMatcher = RegExp(r'^[a-zA-Z0-9_]+.dart$');
final RegExp _dartGeneratedFileNameMatcher = RegExp(r'.gen.dart$');

FileSystem _fs = const LocalFileSystem();

class Tachyon {
  static FileSystem get fileSystem => _fs;

  /// This override the default file system (io is the default file system).
  ///
  /// **This should be used only for testing**.
  @visibleForTesting
  static set fileSystem(FileSystem fs) {
    _fs = fs;
  }

  @visibleForTesting
  static void resetFileSystem() => fileSystem = const LocalFileSystem();

  @visibleForTesting
  static const Duration watchDebounceDuration = Duration(milliseconds: 100);

  Tachyon({
    required this.projectDir,
    final Logger? logger,
  })  : _watcher = DirectoryWatcher(projectDir.path),
        logger = logger ?? ConsoleLogger();

  final Directory projectDir;
  final Logger logger;
  final Watcher _watcher;

  final Map<String, Completer<void>?> _activeWrites = <String, Completer<void>?>{};
  final PackagesDependencyGraph _dependencyGraph = PackagesDependencyGraph();
  final ParsedFilesRegistry _filesPathsRegistry = ParsedFilesRegistry();

  late final DeclarationFinder declarationFinder = DeclarationFinder(
    projectDirectoryPath: projectDir.path,
    parsedFilesRegistry: _filesPathsRegistry,
  );

  final List<OnCodeGenerationHook> _codeGenerationHooks = <OnCodeGenerationHook>[];
  final List<OnDisposeHook> _disposeHooks = <OnDisposeHook>[];

  Completer<void>? _watchModeCompleter;
  StreamSubscription<WatchEvent>? _projectWatcherSubscription;

  /// Returns the absolute file paths for parsed (indexed) files.
  ///
  /// **This should be used only for testing**.
  @visibleForTesting
  List<String> get parsedFilesPaths => _filesPathsRegistry.keys.toList(growable: false);

  @visibleForTesting
  ParsedFileData getParsedFileDataForPath(String path) => _filesPathsRegistry[path]!;

  /// Returns the dependency graph for parsed (indexed) files.
  ///
  /// The [PackagesDependencyGraph] is an immutable copy of the underlaying graph,
  /// so any changes won't affect the real graph.
  ///
  /// **This should be used only for testing**.
  @visibleForTesting
  PackagesDependencyGraph get packagesDependencyGraph => _dependencyGraph.getCopy();

  void addCodeGenerationHook(OnCodeGenerationHook hook) {
    _codeGenerationHooks.add(hook);
  }

  void addDisposeHook(OnDisposeHook hook) {
    _disposeHooks.add(hook);
  }

  /// Watches this project for any files changes and rebuilds the filed and depedants of the file.
  Future<void> watchProject({
    void Function()? onReady,
    bool deleteExistingGeneratedFiles = false,
  }) async {
    final Completer<void> watchModeCompleter = Completer<void>();
    await indexProject();
    await buildProject(
      deleteExistingGeneratedFiles: deleteExistingGeneratedFiles,
    );
    _projectWatcherSubscription =
        _watcher.events.debounceTime(watchDebounceDuration).listen(_onWatchEvent, onDone: () {
      _watchModeCompleter?.complete();
    });
    await _watcher.ready;
    onReady?.call();
    _watchModeCompleter = watchModeCompleter;
    return watchModeCompleter.future;
  }

  /// Calls all the dispose hooks and clears any open resources
  Future<void> dispose() async {
    logger.info('~ Disposing resources... Bye!');
    for (final OnDisposeHook disposeHook in _disposeHooks) {
      await disposeHook();
    }
    await _projectWatcherSubscription?.cancel();
    _watchModeCompleter?.complete();
    _dependencyGraph.clear();
    _filesPathsRegistry.clear();
  }

  /// Indexes the project and creates a dependency graph between source files.
  ///
  /// Use [forceClear] if you are re-indexing the project.
  Future<void> indexProject({bool forceClear = false}) async {
    logger.info('~ Indexing project..');

    if (forceClear) {
      _filesPathsRegistry.clear();
      _dependencyGraph.clear();
    }

    final Stopwatch stopwatch = Stopwatch()..start();
    final TachyonConfig pluginConfig = getConfig();

    final Iterable<File> dartFiles = projectDir
        .listSync(recursive: true) //
        .where((FileSystemEntity entity) {
      if (entity is! File || !_dartFileNameMatcher.hasMatch(path.basename(entity.path))) {
        return false;
      }

      return pluginConfig.fileGenerationPaths.any((Glob glob) {
        return glob.matches(
          path.relative(entity.absolute.path, from: projectDir.absolute.path),
        );
      });
    }).cast<File>();

    for (final File file in dartFiles) {
      final String targetFilePath = file.absolute.path;

      if (_filesPathsRegistry.containsKey(targetFilePath)) {
        continue;
      }

      _filesPathsRegistry[targetFilePath] = ParsedFileData(
        absolutePath: targetFilePath,
        compilationUnit: targetFilePath.parseDart().unit,
        lastModifiedAt: file.lastModifiedSync(),
      );

      await _indexFile(
        targetFilePath: targetFilePath,
        compilationUnit: _filesPathsRegistry[targetFilePath]!.compilationUnit,
      );
    }

    stopwatch.stop();
    logger.info(
        '~ Indexed ${_filesPathsRegistry.length} files in ${stopwatch.elapsedMilliseconds}ms');
  }

  /// Builds the project.
  ///
  /// **Project must be indexed before it can correctly build**.
  Future<void> buildProject({
    bool deleteExistingGeneratedFiles = false,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    if (deleteExistingGeneratedFiles) {
      logger.info('~ Deleting existing generated files');
      await _deleteGeneratedFiles();
      logger.info('~ Deleted existing generated files in ${stopwatch.elapsedMilliseconds}ms..');
      stopwatch.reset();
    }

    logger.info('~ Building project..');

    for (final MapEntry<String, ParsedFileData> entry in _filesPathsRegistry.entries) {
      final String targetFilePath = entry.key;
      await _generateCode(
        targetFilePath: targetFilePath,
        outputFilePath: targetFilePath.replaceFirst('.dart', '.gen.dart'),
        compilationUnit: entry.value.compilationUnit,
        rebuildDependents: false,
      );
    }

    stopwatch.stop();
    logger.info('~ Completed build in ${stopwatch.elapsed.inMilliseconds}ms..');
  }

  /// Gets an instance of [TachyonConfig] from `project_root_dir/tachyon.yaml`.
  ///
  /// If the file does not exists this method **throws**.
  TachyonConfig getConfig() {
    final String yamlContent = Tachyon.fileSystem
        .file(path.join(projectDir.path, kTachyonConfigFileName)) //
        .readAsStringSync();
    return TachyonConfig.fromJson(loadYaml(yamlContent) as Map<dynamic, dynamic>);
  }

  /// Goes through all the (import) dependencies of this [targetFilePath].
  /// and updates [_dependencyGraph] to include dependency links between
  /// the project's files.
  Future<void> _indexFile({
    required String targetFilePath,
    required CompilationUnit compilationUnit,
  }) async {
    for (final Directive directive in compilationUnit.directives) {
      String? directiveUri;
      if (directive is NamespaceDirective) {
        directiveUri = directive.uri.stringValue;
      }

      if (directiveUri == null) {
        continue;
      }

      final String? importFilePath = await findDartFileFromDirectiveUri(
        projectDirectoryPath: projectDir.path,
        currentDirectoryPath: Tachyon.fileSystem.file(targetFilePath).parent.absolute.path,
        uri: directiveUri,
      );
      if (importFilePath == null || !Tachyon.fileSystem.file(importFilePath).existsSync()) {
        continue;
      }

      // If the file is already parsed then it already exists on the project
      if (_filesPathsRegistry.containsKey(importFilePath)) {
        if (directive is ImportDirective) {
          _dependencyGraph.add(targetFilePath, importFilePath);
        }
        continue;
      }

      // Only project files are added on the dependency graph
      if (path.isWithin(projectDir.path, importFilePath)) {
        if (directive is ImportDirective) {
          _dependencyGraph.add(targetFilePath, importFilePath);
        }
        _filesPathsRegistry[importFilePath] = ParsedFileData(
          absolutePath: importFilePath,
          compilationUnit: importFilePath.parseDart().unit,
          lastModifiedAt: Tachyon.fileSystem.file(importFilePath).lastModifiedSync(),
        );

        await _indexFile(
          targetFilePath: importFilePath,
          compilationUnit: _filesPathsRegistry[importFilePath]!.compilationUnit,
        );
      }
    }
  }

  Future<void> _updateDependencyGraphForFile({
    required String targetFilePath,
    required CompilationUnit compilationUnit,
  }) async {
    for (final Directive directive in compilationUnit.directives) {
      String? directiveUri;
      if (directive is ImportDirective) {
        directiveUri = directive.uri.stringValue;
      }

      if (directiveUri == null) {
        continue;
      }

      final String? dartFilePath = await findDartFileFromDirectiveUri(
        projectDirectoryPath: projectDir.path,
        currentDirectoryPath: Tachyon.fileSystem.file(targetFilePath).parent.absolute.path,
        uri: directiveUri,
      );
      if (dartFilePath == null || !Tachyon.fileSystem.file(dartFilePath).existsSync()) {
        continue;
      }

      // Only project files are added on the dependency graph
      if (path.isWithin(projectDir.path, dartFilePath)) {
        _dependencyGraph.add(targetFilePath, dartFilePath);
      }
    }
  }

  void _onWatchEvent(WatchEvent event) async {
    final String targetFilePath = path.normalize(event.path);
    Completer<void>? buildCompleter;

    try {
      if (!_dartFileNameMatcher.hasMatch(path.basename(targetFilePath))) {
        return;
      }

      final String outputFilePath = targetFilePath.replaceFirst('.dart', '.gen.dart');
      await _activeWrites[outputFilePath]?.future;

      buildCompleter = Completer<void>();
      _activeWrites[outputFilePath] = buildCompleter;

      if (event.type == ChangeType.REMOVE) {
        try {
          await Tachyon.fileSystem.file(outputFilePath).delete();
        } catch (_) {}
        return;
      }

      _filesPathsRegistry[targetFilePath] = ParsedFileData(
        absolutePath: targetFilePath,
        compilationUnit: targetFilePath.parseDart().unit,
        lastModifiedAt: Tachyon.fileSystem.file(targetFilePath).lastModifiedSync(),
      );

      await _updateDependencyGraphForFile(
        targetFilePath: targetFilePath,
        compilationUnit: _filesPathsRegistry.getParsedFileData(targetFilePath).compilationUnit,
      );

      await _generateCode(
        targetFilePath: targetFilePath,
        outputFilePath: outputFilePath,
        compilationUnit: _filesPathsRegistry.getParsedFileData(targetFilePath).compilationUnit,
        rebuildDependents: true,
      );
    } catch (error, stackTrace) {
      logger.exception(error, stackTrace);
    } finally {
      buildCompleter?.safeComplete();
    }
  }

  Future<void> _generateCode({
    required final String targetFilePath,
    required final String outputFilePath,
    required final CompilationUnit compilationUnit,
    final bool rebuildDependents = true,
    final String indent = '',
    final bool reportTime = true,
  }) async {
    final String relativeFilePath = path.relative(targetFilePath, from: projectDir.path);
    final TachyonConfig pluginConfig = getConfig();

    if (!pluginConfig.fileGenerationPaths.any((Glob glob) => glob.matches(relativeFilePath))) {
      return;
    }

    late final Stopwatch? stopwatch;
    if (reportTime) {
      stopwatch = Stopwatch()..start();
    } else {
      stopwatch = null;
    }

    logger.info('$indent~ Starting build for $relativeFilePath');

    final CodeWriter codeWriter = CodeWriter.stringBuffer();
    final String header = generateHeaderForPartFile(targetFilePath);

    codeWriter.write(header);

    final List<Future<String?>> futures = <Future<String?>>[
      for (final OnCodeGenerationHook hook in _codeGenerationHooks)
        hook(compilationUnit, targetFilePath),
    ];
    codeWriter.write(
      await Future.wait(futures)
          .then((List<String?> results) => results.whereType<String>().join(kNewLine)),
    );

    final String content = codeWriter.content.trimRight();
    if (header.trimRight().length == content.length) {
      try {
        await Tachyon.fileSystem.file(outputFilePath).delete();
      } catch (_) {}
    } else {
      try {
        await Tachyon.fileSystem.file(outputFilePath).writeAsString(DartFormatter(
              pageWidth: pluginConfig.generatedFileLineLength,
            ).format(content));
      } on FormatterException catch (e) {
        logger
          ..error('Invalid code generation for $relativeFilePath')
          ..writeln(e);
      }
    }

    if (rebuildDependents) {
      await _rebuildDependents(targetFilePath: targetFilePath, indent: indent);
    }

    if (reportTime) {
      stopwatch!.stop();
      logger.info(
          '$indent~ Finished building $relativeFilePath in ${stopwatch.elapsed.inMilliseconds}ms');
    }
  }

  Future<void> _rebuildDependents({
    required final String targetFilePath,
    required final String indent,
  }) async {
    final Map<String, int> depedentsWeights = <String, int>{};

    void visitDependents(List<String> dependents) {
      for (final String dependent in dependents) {
        int weight = depedentsWeights[dependent] ??= 0;
        depedentsWeights[dependent] = 1 + weight;
        visitDependents(_dependencyGraph.getDependents(dependent));
      }
    }

    visitDependents(_dependencyGraph.getDependents(targetFilePath));

    if (depedentsWeights.isEmpty) {
      return;
    }

    final List<_DepedentAndWeight> depedents = <_DepedentAndWeight>[
      for (final MapEntry<String, int> entry in depedentsWeights.entries)
        _DepedentAndWeight(name: entry.key, weight: entry.value)
    ]..sort();

    logger.debug('$indent~ Rebuilding ${depedents.length} depandents..');
    for (final _DepedentAndWeight dependent in depedents) {
      await _generateCode(
        targetFilePath: dependent.name,
        outputFilePath: dependent.name.replaceFirst('.dart', '.gen.dart'),
        compilationUnit: _filesPathsRegistry.getParsedFileData(dependent.name).compilationUnit,
        indent: '  $indent',
        rebuildDependents: false,
        reportTime: false,
      );
    }
  }

  Future<void> _deleteGeneratedFiles() async {
    final Iterable<File> generatedFiles = projectDir
        .listSync(recursive: true) //
        .where((FileSystemEntity entity) {
      return entity is File && _dartGeneratedFileNameMatcher.hasMatch(path.basename(entity.path));
    }).cast<File>();

    try {
      await Future.wait<void>(
        <Future<FileSystemEntity>>[
          for (final File file in generatedFiles) file.delete(),
        ],
        eagerError: false,
      );
    } catch (_) {
      // ignore any error
    }
  }
}

class _DepedentAndWeight extends Comparable<_DepedentAndWeight> {
  _DepedentAndWeight({
    required this.name,
    required this.weight,
  });

  final String name;
  final int weight;

  @override
  int compareTo(_DepedentAndWeight other) {
    return weight - other.weight;
  }
}
