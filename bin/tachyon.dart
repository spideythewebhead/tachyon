import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:tachyon/src/cli/cli.dart';
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/src/dart_version.dart';
import 'package:tachyon/tachyon.dart';

Future<void> main(List<String> args) async {
  try {
    if (isAot) {
      dartSdkVersion = Version.parse(const String.fromEnvironment('DART_SDK_VERSION'));
    } else {
      final Version? parsedDartSdkversion = parseDartSdkVersion();

      if (parsedDartSdkversion == null) {
        stdout.writeln('Failed to parse current dart SDK version');
        exitCode = 1;
        return;
      }

      dartSdkVersion = parsedDartSdkversion;
    }

    await CliRunner().run(args);
    exitCode = 0;
  } on TachyonException catch (e) {
    if (e is PubspecYamlNotFoundException) {
      stdout
        ..writeln('No ${kPubspecYamlFileName.cyan().bold()} found.')
        ..writeln(
          'Run this command on the root folder of your project. Are you sure this is a dart/flutter project?',
        );
    } else if (e is DartToolPackageConfigNotFoundException) {
      stdout.writeln('Run "${Platform.executable} pub get" before running this tool.');
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
        ..writeln('  2. Remove any imports related to "${e.packageName}".');
    } else if (e is TachyonConfigNotFoundException) {
      stdout
        ..writeln('No ${kTachyonConfigFileName.cyan().bold()} found.')
        ..writeln(
          'Run this command on the root folder of your project or create a $kTachyonConfigFileName file.',
        );
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

Version? parseDartSdkVersion() {
  final ProcessResult processResult = Process.runSync(
    Platform.resolvedExecutable,
    const <String>['--version'],
  );

  if (processResult.exitCode != 0) {
    return null;
  }

  final String? versionText =
      // match first digit and then match everything - non greedy - until next whitespace
      RegExp(r'(\d.*?)\s').firstMatch(processResult.stdout as String)?.group(1);

  return switch (versionText) {
    String() => Version.parse(versionText),
    null => null,
  };
}
