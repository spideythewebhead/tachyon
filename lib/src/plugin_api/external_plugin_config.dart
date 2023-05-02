class ExternalPluginConfig {
  ExternalPluginConfig({
    required this.name,
    required this.codeGenerator,
    required this.annotations,
  });

  factory ExternalPluginConfig.fromJson(Map<dynamic, dynamic> json) {
    return ExternalPluginConfig(
      name: json['name'] as String,
      codeGenerator: ExternalPluginCodeGeneratorConfig.fromJson(
          json['code_generator'] as Map<dynamic, dynamic>),
      annotations: <String>[
        for (final dynamic annotation in (json['annotations'] as List<dynamic>)) annotation,
      ],
    );
  }

  final String name;
  final ExternalPluginCodeGeneratorConfig codeGenerator;
  final List<String> annotations;
}

class ExternalPluginCodeGeneratorConfig {
  ExternalPluginCodeGeneratorConfig({
    required this.file,
    required this.className,
  });

  factory ExternalPluginCodeGeneratorConfig.fromJson(Map<dynamic, dynamic> json) {
    return ExternalPluginCodeGeneratorConfig(
      file: json['file'] as String,
      className: json['className'] as String,
    );
  }

  final String file;
  final String className;
}
