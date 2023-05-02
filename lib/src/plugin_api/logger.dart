import 'dart:isolate';

import 'package:stack_trace/stack_trace.dart';
import 'package:tachyon/src/constants.dart';
import 'package:tachyon/src/logger/ansi.dart';
import 'package:tachyon/src/logger/logger.dart';
import 'package:tachyon/src/plugin_api/api/api_message.dart';
import 'package:tachyon/src/plugin_api/simple_id_generator.dart';

class IsolateLogger extends Logger {
  IsolateLogger({
    required SimpleIdGenerator idGenerator,
    required SendPort sendPort,
  })  : _idGenerator = idGenerator,
        _sendPort = sendPort;

  final SendPort _sendPort;
  final SimpleIdGenerator _idGenerator;

  @override
  void info([Object? object]) {
    log(object, LogSeverity.info);
  }

  @override
  void warning([Object? object]) {
    log(object, LogSeverity.warning);
  }

  @override
  void debug([Object? object]) {
    log(object, LogSeverity.debug);
  }

  @override
  void error(
    final Object? error, [
    final StackTrace? st,
    final bool isFatal = false,
  ]) {
    log('$error'.red(), LogSeverity.error);

    if (st != null) {
      log(Ansi.horizontalLine(), LogSeverity.error);
      log('Stacktrace:'.red().bold(), LogSeverity.error);
      log('$st'.red(), LogSeverity.error);
      log(Ansi.horizontalLine(), LogSeverity.error);
    }
  }

  @override
  void exception(
    final Object? error, [
    final StackTrace? st,
    final bool isFatal = false,
  ]) {
    writeln(Ansi.horizontalLine());
    writeln('An exception was thrown:'.red().bold());
    writeln(error.toString().red());

    final StackTrace stackTrace = st ?? Trace(<Frame>[Trace.current(1).frames[0]]);
    writeln(Ansi.horizontalLine());
    writeln('Stacktrace:'.red().bold());
    writeln('$stackTrace'.red());
    writeln(Ansi.horizontalLine());
  }

  @override
  void logHeader(LogHeader header) {
    final String line = Ansi.horizontalLine(
      length: header.lineLength,
      style: header.lineStyle,
    ).bold();

    writeln(line);
    writeln(
      header.title //
          .padLeft((header.title.length + header.lineLength) ~/ 2)
          .blue()
          .bold(),
    );

    if (header.subtitle != null && header.subtitle!.isNotEmpty) {
      writeln(header.subtitle!.padLeft((header.subtitle!.length + header.lineLength) ~/ 2));
    }
    writeln(line);
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
    write('$object$kNewLine');
  }

  @override
  Future<void> dispose() async {}
}
