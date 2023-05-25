import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as path;
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/core/dart_tool_package_info.dart';
import 'package:tachyon/src/core/exceptions.dart';
import 'package:tachyon/src/core/tachyon_config.dart';
import 'package:tachyon/src/plugin_api/external_plugin_config.dart';
import 'package:tachyon/tachyon.dart';
import 'package:yaml/yaml.dart';

// Generates the entrypoint for the tachyon plugins
String _pluginMainDartTemplate(List<ExternalPluginConfig> plugins) {
  String pluginsImportCode = <String>[
    for (final ExternalPluginConfig plugin in plugins)
      "import 'package:${plugin.name}/${plugin.codeGenerator.file}';",
  ].join(kNewLine);

  String pluginsRegistrationCode = <String>[
    for (final ExternalPluginConfig plugin in plugins)
      '''
Isolate.spawn((SendPort mainSendPort) {
  final SimpleIdGenerator idGenerator = SimpleIdGenerator(name: '${plugin.name}');
  final ReceivePort receivePort = ReceivePort();
  final Stream<ApiMessage> apiMessageStream =
      receivePort.asBroadcastStream().map((dynamic message) => ApiMessage.fromJson(message));

  apiMessageStream.listen((ApiMessage message) async {
    if (message is FileModifiedApiMessage) {
      final CompilationUnit unit = parseFile(
        path: message.absoluteFilePath,
        featureSet: FeatureSet.latestLanguageVersion(),
      ).unit;
      final TachyonPluginCodeGenerator generator = ${plugin.codeGenerator.className}();
      final String generatedCode = await generator.generate(
        FileChangeBuildInfo(
          projectDirectoryPath: message.projectDirectoryPath,
          targetFilePath: message.absoluteFilePath,
          compilationUnit: unit,
        ),
        TachyonDeclarationFinder(
          idGenerator: idGenerator,
          apiMessageStream: apiMessageStream,
          mainSendPort: mainSendPort,
          pluginSendPort: receivePort.sendPort,
          targetFilePath: message.absoluteFilePath,
        ),
        IsolateLogger(
          idGenerator: idGenerator,
          sendPort: mainSendPort,
        ),
      );
      mainSendPort.send(GeneratedCodeApiMessage(
        id: message.id,
        code: generatedCode,
      ).toJson());
      return;
    }
  });

  mainSendPort.send(RegisterApiMessage(
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
import 'dart:isolate';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:tachyon/tachyon.dart';

$pluginsImportCode

void main(List<String> args, SendPort mainSendPort) async {
  $pluginsRegistrationCode
}
''');
}

Future<void> registerPlugins({
  required Tachyon tachyon,
  required String projectDirectoryPath,
}) async {
  final File packageConfigFile =
      File(path.join(projectDirectoryPath, kDartToolFolderName, 'package_config.json'));

  if (!await packageConfigFile.exists()) {
    throw const DartToolFolderNotFoundException();
  }

  final Map<dynamic, dynamic> packageConfigJson =
      await packageConfigFile.readAsString().then((String value) => jsonDecode(value));

  final List<PackageInfo> packages = <PackageInfo>[
    for (final Map<dynamic, dynamic> packageJson in packageConfigJson['packages'])
      PackageInfo.fromJson(packageJson)
  ];

  final List<ExternalPluginConfig> validExternalPluginsConfigs = <ExternalPluginConfig>[];

  final TachyonConfig tachyonConfig = tachyon.getConfig();
  if (tachyonConfig.plugins.isEmpty) {
    tachyon.logger.warning('~ No plugins found.. skipping');
    return;
  }

  tachyon.logger.info('~ Setting up ${tachyonConfig.plugins.length} plugins');

  for (final String pluginName in tachyon.getConfig().plugins) {
    final PackageInfo? package =
        packages.firstWhereOrNull((PackageInfo package) => package.name == pluginName);
    if (package == null) {
      tachyon.logger.warning('$pluginName not found.. skipping');
      continue;
    }

    final File pluginConfigurationFile = File(
      path.join(
        path.isRelative(package.rootUri.path)
            ? path.canonicalize(path.join(
                projectDirectoryPath,
                kDartToolFolderName,
                package.rootUri.path,
              ))
            : package.rootUri.path,
        kTachyonPluginConfigFileName,
      ),
    );
    if (!await pluginConfigurationFile.exists()) {
      tachyon.logger.warning('$kTachyonPluginConfigFileName not found for plugin $pluginName');
      continue;
    }

    final ExternalPluginConfig externalPluginConfig = await pluginConfigurationFile
        .readAsString()
        .then((String value) => loadYaml(value))
        .then((dynamic value) => ExternalPluginConfig.fromJson(value as YamlMap));

    validExternalPluginsConfigs.add(externalPluginConfig);
  }

  if (validExternalPluginsConfigs.isEmpty) {
    return;
  }

  final List<RegisterApiMessage> externalPluginsRegisterApiMessage = <RegisterApiMessage>[];
  final File dartProgram = await File(path.join(
    projectDirectoryPath,
    kDartToolFolderName,
    'tachyon',
    'main.dart',
  )).create(recursive: true);
  await dartProgram.writeAsString(_pluginMainDartTemplate(validExternalPluginsConfigs));

  final Completer<void> pluginsSetupCompleter = Completer<void>();
  final ReceivePort mainIsolateReceivePort = ReceivePort();

  final Stream<ApiMessage> apiMessageStream = mainIsolateReceivePort
      .asBroadcastStream()
      .cast<Map<dynamic, dynamic>>()
      .map<ApiMessage>(ApiMessage.fromJson);

  void onApiMessageReceived(ApiMessage message) async {
    if (message is RegisterApiMessage) {
      externalPluginsRegisterApiMessage.add(message);
      if (externalPluginsRegisterApiMessage.length == validExternalPluginsConfigs.length) {
        pluginsSetupCompleter.complete();
      }
      return;
    }

    if (message is FindClassOrEnumDeclarationApiMessage) {
      final ClassOrEnumDeclarationMatch? match = await tachyon.declarationFinder
          .findClassOrEnumDeclarationByName(message.name, targetFilePath: message.targetFilePath);
      message.sendPort.send(FindClassOrEnumDeclarationResultApiMessage(
        id: message.id,
        matchFilePath: match?.filePath,
      ).toJson());
      return;
    }

    if (message is LogApiMessage) {
      tachyon.logger.write(message.log);
      return;
    }
  }

  final StreamSubscription<dynamic> apiMessageSubscription =
      apiMessageStream.listen(onApiMessageReceived);

  final Isolate isolate = await Isolate.spawnUri(
    dartProgram.uri,
    const <String>[],
    mainIsolateReceivePort.sendPort,
    errorsAreFatal: false,
    checked: false,
  );

  await pluginsSetupCompleter.future;

  tachyon.addDisposeHook(() async {
    await apiMessageSubscription.cancel();
    mainIsolateReceivePort.close();
    isolate.kill();
  });

  final Map<String, SimpleIdGenerator> pluginNameToIdGenerator = <String, SimpleIdGenerator>{
    for (final RegisterApiMessage message in externalPluginsRegisterApiMessage)
      message.pluginName: SimpleIdGenerator(name: message.pluginName),
  };

  tachyon.addCodeGenerationHook((CompilationUnit compilationUnit, String absoluteFilePath) async {
    Map<String, RegisterApiMessage> pluginNameToRegisterApiMessage = <String, RegisterApiMessage>{};
    // Gather all plugins that can handle the annotations found in this compilation unit
    for (final CompilationUnitMember member in compilationUnit.declarations) {
      final List<RegisterApiMessage> registerApiMessages =
          externalPluginsRegisterApiMessage.where((RegisterApiMessage message) {
        return message.supportedAnnotations
            .any((String annotation) => member.metadata.hasAnnotationWithName(annotation));
      }).toList(growable: false);
      for (final RegisterApiMessage match in registerApiMessages) {
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
        projectDirectoryPath: projectDirectoryPath,
        absoluteFilePath: absoluteFilePath,
      ).toJson());

      final ApiMessage generatedCodeApiMessage = await apiMessageStream
          .firstWhere((ApiMessage message) => message.id == fileModifiedMessageId)
          .timeout(const Duration(seconds: 5))
          .catchError((Object e) => const UnknownApiMessage());

      if (generatedCodeApiMessage is GeneratedCodeApiMessage &&
          generatedCodeApiMessage.code != null) {
        buffer.write(generatedCodeApiMessage.code);
      }
    }

    await Future.wait(<Future<void>>[
      for (final RegisterApiMessage message in pluginNameToRegisterApiMessage.values)
        informPluginForFileChange(message.pluginName, message.sendPort)
    ]);

    return buffer.toString();
  });

  tachyon.logger.info(
    '~ Registered ${externalPluginsRegisterApiMessage.length} out of ${tachyonConfig.plugins.length} plugins',
  );
}
