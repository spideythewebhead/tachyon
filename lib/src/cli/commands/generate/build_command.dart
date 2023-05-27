import 'dart:async';

import 'package:file/file.dart';
import 'package:tachyon/src/cli/commands/arguments.dart';
import 'package:tachyon/src/cli/commands/base_command.dart';
import 'package:tachyon/src/cli/commands/generate/generate_arguments.dart';
import 'package:tachyon/src/cli/commands/mixins.dart';
import 'package:tachyon/src/core/tachyon.dart';
import 'package:tachyon/src/plugin/register_plugins.dart';

class BuildCommand extends BaseCommand with UtilsCommandMixin {
  BuildCommand({
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
  final String name = 'build';

  @override
  final String description = 'Builds project';

  @override
  Future<void> execute() async {
    ensureHasPubspec();
    ensureHasTachyonConfig();

    await registerPlugins(tachyon: _tachyon, projectDirPath: directory.path);
    await _tachyon.indexProject();
    return await _tachyon.buildProject(
      deleteExistingGeneratedFiles:
          argResults!.getValue<bool>(GenerateArgumentOption.deleteExistingGeneratedFiles),
    );
  }

  @override
  Future<void> dispose() async {
    await _tachyon.dispose();
    await super.dispose();
  }
}
