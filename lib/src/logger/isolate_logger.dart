import 'dart:isolate';

import 'package:stack_trace/stack_trace.dart';
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/logger/ansi.dart';
import 'package:tachyon/src/logger/logger.dart';
import 'package:tachyon/src/plugin_api/api/api_message.dart';
import 'package:tachyon/src/plugin_api/simple_id_generator.dart';

/// A specialized case for a [Logger] that uses a [SendPort] to send logs from an isolate to main thread
/// so plugins can use the [stdout] to print any custom logs
///
/// TODO(pantelis): Batch the logs into 1 call
class IsolateLogger extends Logger {
  IsolateLogger({
    required SimpleIdGenerator idGenerator,
    required SendPort sendPort,
  })  : _idGenerator = idGenerator,
        _sendPort = sendPort;

  final SendPort _sendPort;
  final SimpleIdGenerator _idGenerator;

  @override
  void info([final Object? object]) {
    log('$object'.blue(), LogSeverity.info);
  }

  @override
  void debug([final Object? object]) {
    log('$object'.cyan(), LogSeverity.debug);
  }

  @override
  void warning([final Object? object]) {
    log('$object'.yellow(), LogSeverity.warning);
  }

  @override
  void error(
    final Object? error, [
    final StackTrace? st,
    final bool isFatal = false,
  ]) {
    final StringBuffer buffer = StringBuffer()..writeln('$error'.red());
    if (st != null) {
      buffer
        ..writeln(Ansi.horizontalLine())
        ..write('Stacktrace:'.red().bold())
        ..write(' ')
        ..writeln('$st'.red())
        ..writeln(Ansi.horizontalLine());
    }
    log(buffer, LogSeverity.error);
  }

  @override
  void exception(
    final Object? error, [
    final StackTrace? st,
    final bool isFatal = false,
  ]) {
    final StringBuffer buffer = StringBuffer()
      ..writeln(Ansi.horizontalLine())
      ..writeln('An exception was thrown:'.red().bold())
      ..writeln(error.toString().red());

    final StackTrace stackTrace = st ?? Trace(<Frame>[Trace.current(1).frames[0]]);
    buffer
      ..writeln(Ansi.horizontalLine())
      ..writeln('Stacktrace:'.red().bold())
      ..writeln('$stackTrace'.red())
      ..writeln(Ansi.horizontalLine());

    write(buffer);
  }

  @override
  void logHeader(LogHeader header) {
    final StringBuffer buffer = StringBuffer();
    final String line = Ansi.horizontalLine(
      length: header.lineLength,
      style: header.lineStyle,
    ).bold();

    buffer
      ..writeln(line)
      ..writeln(
        header.title //
            .padLeft((header.title.length + header.lineLength) ~/ 2)
            .blue()
            .bold(),
      );

    if (header.subtitle != null && header.subtitle!.isNotEmpty) {
      buffer.writeln(header.subtitle!.padLeft((header.subtitle!.length + header.lineLength) ~/ 2));
    }
    buffer.writeln(line);

    writeln(buffer);
  }

  @override
  void write([Object? object]) {
    _sendPort.send(LogApiMessage(
      id: _idGenerator.getNext(),
      log: object.toString(),
    ).toJson());
  }

  @override
  void writeln([Object? object]) {
    write('$object $kNewLine');
  }

  @override
  Future<void> dispose() async {}
}
