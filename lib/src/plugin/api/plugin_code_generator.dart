import 'dart:async';

import 'package:tachyon/src/logger/logger.dart';
import 'package:tachyon/src/plugin/api/declaration_finder.dart';
import 'package:tachyon/src/plugin/api/file_change_build_info.dart';

/// Interface for a code generator created by a plugin
///
/// [generate] Provides a list of parameters that
abstract class TachyonPluginCodeGenerator {
  TachyonPluginCodeGenerator();

  /// Generates the code for a plugin
  ///
  /// 1. [buildInfo] contains some basic information for the target file
  /// 2. [declarationFinder] a helper that allows to find a class or enum on a project
  /// 3. [logger] basic logger
  FutureOr<String> generate(
    FileChangeBuildInfo buildInfo,
    TachyonDeclarationFinder declarationFinder,
    Logger logger,
  );
}
