import 'dart:async';
import 'dart:io' show Platform, ProcessSignal, exit;

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

  @override
  Future<void> execute() async {
    ensureHasPubspec();
    ensureHasTachyonConfig();

    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((_) => _dispose());
    }
    ProcessSignal.sigint.watch().listen((_) => _dispose());

    await registerPlugins(tachyon: _tachyon, projectDirPath: directory.path);
    await _tachyon.watchProject(
      onReady: () => logger.debug('Listening'),
      deleteExistingGeneratedFiles:
          argResults!.getValue<bool>(GenerateArgumentOption.deleteExistingGeneratedFiles),
    );
  }

  void _dispose() {
    logger.writeln('Stopping..');
    _tachyon.dispose();
    exit(0);
  }

  @override
  Future<void> dispose() async {
    await _tachyon.dispose();
    await super.dispose();
  }
}
