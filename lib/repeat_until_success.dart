Future<T> repeatUntilSuccess<T>(
  Future<T> Function() callback, {
  Future<void> Function(Object e) onCatch,
  Duration pause = const Duration(seconds: 3),
}) async {
  T result;

  while (result == null) {
    try {
      result = await callback();
    } catch (error) {
      if (onCatch != null) {
        await onCatch.call(error);
      }
    }

    await Future.delayed(pause);
  }

  return result;
}
