import 'dart:math';

const int _kMaxId = 1 << 32;

/// A unique id generator that prefixes the id with the given [name]
class SimpleIdGenerator {
  SimpleIdGenerator({
    required this.name,
  });

  final String name;

  final Random _randomNumberGenerator = Random();

  String getNext() {
    return '$name:${_randomNumberGenerator.nextInt(_kMaxId)}';
  }
}
