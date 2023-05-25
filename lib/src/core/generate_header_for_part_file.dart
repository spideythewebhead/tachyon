import 'package:path/path.dart' as path;

String generateHeaderForPartFile(String targetFilePath) {
  return (StringBuffer()
        ..writeln('// AUTO GENERATED - DO NOT MODIFY')
        ..writeln('// ignore_for_file: type=lint')
        ..writeln('// coverage:ignore-file')
        ..writeln()
        ..writeln("part of '${path.basename(targetFilePath)}';")
        ..writeln())
      .toString();
}
