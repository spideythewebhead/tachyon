import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:tachyon/tachyon.dart';

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
      final CompilationUnit unit = parseString(
        content: await File(absoluteFilePath).readAsString(),
        featureSet: FeatureSet.latestLanguageVersion(),
      ).unit;
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
