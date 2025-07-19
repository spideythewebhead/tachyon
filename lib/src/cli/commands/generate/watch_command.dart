import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, ProcessSignal, exit, stdin;

import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/cli/commands/arguments.dart';
import 'package:tachyon/src/cli/commands/base_command.dart';
import 'package:tachyon/src/cli/commands/generate/generate_arguments.dart';
import 'package:tachyon/src/cli/commands/mixins.dart';
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/tachyon.dart';
import 'package:tachyon/src/plugin/register_plugins.dart';

class WatchCommand extends BaseCommand with UtilsCommandMixin {
  WatchCommand({
    required super.logger,
    required this.directory,
  }) : _tachyon = Tachyon(
          projectDir: directory,
          logger: logger,
        ) {
    argParser.addArgumentOptions(GenerateArgumentOption.options);
  }

  final Tachyon _tachyon;

  @override
  final Directory directory;

  @override
  final String name = 'watch';

  @override
  final String description = 'Watches project for files changes and rebuilds when necessary';

  StreamSubscription<void>? _stdinSubscription;

  bool _isDisposed = false;

  List<StreamSubscription<void>> signalsSubs = <StreamSubscription<void>>[];

  @override
  Future<void> execute() async {
    ensureHasPubspec();
    ensureHasTachyonConfig();

    if (!Platform.isWindows) {
      signalsSubs.add(ProcessSignal.sigterm.watch().listen((_) => dispose()));
    }
    signalsSubs.add(ProcessSignal.sigint.watch().listen((_) => dispose()));

    stdin
      ..echoMode = false
      ..lineMode = false;

    if (isAot) {
      final File pluginsMain = Tachyon.fileSystem.file(path.join(
        _tachyon.projectDir.path,
        kDartToolFolderName,
        'tachyon',
        'main.aot',
      ));

      if (!pluginsMain.existsSync()) {
        logger.error('Failed to find ${pluginsMain.path}. Ensure you run tachyon compile first');
        exit(1);
      }

      await registerPlugins(
        tachyon: _tachyon,
        pluginsMainDartUri: pluginsMain.uri,
      );

      await _tachyon.watchProject(
        onReady: () => logger.debug('Listening'),
        deleteExistingGeneratedFiles:
            argResults!.getValue<bool>(GenerateArgumentOption.deleteExistingGeneratedFiles),
      );

      return;
    }

    PluginsCompilationResult compilationResult;

    bool isRestartingTachyon = false;
    _stdinSubscription = stdin.transform(const Utf8Decoder()).listen((String input) async {
      if (input == 'R') {
        if (isRestartingTachyon) {
          return;
        }

        isRestartingTachyon = true;
        logger.debug('Restarting tachyon..');

        await _tachyon.clearHooks();

        compilationResult = compilePlugins(_tachyon);

        if (compilationResult.exitCode != 0 || compilationResult.main == null) {
          logger.error('Restart failed to generating main.dart for plugins');
          isRestartingTachyon = false;
          return;
        }

        await registerPlugins(
          tachyon: _tachyon,
          pluginsMainDartUri: compilationResult.main!.uri,
        );

        await _tachyon.rebuild(
          deleteExistingGeneratedFiles:
              argResults!.getValue<bool>(GenerateArgumentOption.deleteExistingGeneratedFiles),
        );

        logger.debug('Restart ended..');
        isRestartingTachyon = false;
      }
    });

    compilationResult = compilePlugins(_tachyon);

    if (compilationResult.exitCode != 0) {
      exit(compilationResult.exitCode);
    }

    if (compilationResult.main == null) {
      logger.error('Failed to generate main.aot for plugins');
      exit(1);
    }

    await registerPlugins(
      tachyon: _tachyon,
      pluginsMainDartUri: compilationResult.main!.uri,
    );

    await _tachyon.watchProject(
      onReady: () {
        logger
          ..debug('Listening')
          ..info('TIP: Press "R" to restart tachyon');
      },
      deleteExistingGeneratedFiles:
          argResults!.getValue<bool>(GenerateArgumentOption.deleteExistingGeneratedFiles),
    );
  }

  @override
  Future<void> dispose() async {
    if (!_isDisposed) {
      _isDisposed = true;
      for (final StreamSubscription<void> sub in signalsSubs) {
        await sub.cancel();
      }
      await _stdinSubscription?.cancel();
      await _tachyon.dispose();
      await super.dispose();
    }
  }
}
