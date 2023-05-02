import 'dart:io';

String kNewLine = () {
  if (Platform.isWindows) {
    return '\r\n';
  }
  return '\n';
}();
