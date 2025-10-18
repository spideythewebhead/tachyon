class AnalysisOptionsConfig {
  AnalysisOptionsConfig({required this.formatter});

  factory AnalysisOptionsConfig.fromJson(Map<dynamic, dynamic> json) {
    return AnalysisOptionsConfig(
      formatter: FormatterOptionsConfig.fromJson(json['formatter']),
    );
  }

  final FormatterOptionsConfig formatter;
}

class FormatterOptionsConfig {
  FormatterOptionsConfig({
    required this.pageWidth,
    this.trailingCommas,
  });

  factory FormatterOptionsConfig.fromJson(Map<dynamic, dynamic> json) {
    return FormatterOptionsConfig(
      pageWidth: json['page_width'] as int?,
      trailingCommas: FormatterTrailingCommasOption.fromString(json['trailing_commas']),
    );
  }

  final int? pageWidth;
  final FormatterTrailingCommasOption? trailingCommas;
}

enum FormatterTrailingCommasOption {
  preserve,
  ;

  static FormatterTrailingCommasOption? fromString(String? s) {
    if (s == 'preserve') {
      return FormatterTrailingCommasOption.preserve;
    }
    return null;
  }
}
