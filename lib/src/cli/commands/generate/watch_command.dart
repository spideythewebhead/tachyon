import 'dart:async';
import 'dart:io';

import 'package:tachyon/src/cli/commands/base_command.dart';
import 'package:tachyon/src/cli/commands/mixins.dart';
import 'package:tachyon/src/core/tachyon_generator.dart';
import 'package:tachyon/src/plugin_api/register_plugins.dart';

class WatchCommand extends BaseCommand with UtilsCommandMixin {
  WatchCommand({
    required super.logger,
    required this.directory,
  }) : _tachyon = Tachyon(
          directory: directory,
          logger: logger,
        );

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

    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((_) => _dispose());
    }
    ProcessSignal.sigint.watch().listen((_) => _dispose());

    await registerPlugins(tachyon: _tachyon, projectDirectoryPath: directory.path);
    await _tachyon.watchProject(onReady: () => logger.debug('Listening'));
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
