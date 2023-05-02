import 'dart:async';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:tachyon/src/core/declaration_finder.dart';
import 'package:tachyon/src/core/parse_file_extension.dart';
import 'package:tachyon/src/logger/logger.dart';
import 'package:tachyon/src/plugin_api/api/api_message.dart';
import 'package:tachyon/src/plugin_api/simple_id_generator.dart';

export 'package:analyzer/dart/analysis/features.dart';
export 'package:analyzer/dart/analysis/utilities.dart';
export 'package:analyzer/dart/ast/ast.dart';

class TachyonDeclarationFinder {
  TachyonDeclarationFinder({
    required SimpleIdGenerator idGenerator,
    required Stream<ApiMessage> apiMessageStream,
    required SendPort mainSendPort,
    required SendPort pluginSendPort,
    required String targetFilePath,
  })  : _idGenerator = idGenerator,
        _stream = apiMessageStream,
        _mainSendPort = mainSendPort,
        _pluginSendPort = pluginSendPort,
        _targetFilePath = targetFilePath;

  final SimpleIdGenerator _idGenerator;
  final Stream<ApiMessage> _stream;
  final SendPort _mainSendPort;
  final SendPort _pluginSendPort;
  final String _targetFilePath;

  Future<ClassOrEnumDeclarationMatch?> findClassOrEnum(String name) async {
    final String messageId = _idGenerator.getNext();

    _mainSendPort.send(FindClassOrEnumDeclarationApiMessage(
      id: messageId,
      name: name,
      targetFilePath: _targetFilePath,
      sendPort: _pluginSendPort,
    ).toJson());

    final ApiMessage message =
        await _stream.firstWhere((ApiMessage message) => message.id == messageId);
    if (message is FindClassOrEnumDeclarationResultApiMessage) {
      final String? absoluteFilePath = message.matchFilePath;
      if (absoluteFilePath == null) {
        return null;
      }
      final CompilationUnit unit =
          absoluteFilePath.parse(featureSet: FeatureSet.latestLanguageVersion()).unit;
      for (final CompilationUnitMember declaration in unit.declarations) {
        if (declaration is NamedCompilationUnitMember && declaration.name.lexeme == name) {
          return ClassOrEnumDeclarationMatch(
            node: declaration,
            filePath: absoluteFilePath,
          );
        }
      }
    }
    return null;
  }
}

class BuildInfo {
  BuildInfo({
    required this.projectDirectoryPath,
    required this.targetFilePath,
    required this.compilationUnit,
  });

  final String projectDirectoryPath;
  final String targetFilePath;
  final CompilationUnit compilationUnit;
}

abstract class TachyonPluginCodeGenerator {
  TachyonPluginCodeGenerator();

  FutureOr<String> generate(
    BuildInfo buildInfo,
    TachyonDeclarationFinder declarationFinder,
    Logger logger,
  );
}
