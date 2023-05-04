import 'package:tachyon/src/cli/commands/arguments.dart';

class GenerateArgumentOption extends ArgumentOption {
  const GenerateArgumentOption({
    required super.name,
    super.abbr,
    super.defaultsTo,
    super.help,
    super.mandatory,
  });

  static const List<GenerateArgumentOption> options = <GenerateArgumentOption>[
    deleteExistingGeneratedFiles,
  ];

  static const GenerateArgumentOption deleteExistingGeneratedFiles = GenerateArgumentOption(
    name: 'delete-generated',
    abbr: 'd',
    defaultsTo: false,
    help: 'Delete all generated files (.gen.dart) before building',
    mandatory: false,
  );
}
