## 0.3.2

- Fix: Active write completer never being remove from the active writes map

## 0.3.1

- Remove dependency on rxdart
- Fix: Tachyon being disposed twice in "watch" command

## 0.3.0

- Fix: Not able to build when for in is used with pattern matching

## 0.2.2

- Fix: Unable to find from/to json methods for enums
- Handle watcher crashes
- Update README with vscode issue

## 0.2.1

- Lower meta and stack_trace dependencies to solve conflicts with flutter_test

## 0.2.0

- Add function declaration method support in DeclarationFinder
- Add ability to reload plugins without re-running tachyon
- Add ability to get a named argument (expression) in AnnotationValueExtractor
- Add "discarded_futures" in analysis_options.yaml
- Update "ignore_for_file" for generated files

## 0.1.0

- Bump dependencies versions to latest

## 0.0.9

- Fix not resolving classes correctly on Windows

## 0.0.8

- Bump dart sdk minimum version to 3.1.0
- Bump "watcher" to ^1.1.0

## 0.0.7

- Fix tachyon build crashing when using flutter > generate: true

## 0.0.6

- Update "analyzer" dependency to 5.13.0
- Fix registerPlugins path resolving on Windows

## 0.0.5

- Improved rebuild for circular dependencies
- Fix deprecation lints

## 0.0.4

- Improved indexing
- Improved rebuilding on watch mode

## 0.0.3

- Added tests
- Added prefix support for `CustomDartType`
  - If a symbol is using a prefix (import as) this will be included now as `prefix`
  - Renamed `CustomDartType` to `TachyonDartType`
- Improvements for `AnnotationValueExtractor`
- Improvements for `findDartFileFromDirectiveUri`
- Improvements for plugins registrations
- Generated files will now be excluded from coverage

## 0.0.2

- Improve naming of the API
- Improve running plugins code generation "simultaneously"
- Improve IsolateLogger batching multiple writes into 1 message
- Improve documentation
- Bug fixes

  - `findDartFileFromUri` (now `findDartFileFromDirectiveUri`) would return wrong path for a relative import/export
  - IsolateLogger not respecting severity when printing

## 0.0.1

- Initial version.
