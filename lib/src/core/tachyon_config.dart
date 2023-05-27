import 'package:glob/glob.dart';

/// Data class for tachyon_config.yaml
class TachyonConfig {
  TachyonConfig({
    required this.fileGenerationPaths,
    required this.generatedFileLineLength,
    this.plugins = const <String>[],
  });

  factory TachyonConfig.fromJson(Map<dynamic, dynamic> json) {
    return TachyonConfig(
      fileGenerationPaths: json['file_generation_paths'] == null
          ? const <Glob>[]
          : List<Glob>.unmodifiable(<Glob>[
              for (final String path in (json['file_generation_paths'] as List<dynamic>))
                Glob(path),
            ]),
      generatedFileLineLength: json['generated_file_line_length'] as int? ?? 80,
      plugins: json['plugins'] == null
          ? const <String>[]
          : List<String>.unmodifiable(<String>[
              for (final dynamic entry in (json['plugins'] as List<dynamic>)) entry,
            ]),
    );
  }

  final List<Glob> fileGenerationPaths;
  final int generatedFileLineLength;
  final List<String> plugins;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'file_generation_paths': <String>[
        for (final Glob glob in fileGenerationPaths) glob.pattern,
      ],
      'generated_file_line_length': generatedFileLineLength,
      'plugins': <String>[
        for (final String plugin in plugins) plugin,
      ]
    };
  }
}
