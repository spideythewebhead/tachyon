import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/src/plugin/register_plugins.dart';
import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

import '../plugin_project_creator.dart';
import '../test_project_creator.dart';
import '../utils.dart';

const String _kProjectDirPath = '/home/user/project';
const Logger _logger = NoOpLogger();

void main() {
  late Directory projectDir;

  tearDownAll(() {
    projectDir.safelyRecursivelyDeleteSync();
  });

  group('registerPlugins', () {
    setUp(() {
      Tachyon.fileSystem = MemoryFileSystem.test();
      projectDir = Tachyon.fileSystem.directory(_kProjectDirPath)..createSync(recursive: true);
    });

    test('Registers 2 plugins and generates code', () async {
      Tachyon.resetFileSystem();

      const String pluginAName = 'plugin_a', pluginBName = 'plugin_b';

      pluginProjectCreator(
        pluginName: pluginAName,
        annotationName: 'PluginA',
        generatorName: 'PluginACodeGenerator',
      );

      pluginProjectCreator(
        pluginName: pluginBName,
        annotationName: 'PluginB',
        generatorName: 'PluginBCodeGenerator',
      );

      final Directory pluginsTesterProjectDir = testProjectCreator(
        pluginsNames: <String>[pluginAName, pluginBName],
      );

      pluginsTesterProjectDir.childDirectory('lib').childFile('main.dart').writeAsStringSync('''
import 'package:$pluginAName/$pluginAName.dart';
import 'package:$pluginBName/$pluginBName.dart';

@PluginA()
@PluginB()
class Test {}
''');

      final Tachyon tachyon = Tachyon(
        projectDir: pluginsTesterProjectDir,
        logger: _logger,
      );

      final (exitCode: _, :File? main) = compilePlugins(tachyon);

      await expectLater(
        registerPlugins(tachyon: tachyon, pluginsMainDartUri: main!.uri),
        completes,
      );

      expect(
        Tachyon.fileSystem
            .file(path.join(
              pluginsTesterProjectDir.path,
              kDartToolFolderName,
              'tachyon',
              'main.dart',
            ))
            .existsSync(),
        isTrue,
      );

      await tachyon.indexProject();
      await tachyon.buildProject();

      final String generatedFileContent = pluginsTesterProjectDir
          .childDirectory('lib')
          .childFile('main.gen.dart')
          .readAsStringSync();

      expect(
        generatedFileContent,
        contains('// Plugin $pluginAName registered'),
      );

      expect(
        generatedFileContent,
        contains('// Plugin $pluginBName registered'),
      );

      await tachyon.dispose();
    });
  });

  group('compilePlugins', () {
    setUp(() {
      Tachyon.fileSystem = MemoryFileSystem.test();
      projectDir = Tachyon.fileSystem.directory(_kProjectDirPath)..createSync(recursive: true);
    });

    test('Throws "DartToolPackageConfigNotFoundException"', () {
      _createCommonTachyonYaml();

      final Tachyon tachyon = Tachyon(
        projectDir: projectDir,
        logger: _logger,
      );

      expect(
        () async => compilePlugins(tachyon),
        throwsA(isA<DartToolPackageConfigNotFoundException>()),
      );
    });
  });
}

void _createCommonTachyonYaml({
  List<String>? plugins,
}) {
  StringBuffer pluginsCode = StringBuffer();
  if (plugins != null) {
    pluginsCode.writeln('plugins:');
    for (final String pluginName in plugins) {
      pluginsCode.writeln('  - $pluginName');
    }
  }
  Tachyon.fileSystem.file(path.join(_kProjectDirPath, kTachyonConfigFileName))
    ..createSync()
    ..writeAsStringSync('''
file_generation_paths:
  - "lib/**"

$pluginsCode
''');
}
