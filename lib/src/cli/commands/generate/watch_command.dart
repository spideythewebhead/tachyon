import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, ProcessSignal, stdin;

import 'package:file/file.dart';
import 'package:tachyon/src/cli/commands/arguments.dart';
import 'package:tachyon/src/cli/commands/base_command.dart';
import 'package:tachyon/src/cli/commands/generate/generate_arguments.dart';
import 'package:tachyon/src/cli/commands/mixins.dart';
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

  @override
  Future<void> execute() async {
    ensureHasPubspec();
    ensureHasTachyonConfig();

    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((_) => dispose());
    }
    ProcessSignal.sigint.watch().listen((_) => dispose());

    stdin
      ..echoMode = false
      ..lineMode = false;

    bool isRestartingTachyon = false;
    _stdinSubscription = stdin.transform(const Utf8Decoder()).listen((String input) async {
      if (input == 'R') {
        if (isRestartingTachyon) {
          return;
        }

        isRestartingTachyon = true;
        logger.debug('Restarting tachyon..');

        await _tachyon.clearHooks();

        await registerPlugins(tachyon: _tachyon, projectDirPath: directory.path);
        await _tachyon.rebuild(
          deleteExistingGeneratedFiles:
              argResults!.getValue<bool>(GenerateArgumentOption.deleteExistingGeneratedFiles),
        );

        logger.debug('Restart ended..');
        isRestartingTachyon = false;
      }
    });

    await registerPlugins(tachyon: _tachyon, projectDirPath: directory.path);
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
      await _stdinSubscription?.cancel();
      await _tachyon.dispose();
      await super.dispose();
    }
  }
}
