import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:tachyon/src/cli/commands/base_command.dart';
import 'package:tachyon/src/cli/commands/generate/build_command.dart';
import 'package:tachyon/src/cli/commands/generate/watch_command.dart';
import 'package:tachyon/tachyon.dart';

class CliRunner extends CommandRunner<void> {
  CliRunner([IOSink? sink])
      : logger = ConsoleLogger(sink),
        super(
          'tachyon',
          'Tachyon code generator.'.bold(),
        ) {
    <BaseCommand>[
      BuildCommand(logger: logger, directory: Directory.current),
      WatchCommand(logger: logger, directory: Directory.current),
    ].forEach(addCommand);
  }

  final Logger logger;
}
