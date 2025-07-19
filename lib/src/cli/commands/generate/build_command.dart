import 'dart:async';
import 'dart:io' hide File;

import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/cli/commands/arguments.dart';
import 'package:tachyon/src/cli/commands/base_command.dart';
import 'package:tachyon/src/cli/commands/generate/generate_arguments.dart';
import 'package:tachyon/src/cli/commands/mixins.dart';
import 'package:tachyon/src/constants.dart';
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

    File pluginsMain;

    if (isAot) {
      pluginsMain = Tachyon.fileSystem.file(path.join(
        _tachyon.projectDir.path,
        kDartToolFolderName,
        'tachyon',
        'main.aot',
      ));

      if (!pluginsMain.existsSync()) {
        logger.error('Failed to find ${pluginsMain.path}. Ensure you run tachyon compile first');
        exit(1);
      }
    } else {
      final PluginsCompilationResult compilationResult = compilePlugins(_tachyon);

      if (compilationResult.exitCode != 0) {
        exit(compilationResult.exitCode);
      }

      if (compilationResult.main == null) {
        logger.error('Failed to generate main.aot for plugins');
        exit(1);
      }

      pluginsMain = compilationResult.main!;
    }

    await registerPlugins(
      tachyon: _tachyon,
      pluginsMainDartUri: pluginsMain.uri,
    );

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
