import 'dart:math';

const int _kMaxId = 1 << 32;

class SimpleIdGenerator {
  SimpleIdGenerator({
    required this.name,
  });

  final String name;

  final Random _randomNumberGenerator = Random.secure();

  String getNext() {
    return '$name:${_randomNumberGenerator.nextInt(_kMaxId)}';
  }
}
