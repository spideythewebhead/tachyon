import 'dart:io';

import 'package:file/file.dart';
import 'package:tachyon/src/cli/commands/base_command.dart';
import 'package:tachyon/src/cli/commands/mixins.dart';
import 'package:tachyon/src/core/dart_tool_package_info.dart';
import 'package:tachyon/src/plugin/register_plugins.dart';
import 'package:tachyon/tachyon.dart';

class CompileCommand extends BaseCommand with UtilsCommandMixin {
  CompileCommand({
    required super.logger,
    required this.directory,
  }) : _tachyon = Tachyon(
          projectDir: directory,
          logger: logger,
        );

  @override
  final Directory directory;

  final Tachyon _tachyon;

  @override
  String get name => 'compile';

  @override
  String get description => 'Compiles tachyon';

  @override
  Future<void> execute() async {
    ensureHasPubspec();
    ensureHasTachyonConfig();

    final PluginsCompilationResult compilationResult = compilePlugins(
      _tachyon,
      aot: true,
    );

    if (compilationResult.exitCode != 0) {
      exit(compilationResult.exitCode);
    }

    if (compilationResult.main == null) {
      logger.error('Failed to generate main.aot for plugins');
      exit(1);
    }

    final String? tachyonMain = PackageResolver.getTachyonMainDartPath(_tachyon.projectDir.path);
    if (tachyonMain == null) {
      logger.error('Failed to find "tachyon.dart" to compile.');
      exit(1);
    }

    final ProcessResult tachyonCompileResult = Process.runSync('dart', <String>[
      'compile',
      'exe',
      tachyonMain,
      '-o',
      'ctachyon',
    ]);

    if (tachyonCompileResult.exitCode != 0) {
      logger.error('Failed to compile tachyon');
      exit(compilationResult.exitCode);
    }

    logger.info('Compiled tachyon. Execute "./ctachyon --help" to verify installation');
  }
}
