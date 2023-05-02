import 'dart:async';
import 'dart:io';

import 'package:tachyon/src/cli/commands/base_command.dart';
import 'package:tachyon/src/cli/commands/mixins.dart';

import 'package:tachyon/src/core/tachyon_generator.dart';
import 'package:tachyon/src/plugin_api/register_plugins.dart';

class BuildCommand extends BaseCommand with UtilsCommandMixin {
  BuildCommand({
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
  final String name = 'build';

  @override
  final String description = 'Builds project';

  @override
  Future<void> execute() async {
    ensureHasPubspec();

    await registerPlugins(tachyon: _tachyon, projectDirectoryPath: directory.path);
    await _tachyon.indexProject();
    return await _tachyon.buildProject();
  }

  @override
  Future<void> dispose() async {
    await _tachyon.dispose();
    await super.dispose();
  }
}
