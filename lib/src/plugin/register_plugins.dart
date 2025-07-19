import 'dart:async';
import 'dart:convert';
import 'dart:io' hide File;
import 'dart:isolate';

import 'package:dart_style/dart_style.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/dart_tool_package_info.dart';
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/src/core/tachyon_config.dart';
import 'package:tachyon/src/plugin/external_plugin_config.dart';
import 'package:tachyon/tachyon.dart';
import 'package:yaml/yaml.dart';

// Generates the entrypoint for the tachyon plugins
String _pluginMainDartTemplate(List<ExternalPluginConfig> plugins) {
  String pluginsImportCode = <String>[
    for (final ExternalPluginConfig plugin in plugins)
      "import 'package:${plugin.name}/${plugin.codeGenerator.file}';",
  ].join(kNewLine);

  // Each plugin uses its own isolate to communicate with Tachyon
  // This includes, informing Tachyon about registration, generate code etc
  String pluginsRegistrationCode = <String>[
    for (final ExternalPluginConfig plugin in plugins)
      '''
Isolate.spawn((SendPort tachyonSendPort) {
  final SimpleIdGenerator idGenerator = SimpleIdGenerator(name: '${plugin.name}');
  final ReceivePort receivePort = ReceivePort();
  final Stream<ApiMessage> apiMessageStream =
      receivePort
        .asBroadcastStream()      
        .cast<Map<dynamic, dynamic>>()
        .map<ApiMessage>(ApiMessage.fromJson);
  final TachyonPluginCodeGenerator generator = ${plugin.codeGenerator.className}();
  final Logger logger = ConsoleLogger();

  apiMessageStream.listen((ApiMessage message) async {
    try {
      if (message is FileModifiedApiMessage) {
        final CompilationUnit unit = parseString(
          content: File(message.absoluteFilePath).readAsStringSync(),
          path: message.absoluteFilePath,
          featureSet: FeatureSet.latestLanguageVersion(),
        ).unit;
        final String generatedCode = await generator.generate(
          FileChangeBuildInfo(
            projectDirectoryPath: message.projectDirectoryPath,
            targetFilePath: message.absoluteFilePath,
            compilationUnit: unit,
          ),
          TachyonDeclarationFinder(
            idGenerator: idGenerator,
            apiMessageStream: apiMessageStream,
            mainSendPort: tachyonSendPort,
            pluginSendPort: receivePort.sendPort,
            targetFilePath: message.absoluteFilePath,
          ),
          logger,
        );
        tachyonSendPort.send(GeneratedCodeApiMessage(
          id: message.id,
          code: generatedCode,
        ).toJson());
        return;
      }
    } catch (error, stackTrace) {
      logger.error(error, stackTrace);
    }
  });

  tachyonSendPort.send(PluginRegisteredApiMessage(
    id: idGenerator.getNext(),
    pluginName: '${plugin.name}',
    sendPort: receivePort.sendPort,
    supportedAnnotations: [${plugin.annotations.map((String e) => "'$e'").join(', ')}],
  ).toJson());
}, mainSendPort, errorsAreFatal: false),
'''
  ].join(kNewLine);

  pluginsRegistrationCode = '''
await Future.wait(<Future<Isolate>>[
  $pluginsRegistrationCode
]);


''';

  return DartFormatter().format('''
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:tachyon/tachyon.dart';

$pluginsImportCode

void main(List<String> args, SendPort mainSendPort) async {
  const int pluginsCount = ${plugins.length};

  mainSendPort.send(PluginsRegistrationCountApiMessage(
    id: '',
    count: pluginsCount,
  ).toJson());

  $pluginsRegistrationCode
}
''');
}

// Contains information about a plugin's registration state
class TachyonPluginRegistrationResult {
  TachyonPluginRegistrationResult({
    required this.pluginName,
    required this.isRegistered,
  });

  final String pluginName;
  final bool isRegistered;

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      pluginName,
      isRegistered,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TachyonPluginRegistrationResult &&
            runtimeType == other.runtimeType &&
            pluginName == other.pluginName &&
            isRegistered == other.isRegistered;
  }
}

Future<void> registerPlugins({
  required Tachyon tachyon,
  required Uri pluginsMainDartUri,
}) async {
  final TachyonConfig tachyonConfig = tachyon.getConfig();
  if (tachyonConfig.plugins.isEmpty) {
    tachyon.logger.warning('~ No plugins found.. skipping');
    return;
  }

  tachyon.logger.info('~ Setting up ${tachyonConfig.plugins.length} plugins');

  final List<PluginRegisteredApiMessage> externalPluginsRegisterApiMessage =
      <PluginRegisteredApiMessage>[];

  final Completer<void> pluginsSetupCompleter = Completer<void>();
  final ReceivePort mainIsolateReceivePort = ReceivePort();

  late int expectedPluginsRegistrationCount;

  final Stream<ApiMessage> apiMessageStream = mainIsolateReceivePort
      .asBroadcastStream()
      .cast<Map<dynamic, dynamic>>()
      .map<ApiMessage>(ApiMessage.fromJson);

  void onApiMessageReceived(ApiMessage message) async {
    if (message is PluginsRegistrationCountApiMessage) {
      expectedPluginsRegistrationCount = message.count;
      return;
    }

    if (message is PluginRegisteredApiMessage) {
      externalPluginsRegisterApiMessage.add(message);
      if (externalPluginsRegisterApiMessage.length == expectedPluginsRegistrationCount) {
        pluginsSetupCompleter.complete();
      }
      return;
    }

    if (message is FindDeclarationApiMessage) {
      final FinderDeclarationMatch<NamedCompilationUnitMember>? match =
          await switch (message.type) {
        FindDeclarationType.classOrEnum => tachyon.declarationFinder
            .findClassOrEnumDeclarationByName(message.name, targetFilePath: message.targetFilePath),
        FindDeclarationType.function => tachyon.declarationFinder
            .findFunctionDeclarationByName(message.name, targetFilePath: message.targetFilePath),
      };
      message.sendPort.send(FindDeclarationResultApiMessage(
        id: message.id,
        matchFilePath: match?.filePath,
        unitMemberContent: match?.node.toSource(),
      ).toJson());
      return;
    }
  }

  final StreamSubscription<dynamic> apiMessageSubscription =
      apiMessageStream.listen(onApiMessageReceived);

  final Isolate isolate = await Isolate.spawnUri(
    pluginsMainDartUri,
    const <String>[],
    mainIsolateReceivePort.sendPort,
    errorsAreFatal: true,
    checked: false,
    packageConfig:
        Uri.parse(path.join(tachyon.projectDir.path, kDartToolFolderName, 'package_config.json')),
  );

  await pluginsSetupCompleter.future;

  // Clear resources when Tachyon is disposed
  tachyon.addDisposeHook(() {
    apiMessageSubscription.cancel();
    mainIsolateReceivePort.close();
    isolate.kill(priority: Isolate.immediate);
  });

  final Map<String, SimpleIdGenerator> pluginNameToIdGenerator = <String, SimpleIdGenerator>{
    for (final PluginRegisteredApiMessage message in externalPluginsRegisterApiMessage)
      message.pluginName: SimpleIdGenerator(name: message.pluginName),
  };

  // This hook is called everytime a file change occurs
  tachyon.addCodeGenerationHook((CompilationUnit compilationUnit, String absoluteFilePath) async {
    Map<String, PluginRegisteredApiMessage> pluginNameToRegisterApiMessage =
        <String, PluginRegisteredApiMessage>{};
    // Gather all plugins that can handle the annotations found in this compilation unit
    for (final CompilationUnitMember member in compilationUnit.declarations) {
      final List<PluginRegisteredApiMessage> registerApiMessages =
          externalPluginsRegisterApiMessage.where((PluginRegisteredApiMessage message) {
        return message.supportedAnnotations
            .any((String annotation) => member.metadata.hasAnnotationWithName(annotation));
      }).toList(growable: false);
      for (final PluginRegisteredApiMessage match in registerApiMessages) {
        pluginNameToRegisterApiMessage[match.pluginName] = match;
      }
    }

    final StringBuffer buffer = StringBuffer();

    Future<void> informPluginForFileChange(
      String pluginName,
      SendPort sendPort,
    ) async {
      final String fileModifiedMessageId = pluginNameToIdGenerator[pluginName]!.getNext();
      sendPort.send(FileModifiedApiMessage(
        id: fileModifiedMessageId,
        projectDirectoryPath: tachyon.projectDir.path,
        absoluteFilePath: absoluteFilePath,
      ).toJson());

      final ApiMessage generatedCodeApiMessage = await apiMessageStream
          .firstWhere((ApiMessage message) => message.id == fileModifiedMessageId)
          .timeout(const Duration(seconds: 5))
          .catchError((Object e) => const UnknownApiMessage());

      if (generatedCodeApiMessage is GeneratedCodeApiMessage &&
          generatedCodeApiMessage.code != null) {
        buffer.writeln(generatedCodeApiMessage.code);
      }
    }

    await Future.wait(<Future<void>>[
      for (final PluginRegisteredApiMessage message in pluginNameToRegisterApiMessage.values)
        informPluginForFileChange(message.pluginName, message.sendPort)
    ]);

    return buffer.toString();
  });

  tachyon.logger.info(
    '~ Registered ${externalPluginsRegisterApiMessage.length} out of ${tachyonConfig.plugins.length} plugins',
  );
}

typedef PluginsCompilationResult = ({
  File? main,
  int exitCode,
});

PluginsCompilationResult compilePlugins(
  Tachyon tachyon, {
  bool aot = false,
}) {
  final (
    :File? pluginsMain,
    :List<TachyonPluginRegistrationResult> pluginsRegistrationResults,
  ) = _createPluginsMainDart(tachyon);

  if (pluginsMain == null) {
    return (main: null, exitCode: 0);
  }

  if (aot) {
    final ProcessResult result = Process.runSync('dart', <String>[
      'compile',
      'aot-snapshot',
      pluginsMain.path,
    ]);

    if (result.exitCode != 0) {
      tachyon.logger.error('Failed to compile plugins as AOT');
      return (main: pluginsMain, exitCode: result.exitCode);
    }

    final File aotDartProgram =
        Tachyon.fileSystem.file(path.join(path.dirname(pluginsMain.path), 'main.aot'));

    tachyon.logger.info('Compiled plugins as AOT');

    return (main: aotDartProgram, exitCode: 0);
  }

  return (main: pluginsMain, exitCode: 0);
}

typedef _CreatePluginsMainDartResult = ({
  File? pluginsMain,
  List<TachyonPluginRegistrationResult> pluginsRegistrationResults,
});

_CreatePluginsMainDartResult _createPluginsMainDart(Tachyon tachyon) {
  final File packageConfigFile = Tachyon.fileSystem.file(path.join(
    tachyon.projectDir.path,
    kDartToolFolderName,
    'package_config.json',
  ));

  if (!packageConfigFile.existsSync()) {
    throw const DartToolPackageConfigNotFoundException();
  }

  final Map<String, dynamic> packageFileJson = jsonDecode(packageConfigFile.readAsStringSync());
  final Map<String, PackageInfo> packages = <String, PackageInfo>{
    for (final Map<dynamic, dynamic> packageJson in packageFileJson['packages'])
      packageJson['name'] as String: PackageInfo.fromJson(packageJson)
  };

  final List<TachyonPluginRegistrationResult> pluginsRegistrationResults =
      <TachyonPluginRegistrationResult>[];

  final List<ExternalPluginConfig> validExternalPluginsConfigs = <ExternalPluginConfig>[];

  // Checks the following for all the declared plugins
  //
  // 1. If it's declared on ".dart_tool/package_config.json", meaning that "pub get" has been run for this plugin
  // 2. If the plugin's configuration exists ("tachyon_plugin_config.yaml" file)
  for (final String pluginName in tachyon.getConfig().plugins) {
    final PackageInfo? package = packages[pluginName];
    if (package == null) {
      pluginsRegistrationResults
          .add(TachyonPluginRegistrationResult(pluginName: pluginName, isRegistered: false));
      tachyon.logger.warning(
          '$pluginName not found. Run ${"pub get".red()} to fix or check ${"pubspec.yaml".red()} for the existence of the dependency. ${"Skipping this plugin".bold()}');
      continue;
    }

    final File pluginConfigurationFile = Tachyon.fileSystem.file(
      path.join(
        path.isRelative(package.rootUri.toFilePath())
            ?
            // The root uri is relative to the project's directory
            path.normalize(path.join(
                tachyon.projectDir.path,
                kDartToolFolderName,
                package.rootUri.toFilePath(),
              ))
            : package.rootUri.toFilePath(),
        kTachyonPluginConfigFileName,
      ),
    );

    if (!pluginConfigurationFile.existsSync()) {
      pluginsRegistrationResults
          .add(TachyonPluginRegistrationResult(pluginName: pluginName, isRegistered: false));
      tachyon.logger
          .warning('${kTachyonPluginConfigFileName.bold()} not found for plugin $pluginName');
      continue;
    }

    try {
      final ExternalPluginConfig pluginConfig = ExternalPluginConfig.fromJson(
        loadYaml(pluginConfigurationFile.readAsStringSync()) as YamlMap,
      );

      validExternalPluginsConfigs.add(pluginConfig);
      pluginsRegistrationResults
          .add(TachyonPluginRegistrationResult(pluginName: pluginName, isRegistered: true));
    } catch (error, stackTrace) {
      pluginsRegistrationResults
          .add(TachyonPluginRegistrationResult(pluginName: pluginName, isRegistered: false));
      tachyon.logger
        ..warning('Failed to register plugin $pluginName')
        ..error(error, stackTrace);
    }
  }

  if (validExternalPluginsConfigs.isEmpty) {
    tachyon.logger.warning(
        'All plugins have failed to be registered. Check the configuration of your project and try again. Or report an issue ($kIssueReportUrl)');
    return (
      pluginsMain: null,
      pluginsRegistrationResults: pluginsRegistrationResults,
    );
  }

  final File dartProgram = Tachyon.fileSystem.file(path.join(
    tachyon.projectDir.path,
    kDartToolFolderName,
    'tachyon',
    'main.dart',
  ))
    ..createSync(recursive: true);
  dartProgram.writeAsStringSync(_pluginMainDartTemplate(validExternalPluginsConfigs));

  return (
    pluginsMain: dartProgram,
    pluginsRegistrationResults: pluginsRegistrationResults,
  );
}
