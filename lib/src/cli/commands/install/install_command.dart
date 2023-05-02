import 'dart:io';

import 'package:tachyon/src/cli/commands/arguments.dart';
import 'package:tachyon/src/cli/commands/base_command.dart';
import 'package:tachyon/src/cli/commands/install/install_argument.dart';
import 'package:tachyon/src/logger/ansi.dart';

class InstallCommand extends BaseCommand {
  @override
  String get name => 'install';

  @override
  String get description => 'Install Data Class Plugin'.bold();

  InstallCommand({
    required super.logger,
  }) {
    argParser.addArgumentOptions(InstallArgument.values);
  }

  @override
  Future<void> execute() async {
    logger.writeln('Installing Data Class Plugin'.blue());

    final String path = argResults![InstallArgument.path.name] ?? Directory.current.path;
    logger.writeln("Target path: '$path'");

    try {
      _installPubspec(path);
      _installAnalysisOptions(path);
      _installPluginOptions(path);
    } catch (e, st) {
      logger.error(e, st);
    }
  }

  void _installPubspec(String path) {
    // TODO
  }

  void _installAnalysisOptions(String path) {
    // TODO
  }

  void _installPluginOptions(String path) {
    // TODO
  }
}
