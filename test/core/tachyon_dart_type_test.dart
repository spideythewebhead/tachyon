import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

void main() {
  group('basic types', () {
    test('isInt', () {
      final CompilationUnit unit = parseString(content: '''
int variable = 0;
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isInt, equals(true));
      expect(customDartType.isPrimitive, equals(true));
    });

    test('isDouble', () {
      final CompilationUnit unit = parseString(content: '''
double variable = 0.0;
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isDouble, equals(true));
      expect(customDartType.isPrimitive, equals(true));
    });

    test('isNum', () {
      final CompilationUnit unit = parseString(content: '''
num variable = 0;
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isNum, equals(true));
      expect(customDartType.isPrimitive, equals(true));
    });

    test('isString', () {
      final CompilationUnit unit = parseString(content: '''
String variable = '';
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isString, equals(true));
      expect(customDartType.isPrimitive, equals(true));
    });

    test('isDynamic', () {
      final CompilationUnit unit = parseString(content: '''
dynamic variable;
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isDynamic, equals(true));
    });

    test('isBool', () {
      final CompilationUnit unit = parseString(content: '''
bool variable = false;
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isBool, equals(true));
      expect(customDartType.isPrimitive, equals(true));
    });

    test('isDuration', () {
      final CompilationUnit unit = parseString(content: '''
Duration variable = Duration(days: 1);
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isDuration, equals(true));
    });

    test('isDateTime', () {
      final CompilationUnit unit = parseString(content: '''
DateTime variable = DateTime(days: 1);
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isDateTime, equals(true));
    });

    test('isUri', () {
      final CompilationUnit unit = parseString(content: '''
Uri variable = Uri.parse('https://google.com');
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isUri, equals(true));
    });

    test('isList', () {
      final CompilationUnit unit = parseString(content: '''
List<int> variable = <int>[1,2,3];
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isList, equals(true));
      expect(customDartType.isCollection, equals(true));
    });

    test('isMap', () {
      final CompilationUnit unit = parseString(content: '''
Map<int, String> variable = <int, String>[1,2,3];
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isMap, equals(true));
      expect(customDartType.isCollection, equals(true));
    });
  });

  group('nullability', () {
    test('isNullable should be true', () {
      final CompilationUnit unit = parseString(content: '''
int? variable;
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isNullable, equals(true));
    });

    test('isNullable should be false', () {
      final CompilationUnit unit = parseString(content: '''
int variable = 0;
''').unit;

      final TypeAnnotation? typeAnnotation =
          (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
      final TachyonDartType customDartType = typeAnnotation.customDartType;

      expect(customDartType.isNullable, equals(false));
    });
  });

  test('prefix', () {
    final CompilationUnit unit = parseString(content: '''
import './models.dart' as models;
models.User variable = models.User();
''').unit;

    final TypeAnnotation? typeAnnotation =
        (unit.declarations.first as TopLevelVariableDeclaration).variables.type;
    final TachyonDartType customDartType = typeAnnotation.customDartType;

    expect(customDartType.prefix, isNotNull);
    expect(customDartType.prefix, 'models');
    expect(customDartType.name, 'User');
  });
}
