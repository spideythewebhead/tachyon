import 'package:args/command_runner.dart';
import 'package:tachyon/tachyon.dart';

abstract class BaseCommand extends Command<void> {
  BaseCommand({
    required this.logger,
  });

  final Logger logger;

  @override
  String get invocation => '${runner?.executableName} $name [arguments]';

  Future<void> init() async {
    logger.info('> Running command: $name');
  }

  Future<void> execute();

  @override
  Future<void> run() async {
    await init();
    await execute();
    await dispose();
  }

  Future<void> dispose() async {
    logger.info('Thanks for using Tachyon!');
  }
}
