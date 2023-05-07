/// Base class for exceptions thrown by Tachyon
abstract class TachyonException implements Exception {
  const TachyonException();
}

class PubspecYamlNotFoundException implements TachyonException {
  const PubspecYamlNotFoundException();
}

class RequiresFileGenerationModeException implements TachyonException {
  const RequiresFileGenerationModeException();
}

class DartToolFolderNotFoundException implements TachyonException {
  const DartToolFolderNotFoundException();
}

class PackageNotFoundException implements TachyonException {
  const PackageNotFoundException(this.packageName);

  final String packageName;
}

class MissingDataClassPluginImportException implements TachyonException {
  const MissingDataClassPluginImportException(this.relativeFilePath);

  final String relativeFilePath;
}

class TachyonConfigNotFoundException implements TachyonException {
  const TachyonConfigNotFoundException();
}
