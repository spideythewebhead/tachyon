import 'dart:io';

String kNewLine = () {
  if (Platform.isWindows) {
    return '\r\n';
  }
  return '\n';
}();

const String kPubspecYamlFileName = 'pubspec.yaml';
const String kTachyonConfigFileName = 'tachyon_config.yaml';
const String kTachyonPluginConfigFileName = 'tachyon_plugin_config.yaml';
