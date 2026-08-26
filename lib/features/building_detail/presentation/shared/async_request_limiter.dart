part of '../building_detail_page.dart';

class _AsyncRequestLimiter {
  _AsyncRequestLimiter({required this.maxConcurrent})
    : assert(maxConcurrent > 0);

  final int maxConcurrent;
  final Queue<Future<void> Function()> _queue =
      Queue<Future<void> Function()>();
  int _activeCount = 0;

  Future<T> schedule<T>(Future<T> Function() action) {
    final Completer<T> completer = Completer<T>();
    _queue.add(() async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    _drain();
    return completer.future;
  }

  void _drain() {
    while (_activeCount < maxConcurrent && _queue.isNotEmpty) {
      final Future<void> Function() task = _queue.removeFirst();
      _activeCount += 1;
      unawaited(
        task().whenComplete(() {
          _activeCount -= 1;
          _drain();
        }),
      );
    }
  }
}
