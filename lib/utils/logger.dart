String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _timestamp() {
  final now = DateTime.now();
  final millis = now.millisecond.toString().padLeft(3, '0');
  return '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} '
      '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:'
      '${_twoDigits(now.second)}.$millis';
}

void logWithTime(String message) {
  final ts = _timestamp();
  // ignore: avoid_print
  print('[$ts] $message');
}
