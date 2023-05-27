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
    if (message is FileModifiedApiMessage) {
      final CompilationUnit unit = parseString(
        content: message.fileContent,
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
  });

  tachyonSendPort.send(RegisterApiMessage(
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

Future<List<TachyonPluginRegistrationResult>> registerPlugins({
  required Tachyon tachyon,
  required String projectDirPath,
}) async {
  final File packageConfigFile = Tachyon.fileSystem
      .file(path.join(projectDirPath, kDartToolFolderName, 'package_config.json'));

  if (!await packageConfigFile.exists()) {
    throw const DartToolPackageConfigNotFoundException();
  }

  final List<PackageInfo> packages = await packageConfigFile
      .readAsString()
      .then((String value) => jsonDecode(value) as Map<dynamic, dynamic>)
      .then((Map<dynamic, dynamic> json) {
    return <PackageInfo>[
      for (final Map<dynamic, dynamic> packageJson in json['packages'])
        PackageInfo.fromJson(packageJson)
    ];
  });

  final List<TachyonPluginRegistrationResult> pluginsRegistrationResults =
      <TachyonPluginRegistrationResult>[];
  final List<ExternalPluginConfig> validExternalPluginsConfigs = <ExternalPluginConfig>[];

  final TachyonConfig tachyonConfig = tachyon.getConfig();
  if (tachyonConfig.plugins.isEmpty) {
    tachyon.logger.warning('~ No plugins found.. skipping');
    return pluginsRegistrationResults;
  }

  tachyon.logger.info('~ Setting up ${tachyonConfig.plugins.length} plugins');

  // Checks the following for all the declared plugins
  //
  // 1. If it's declared on ".dart_tool/package_config.json", meaning that "pub get" has been run for this plugin
  // 2. If the plugin's configuration exists ("tachyon_plugin_config.yaml" file)
  for (final String pluginName in tachyon.getConfig().plugins) {
    final PackageInfo? package =
        packages.firstWhereOrNull((PackageInfo package) => package.name == pluginName);
    if (package == null) {
      pluginsRegistrationResults
          .add(TachyonPluginRegistrationResult(pluginName: pluginName, isRegistered: false));
      tachyon.logger.warning(
          '$pluginName not found. Run ${"pub get".red()} to fix or check ${"pubspec.yaml".red()} for the existence of the dependency. ${"Skipping this plugin".bold()}');
      continue;
    }

    final File pluginConfigurationFile = Tachyon.fileSystem.file(
      path.join(
        path.isRelative(package.rootUri.path)
            ?
            // The root uri is relative to the project's directory
            path.canonicalize(path.join(
                projectDirPath,
                kDartToolFolderName,
                package.rootUri.path,
              ))
            : package.rootUri.path,
        kTachyonPluginConfigFileName,
      ),
    );
    if (!await pluginConfigurationFile.exists()) {
      pluginsRegistrationResults
          .add(TachyonPluginRegistrationResult(pluginName: pluginName, isRegistered: false));
      tachyon.logger
          .warning('${kTachyonPluginConfigFileName.bold()} not found for plugin $pluginName');
      continue;
    }

    try {
      final ExternalPluginConfig pluginConfig = await pluginConfigurationFile
          .readAsString()
          .then((String value) => loadYaml(value) as YamlMap)
          .then((YamlMap value) => ExternalPluginConfig.fromJson(value));

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
    return pluginsRegistrationResults;
  }

  final List<RegisterApiMessage> externalPluginsRegisterApiMessage = <RegisterApiMessage>[];
  final File dartProgram = await Tachyon.fileSystem
      .file(path.join(
        projectDirPath,
        kDartToolFolderName,
        'tachyon',
        'main.dart',
      ))
      .create(recursive: true);
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
        unitMemberContent: match?.node.toSource(),
      ).toJson());
      return;
    }
  }

  final StreamSubscription<dynamic> apiMessageSubscription =
      apiMessageStream.listen(onApiMessageReceived);

  final Isolate isolate = await Isolate.spawnUri(
    dartProgram.uri,
    const <String>[],
    mainIsolateReceivePort.sendPort,
    errorsAreFatal: true,
    checked: false,
    packageConfig:
        Uri.parse(path.join(tachyon.projectDir.path, kDartToolFolderName, 'package_config.json')),
  );

  await pluginsSetupCompleter.future;

  // Clear resources when Tachyon is disposed
  tachyon.addDisposeHook(() async {
    await apiMessageSubscription.cancel();
    mainIsolateReceivePort.close();
    isolate.kill();
  });

  final Map<String, SimpleIdGenerator> pluginNameToIdGenerator = <String, SimpleIdGenerator>{
    for (final RegisterApiMessage message in externalPluginsRegisterApiMessage)
      message.pluginName: SimpleIdGenerator(name: message.pluginName),
  };

  // This hook is called everytime a file change occurs
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
        projectDirectoryPath: projectDirPath,
        absoluteFilePath: absoluteFilePath,
        fileContent: compilationUnit.toSource(),
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
      for (final RegisterApiMessage message in pluginNameToRegisterApiMessage.values)
        informPluginForFileChange(message.pluginName, message.sendPort)
    ]);

    return buffer.toString();
  });

  tachyon.logger.info(
    '~ Registered ${externalPluginsRegisterApiMessage.length} out of ${tachyonConfig.plugins.length} plugins',
  );

  return pluginsRegistrationResults;
}
