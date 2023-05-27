import 'dart:io';

/// On Windows uses `\r\n` otherwise uses `\n`
final String kNewLine = () {
  if (Platform.isWindows) {
    return '\r\n';
  }
  return '\n';
}();

const String kPubspecYamlFileName = 'pubspec.yaml';
const String kTachyonConfigFileName = 'tachyon_config.yaml';
const String kTachyonPluginConfigFileName = 'tachyon_plugin_config.yaml';
const String kDartToolFolderName = '.dart_tool';

const String kIssueReportUrl = 'https://github.com/spideythewebhead/tachyon/issues';
