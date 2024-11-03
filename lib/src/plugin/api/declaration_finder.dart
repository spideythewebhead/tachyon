import 'dart:async';
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

  Future<FinderDeclarationMatch<NamedCompilationUnitMember>?> findClassOrEnum(String name) async {
    return _findDeclaration<NamedCompilationUnitMember>(
      name: name,
      findDeclarationType: FindDeclarationType.classOrEnum,
    );
  }

  Future<FinderDeclarationMatch<FunctionDeclaration>?> findFunction(String name) async {
    return _findDeclaration<FunctionDeclaration>(
      name: name,
      findDeclarationType: FindDeclarationType.function,
    );
  }

  Future<FinderDeclarationMatch<T>?> _findDeclaration<T extends NamedCompilationUnitMember>({
    required String name,
    required FindDeclarationType findDeclarationType,
  }) async {
    final String messageId = _idGenerator.getNext();

    _mainSendPort.send(FindDeclarationApiMessage(
      id: messageId,
      name: name,
      targetFilePath: _targetFilePath,
      sendPort: _pluginSendPort,
      type: findDeclarationType,
    ).toJson());

    final ApiMessage message =
        await _stream.firstWhere((ApiMessage message) => message.id == messageId);

    if (message is FindDeclarationResultApiMessage) {
      final String? absoluteFilePath = message.matchFilePath;
      final String? fileContent = message.unitMemberContent;
      if (absoluteFilePath == null || fileContent == null) {
        return null;
      }
      final CompilationUnit unit = parseString(
        content: fileContent,
        path: absoluteFilePath,
        featureSet: FeatureSet.latestLanguageVersion(),
      ).unit;
      final CompilationUnitMember? unitMember = unit.declarations.firstOrNull;
      if (unitMember is T) {
        return FinderDeclarationMatch<T>(
          node: unitMember,
          filePath: absoluteFilePath,
        );
      }
    }

    return null;
  }
}
