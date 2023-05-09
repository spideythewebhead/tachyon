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
