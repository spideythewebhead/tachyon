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
