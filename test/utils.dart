import 'package:file/file.dart';
import 'package:tachyon/tachyon.dart';

class NoOpLogger extends Logger {
  const NoOpLogger();

  @override
  void debug([Object? object]) {}

  @override
  Future<void> dispose() async {}

  @override
  void error(Object? error, [StackTrace? st, bool isFatal = false]) {}

  @override
  void exception(Object? error, [StackTrace? st, bool isFatal = false]) {}

  @override
  void info([Object? object]) {}

  @override
  void logHeader(LogHeader header) {}

  @override
  void warning([Object? object]) {}

  @override
  void write([Object? object]) {}

  @override
  void writeln([Object? object]) {}
}

extension FileSystemEntityExtension on FileSystemEntity {
  void safelyRecursivelyDeleteSync() {
    try {
      deleteSync(recursive: true);
    } catch (_) {}
  }
}
