import 'dart:isolate';

typedef _ApiMessageFromJson = ApiMessage Function(Map<dynamic, dynamic> json);

final Map<String, _ApiMessageFromJson> _fromJsonMapper = <String, _ApiMessageFromJson>{
  RegisterApiMessage._kName: RegisterApiMessage.fromJson,
  FileModifiedApiMessage._kName: FileModifiedApiMessage.fromJson,
  GeneratedCodeApiMessage._kName: GeneratedCodeApiMessage.fromJson,
  FindDeclarationApiMessage._kName: FindDeclarationApiMessage.fromJson,
  FindDeclarationResultApiMessage._kName: FindDeclarationResultApiMessage.fromJson,
};

/// Base class for messages between isolates used in plugins
///
/// As isolates can only pass basic data structures the messages are transformed to and from maps (JSON)
abstract class ApiMessage {
  const ApiMessage();

  factory ApiMessage.fromJson(Map<dynamic, dynamic> json) {
    return _fromJsonMapper[json['_message']]?.call(json) ?? const UnknownApiMessage();
  }

  String get id;

  Map<String, dynamic> toJson();
}

class RegisterApiMessage implements ApiMessage {
  static const String _kName = 'register';

  RegisterApiMessage({
    required this.id,
    required this.pluginName,
    required this.sendPort,
    required this.supportedAnnotations,
  });

  factory RegisterApiMessage.fromJson(Map<dynamic, dynamic> json) {
    return RegisterApiMessage(
      id: json['id'] as String,
      pluginName: json['pluginName'] as String,
      sendPort: json['sendPort'] as SendPort,
      supportedAnnotations: <String>[
        for (final dynamic annotation in (json['supportedAnnotations'] as List<dynamic>))
          annotation,
      ],
    );
  }

  @override
  final String id;
  final String pluginName;
  final SendPort sendPort;
  final List<String> supportedAnnotations;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_message': _kName,
      'id': id,
      'pluginName': pluginName,
      'sendPort': sendPort,
      'supportedAnnotations': supportedAnnotations,
    };
  }
}

class FileModifiedApiMessage implements ApiMessage {
  static const String _kName = 'file_modified';

  FileModifiedApiMessage({
    required this.id,
    required this.projectDirectoryPath,
    required this.absoluteFilePath,
  });

  factory FileModifiedApiMessage.fromJson(Map<dynamic, dynamic> json) {
    return FileModifiedApiMessage(
      id: json['id'] as String,
      projectDirectoryPath: json['projectDirectoryPath'] as String,
      absoluteFilePath: json['absoluteFilePath'] as String,
    );
  }

  @override
  final String id;
  final String projectDirectoryPath;
  final String absoluteFilePath;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_message': _kName,
      'id': id,
      'projectDirectoryPath': projectDirectoryPath,
      'absoluteFilePath': absoluteFilePath,
    };
  }
}

class GeneratedCodeApiMessage implements ApiMessage {
  static const String _kName = 'generated_code';

  GeneratedCodeApiMessage({
    required this.id,
    this.code,
  });

  factory GeneratedCodeApiMessage.fromJson(Map<dynamic, dynamic> json) {
    return GeneratedCodeApiMessage(
      id: json['id'] as String,
      code: json['code'] as String?,
    );
  }

  @override
  final String id;
  final String? code;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_message': _kName,
      'id': id,
      'code': code,
    };
  }
}

class FindDeclarationApiMessage implements ApiMessage {
  static const String _kName = 'find_declaration';

  FindDeclarationApiMessage({
    required this.id,
    required this.name,
    required this.targetFilePath,
    required this.sendPort,
    required this.type,
  });

  factory FindDeclarationApiMessage.fromJson(Map<dynamic, dynamic> json) {
    return FindDeclarationApiMessage(
      id: json['id'] as String,
      name: json['name'] as String,
      targetFilePath: json['targetFilePath'] as String,
      sendPort: json['sendPort'] as SendPort,
      type: FindDeclarationType.values.firstWhere(
        (FindDeclarationType type) => type.name == json['type'],
      ),
    );
  }

  @override
  final String id;
  final String name;
  final String targetFilePath;
  final SendPort sendPort;
  final FindDeclarationType type;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_message': _kName,
      'id': id,
      'name': name,
      'targetFilePath': targetFilePath,
      'sendPort': sendPort,
      'type': type.name,
    };
  }
}

enum FindDeclarationType {
  classOrEnum,
  function,
}

class FindDeclarationResultApiMessage implements ApiMessage {
  static const String _kName = 'find_declaration_result';

  FindDeclarationResultApiMessage({
    required this.id,
    this.matchFilePath,
    this.unitMemberContent,
  });

  factory FindDeclarationResultApiMessage.fromJson(Map<dynamic, dynamic> json) {
    return FindDeclarationResultApiMessage(
      id: json['id'] as String,
      matchFilePath: json['matchFilePath'] as String?,
      unitMemberContent: json['unitMemberContent'] as String?,
    );
  }

  @override
  final String id;
  final String? matchFilePath;
  final String? unitMemberContent;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_message': _kName,
      'id': id,
      'matchFilePath': matchFilePath,
      'unitMemberContent': unitMemberContent,
    };
  }
}

class UnknownApiMessage implements ApiMessage {
  const UnknownApiMessage();

  @override
  String get id => '';

  @override
  Map<String, dynamic> toJson() {
    return const <String, dynamic>{};
  }
}
