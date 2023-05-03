import 'dart:collection';

import 'package:example/generator/annotations.dart';

part 'example.gen.dart';

@ProvideExceptions(<String>[
  'notFound',
  'invalidFormat',
])
class PubspecYaml {}

@ProvideExceptions(<String>[
  'notFound',
  'permissionDenied',
  'osError',
])
class FileReader {}

@ProvideExceptions(<String>[
  'outOfBounds',
  'notImplemented',
])
class MyList<T> with ListMixin<T> {
  @override
  int get length => 0;

  @override
  set length(int newLength) {}

  @override
  T operator [](int index) {
    if (index < 0 || index >= length) {
      throw MyListException.outOfBounds('Invalid index at position $index.');
    }
    throw MyListException.notImplemented();
  }

  @override
  void operator []=(int index, T value) {
    if (index < 0 || index >= length) {
      throw MyListException.outOfBounds();
    }
  }
}
