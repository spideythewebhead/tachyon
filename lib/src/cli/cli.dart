import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:file/local.dart';
import 'package:tachyon/src/cli/commands/compile_command.dart';
import 'package:tachyon/src/cli/commands/generate/build_command.dart';
import 'package:tachyon/src/cli/commands/generate/watch_command.dart';
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/tachyon.dart';

class CliRunner extends CommandRunner<void> {
  static const LocalFileSystem _fileSystem = LocalFileSystem();

  CliRunner([IOSink? sink])
      : logger = ConsoleLogger(sink),
        super('tachyon', 'Tachyon code generator.'.bold()) {
    addCommand(BuildCommand(
      logger: logger,
      directory: _fileSystem.currentDirectory,
    ));

    addCommand(WatchCommand(
      logger: logger,
      directory: _fileSystem.currentDirectory,
    ));

    if (!isAot) {
      addCommand(CompileCommand(
        logger: logger,
        directory: _fileSystem.currentDirectory,
      ));
    }
  }

  final Logger logger;
}
