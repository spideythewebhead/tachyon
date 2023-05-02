import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/cli/cli.dart';
import 'package:tachyon/src/core/exceptions.dart';

Future<void> main(List<String> args) async {
  try {
    await CliRunner().run(args);
    exitCode = 0;
  } on TachyonException catch (e) {
    if (e is PubspecYamlNotFoundException) {
      stdout.writeln('No pubspec.yaml found.. Run this command on the root folder of your project');
    } else if (e is DartToolFolderNotFoundException) {
      stdout.writeln('Run "${Platform.executable} pub get" before running this tool');
    } else if (e is PackageNotFoundException) {
      final String executableBasename = path.basename(Platform.executable).toLowerCase();
      final bool isDartOrFlutterExecutable =
          executableBasename == 'dart' || executableBasename == 'flutter';
      stdout
        ..writeln()
        ..writeln('Package ${e.packageName} is not installed.')
        ..writeln('To fix this either: ')
        ..writeln(
          '  1. Run "${isDartOrFlutterExecutable ? executableBasename : '<dart | flutter>'} pub get"',
        )
        ..writeln('  2. Remove any imports related to "${e.packageName}"');
    }
    exitCode = 1;
  } on UsageException catch (e) {
    stdout
      ..writeln(e.message)
      ..writeln()
      ..writeln(e.usage);

    exitCode = 1;
  }
}
