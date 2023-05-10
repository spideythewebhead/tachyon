import 'package:tachyon/tachyon.dart';
import 'package:test/test.dart';

void main() {
  group('getPositionedArgument', () {
    late final CompilationUnit unit;

    setUpAll(() {
      unit = parseString(content: '''
abstract class HttpService {
  @HttpRoute.get('/users')
  Future<HttpResponse> getUsers();
}
''').unit;
    });

    test('Returns positioned string', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final MethodDeclaration method = clazz.methods.first;
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(method.metadata.firstWhereOrNull(
        (Annotation element) => element.name.name.startsWith('HttpRoute'),
      ));

      expect(annotationValueExtractor.getPositionedArgument(0), isNotNull);
      expect(annotationValueExtractor.getPositionedArgument(0), isA<StringLiteral>());
    });

    test('Returns null (not found)', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final MethodDeclaration method = clazz.methods.first;
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(method.metadata.firstWhereOrNull(
        (Annotation element) => element.name.name.startsWith('HttpRoute'),
      ));

      expect(annotationValueExtractor.getPositionedArgument(1), isNull);
    });
  });

  group('getPositioned', () {
    late final CompilationUnit unit;

    setUpAll(() {
      unit = parseString(content: '''
abstract class HttpService {
  @HttpRoute.get('/users')
  Future<HttpResponse> getUsers();
}
''').unit;
    });

    test('Returns positioned string', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final MethodDeclaration method = clazz.methods.first;
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(method.metadata.firstWhereOrNull(
        (Annotation element) => element.name.name.startsWith('HttpRoute'),
      ));

      expect(annotationValueExtractor.getPositionedString(0), equals('/users'));
    });

    test('Returns null (not found)', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final MethodDeclaration method = clazz.methods.first;
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(method.metadata.firstWhereOrNull(
        (Annotation element) => element.name.name.startsWith('HttpRoute'),
      ));

      expect(annotationValueExtractor.getPositionedString(1), isNull);
    });
  });

  group('getString', () {
    late final CompilationUnit unit;

    setUpAll(() {
      unit = parseString(content: '''
@DataClass(constructorName: '_')
abstract class User {}
''').unit;
    });

    test('Returns value for named argument', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(clazz.metadata.getAnnotationWithName('DataClass'));

      expect(annotationValueExtractor.getString('constructorName'), equals('_'));
    });

    test('Returns null (not found)', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(clazz.metadata.getAnnotationWithName('DataClass'));

      expect(annotationValueExtractor.getString('name'), isNull);
    });
  });

  group('getBool', () {
    late final CompilationUnit unit;

    setUpAll(() {
      unit = parseString(content: '''
@DataClass(fromJson: true)
abstract class User {}
''').unit;
    });

    test('Returns value for named argument', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(clazz.metadata.getAnnotationWithName('DataClass'));

      expect(annotationValueExtractor.getBool('fromJson'), isTrue);
    });

    test('Returns null (not found)', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(clazz.metadata.getAnnotationWithName('DataClass'));

      expect(annotationValueExtractor.getString('json'), isNull);
    });
  });

  group('getEnumValue', () {
    late final CompilationUnit unit;

    setUpAll(() {
      unit = parseString(content: '''
@DataClass()
abstract class User {
  @JsonKey(nameConvention: JsonKeyNameConvention.snakeCase)
  String get username;
}
''').unit;
    });

    test('Returns value for named argument', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final MethodDeclaration field =
          clazz.methods.firstWhere((MethodDeclaration method) => method.name.lexeme == 'username');
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(field.metadata.getAnnotationWithName('JsonKey'));

      expect(annotationValueExtractor.getEnumValue('nameConvention'), equals('snakeCase'));
    });

    test('Returns null (not found)', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final MethodDeclaration field =
          clazz.methods.firstWhere((MethodDeclaration method) => method.name.lexeme == 'username');
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(field.metadata.getAnnotationWithName('JsonKey'));

      expect(annotationValueExtractor.getString('name'), isNull);
    });
  });

  group('getEnumValue', () {
    late final CompilationUnit unit;

    setUpAll(() {
      unit = parseString(content: '''
@DataClass()
abstract class User {
  @JsonKey(fromJson: _usernameFromJson)
  String get username;
}
''').unit;
    });

    test('Returns value for named argument', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final MethodDeclaration field =
          clazz.methods.firstWhere((MethodDeclaration method) => method.name.lexeme == 'username');
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(field.metadata.getAnnotationWithName('JsonKey'));

      expect(annotationValueExtractor.getFunction('fromJson'), equals('_usernameFromJson'));
    });

    test('Returns null (not found)', () {
      final ClassDeclaration clazz = unit.classDeclarations.first;
      final MethodDeclaration field =
          clazz.methods.firstWhere((MethodDeclaration method) => method.name.lexeme == 'username');
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(field.metadata.getAnnotationWithName('JsonKey'));

      expect(annotationValueExtractor.getFunction('json'), isNull);
    });
  });

  group('getNamedConstructorName', () {
    test('Returns constructor name', () {
      final CompilationUnit unit = parseString(content: '''
abstract class HttpService {
  @HttpRoute.get('/users')
  Future<HttpResponse> getUsers();
}
''').unit;

      final ClassDeclaration clazz = unit.classDeclarations.first;
      final MethodDeclaration method = clazz.methods.first;
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(method.metadata.firstWhereOrNull(
        (Annotation element) => element.name.name.startsWith('HttpRoute'),
      ));

      expect(annotationValueExtractor.getNamedConstructorName(), equals('get'));
    });

    test('Returns null (not found)', () {
      final CompilationUnit unit = parseString(content: '''
@DataClass()
abstract class User {}
''').unit;

      final ClassDeclaration clazz = unit.classDeclarations.first;
      final AnnotationValueExtractor annotationValueExtractor =
          AnnotationValueExtractor(clazz.metadata.getAnnotationWithName('DataClass'));

      expect(annotationValueExtractor.getNamedConstructorName(), isNull);
    });
  });
}
