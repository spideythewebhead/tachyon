import 'dart:io';

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/cli/commands/base_command.dart';
import 'package:tachyon/src/cli/commands/mixins.dart';
import 'package:tachyon/src/core/dart_tool_package_info.dart';
import 'package:tachyon/src/dart_version.dart';
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

    String? tachyonDirectoryPath = PackageResolver.getTachyonDirectoryPath(
      _tachyon.projectDir.path,
    );

    if (tachyonDirectoryPath == null) {
      logger.error('Failed to find "tachyon.dart" to compile.');
      exit(1);
    }

    void Function()? cleanUp;

    if (path.isAbsolute(tachyonDirectoryPath) && tachyonDirectoryPath.contains('.pub-cache')) {
      tachyonDirectoryPath = Tachyon.fileSystem
          .directory(tachyonDirectoryPath)
          .cloneTachyonToTemporary(Tachyon.fileSystem.systemTempDirectory.path)
          .path;

      final ProcessResult pubGetResult = Process.runSync(
        Platform.resolvedExecutable,
        <String>['pub', 'get'],
        workingDirectory: tachyonDirectoryPath,
      );

      if (pubGetResult.exitCode != 0) {
        logger.error('Failed to run "dart pub get" on tachyon');
        exit(pubGetResult.exitCode);
      }

      cleanUp = () {
        Tachyon.fileSystem.directory(tachyonDirectoryPath).deleteSync(recursive: true);
      };
    }

    try {
      final ProcessResult tachyonCompileResult = Process.runSync(
        Platform.resolvedExecutable,
        <String>[
          'compile',
          'exe',
          '-DDART_SDK_VERSION=$dartSdkVersion',
          path.join(tachyonDirectoryPath, 'bin', 'tachyon.dart'),
          '-o',
          'ctachyon',
        ],
      );

      if (tachyonCompileResult.exitCode != 0) {
        logger
          ..error('Failed to compile tachyon')
          ..error(tachyonCompileResult.stderr);
        exit(compilationResult.exitCode);
      }

      logger.info('Compiled tachyon. Execute "./ctachyon --help" to verify installation');
    } finally {
      cleanUp?.call();
    }
  }
}

extension on Directory {
  static final List<Glob> _ignorePaths = <Glob>[
    Glob('.git', recursive: true),
    Glob('.fvm', recursive: true),
    Glob('.dart_tool', recursive: true),
    Glob('test', recursive: true),
    Glob('example', recursive: true),
  ];

  Directory cloneTachyonToTemporary(String to) {
    final String inDirectoryPath = absolute.path;

    // Create root folder
    final Directory outDirectory = Tachyon.fileSystem.directory(
      path.join(to, path.basename(inDirectoryPath)),
    )..createSync(recursive: true);

    for (final FileSystemEntity file in listSync(recursive: true, followLinks: false)) {
      final String pathRelativeToInDirectory = path.relative(file.path, from: inDirectoryPath);
      final String newPath = path.join(outDirectory.path, pathRelativeToInDirectory);

      if (_ignorePaths.any((Glob g) => g.matches(pathRelativeToInDirectory))) {
        continue;
      }

      switch (file) {
        case Directory():
          Tachyon.fileSystem.directory(newPath).createSync(recursive: true);
          break;

        case File():
          file.copySync(newPath);
          break;

        case Link():
          break;
      }
    }

    return outDirectory.absolute;
  }
}
