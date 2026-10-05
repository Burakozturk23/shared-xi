import 'dart:async';

/// Owns one upstream subscription and replays the latest snapshot to each tab.
/// A single-subscription Firebase mapping must not be listened to a second time.
class ReplayStream<T> {
  ReplayStream(Stream<T> source) {
    stream = Stream<T>.multi((listener) {
      if (_hasValue) listener.add(_value as T);
      if (_error != null) listener.addError(_error!, _stack);
      if (_done) {
        listener.close();
        return;
      }
      _listeners.add(listener);
      listener.onCancel = () {
        _listeners.remove(listener);
      };
    });
    _subscription = source.listen(
      (value) {
        _value = value;
        _hasValue = true;
        _error = null;
        for (final listener in _listeners.toList()) {
          listener.add(value);
        }
      },
      onError: (Object error, StackTrace stack) {
        _error = error;
        _stack = stack;
        for (final listener in _listeners.toList()) {
          listener.addError(error, stack);
        }
      },
      onDone: () {
        _done = true;
        for (final listener in _listeners.toList()) {
          listener.close();
        }
        _listeners.clear();
      },
    );
  }
  late final Stream<T> stream;
  late final StreamSubscription<T> _subscription;
  final _listeners = <MultiStreamController<T>>{};
  T? _value;
  Object? _error;
  StackTrace? _stack;
  bool _hasValue = false, _done = false;
  Future<void> dispose() async {
    _done = true;
    await _subscription.cancel();
    for (final listener in _listeners.toList()) {
      listener.close();
    }
    _listeners.clear();
  }
}
