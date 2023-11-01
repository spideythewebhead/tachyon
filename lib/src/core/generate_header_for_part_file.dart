import 'package:path/path.dart' as path;

String generateHeaderForPartFile(String targetFilePath) {
  return (StringBuffer()
        ..writeln('// AUTO GENERATED - DO NOT MODIFY')
        ..writeln('// ignore_for_file: type=lint')
        ..writeln(
            '// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, inference_failure_on_uninitialized_variable, inference_failure_on_function_return_type, inference_failure_on_untyped_parameter, deprecated_member_use_from_same_package')
        ..writeln('// coverage:ignore-file')
        ..writeln()
        ..writeln("part of '${path.basename(targetFilePath)}';")
        ..writeln())
      .toString();
}
