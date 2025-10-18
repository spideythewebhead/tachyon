import 'package:glob/glob.dart';

/// Data class for tachyon_config.yaml
class TachyonConfig {
  TachyonConfig({
    required this.fileGenerationPaths,
    required this.generatedFileLineLength,
    this.plugins = const <String>[],
    this.externalPackages = const <String, ExternalPackageConfig>{},
  });

  factory TachyonConfig.fromJson(Map<dynamic, dynamic> json) {
    return TachyonConfig(
      fileGenerationPaths: json['file_generation_paths'] == null
          ? const <Glob>[]
          : List<Glob>.unmodifiable(<Glob>[
              for (final String path in (json['file_generation_paths'] as List<dynamic>))
                Glob(path),
            ]),
      externalPackages: json['external_packages'] == null
          ? const <String, ExternalPackageConfig>{}
          : <String, ExternalPackageConfig>{
              for (final MapEntry<dynamic, dynamic> entry
                  in (json['external_packages'] as Map<dynamic, dynamic>).entries)
                entry.key as String: ExternalPackageConfig.fromJson(
                  entry.key as String,
                  entry.value ?? const <dynamic, dynamic>{},
                )
            },
      generatedFileLineLength: json['generated_file_line_length'] as int? ?? 80,
      plugins: json['plugins'] == null
          ? const <String>[]
          : List<String>.unmodifiable(<String>[
              for (final dynamic entry in (json['plugins'] as List<dynamic>)) entry,
            ]),
    );
  }

  final List<Glob> fileGenerationPaths;
  final Map<String, ExternalPackageConfig> externalPackages;

  @Deprecated('Should use "formatter.page_width" in "analysis_options.yaml"')
  final int generatedFileLineLength;

  final List<String> plugins;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'file_generation_paths': <String>[
        for (final Glob glob in fileGenerationPaths) glob.pattern,
      ],
      'external_packages': externalPackages,
      'generated_file_line_length': generatedFileLineLength,
      'plugins': <String>[
        for (final String plugin in plugins) plugin,
      ]
    };
  }
}

class ExternalPackageConfig {
  const ExternalPackageConfig({
    required this.name,
    required this.fileGenerationPaths,
  });

  factory ExternalPackageConfig.fromJson(String name, Map<dynamic, dynamic> json) {
    return ExternalPackageConfig(
      name: name,
      fileGenerationPaths: json['file_generation_paths'] == null
          ? const <Glob>[]
          : List<Glob>.unmodifiable(<Glob>[
              for (final String path in (json['file_generation_paths'] as List<dynamic>))
                Glob(path),
            ]),
    );
  }

  final String name;
  final List<Glob> fileGenerationPaths;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'file_generation_paths': <String>[
        for (final Glob glob in fileGenerationPaths) glob.pattern,
      ],
    };
  }
}
