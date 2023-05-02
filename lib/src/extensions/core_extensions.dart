import 'dart:async';
import 'dart:core';

extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    try {
      return firstWhere(test);
    } catch (_) {
      return null;
    }
  }

  T? get firstOrNull => isEmpty ? null : elementAt(0);

  T? lastWhereOrNull(bool Function(T element) test) {
    try {
      return lastWhere(test);
    } catch (_) {
      return null;
    }
  }

  T? get lastOrNull => isEmpty ? null : last;
}

extension ListX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    try {
      return firstWhere(test);
    } catch (_) {
      return null;
    }
  }

  T? get firstOrNull => isEmpty ? null : elementAt(0);

  T? lastWhereOrNull(bool Function(T element) test) {
    try {
      return lastWhere(test);
    } catch (_) {
      return null;
    }
  }

  T? get lastOrNull => isEmpty ? null : last;
}

extension DateTimeX on DateTime {
  Duration getElapsedDuration() {
    return DateTime.now().difference(this);
  }
}

extension CompleterX<T> on Completer<T> {
  void safeComplete([T? value]) {
    if (!isCompleted) {
      complete(value);
    }
  }
}
