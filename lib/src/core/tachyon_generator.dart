import 'dart:async';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_style/dart_style.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/code_writer.dart';
import 'package:tachyon/src/core/declaration_finder.dart';
import 'package:tachyon/src/core/find_package_path_by_import.dart';
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

class Tachyon {
  Tachyon({
    required this.directory,
    final FileSystem? fileSystem,
    final Logger? logger,
  })  : _watcher = DirectoryWatcher(directory.path),
        _fileSystem = fileSystem ?? const LocalFileSystem(),
        logger = logger ?? ConsoleLogger();

  final Directory directory;
  final Logger logger;
  final Watcher _watcher;
  final FileSystem _fileSystem;

  final Map<String, Completer<void>?> _activeWrites = <String, Completer<void>?>{};
  final DependencyGraph _dependencyGraph = DependencyGraph();
  final ParsedFilesRegistry _filesRegistry = ParsedFilesRegistry();

  late final DeclarationFinder declarationFinder = DeclarationFinder(
    projectDirectoryPath: directory.path,
    parsedFilesRegistry: _filesRegistry,
    fileSystem: _fileSystem,
  );

  final List<OnCodeGenerationHook> _codeGenerationHooks = <OnCodeGenerationHook>[];
  final List<OnDisposeHook> _disposeHooks = <OnDisposeHook>[];

  StreamSubscription<WatchEvent>? _watchSubscription;

  List<String> get registeredFiles => _filesRegistry.keys.toList(growable: false);

  void addCodeGenerationHook(OnCodeGenerationHook hook) {
    _codeGenerationHooks.add(hook);
  }

  void addDisposeHook(OnDisposeHook hook) {
    _disposeHooks.add(hook);
  }

  /// Watches this project for any files changes and rebuilds when necessary
  Future<void> watchProject({
    void Function()? onReady,
    bool deleteExistingGeneratedFiles = false,
  }) async {
    final Completer<void> completer = Completer<void>();
    await indexProject();
    await buildProject(
      deleteExistingGeneratedFiles: deleteExistingGeneratedFiles,
    );
    _watchSubscription = _watcher.events
        .debounceTime(const Duration(milliseconds: 100))
        .listen(_onWatchEvent, onDone: () {
      completer.complete();
    });
    await _watcher.ready;
    onReady?.call();
    return completer.future;
  }

  Future<void> dispose() async {
    logger.info('~ Disposing resources... Bye!');
    for (final OnDisposeHook disposeHook in _disposeHooks) {
      await disposeHook();
    }
    await _watchSubscription?.cancel();
  }

  /// Indexes the project and creates links between source files
  Future<void> indexProject({bool forceClear = false}) async {
    logger.info('~ Indexing project..');

    if (forceClear) {
      _filesRegistry.clear();
      _dependencyGraph.clear();
    }

    final Stopwatch stopwatch = Stopwatch()..start();
    final TachyonConfig pluginConfig = getConfig();

    final Iterable<File> dartFiles = directory
        .listSync(recursive: true) //
        .where((FileSystemEntity entity) {
      if (entity is! File || !_dartFileNameMatcher.hasMatch(path.basename(entity.path))) {
        return false;
      }

      return pluginConfig.fileGenerationPaths.any((Glob glob) {
        return glob.matches(
          path.relative(entity.absolute.path, from: directory.absolute.path),
        );
      });
    }).cast<File>();

    for (final File file in dartFiles) {
      final String targetFilePath = file.absolute.path;

      if (_filesRegistry.containsKey(targetFilePath)) {
        continue;
      }

      _filesRegistry[targetFilePath] = ParsedFileData(
        absolutePath: targetFilePath,
        compilationUnit: targetFilePath.parse(featureSet: FeatureSet.latestLanguageVersion()).unit,
        lastModifiedAt: file.lastModifiedSync(),
      );

      await _indexFile(
        targetFilePath: targetFilePath,
        compilationUnit: _filesRegistry[targetFilePath]!.compilationUnit,
      );
    }

    stopwatch.stop();
    logger.info('~ Indexed ${_filesRegistry.length} files in ${stopwatch.elapsedMilliseconds}ms');
  }

  /// Builds the project
  ///
  /// **Project must be indexed before it can correctly build**
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

    for (final MapEntry<String, ParsedFileData> entry in _filesRegistry.entries) {
      final String targetFilePath = entry.key;
      await _generateCode(
        targetFilePath: targetFilePath,
        outputFilePath: targetFilePath.replaceFirst('.dart', '.gen.dart'),
        compilationUnit: entry.value.compilationUnit,
      );
    }

    stopwatch.stop();
    logger.info('~ Completed build in ${stopwatch.elapsed.inMilliseconds}ms..');
  }

  TachyonConfig getConfig() {
    final String yamlContent = _fileSystem
        .file(path.join(directory.path, 'tachyon_config.yaml')) //
        .readAsStringSync();
    return TachyonConfig.fromJson(loadYaml(yamlContent) as Map<dynamic, dynamic>);
  }

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

      final String? dartFilePath = await findDartFileFromDirectiveUri(
        projectDirectoryPath: directory.path,
        currentDirectoryPath: _fileSystem.file(targetFilePath).parent.absolute.path,
        uri: directiveUri,
        fileSystem: _fileSystem,
      );

      if (dartFilePath == null || !_fileSystem.file(dartFilePath).existsSync()) {
        continue;
      }

      if (_filesRegistry.containsKey(dartFilePath)) {
        _dependencyGraph.add(
          targetFilePath,
          dartFilePath,
        );
        continue;
      }

      if (path.isWithin(directory.path, dartFilePath)) {
        _dependencyGraph.add(targetFilePath, dartFilePath);
        _filesRegistry[dartFilePath] = ParsedFileData(
          absolutePath: dartFilePath,
          compilationUnit: dartFilePath.parse(featureSet: FeatureSet.latestLanguageVersion()).unit,
          lastModifiedAt: _fileSystem.file(dartFilePath).lastModifiedSync(),
        );

        await _indexFile(
          targetFilePath: dartFilePath,
          compilationUnit: _filesRegistry[dartFilePath]!.compilationUnit,
        );
      }
    }
  }

  void _onWatchEvent(WatchEvent event) async {
    final String targetFilePath = path.normalize(event.path);
    Completer<void>? completer;

    try {
      if (!_dartFileNameMatcher.hasMatch(path.basename(targetFilePath))) {
        return;
      }

      final String outputFilePath = targetFilePath.replaceFirst('.dart', '.gen.dart');
      await _activeWrites[outputFilePath]?.future;

      completer = Completer<void>();
      _activeWrites[outputFilePath] = completer;

      if (event.type == ChangeType.REMOVE) {
        try {
          await _fileSystem.file(outputFilePath).delete();
        } catch (_) {}

        return;
      }

      if (!_filesRegistry.containsKey(targetFilePath)) {
        _filesRegistry[targetFilePath] = ParsedFileData(
          absolutePath: targetFilePath,
          compilationUnit:
              targetFilePath.parse(featureSet: FeatureSet.latestLanguageVersion()).unit,
          lastModifiedAt: _fileSystem.file(targetFilePath).lastModifiedSync(),
        );
        await _indexFile(
          targetFilePath: targetFilePath,
          compilationUnit: _filesRegistry[targetFilePath]!.compilationUnit,
        );
      }

      await _generateCode(targetFilePath: targetFilePath, outputFilePath: outputFilePath);
    } catch (error, stackTrace) {
      logger.exception(error, stackTrace);
    } finally {
      completer?.safeComplete();
    }
  }

  Future<void> _generateCode({
    required String targetFilePath,
    required String outputFilePath,
    bool skipDependencies = false,
    CompilationUnit? compilationUnit,
    String indent = '',
    bool reportTime = true,
  }) async {
    final String relativeFilePath = path.relative(targetFilePath, from: directory.path);
    final TachyonConfig pluginConfig = getConfig();

    if (!pluginConfig.fileGenerationPaths.any((Glob glob) => glob.matches(relativeFilePath))) {
      return;
    }

    logger.debug('$indent~ Checking $relativeFilePath');

    late final Stopwatch? stopwatch;
    if (reportTime) {
      stopwatch = Stopwatch()..start();
    } else {
      stopwatch = null;
    }

    CodeWriter codeWriter = CodeWriter.stringBuffer();

    if (compilationUnit == null) {
      _filesRegistry[targetFilePath] = ParsedFileData(
        absolutePath: targetFilePath,
        compilationUnit: targetFilePath.parse(featureSet: FeatureSet.latestLanguageVersion()).unit,
        lastModifiedAt: await _fileSystem.file(targetFilePath).lastModified(),
      );
    }

    compilationUnit ??= _filesRegistry[targetFilePath]!.compilationUnit;

    logger.debug('$indent~ Starting build for $relativeFilePath');

    final String header = (StringBuffer()
          ..writeln('// AUTO GENERATED - DO NOT MODIFY')
          ..writeln('// ignore_for_file: type=lint')
          ..writeln()
          ..writeln("part of '${path.basename(targetFilePath)}';")
          ..writeln())
        .toString();

    codeWriter.write(header);

    final List<Future<String?>> futures = <Future<String?>>[
      for (final OnCodeGenerationHook hook in _codeGenerationHooks)
        hook(compilationUnit, targetFilePath),
    ];
    codeWriter.writeln(await Future.wait(futures)
        .then((List<String?> results) => results.whereType<String>().join(kNewLine)));

    final String content = codeWriter.content.trimRight();
    if (content.length == header.length && content == header) {
      try {
        await _fileSystem.file(outputFilePath).delete();
      } catch (_) {}
    } else {
      try {
        await _fileSystem.file(outputFilePath).writeAsString(DartFormatter(
              pageWidth: pluginConfig.generatedFileLineLength,
            ).format(content));
      } on FormatterException catch (e) {
        logger
          ..error('Invalid code generation for $relativeFilePath')
          ..writeln(e);
      }
    }

    if (!skipDependencies) {
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
    final List<String> dependants = _dependencyGraph.getDependents(targetFilePath);
    if (dependants.isEmpty) {
      return;
    }

    logger.debug('  Rebuilding ${dependants.length} depandents..');
    await Future.wait(<Future<void>>[
      for (final String dependency in dependants)
        _generateCode(
          targetFilePath: dependency,
          outputFilePath: dependency.replaceFirst('.dart', '.gen.dart'),
          compilationUnit: _filesRegistry[dependency]?.compilationUnit,
          indent: '  $indent',
          skipDependencies: true,
          reportTime: false,
        )
    ]);
  }

  Future<void> _deleteGeneratedFiles() async {
    final Iterable<File> generatedFiles = directory
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
